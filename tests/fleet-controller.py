#!/usr/bin/env python3
"""usage: fleet-controller.py [<scripts/fleet-controller.py> <scripts/fleet/dotfiles-apply.sh>]"""

import importlib.util
import os
import plistlib
import sys

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
controller_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, "scripts/fleet-controller.py")
template_path = sys.argv[2] if len(sys.argv) > 2 else os.path.join(root, "scripts/fleet/dotfiles-apply.sh")

spec = importlib.util.spec_from_file_location("controller", controller_path)
c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)

new = "b" * 40

hosts = [{"id": 1}, {"id": 2}, {"id": 3}]
attempts = {"2": {new: c.MAX_ATTEMPTS}, "3": {new: 1}}
assert c.hosts_to_apply(hosts, {1}, attempts, new) == [3], "in-flight and exhausted hosts must be skipped"

q = c.policy_query(new)
assert f"value = '{new}'" in q and "/var/db/dotfiles.plist" in q

with open(template_path) as f:
    template = f.read()
assert "@TARGET@" in template
rendered = c.render_script(template, new)
assert "@TARGET@" not in rendered and f'target="{new}"' in rendered
# 書き込み先が policy の参照先と一致する (defaults は .plist を付けて保存する)
assert "defaults write /var/db/dotfiles rev" in rendered

p1 = c.dns_profile("https://x.cloudflare-gateway.com/dns-query")
assert p1 == c.dns_profile("https://x.cloudflare-gateway.com/dns-query"), "profile must be stable across runs"
payload = plistlib.loads(p1)["PayloadContent"][0]
assert payload["PayloadType"] == "com.apple.dnsSettings.managed"
assert payload["DNSSettings"]["ServerURL"].startswith("https://")
assert "ts.net" in payload["OnDemandRules"][0]["ActionParameters"][0]["Domains"]

print("fleet-controller: ok")
