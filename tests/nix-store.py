#!/usr/bin/env python3
import os
import plistlib
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
plist = plistlib.loads((root / 'modules/darwin/nix-store.plist').read_bytes())
assert plist['RunAtLoad'] and plist['Label'] == 'org.nixos.darwin-store'
command = plist['ProgramArguments'][2]
assert '/nix/store/' not in command and 'determinate-nixd' not in command
with tempfile.TemporaryDirectory() as directory:
    tmp = Path(directory)
    stub = tmp / 'stub'
    stub.write_text('''#!/bin/sh
case "$1" in
info) printf '%s' info ;;
-extract) cat >/dev/null; printf '%s' test-uuid ;;
find-generic-password)
  [ "$MODE" != missing ] || exit 1
  if [ "$MODE" = fallback ] && [ "$3" = test-uuid ]; then exit 1; fi
  printf '%s' test-secret ;;
apfs)
  [ "$MODE" != unlock-fail ] || exit 1
  [ "$3" = test-uuid ] && [ "$5" = /nix ] || exit 1
  [ "$(cat)" = test-secret ] || exit 1 ;;
esac
''')
    stub.chmod(0o755)
    script = command.replace('/nix/store', str(tmp / 'store'))
    for binary in ('/usr/sbin/diskutil', '/usr/bin/plutil', '/usr/bin/security'):
        script = script.replace(binary, str(stub))
    for mode, success in [('uuid', True), ('fallback', True), ('missing', False), ('unlock-fail', False)]:
        result = subprocess.run(['/bin/sh', '-c', script], env={**os.environ, 'MODE': mode}, capture_output=True)
        assert (result.returncode == 0) == success, (mode, result)
        assert b'test-secret' not in result.stdout + result.stderr
    (tmp / 'store').mkdir()
    assert subprocess.run(['/bin/sh', '-c', script], env={**os.environ, 'MODE': 'missing'}).returncode == 0
print('ok: mounted store, UUID key, legacy key, missing key, unlock failure')
