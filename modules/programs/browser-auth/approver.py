"""mac-studio のブラウザからの認証要求を、スマホの承認後に macbook-air の Bitwarden で満たす。

vault と passkey の秘密鍵は air の外に出さない。返すのは承認された 1 件のパスワードか、WebAuthn の署名だけ。
"""

import argparse
import base64
import hashlib
import html
import json
import os
import secrets
import subprocess
import sys
import threading
import time
import urllib.request
import uuid
from dataclasses import dataclass, field
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec

APPROVAL_TIMEOUT = 90
MAX_PENDING = 4
SESSION_TTL = 12 * 3600
SYNC_INTERVAL = 600
# UP | UV | BE | BS。Bitwarden の passkey は同期される前提で登録されている
AUTH_FLAGS = 0x01 | 0x04 | 0x08 | 0x10


def b64u(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def b64u_decode(text: str) -> bytes:
    text = text.replace("+", "-").replace("/", "_").rstrip("=")
    return base64.urlsafe_b64decode(text + "=" * (-len(text) % 4))


def host_matches(host: str, site: str) -> bool:
    return host == site or host.endswith("." + site)


def site_allowed(origin: str, sites: list[str]) -> str | None:
    """https の origin で sites のどれかに一致すれば host を返す。"""
    if not origin.startswith("https://"):
        return None
    host = origin[len("https://") :].split("/", 1)[0]
    if ":" in host or not host:
        return None
    return host if any(host_matches(host, s) for s in sites) else None


def rp_id_valid(rp_id: str, host: str, sites: list[str]) -> bool:
    return host_matches(host, rp_id) and any(host_matches(rp_id, s) for s in sites)


def credential_id_bytes(cred_id: str) -> bytes:
    # Bitwarden は GUID 形式か "b64.<base64url>" で credentialId を保存する
    if cred_id.startswith("b64."):
        return b64u_decode(cred_id[4:])
    return uuid.UUID(cred_id).bytes


def make_assertion(cred: dict, origin: str, rp_id: str, challenge: str) -> dict:
    client_data = json.dumps(
        {"type": "webauthn.get", "challenge": challenge, "origin": origin, "crossOrigin": False},
        separators=(",", ":"),
    ).encode()
    # counter は 0 固定。air から書き戻さないので増分を偽ると clone 検知に掛かる
    auth_data = hashlib.sha256(rp_id.encode()).digest() + bytes([AUTH_FLAGS]) + (0).to_bytes(4, "big")
    key = serialization.load_der_private_key(b64u_decode(cred["keyValue"]), None)
    if not isinstance(key, ec.EllipticCurvePrivateKey):
        raise ValueError("unsupported passkey algorithm")
    signature = key.sign(auth_data + hashlib.sha256(client_data).digest(), ec.ECDSA(hashes.SHA256()))
    raw_id = credential_id_bytes(cred["credentialId"])
    out = {
        "id": b64u(raw_id),
        "rawId": b64u(raw_id),
        "clientDataJSON": b64u(client_data),
        "authenticatorData": b64u(auth_data),
        "signature": b64u(signature),
    }
    if cred.get("userHandle"):
        out["userHandle"] = b64u(b64u_decode(cred["userHandle"]))
    return out


def pick_passkeys(items: list[dict], rp_id: str, allow: list[str]) -> list[tuple[dict, dict]]:
    allow_raw = {b64u_decode(a) for a in allow}
    found = []
    for item in items:
        for cred in (item.get("login") or {}).get("fido2Credentials") or []:
            if cred.get("rpId") != rp_id:
                continue
            if allow_raw and credential_id_bytes(cred["credentialId"]) not in allow_raw:
                continue
            found.append((item, cred))
    return found


class Vault:
    def __init__(self, bw: str, unlock_cmd: list[str]):
        self.bw = bw
        self.unlock_cmd = unlock_cmd
        self.session: str | None = None
        self.unlocked_at = 0.0
        self.synced_at = 0.0
        self.lock = threading.Lock()

    def _run(self, *args: str) -> str:
        env = dict(os.environ, BW_SESSION=self.session or "", BW_NOINTERACTION="true")
        return subprocess.run([self.bw, *args], env=env, check=True, capture_output=True, text=True).stdout

    def _ensure(self) -> None:
        now = time.time()
        if self.session is None or now - self.unlocked_at > SESSION_TTL:
            # unlock_cmd は Secure Enclave の鍵で master password を復号するので、air で Touch ID が要る
            self.session = subprocess.run(self.unlock_cmd, check=True, capture_output=True, text=True).stdout.strip()
            self.unlocked_at = now
        if now - self.synced_at > SYNC_INTERVAL:
            self._run("sync")
            self.synced_at = now

    def logins(self, origin: str) -> list[dict]:
        with self.lock:
            self._ensure()
            items = json.loads(self._run("list", "items", "--url", origin))
        return [i for i in items if i.get("type") == 1]

    def totp(self, item_id: str) -> str | None:
        with self.lock:
            try:
                return self._run("get", "totp", item_id).strip() or None
            except subprocess.CalledProcessError:
                return None


@dataclass
class Pending:
    requester: str
    kind: str
    origin: str
    choices: list[dict]
    event: threading.Event = field(default_factory=threading.Event)
    choice: int | None = None
    created: float = field(default_factory=time.time)


class Approver:
    def __init__(self, args, vault: Vault, whois, notify):
        self.sites: list[str] = args.site
        self.requesters: set[str] = set(args.requester)
        self.base_url: str = args.base_url
        self.audit = Path(args.state_dir) / "audit.jsonl"
        self.vault = vault
        self.whois = whois
        self.notify = notify
        self.pending: dict[str, Pending] = {}
        self.lock = threading.Lock()
        self.self_user = None

    def log(self, **entry) -> None:
        entry["ts"] = time.strftime("%Y-%m-%dT%H:%M:%S%z")
        with self.audit.open("a") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")

    def peer(self, ip: str | None) -> dict | None:
        if not ip:
            return None
        try:
            return self.whois(ip)
        except Exception:
            return None

    def is_requester(self, peer: dict) -> str | None:
        node = peer.get("Node") or {}
        name = (node.get("Name") or "").split(".", 1)[0]
        if node.get("Tags") or name not in self.requesters or not self.same_user(peer):
            return None
        return name

    def is_phone(self, peer: dict) -> bool:
        os_name = ((peer.get("Node") or {}).get("Hostinfo") or {}).get("OS", "")
        return os_name.lower() in {"android", "ios"} and not (peer.get("Node") or {}).get("Tags") and self.same_user(peer)

    def same_user(self, peer: dict) -> bool:
        return self.self_user is not None and (peer.get("UserProfile") or {}).get("ID") == self.self_user

    def request(self, requester: str, body: dict) -> tuple[int, dict]:
        kind = body.get("kind")
        origin = body.get("origin", "")
        host = site_allowed(origin, self.sites)
        if kind not in {"password", "passkey"} or host is None:
            self.log(event="reject", requester=requester, kind=kind, origin=origin, reason="site")
            return 403, {"error": "site not allowed"}
        if kind == "passkey":
            rp_id = body.get("rpId") or host
            challenge = body.get("challenge", "")
            if not rp_id_valid(rp_id, host, self.sites) or not challenge:
                return 400, {"error": "bad rpId or challenge"}
            found = pick_passkeys(self.vault.logins(origin), rp_id, body.get("allowCredentials") or [])
            choices = [{"label": c.get("userName") or i.get("name"), "item": i, "cred": c} for i, c in found]
        else:
            choices = [
                {"label": (i.get("login") or {}).get("username") or i.get("name"), "item": i}
                for i in self.vault.logins(origin)
                if (i.get("login") or {}).get("password")
            ]
        if not choices:
            return 404, {"error": "no credential"}

        rid = secrets.token_urlsafe(16)
        with self.lock:
            if len(self.pending) >= MAX_PENDING:
                return 429, {"error": "too many pending"}
            p = self.pending[rid] = Pending(requester, kind, origin, choices)
        self.log(event="request", id=rid, requester=requester, kind=kind, origin=origin)
        try:
            self.notify(f"{self.base_url}/a/{rid}")
            p.event.wait(APPROVAL_TIMEOUT)
        finally:
            with self.lock:
                self.pending.pop(rid, None)
        if p.choice is None:
            self.log(event="deny", id=rid, timeout=not p.event.is_set())
            return 403, {"error": "denied"}
        chosen = choices[p.choice]
        self.log(event="approve", id=rid, account=chosen["label"])
        if kind == "passkey":
            return 200, make_assertion(chosen["cred"], origin, rp_id, challenge)
        login = chosen["item"]["login"]
        out = {"username": login.get("username") or "", "password": login["password"]}
        if login.get("totp"):
            out["totp"] = self.vault.totp(chosen["item"]["id"])
        return 200, out

    def page(self, rid: str) -> str | None:
        p = self.pending.get(rid)
        if p is None:
            return None
        what = "passkey でログイン" if p.kind == "passkey" else "パスワードを入力"
        buttons = "".join(
            f'<button name="choice" value="{n}">{html.escape(c["label"] or "?")}</button>'
            for n, c in enumerate(p.choices)
        )
        return f"""<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>認証要求</title>
<style>body{{font:18px system-ui;margin:24px}}button{{display:block;width:100%;padding:16px;margin:12px 0;font-size:18px}}
.deny{{background:#eee}}code{{font-size:20px;word-break:break-all}}</style>
<h1>{html.escape(what)}</h1>
<p>要求元: <b>{html.escape(p.requester)}</b></p>
<p>サイト: <code>{html.escape(p.origin)}</code></p>
<form method="post">{buttons}<button class="deny" name="choice" value="deny">拒否</button></form>"""

    def decide(self, rid: str, choice: str) -> bool:
        with self.lock:
            p = self.pending.get(rid)
            if p is None or p.event.is_set():
                return False
            if choice != "deny":
                n = int(choice)
                if not 0 <= n < len(p.choices):
                    return False
                p.choice = n
            p.event.set()
        return True


def make_handler(app: Approver):
    class Handler(BaseHTTPRequestHandler):
        def peer_ip(self) -> str | None:
            # tailscale serve が付ける X-Forwarded-For の末尾が tailnet 上の送信元。付いていない要求は loopback 直なので拒む
            xff = self.headers.get("X-Forwarded-For")
            return xff.split(",")[-1].strip() if xff else None

        def send(self, code: int, body: str, ctype="application/json") -> None:
            data = body.encode()
            self.send_response(code)
            self.send_header("Content-Type", ctype + "; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_POST(self):
            peer = app.peer(self.peer_ip())
            length = min(int(self.headers.get("Content-Length") or 0), 65536)
            raw = self.rfile.read(length)
            if self.path == "/v1/request":
                requester = peer and app.is_requester(peer)
                if not requester:
                    return self.send(403, '{"error":"requester"}')
                try:
                    code, out = app.request(requester, json.loads(raw))
                except (ValueError, subprocess.CalledProcessError) as e:
                    code, out = 500, {"error": type(e).__name__}
                return self.send(code, json.dumps(out))
            if self.path.startswith("/a/"):
                if not (peer and app.is_phone(peer)):
                    return self.send(403, "forbidden", "text/plain")
                form = dict(p.split("=", 1) for p in raw.decode().split("&") if "=" in p)
                ok = app.decide(self.path[3:], form.get("choice", ""))
                return self.send(200 if ok else 410, "<p>送信しました</p>" if ok else "<p>期限切れです</p>", "text/html")
            self.send(404, "{}")

        def do_GET(self):
            if not self.path.startswith("/a/"):
                return self.send(404, "{}")
            peer = app.peer(self.peer_ip())
            if not (peer and app.is_phone(peer)):
                return self.send(403, "forbidden", "text/plain")
            body = app.page(self.path[3:])
            self.send(200 if body else 410, body or "<p>期限切れです</p>", "text/html")

        def log_message(self, *_):
            pass

    return Handler


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--listen-port", type=int, required=True)
    ap.add_argument("--base-url", required=True)
    ap.add_argument("--site", action="append", required=True)
    ap.add_argument("--requester", action="append", required=True)
    ap.add_argument("--state-dir", required=True)
    ap.add_argument("--tailscale", required=True)
    ap.add_argument("--bw", required=True)
    ap.add_argument("--ntfy-server", default="https://ntfy.sh")
    ap.add_argument("unlock", nargs="+")
    args = ap.parse_args()

    state = Path(args.state_dir)
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    topic_file = state / "ntfy-topic"
    if not topic_file.exists():
        topic_file.write_text("bwa-" + secrets.token_urlsafe(24) + "\n")
        topic_file.chmod(0o600)
    topic = topic_file.read_text().strip()

    def whois(ip: str) -> dict:
        out = subprocess.run([args.tailscale, "whois", "--json", ip], check=True, capture_output=True, text=True)
        return json.loads(out.stdout)

    def notify(url: str) -> None:
        # ntfy には site を載せず、承認ページ (tailnet の中) でだけ見せる
        req = urllib.request.Request(
            f"{args.ntfy_server}/{topic}",
            data="mac-studio から認証の承認要求".encode(),
            headers={"Title": "Bitwarden", "Click": url, "Priority": "high", "Tags": "key"},
        )
        urllib.request.urlopen(req, timeout=10).read()

    app = Approver(args, Vault(args.bw, args.unlock), whois, notify)
    status = json.loads(subprocess.run([args.tailscale, "status", "--json"], check=True, capture_output=True, text=True).stdout)
    app.self_user = status["Self"]["UserID"]
    print(f"ntfy topic: {topic}", file=sys.stderr, flush=True)
    ThreadingHTTPServer(("127.0.0.1", args.listen_port), make_handler(app)).serve_forever()


if __name__ == "__main__":
    main()
