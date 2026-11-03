# shellcheck shell=bash
# `use secrets [KEY...]`: ~/.config/secrets/env.age を復号し、指定したキーだけ (無指定なら全部) を export する
use_secrets() {
  local dir="$HOME/.config/secrets"
  local plain line name value wanted
  if [ ! -r "$dir/env.age" ] || [ ! -r "$dir/age-key.txt" ]; then
    log_error "use_secrets: $dir/env.age or age-key.txt is not readable"
    return 1
  fi
  plain=$(age -d -i "$dir/age-key.txt" "$dir/env.age") || return 1
  local -a found=()
  while IFS= read -r line || [ -n "$line" ]; do
    case $line in '' | '#'*) continue ;; esac
    name=${line%%=*}
    value=${line#*=}
    if [ $# -gt 0 ]; then
      wanted=0
      for k in "$@"; do [ "$k" = "$name" ] && wanted=1; done
      [ "$wanted" = 1 ] || continue
    fi
    export "$name=$value"
    found+=("$name")
  done <<<"$plain"
  local missing=0
  for k in "$@"; do
    case " ${found[*]-} " in *" $k "*) ;; *)
      log_error "use_secrets: $k is not in $dir/env.age"
      missing=1
      ;;
    esac
  done
  [ -n "${FLATT_GUARD_TOKEN-}" ] && export UV_INDEX_URL="https://token:$FLATT_GUARD_TOKEN@pypi.flatt.tech/simple/"
  return "$missing"
}
