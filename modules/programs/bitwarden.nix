{ pkgs, lib, ... }:

let
  age = lib.getExe pkgs.age;
  se = lib.getExe pkgs.age-plugin-se;
  dir = "$HOME/.config/secrets";
in
{
  programs.zsh.initContent = ''
    bw-touchid-enroll() {
      (
        set -euo pipefail
        umask 077
        local pw
        PATH="${lib.makeBinPath [ pkgs.age-plugin-se ]}:$PATH"
        # any-biometry にしないと復号毎の Touch ID 承認が要求されない
        ${se} keygen --access-control any-biometry -o "${dir}/bw-se.txt.new"
        read -rs "pw?Bitwarden master password: "; echo
        printf %s "$pw" | ${age} -e -R <(${se} recipients -i "${dir}/bw-se.txt.new") -o "${dir}/bw-master.age.new"
        mv "${dir}/bw-se.txt.new" "${dir}/bw-se.txt"
        mv "${dir}/bw-master.age.new" "${dir}/bw-master.age"
      )
    }

    bwu() {
      local session
      session=$(PATH="${lib.makeBinPath [ pkgs.age-plugin-se ]}:$PATH" \
        ${age} -d -i "${dir}/bw-se.txt" "${dir}/bw-master.age" \
        | bw unlock --raw --passwordfile /dev/stdin) || return
      export BW_SESSION=$session
    }
  '';
}
