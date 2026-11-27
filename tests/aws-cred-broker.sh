#!/usr/bin/env bash
# aws credential broker が allowlist 外を拒否し、allowlist 内は host の aws 出力をそのまま返すことを固定する
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
broker="$root/modules/programs/aws/broker.py"
aws_nix="$root/modules/programs/aws.nix"

# read 系 profile は sandbox が届く broker、特権 profile は sandbox が届かない別 socket の broker だけが返す
grep -Fq 'label = "dev.egahika.aws-cred-agent";' "$aws_nix"
grep -Fq 'label = "dev.egahika.aws-cred-admin-agent";' "$aws_nix"
for p in sso-readonly sisaku-security-readonly-sso; do
  # shellcheck disable=SC2016 # Match the literal Nix interpolation.
  grep -Fq 'credential_process = ${client} '"$p" "$aws_nix"
done
for p in sso-admin iac-aws-apply-chain artex-microvm-chain seccamp-lab-apply-chain; do
  # shellcheck disable=SC2016
  grep -Fq 'credential_process = ${adminClient} '"$p" "$aws_nix"
done
read_profiles=$(awk '/socket = readSocket;/{a=1} a&&/\];/{exit} a' "$aws_nix")
if printf '%s\n' "$read_profiles" | grep -Eq 'sso-admin|-chain"'; then
  printf '%s\n' 'FAIL: the sandbox-reachable broker serves a privileged profile' >&2
  exit 1
fi
# chain の source は host 専用 profile に限り、broker client を source にして socket を再帰させない
if grep -E '^\s*source_profile' "$aws_nix" | grep -vqE '= (sso-admin|seccamp-lab-org)$'; then
  printf '%s\n' 'FAIL: a role chain sources a broker-backed profile' >&2
  exit 1
fi
if grep -Fq 'export-credentials' "$aws_nix"; then
  printf '%s\n' 'FAIL: aws.nix wraps profiles in export-credentials instead of the broker client' >&2
  exit 1
fi

printf '%s\n' 'ok: aws profiles delegate credentials to the broker without recursing'

command -v python3 >/dev/null || {
  printf '%s\n' 'skip: python3 not available for broker runtime test'
  exit 0
}

tmp=$(mktemp -d)
trap 'kill "$agent_pid" 2>/dev/null || true; rm -rf "$tmp"' EXIT
sock="$tmp/run/agent.sock"

fake_aws="$tmp/aws"
cat >"$fake_aws" <<'EOF'
#!/bin/sh
# argv: configure export-credentials --profile <p> --format process
case "$4" in
  good) printf '{"Version":1,"AccessKeyId":"AKIAFAKE","SecretAccessKey":"x","SessionToken":"y","Expiration":"2099-01-01T00:00:00Z"}\n' ;;
  *) echo "Error loading SSO Token" >&2; exit 255 ;;
esac
EOF
chmod +x "$fake_aws"

python3 "$broker" --socket "$sock" agent --aws "$fake_aws" --allow good --allow broken >"$tmp/agent.log" 2>&1 &
agent_pid=$!
for _ in $(seq 1 50); do
  [ -S "$sock" ] && break
  sleep 0.1
done
[ -S "$sock" ] || {
  cat "$tmp/agent.log" >&2
  exit 1
}

perm=$(python3 -c 'import os,sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$sock")
[ "$perm" = "0o600" ]
perm=$(python3 -c 'import os,sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$tmp/run")
[ "$perm" = "0o700" ]

out=$(python3 "$broker" --socket "$sock" client good)
[ "$out" = '{"Version":1,"AccessKeyId":"AKIAFAKE","SecretAccessKey":"x","SessionToken":"y","Expiration":"2099-01-01T00:00:00Z"}' ]

if out=$(python3 "$broker" --socket "$sock" client unknown 2>"$tmp/err"); then
  printf '%s\n' 'FAIL: unknown profile was served' >&2
  exit 1
fi
[ -z "$out" ]
grep -Fq 'profile not allowed' "$tmp/err"

if out=$(python3 "$broker" --socket "$sock" client broken 2>"$tmp/err"); then
  printf '%s\n' 'FAIL: aws failure was reported as success' >&2
  exit 1
fi
[ -z "$out" ]
grep -Fq 'Error loading SSO Token' "$tmp/err"

if python3 "$broker" --socket "$tmp/missing.sock" client good 2>"$tmp/err"; then
  printf '%s\n' 'FAIL: client succeeded without a broker' >&2
  exit 1
fi
grep -Fq 'cannot reach broker' "$tmp/err"

printf '%s\n' 'ok: broker serves allowlisted profiles only and propagates aws failures'

# live: 有効な SSO session と常駐 agent がある host でだけ実行する
if [ "${AWS_CRED_BROKER_LIVE:-}" = 1 ]; then
  for p in default sisaku-security-readonly hikae-admin-sso iac-aws-apply seccamp-lab-apply; do
    aws sts get-caller-identity --profile "$p" --query Arn --output text
  done
  for p in iac-aws-apply sso-admin iac-aws-apply-chain; do
    if ~/.local/bin/aws-cred-client "$p" >/dev/null 2>&1; then
      printf '%s\n' "FAIL: the sandbox-reachable broker serves $p" >&2
      exit 1
    fi
  done
  printf '%s\n' 'ok: live broker resolves every sandbox profile and rejects names outside the allowlist'
fi
