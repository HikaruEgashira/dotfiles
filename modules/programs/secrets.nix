# 秘密は launchd が待ち受ける unix socket 越しに 1 key ずつ取り出す。shell env には載せない
{
  config,
  lib,
  pkgs,
  ...
}:

let
  home = config.home.homeDirectory;
  secretsDir = "${home}/.config/secrets";
  socket = "${home}/.local/state/secrets.sock";
  wrapperDir = "${home}/.config/secrets-env/bin";

  broker = pkgs.writeShellScript "secrets-broker" ''
    set -eu
    IFS= read -r -t 5 name || exit 1
    case "$name" in "" | *[!A-Z0-9_]*) exit 1 ;; esac
    ${pkgs.age}/bin/age -d -i ${secretsDir}/age-key.txt ${secretsDir}/env.age \
      | ${pkgs.gnugrep}/bin/grep -m1 "^$name=" | ${pkgs.coreutils}/bin/cut -d= -f2-
  '';

  client = pkgs.writeShellScript "secret" ''
    set -eu
    sock=${lib.escapeShellArg socket}
    get() { printf '%s\n' "$1" | /usr/bin/nc -U "$sock"; }
    case "''${1-}" in
      get) get "$2" ;;
      run)
        shift
        while [ $# -gt 0 ] && [ "$1" != "--" ]; do
          export "$1=$(get "$1")"
          shift
        done
        shift
        exec "$@"
        ;;
      *) echo "usage: secret get NAME | secret run NAME... -- cmd args" >&2; exit 2 ;;
    esac
  '';

  # tool ごとに必要な key だけを注入する。socket に届かない (sandbox 内) 時は空で続行する
  wrap =
    name: vars:
    pkgs.writeShellScript "secrets-env-${name}" ''
      set -eu
      real=$(PATH="''${PATH//${lib.escapeShellArg wrapperDir}:/}" command -v ${name})
      ${lib.concatMapStrings (v: ''
        export ${v.env}="$(${client} get ${v.key} 2>/dev/null | ${pkgs.gnused}/bin/sed ${lib.escapeShellArg v.sed} || true)"
      '') vars}
      exec "$real" "$@"
    '';
  id = key: {
    env = key;
    inherit key;
    sed = "";
  };
  wrappers = {
    npm = [ (id "FLATT_GUARD_TOKEN") ];
    npx = [ (id "FLATT_GUARD_TOKEN") ];
    pnpm = [ (id "FLATT_GUARD_TOKEN") ];
    orca = [ (id "ORCA_KEY") ];
    uv = [
      {
        env = "UV_INDEX_URL";
        key = "FLATT_GUARD_TOKEN";
        sed = "s|^.\\+$|https://token:&@pypi.flatt.tech/simple/|";
      }
    ];
  };
in
{
  launchd.agents.secrets-broker = {
    enable = true;
    config = {
      Label = "dev.egahika.secrets-broker";
      ProgramArguments = [ "${broker}" ];
      Sockets.Listener = {
        SockPathName = socket;
        SockPathMode = 384;
      };
      inetdCompatibility.Wait = false;
      EnvironmentVariables.HOME = home;
      StandardErrorPath = "${home}/.cache/secrets-broker.err";
    };
  };

  home.file = {
    ".local/bin/secret".source = client;
  }
  // lib.mapAttrs' (
    name: vars: lib.nameValuePair ".config/secrets-env/bin/${name}" { source = wrap name vars; }
  ) wrappers;

  programs.zsh.initContent = lib.mkAfter ''
    path=(${lib.escapeShellArg wrapperDir} $path)
  '';
}
