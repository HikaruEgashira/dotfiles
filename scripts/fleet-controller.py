#!/usr/bin/env python3
"""Reconcile Fleet with the dotfiles main branch using only Fleet Free APIs.

Fleet Free has no policy-triggered scripts, so this loop does it: read the deploy
branch (CI fast-forwards it to each green main commit), keep a policy that checks each Mac's applied commit,
and run the apply script on Macs that fail it. With MDM on, it also keeps the DNS
profile installed.

usage: fleet-controller.py <state-dir> <api-url> <public-url> <apply-script-template> <enroll-export-path>
"""

import grp
import json
import os
import plistlib
import secrets
import subprocess
import sys
import urllib.error
import urllib.request
import uuid

REPO = "HikaruEgashira/dotfiles"
POLICY_NAME = "dotfiles: applied CI-green main"
SCRIPT_NAME = "dotfiles-apply.sh"
DNS_PROFILE_NAME = "Encrypted DNS"
MAX_ATTEMPTS = 3
SCRIPT_TIMEOUT_S = 3600


def policy_query(sha):
    return f"SELECT 1 FROM plist WHERE path = '/var/db/dotfiles.plist' AND key = 'rev' AND value = '{sha}';"


def render_script(template, sha):
    return template.replace("@TARGET@", sha)


def hosts_to_apply(failing_hosts, pending_host_ids, attempts, sha):
    """Failing Macs without a run in flight and under the retry cap for this commit."""
    out = []
    for host in failing_hosts:
        hid = str(host["id"])
        if host["id"] in pending_host_ids:
            continue
        if attempts.get(hid, {}).get(sha, 0) >= MAX_ATTEMPTS:
            continue
        out.append(host["id"])
    return out


def dns_profile(doh_url):
    # uuid5 keeps the payload byte-identical across runs, so Fleet does not resend it
    ns = uuid.uuid5(uuid.NAMESPACE_URL, doh_url)
    payload = {
        "PayloadContent": [
            {
                "DNSSettings": {"DNSProtocol": "HTTPS", "ServerURL": doh_url},
                # MagicDNS と captive portal は system resolver に任せる
                "OnDemandRules": [
                    {
                        "Action": "EvaluateConnection",
                        "ActionParameters": [
                            {"DomainAction": "NeverConnect", "Domains": ["ts.net", "captive.apple.com"]}
                        ],
                    },
                    {"Action": "Connect"},
                ],
                "PayloadDisplayName": DNS_PROFILE_NAME,
                "PayloadIdentifier": "dev.egahika.dns.settings",
                "PayloadType": "com.apple.dnsSettings.managed",
                "PayloadUUID": str(uuid.uuid5(ns, "settings")).upper(),
                "PayloadVersion": 1,
            }
        ],
        "PayloadDisplayName": DNS_PROFILE_NAME,
        "PayloadIdentifier": "dev.egahika.dns",
        "PayloadType": "Configuration",
        "PayloadUUID": str(uuid.uuid5(ns, "profile")).upper(),
        "PayloadVersion": 1,
    }
    return plistlib.dumps(payload)


class Fleet:
    def __init__(self, url, token=None):
        self.url = url.rstrip("/")
        self.token = token

    def call(self, method, path, body=None, files=None):
        headers = {}
        data = None
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        if files is not None:
            boundary = secrets.token_hex(16)
            parts = []
            for field, (name, content) in files.items():
                parts.append(
                    f'--{boundary}\r\nContent-Disposition: form-data; name="{field}"; filename="{name}"\r\n'
                    "Content-Type: application/octet-stream\r\n\r\n".encode() + content + b"\r\n"
                )
            data = b"".join(parts) + f"--{boundary}--\r\n".encode()
            headers["Content-Type"] = f"multipart/form-data; boundary={boundary}"
        elif body is not None:
            data = json.dumps(body).encode()
            headers["Content-Type"] = "application/json"
        req = urllib.request.Request(self.url + path, data=data, method=method, headers=headers)
        with urllib.request.urlopen(req, timeout=60) as resp:
            raw = resp.read()
            return json.loads(raw) if raw and resp.headers.get_content_type() == "application/json" else raw


def deploy_sha():
    # git の smart HTTP は REST API のレート制限を受けない
    out = subprocess.run(
        ["git", "ls-remote", f"https://github.com/{REPO}", "refs/heads/deploy"],
        check=True,
        capture_output=True,
        text=True,
        timeout=60,
    ).stdout.split()
    return out[0] if out else None


def read(path, default=None):
    try:
        with open(path) as f:
            return f.read().strip()
    except FileNotFoundError:
        return default


def write_private(path, text):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(text)


def ensure_admin(fleet, state_dir, public_url):
    creds_path = os.path.join(state_dir, "admin.json")
    # 初期 admin は初回だけ作れる。資格情報はこの host の外に出さない
    if not os.path.exists(creds_path):
        password = secrets.token_urlsafe(24) + "A1!"
        creds = {"email": "admin@fleet.invalid", "password": password}
        fleet.call(
            "POST",
            "/api/v1/setup",
            {
                "admin": {
                    "admin": True,
                    "email": creds["email"],
                    "name": "admin",
                    "password": password,
                    "password_confirmation": password,
                },
                "org_info": {"org_name": "hikae"},
                "server_url": public_url,
            },
        )
        write_private(creds_path, json.dumps(creds))
    with open(creds_path) as f:
        creds = json.load(f)
    fleet.token = fleet.call("POST", "/api/v1/fleet/login", creds)["token"]


