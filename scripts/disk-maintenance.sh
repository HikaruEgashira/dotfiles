#!/usr/bin/env bash
# disk-maintenance.sh — 空き率が TARGET_PCT を下回ったときだけ、失うものの小さい順に回収する
#
# 週次・年齢ベースの掃除は増加に追従しない (週 5GB 増えて 3GB しか消えない)。トリガを
# 空き率に置き、回収できる段を順に試して目標に届いた時点で止める。
# 各段の「失うもの」:
#   1-2 nix    : 古い generation と未参照 path、重複内容。再ビルドで戻る
#   3   cache  : 再取得できるキャッシュ
#   4   codex  : current 以外の Codex CLI release。auto-update が戻す
#   4b  artex  : deploy 世代 (backups/ deploy-staging/) の新しい ARTEX_KEEP 個以外。直前世代へ戻せれば足りる
#   5   trash  : 7 日以上放置されたゴミ箱
#   6   podman : 未使用 image/container、CACHE_AGE_DAYS 起動していない停止済み VM、--podman-machine で指定した VM
# 空き率に関係なく毎回やること:
#   tombstone  : 退役した tool の state と sandbox fallback の .pnpm-store。宣言に無いので存在自体が drift
#   sizes      : artex / containers / Documents/Codex の大きさを週次で記録し、前回比の増加を出す
# ladder の外 (手動、SSO セッションが要る):
#   --archive PATH : S3 (GLACIER_IR) へ退避し、size / sha256 を照合してからローカルを消す
set -euo pipefail

TARGET_PCT=${TARGET_PCT:-10}
CACHE_AGE_DAYS=30
TRASH_AGE_DAYS=7
ARCHIVE_BUCKET=${ARCHIVE_BUCKET:-hikae-archive-951872725222}
PODMAN_MACHINE=
ARCHIVE_PATH=
DRY_RUN=0

usage() {
  cat >&2 <<USAGE
usage: disk-maintenance.sh [-n|--dry-run] [--days N] [--target PCT] [--podman-machine NAME]
       disk-maintenance.sh [-n|--dry-run] --archive PATH
  --days N             キャッシュと nix generation の保持日数 (既定 30)
  --target PCT         目標空き率 % (既定 10、環境変数 TARGET_PCT)
  --podman-machine N   指定した停止済み podman VM を削除して回収する
  --archive PATH       HOME 配下の PATH を s3://$ARCHIVE_BUCKET へ退避し、検証後にローカルを消す (環境変数 ARCHIVE_BUCKET)
USAGE
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
  -n | --dry-run) DRY_RUN=1 ;;
  --days)
    CACHE_AGE_DAYS="$2"
    shift
    ;;
  --target)
    TARGET_PCT="$2"
    shift
    ;;
  --podman-machine)
    PODMAN_MACHINE="$2"
    shift
    ;;
  --archive)
    ARCHIVE_PATH="$2"
    shift
    ;;
  -h | --help) usage ;;
  *)
    echo "unknown option: $1" >&2
    usage 1
    ;;
  esac
  shift
done

for n in "$CACHE_AGE_DAYS" "$TARGET_PCT"; do
  case "$n" in
  '' | *[!0-9]*)
    echo "正の整数を期待: $n" >&2
    exit 1
    ;;
  esac
done

CACHES=(
  "$HOME/.cache/npm"
  "$HOME/.cache/pnpm"
  "$HOME/.cache/node"
  "$HOME/.cache/uv"
  "$HOME/.cache/puppeteer"
  "$HOME/.cache/codex-runtimes"
  "$HOME/Library/Caches/pip"
  "$HOME/Library/Caches/pnpm"
  "$HOME/Library/Caches/bun"
  "$HOME/Library/Caches/node-gyp"
  "$HOME/Library/Caches/com.openai.codex/org.sparkle-project.Sparkle"
  "$HOME/.local/share/artex/import" # 取り込み済みの残骸。元データから再取り込みできる
)

# artex/ (server の data dir) と pg/ は消さない。世代 dir だけ新しい順に残す
ARTEX_GENERATION_DIRS=(
  "$HOME/.local/share/artex/backups"
  "$HOME/.local/share/artex/deploy-staging"
)
ARTEX_KEEP=2

SIZES_TSV=$HOME/.local/state/disk-maintenance/sizes.tsv
SIZES_INTERVAL_DAYS=7
# pg は削除せず記録だけ。Documents/Codex は --archive の判断材料
WATCHED=(
  "$HOME/.local/share/artex"
  "$HOME/.local/share/containers"
  "$HOME/Documents/Codex"
)

