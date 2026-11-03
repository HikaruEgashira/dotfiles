# shellcheck shell=bash
# local.env を shell として評価せず、KEY=VALUE 行だけを受け付けて export する。
# 読めない行は起動前に落とし、`&` 等のメタ文字で値が静かに消える事故を防ぐ。
load_env_file() {
  local file=$1 line name value lineno=0
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))
    case $line in '' | '#'*) continue ;; esac
    name=${line%%=*}
    value=${line#*=}
    if [ "$name" = "$line" ] || ! [[ $name =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      echo "load_env_file: $file:$lineno is not KEY=VALUE" >&2
      return 1
    fi
    case $value in
    \'*\') value=${value#\'} value=${value%\'} ;;
    \"*\") value=${value#\"} value=${value%\"} ;;
    esac
    export "$name=$value"
  done <"$file"
}