def ensure_enroll_secret(fleet, state_dir, export_path):
    path = os.path.join(state_dir, "enroll-secret")
    secret = read(path)
    if not secret:
        secret = secrets.token_urlsafe(32)
        write_private(path, secret)
    # Mac の登録時に管理者 (wheel) が ssh 越しに読む。読めても端末を登録できるだけ
    if read(export_path) != secret:
        write_private(export_path, secret)
    if os.geteuid() == 0:
        os.chown(export_path, 0, grp.getgrnam("wheel").gr_gid)
    os.chmod(export_path, 0o640)
    current = fleet.call("GET", "/api/v1/fleet/spec/enroll_secret")["spec"]["secrets"] or []
    if [s["secret"] for s in current] != [secret]:
        fleet.call("POST", "/api/v1/fleet/spec/enroll_secret", {"spec": {"secrets": [{"secret": secret}]}})


def ensure_script_timeout(fleet):
    config = fleet.call("GET", "/api/v1/fleet/config")
    options = config.get("agent_options") or {}
    if options.get("script_execution_timeout") != SCRIPT_TIMEOUT_S:
        options["script_execution_timeout"] = SCRIPT_TIMEOUT_S
        fleet.call("PATCH", "/api/v1/fleet/config", {"agent_options": options})
    return config


def ensure_policy(fleet, sha):
    query = policy_query(sha)
    for policy in fleet.call("GET", "/api/v1/fleet/global/policies").get("policies") or []:
        if policy["name"] == POLICY_NAME:
            if policy["query"] != query:
                fleet.call("PATCH", f"/api/v1/fleet/global/policies/{policy['id']}", {"query": query})
            return policy["id"]
    created = fleet.call(
        "POST",
        "/api/v1/fleet/global/policies",
        {"name": POLICY_NAME, "query": query, "platform": "darwin", "description": "managed by fleet-controller"},
    )
    return created["policy"]["id"]


def ensure_script(fleet, content):
    for script in fleet.call("GET", "/api/v1/fleet/scripts").get("scripts") or []:
        if script["name"] == SCRIPT_NAME:
            current = fleet.call("GET", f"/api/v1/fleet/scripts/{script['id']}?alt=media")
            if current == content:
                return script["id"]
            try:
                fleet.call("PATCH", f"/api/v1/fleet/scripts/{script['id']}", files={"script": (SCRIPT_NAME, content)})
                return script["id"]
            except urllib.error.HTTPError as e:
                if e.code not in (404, 405):
                    raise
            fleet.call("DELETE", f"/api/v1/fleet/scripts/{script['id']}")
            break
    return fleet.call("POST", "/api/v1/fleet/scripts", files={"script": (SCRIPT_NAME, content)})["script_id"]


def ensure_dns_profile(fleet, config, state_dir):
    doh_url = read(os.path.join(state_dir, "doh-url"))
    if not doh_url or not (config.get("mdm") or {}).get("enabled_and_configured"):
        return
    content = dns_profile(doh_url)
    profiles = fleet.call("GET", "/api/v1/fleet/configuration_profiles").get("profiles") or []
    for profile in profiles:
        if profile["name"] == DNS_PROFILE_NAME:
            current = fleet.call("GET", f"/api/v1/fleet/configuration_profiles/{profile['profile_uuid']}?alt=media")
            if current == content:
                return
            fleet.call("DELETE", f"/api/v1/fleet/configuration_profiles/{profile['profile_uuid']}")
    fleet.call("POST", "/api/v1/fleet/configuration_profiles", files={"profile": ("dns.mobileconfig", content)})


def pending_hosts(fleet, script_id, host_ids):
    pending = set()
    for hid in host_ids:
        for script in fleet.call("GET", f"/api/v1/fleet/hosts/{hid}/scripts").get("scripts") or []:
            if script.get("script_id") == script_id and (script.get("last_execution") or {}).get("status") == "pending":
                pending.add(hid)
    return pending


def main(argv):
    state_dir, api_url, public_url, template_path, export_path = argv
    state_path = os.path.join(state_dir, "controller-state.json")
    state = json.loads(read(state_path, "{}"))

    target = deploy_sha()
    if not target:
        print("deploy branch does not exist yet")
        return 0

    fleet = Fleet(api_url)
    ensure_admin(fleet, state_dir, public_url)
    ensure_enroll_secret(fleet, state_dir, export_path)
    config = ensure_script_timeout(fleet)
    ensure_dns_profile(fleet, config, state_dir)
    with open(template_path) as f:
        script_id = ensure_script(fleet, render_script(f.read(), target).encode())
    policy_id = ensure_policy(fleet, target)

    failing = fleet.call("GET", f"/api/v1/fleet/hosts?policy_id={policy_id}&policy_response=failing").get("hosts") or []
    # 古い commit の試行回数は不要なので現在の target 分だけ残す
    attempts = {h: {target: n[target]} for h, n in state.get("attempts", {}).items() if target in n}
    for hid in hosts_to_apply(failing, pending_hosts(fleet, script_id, [h["id"] for h in failing]), attempts, target):
        fleet.call("POST", "/api/v1/fleet/scripts/run", {"host_id": hid, "script_id": script_id})
        per_host = attempts.setdefault(str(hid), {})
        per_host[target] = per_host.get(target, 0) + 1
        print(f"apply {target[:7]} on host {hid} (attempt {per_host[target]})")

    write_private(state_path, json.dumps({"target": target, "attempts": attempts}))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except (urllib.error.URLError, subprocess.SubprocessError) as e:
        print(f"fleet-controller: {e}", file=sys.stderr)
        sys.exit(1)