# 存在してはいけない path。退役済みで、再出現は env 漏れ (GOPATH 無しの process) か sandbox の fallback
TOMBSTONES=(
  "$HOME/go"                # GOPATH は ~/.local/share/go へ移設済み (xdg-entries)
  "$HOME/Library/pnpm"      # pnpm store は XDG_DATA_HOME 配下。XDG 以前の store
  "$HOME/.local/share/mise" # mise は nix へ置換済み (registry に無い)
  "$HOME/.config/mise"      # 同上
  "$HOME/.local/state/mise" # 同上
  "$HOME/.cache/mise"       # 同上
)

days_ago() { # N -> YYYY-MM-DD
  if date --version >/dev/null 2>&1; then
    date -d "$1 days ago" +%F
  else
    date -v-"$1"d +%F
  fi
}

# sandbox が ~/.local/share/pnpm に書けなかったとき pnpm が黙って上位 dir へ落とす store。再 fetch できる
pnpm_fallback_stores() {
  [ -d "$HOME/ghq" ] || return 0
  find "$HOME/ghq" -maxdepth 5 -type d -name .pnpm-store -prune 2>/dev/null
}

avail_mib() { df -Pk "$HOME" | awk 'NR==2 {print int($4 / 1024)}'; }
used_pct() { df -Pk "$HOME" | awk 'NR==2 {print int($3 * 100 / ($3 + $4))}'; }
free_pct() { echo $((100 - $(used_pct))); }
below_target() { [ "$(free_pct)" -lt "$TARGET_PCT" ]; }

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] $*"
    return 0
  fi
  "$@"
}

pace() { # label
  local after delta
  after=$(avail_mib)
  delta=$((after - BEFORE))
  echo "  -> $1: ${delta}MiB 増 (空き ${after}MiB)"
  BEFORE=$after
}

step_tombstones() {
  local path paths=("${TOMBSTONES[@]}")
  while read -r path; do paths+=("$path"); done < <(pnpm_fallback_stores)
  for path in "${paths[@]}"; do
    [ -e "$path" ] || continue
    echo "==> tombstone: $path ($(du -sh "$path" 2>/dev/null | cut -f1))"
    # go の module cache は書込不可で rm が止まる
    run chmod -R u+w "$path"
    run rm -rf "$path"
  done
}

record_sizes() {
  local today row prev cur name size i
  today=$(date +%F)
  [ -f "$SIZES_TSV" ] && prev=$(tail -n 1 "$SIZES_TSV") || prev=
  row=$today
  for name in "${WATCHED[@]}"; do
    # 読めない file があると du は合計を出した上で非 0 になるので、終了値ではなく出力の有無で判断する
    size=$(du -sk "$name" 2>/dev/null | cut -f1 || true)
    row+=$'\t'${size:-0}
  done
  echo "==> sizes: $(printf '%s' "$row" | tr '\t' ' ') (KiB; artex containers Documents/Codex)"
  if [ -n "$prev" ]; then
    IFS=$'\t' read -r -a prev <<<"$prev"
    IFS=$'\t' read -r -a cur <<<"$row"
    for i in "${!WATCHED[@]}"; do
      [ "${cur[i + 1]}" -gt "${prev[i + 1]:-0}" ] || continue
      echo "  増加: ${WATCHED[i]} ${prev[i + 1]:-0} -> ${cur[i + 1]} KiB (前回 ${prev[0]})"
    done
  fi
  [ "$DRY_RUN" -eq 1 ] && return 0
  # 6h 毎の起動で週次の記録に揃える
  if [ -n "${prev[0]}" ] && ! [[ ${prev[0]} < $(days_ago "$SIZES_INTERVAL_DAYS") ]]; then
    return 0
  fi
  mkdir -p "$(dirname "$SIZES_TSV")"
  printf '%s\n' "$row" >>"$SIZES_TSV"
}

step_nix_gc() {
  command -v nix-collect-garbage >/dev/null || return 0
  echo "==> nix: ${CACHE_AGE_DAYS}d より古い generation と未参照 path の回収"
  run nix-collect-garbage --delete-older-than "${CACHE_AGE_DAYS}d"
}

step_nix_optimise() {
  command -v nix >/dev/null || return 0
  echo "==> nix: 同一内容の hardlink 化"
  run nix store optimise
}

