#!/usr/bin/env bash
# AI CLI の Aqua pin を、npm 公開から AQUA_BUMP_MIN_AGE_DAYS 日以上経った最新安定版へ上げ checksum を更新する。
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
aqua=$root/modules/programs/aqua
min_age=$((${AQUA_BUMP_MIN_AGE_DAYS:-3} * 86400))

latest_aged() {
  curl -fsSL --retry 3 "https://registry.npmjs.org/${1/\//%2f}" |
    jq -er --argjson min_age "$min_age" '
      .time | to_entries
      | map(select(.key | test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))
            | select((.value | sub("\\.[0-9]+Z$"; "Z") | fromdate) <= now - $min_age))
      | max_by(.key | split(".") | map(tonumber)) | .key'
}

bump() {
  local name=$1 version=$2 current
  current=$(sed -nE "s|^  - name: $name@(.+)\$|\\1|p" "$aqua/aqua.yaml")
  # 手動で先行 pin した版を下げない
  [ "$(printf '%s\n' "$current" "$version" | sort -V | tail -1)" = "$version" ] || return 0
  sed -i.bak -E "s|^(  - name: $name@).+\$|\\1$version|" "$aqua/aqua.yaml"
  rm "$aqua/aqua.yaml.bak"
}

bump anthropics/claude-code "$(latest_aged @anthropic-ai/claude-code)"
bump openai/codex "$(latest_aged @openai/codex)"
bump anomalyco/opencode "$(latest_aged @opencode/cli-darwin-arm64)"

AQUA_GLOBAL_CONFIG=$aqua/aqua.yaml AQUA_POLICY_CONFIG=$aqua/aqua-policy.yaml \
  aqua update-checksum -a --prune
git -C "$root" diff --stat -- "$aqua"
