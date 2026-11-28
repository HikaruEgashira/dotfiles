import base64
import hashlib
import importlib.util
import json
import sys
import threading
import time
import uuid
from pathlib import Path
from types import SimpleNamespace

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("approver", ROOT / "modules/programs/browser-auth/approver.py")
ap = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ap)

key = ec.generate_private_key(ec.SECP256R1())
cred_uuid = uuid.uuid4()
cred = {
    "credentialId": str(cred_uuid),
    "rpId": "github.com",
    "keyValue": ap.b64u(key.private_bytes(serialization.Encoding.DER, serialization.PrivateFormat.PKCS8, serialization.NoEncryption())),
    "userHandle": ap.b64u(b"user-1"),
    "userName": "hikae",
}
items = [
    {"id": "i1", "type": 1, "name": "GitHub", "login": {"username": "hikae", "password": "pw", "fido2Credentials": [cred]}},
    {"id": "i2", "type": 1, "name": "Other", "login": {"username": "x", "password": "y", "fido2Credentials": [dict(cred, rpId="evil.com")]}},
]

# 署名は RP 側の検証手順で通る
challenge = ap.b64u(b"chal")
a = ap.make_assertion(cred, "https://github.com", "github.com", challenge)
auth = ap.b64u_decode(a["authenticatorData"])
cdj = ap.b64u_decode(a["clientDataJSON"])
assert auth[:32] == hashlib.sha256(b"github.com").digest()
assert auth[32] & 0x05 == 0x05
assert json.loads(cdj) == {"type": "webauthn.get", "challenge": challenge, "origin": "https://github.com", "crossOrigin": False}
key.public_key().verify(ap.b64u_decode(a["signature"]), auth + hashlib.sha256(cdj).digest(), ec.ECDSA(hashes.SHA256()))
assert ap.b64u_decode(a["rawId"]) == cred_uuid.bytes
assert ap.b64u_decode(a["userHandle"]) == b"user-1"
assert ap.credential_id_bytes("b64." + ap.b64u(b"\x01\x02")) == b"\x01\x02"

# site と rpId
sites = ["github.com"]
assert ap.site_allowed("https://github.com", sites) == "github.com"
assert ap.site_allowed("https://gist.github.com", sites) == "gist.github.com"
assert ap.site_allowed("http://github.com", sites) is None
assert ap.site_allowed("https://evilgithub.com", sites) is None
assert ap.site_allowed("https://github.com:8443", sites) is None
assert ap.rp_id_valid("github.com", "gist.github.com", sites)
assert not ap.rp_id_valid("gist.github.com", "github.com", sites)
assert not ap.rp_id_valid("com", "github.com", sites)
assert [c["rpId"] for _, c in ap.pick_passkeys(items, "github.com", [])] == ["github.com"]
assert ap.pick_passkeys(items, "github.com", [ap.b64u(b"other")]) == []

# 要求元と承認者の判定、承認フロー
SELF = 42
peers = {
    "studio": {"Node": {"Name": "mac-studio.t.ts.net.", "Hostinfo": {"OS": "macOS"}}, "UserProfile": {"ID": SELF}},
    "phone": {"Node": {"Name": "poco.t.ts.net.", "Hostinfo": {"OS": "android"}}, "UserProfile": {"ID": SELF}},
    "ms-a2": {"Node": {"Name": "mac-studio.t.ts.net.", "Tags": ["tag:untrusted-dev"], "Hostinfo": {"OS": "linux"}}, "UserProfile": {"ID": SELF}},
    "other": {"Node": {"Name": "phone.t.ts.net.", "Hostinfo": {"OS": "android"}}, "UserProfile": {"ID": 7}},
}


class FakeVault:
    def logins(self, origin):
        return items

    def totp(self, _):
        return None


import tempfile

tmp = tempfile.mkdtemp()
args = SimpleNamespace(site=sites, requester=["mac-studio"], base_url="https://air", state_dir=tmp)
app = ap.Approver(args, FakeVault(), peers.__getitem__)
sub = app.subscribe()
urls = []


def pump():
    while True:
        kind, data = sub.get()
        if kind == "approval":
            assert data["body"] == "mac-studio → https://github.com" and data["expires"] > time.time()
            urls.append(data["url"])


threading.Thread(target=pump, daemon=True).start()
app.self_user = SELF
assert app.is_requester(peers["studio"]) == "mac-studio"
assert not app.is_requester(peers["ms-a2"]) and not app.is_requester(peers["phone"])
assert app.is_phone(peers["phone"]) and not app.is_phone(peers["other"]) and not app.is_phone(peers["studio"])

assert app.request("mac-studio", {"kind": "password", "origin": "https://evil.com"})[0] == 403


def approve_when_notified(choice):
    def run():
        while not urls:
            time.sleep(0.01)
        rid = urls.pop().rsplit("/", 1)[1]
        assert app.page(rid) and "github.com" in app.page(rid)
        assert not app.decide(rid, "9")
        assert app.decide(rid, choice)
        assert not app.decide(rid, choice)

    t = threading.Thread(target=run)
    t.start()
    return t


t = approve_when_notified("0")
code, out = app.request("mac-studio", {"kind": "password", "origin": "https://github.com"})
t.join()
assert (code, out) == (200, {"username": "hikae", "password": "pw"}), (code, out)

t = approve_when_notified("deny")
assert app.request("mac-studio", {"kind": "password", "origin": "https://github.com"})[0] == 403
t.join()

t = approve_when_notified("0")
code, out = app.request("mac-studio", {"kind": "passkey", "origin": "https://github.com", "rpId": "github.com", "challenge": challenge})
t.join()
assert code == 200 and out["rawId"] == a["rawId"]
assert app.request("mac-studio", {"kind": "passkey", "origin": "https://github.com", "rpId": "evil.com", "challenge": challenge})[0] == 400

log = (Path(tmp) / "audit.jsonl").read_text()
assert "pw" not in log.replace("password", "")
late = app.subscribe()
assert late.empty()
print("ok")