prune() { # dir age_days
  local dir=$1 n
  [ -d "$dir" ] || return 0
  if [ "$DRY_RUN" -eq 1 ]; then
    n=$(find "$dir" -type f -mtime "+$CACHE_AGE_DAYS" 2>/dev/null | wc -l | tr -d ' ')
    [ "$n" -gt 0 ] && echo "  [dry-run] $dir ($n files)"
    return 0
  fi
  n=$(find "$dir" -type f -mtime "+$CACHE_AGE_DAYS" -print -delete 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" -gt 0 ] || return 0
  find "$dir" -mindepth 1 -type d -empty -delete 2>/dev/null || true
  echo "  prune $dir ($n files)"
}

step_caches() {
  echo "==> cache: ${CACHE_AGE_DAYS}d 触られていないファイル"
  local dir
  for dir in "${CACHES[@]}"; do prune "$dir"; done
}

step_codex_releases() {
  local dir=$HOME/.codex/packages/standalone current rel
  [ -L "$dir/current" ] || return 0
  echo "==> codex: current 以外の standalone release"
  current=$(readlink "$dir/current")
  case "$current" in
  /*) ;;
  *) current="$dir/$current" ;;
  esac
  current=$(cd "$current" && pwd -P)
  for rel in "$dir"/releases/*; do
    [ -d "$rel" ] || continue
    [ "$(cd "$rel" && pwd -P)" != "$current" ] || continue
    run rm -rf "$rel"
  done
}

step_artex_generations() {
  local dir gen n
  echo "==> artex: 新しい ${ARTEX_KEEP} 世代以外の deploy 残骸"
  for dir in "${ARTEX_GENERATION_DIRS[@]}"; do
    [ -d "$dir" ] || continue
    n=0
    # mtime 降順。世代 dir 名は hash で順序を持たないので時刻で切る
    while IFS= read -r gen; do
      n=$((n + 1))
      [ "$n" -gt "$ARTEX_KEEP" ] || continue
      run rm -rf "$gen"
    done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d -exec stat -f '%m %N' {} + 2>/dev/null | sort -rn | cut -d' ' -f2-)
  done
}

report_codex_workspaces() {
  local cutoff dir name size
  cutoff=$(days_ago 30)
  for dir in "$HOME/Documents/Codex/"[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]; do
    [ -d "$dir" ] || continue
    name=${dir##*/}
    [[ $name < $cutoff ]] || continue
    size=$(du -sh "$dir" 2>/dev/null | cut -f1)
    printf '  [archive candidate: older than 30d] %s  %s\n' "$size" "$dir"
  done
}

step_trash() {
  echo "==> trash: ${TRASH_AGE_DAYS}d 以上前の項目"
  [ -d "$HOME/.Trash" ] || return 0
  if [ "$DRY_RUN" -eq 1 ]; then
    find "$HOME/.Trash" -mindepth 1 -maxdepth 1 -mtime "+$TRASH_AGE_DAYS" 2>/dev/null | wc -l |
      xargs -I {} echo "  [dry-run] ~/.Trash ({} items)"
    return 0
  fi
  find "$HOME/.Trash" -mindepth 1 -maxdepth 1 -mtime "+$TRASH_AGE_DAYS" -exec rm -rf {} + 2>/dev/null || true
}

