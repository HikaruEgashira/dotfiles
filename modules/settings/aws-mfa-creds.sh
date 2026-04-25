#!/usr/bin/env bash
# AWS credential_process helper: fetches an MFA-authenticated STS session
# token using the long-term keys in [default] of ~/.aws/credentials, caches
# it, and emits it in the JSON shape the AWS CLI / SDKs expect.
#
# Wired in via ~/.aws/config:
#   [profile hikae-admin-mfa]
#   credential_process = /Users/hikae/.local/bin/aws-mfa-creds <serial>
#
# Args:
#   $1  MFA device ARN (mfa_serial)
#   $2  source profile holding long-term creds (default: "default")
#   $3  session duration seconds (default: 43200 = 12h)
#
# Behaviour:
#   - Reads cached session at $XDG_CACHE_HOME/aws-mfa/<serial-hash>.json
#   - Reuses cache if expiration > now + 60s
#   - Otherwise prompts on /dev/tty for the 6-digit TOTP code, calls
#     sts:GetSessionToken via the source profile, refreshes cache.
#   - Always writes credentials JSON to stdout in process_credentials format.
set -euo pipefail

SERIAL="${1:?mfa serial arn required}"
SOURCE_PROFILE="${2:-default}"
DURATION="${3:-43200}"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/aws-mfa"
mkdir -p "$CACHE_DIR"
chmod 700 "$CACHE_DIR"

CACHE_KEY=$(printf '%s' "$SERIAL" | shasum -a 256 | cut -c1-16)
CACHE_FILE="$CACHE_DIR/$CACHE_KEY.json"

emit_cached() {
  jq '{Version:1, AccessKeyId:.Credentials.AccessKeyId, SecretAccessKey:.Credentials.SecretAccessKey, SessionToken:.Credentials.SessionToken, Expiration:.Credentials.Expiration}' "$CACHE_FILE"
}

if [ -f "$CACHE_FILE" ]; then
  EXPIRATION=$(jq -r '.Credentials.Expiration' "$CACHE_FILE" 2>/dev/null || echo "")
  if [ -n "$EXPIRATION" ]; then
    EXP_EPOCH=$(date -j -u -f "%Y-%m-%dT%H:%M:%S+00:00" "$EXPIRATION" "+%s" 2>/dev/null || echo 0)
    NOW_EPOCH=$(date -u "+%s")
    if [ "$EXP_EPOCH" -gt "$((NOW_EPOCH + 60))" ]; then
      emit_cached
      exit 0
    fi
  fi
fi

# Cache stale or missing: prompt and refresh.
if [ ! -t 0 ] && [ ! -e /dev/tty ]; then
  echo "aws-mfa-creds: no tty available to prompt for MFA token" >&2
  exit 1
fi

printf 'MFA code for %s: ' "$SERIAL" > /dev/tty
read -r TOKEN < /dev/tty

# Source-profile call must NOT inherit the consumer profile or we recurse.
unset AWS_PROFILE AWS_DEFAULT_PROFILE
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

aws --profile "$SOURCE_PROFILE" sts get-session-token \
  --serial-number "$SERIAL" \
  --token-code "$TOKEN" \
  --duration-seconds "$DURATION" \
  --output json > "$CACHE_FILE.tmp"

mv "$CACHE_FILE.tmp" "$CACHE_FILE"
chmod 600 "$CACHE_FILE"
emit_cached
