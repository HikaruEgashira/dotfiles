#!/usr/bin/env bash
if [ "${CODEX_SANDBOX:-}" = seatbelt ]; then
  printf '%s\n' 'aws: このサンドボックスでは ~/.aws へのアクセスが禁止されています。保存済みプロファイルと SSO キャッシュは利用できません。' >&2
fi