step_podman() {
  command -v podman >/dev/null || return 0
  local cutoff name info
  if [ -n "$PODMAN_MACHINE" ]; then
    info=$(podman machine inspect --format '{{.State}}' "$PODMAN_MACHINE") || return 1
    if [ "$info" != stopped ]; then
      echo "podman: machine $PODMAN_MACHINE は停止済みと確認できないため削除しない" >&2
      return 1
    fi
    echo "==> podman: stopped machine $PODMAN_MACHINE を削除 (VM 内のデータも失われる)"
    run podman machine rm --force "$PODMAN_MACHINE"
  fi
  echo "==> podman: 未使用 image / 停止 container"
  # machine が停止中は socket に繋がらない。VM 側の削除は下で扱うのでここでは止めない
  run podman system prune -f || echo "podman: 接続できないので system prune を飛ばす" >&2
  # BSD date は -d を持たない
  date --version >/dev/null 2>&1 || return 0
  echo "==> podman: ${CACHE_AGE_DAYS}d 起動していない停止済み machine"
  cutoff=$(date -d "${CACHE_AGE_DAYS} days ago" +%s)
  for name in $(podman machine list --format '{{.Name}}' 2>/dev/null); do
    name=${name%\*} # 既定 machine は Name 末尾に * が付く
    info=$(podman machine inspect --format '{{.State}} {{.LastUp.Format "2006-01-02T15:04:05Z07:00"}}' "$name" 2>/dev/null) || continue
    case "$info" in stopped\ *) ;; *) continue ;; esac
    [ "$(date -d "${info#stopped }" +%s)" -lt "$cutoff" ] || continue
    run podman machine rm --force "$name"
  done
}

archive() { # path
  local src=$1 key payload tmp='' size sha remote
  [ -e "$src" ] || {
    echo "存在しない: $src" >&2
    exit 1
  }
  src=$(cd "$(dirname "$src")" && pwd)/$(basename "$src")
  # key を HOME 相対にするため HOME 外は受けない
  case "$src" in "$HOME"/*) ;; *)
    echo "HOME 配下のみ退避できる: $src" >&2
    exit 1
    ;;
  esac
  key=$(hostname -s | tr "[:upper:]" "[:lower:]")/${src#"$HOME"/}
  [ -d "$src" ] && key=$key.tar.zst
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] $src ($(du -sh "$src" | cut -f1)) -> s3://$ARCHIVE_BUCKET/$key"
    return 0
  fi
  command -v aws >/dev/null || {
    echo "aws が無い" >&2
    exit 1
  }
  aws sts get-caller-identity >/dev/null 2>&1 || {
    echo "AWS SSO セッションが無い: aws sso login" >&2
    exit 1
  }
  if [ -d "$src" ]; then
    tmp=$(mktemp -d)
    payload=$tmp/$(basename "$src").tar.zst
    echo "==> tar: $src"
    tar --zstd -cf "$payload" -C "$(dirname "$src")" "$(basename "$src")"
  else
    payload=$src
  fi
  size=$(wc -c <"$payload" | tr -d ' ')
  sha=$(shasum -a 256 "$payload" | cut -d' ' -f1)
  echo "==> upload: s3://$ARCHIVE_BUCKET/$key ($((size / 1048576))MiB, sha256 $sha)"
  aws s3 cp "$payload" "s3://$ARCHIVE_BUCKET/$key" --storage-class GLACIER_IR --metadata "sha256=$sha"
  remote=$(aws s3api head-object --bucket "$ARCHIVE_BUCKET" --key "$key" --query '[ContentLength, Metadata.sha256]' --output text)
  [ "$remote" = "$size"$'\t'"$sha" ] || {
    echo "検証失敗 (ローカルは残す): local=$size $sha remote=$remote" >&2
    exit 1
  }
  rm -rf "$src"
  [ -z "$tmp" ] || rm -rf "$tmp"
  echo "==> archived: $src -> s3://$ARCHIVE_BUCKET/$key"
}

report_candidates() {
  echo "!! 目標空き率 ${TARGET_PCT}% に届いていない。判断が要る候補:" >&2
  local staged odd
  # staged 更新が無い Mac では du が失敗し、pipefail + errexit で report が途中で止まる
  staged=$(du -sh /System/Volumes/Preboot/*/cryptex1/proposed 2>/dev/null | cut -f1 || true)
  [ -z "$staged" ] || echo "  $staged  適用待ち macOS 更新 (Preboot)。sudo softwareupdate で適用: docs/operations.md 7.1" >&2
  if command -v podman >/dev/null; then
    while IFS='|' read -r name last disk; do
      [ -n "$name" ] || continue
      echo "  podman machine $name (${disk}, 最終起動 ${last}) — --podman-machine $name で回収" >&2
    done < <(podman machine list --format '{{.Name}}|{{.LastUp}}|{{.DiskSize}}' 2>/dev/null)
  fi
  odd=$HOME/Documents/Codex
  [ -e "$odd" ] && echo "  $(du -sh "$odd" 2>/dev/null | cut -f1)  $odd — $0 --archive <path> で S3 へ退避: docs/operations.md 7.2" >&2
  report_codex_workspaces >&2
  # HOME を package dir に差し替えた検証の残骸。repo の gitignore 対象なので削除は repo 側の clean 手順
  [ -d "$HOME/ghq" ] && find "$HOME/ghq" -maxdepth 6 -type d -path '*/packages/*/.local' -prune 2>/dev/null |
    while read -r odd; do
      echo "  $(du -sh "$odd" 2>/dev/null | cut -f1)  $odd — repo 側の clean 手順で消す (gitignore 済み)" >&2
    done
}

report_ghq_candidates() {
  local script
  script=${GHQ_CLEAN_SCRIPT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/ghq-clean.py}
  [ -x "$script" ] || {
    echo "ghq clone report unavailable: $script is not executable" >&2
    return 0
  }
  echo "==> ghq: clone retention inventory (dry-run)"
  if ! "$script" --dry-run; then
    echo "ghq clone report failed; no clone removal was attempted" >&2
  fi
}

if [ -n "$ARCHIVE_PATH" ]; then
  archive "$ARCHIVE_PATH"
  exit 0
fi

BEFORE=$(avail_mib)
echo "start: 空き $(free_pct)% (${BEFORE}MiB)"
report_ghq_candidates
step_tombstones
record_sizes

if ! below_target; then
  echo "空き率が目標以上なので何もしない"
  [ "$DRY_RUN" -eq 1 ] && report_codex_workspaces
  exit 0
fi

for step in nix_gc nix_optimise caches codex_releases artex_generations trash podman; do
  below_target || break
  "step_$step"
  pace "$step"
done

echo "---"
if below_target; then
  report_candidates
  exit 1
fi
echo "空き $(free_pct)% ($(avail_mib)MiB)${DRY_RUN:+ (dry-run)}"
