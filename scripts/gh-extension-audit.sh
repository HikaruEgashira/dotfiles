#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

dir=${1:?usage: gh-extension-audit.sh <extensions-dir>}
broken=0
total=0

report() { printf '  %-9s %-14s %s\n' "$1" "$2" "$3"; }

echo "## gh extensions ($dir)"
echo ""

if [ ! -d "$dir" ]; then
  echo "OK: gh extension directory is absent"
  exit 0
fi

for entry in "$dir"/*; do
  name=${entry##*/}
  total=$((total + 1))
  case "$name" in
  gh-*) ;;
  *)
    report SKIP "$name" "gh- prefix が無く gh は読まない"
    continue
    ;;
  esac
  if [ -L "$entry" ]; then
    target=$(readlink "$entry")
    if [ ! -e "$entry" ]; then
      report DANGLING "$name" "symlink 先が無い: $target"
      broken=1
      continue
    fi
    origin="symlink -> $target"
  else
    origin="managed"
  fi
  if [ ! -d "$entry" ]; then
    report BROKEN "$name" "directory ではない ($origin)"
    broken=1
    continue
  fi
  bin="$entry/$name"
  if [ ! -f "$bin" ]; then
    report BROKEN "$name" "$name が無い ($origin)"
    broken=1
  elif [ ! -x "$bin" ]; then
    report BROKEN "$name" "$name が実行可能でない ($origin)"
    broken=1
  else
    report OK "$name" "$origin"
  fi
done

echo ""
if [ "$broken" -eq 1 ]; then
  echo "壊れた gh extension あり: 復旧は docs/operations.md §4.8"
  exit 1
fi
echo "OK: $total gh extensions resolve to an executable"
