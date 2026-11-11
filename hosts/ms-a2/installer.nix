# Windows の NVMe 上の FAT32 パーティションから起動し、同じ NVMe を消して ms-a2 を入れる installer。
# 自分が載っているディスクを消すため、squashfs を RAM へ複写して /iso を手放してから disko を走らせる。
# ISO を FAT32 の 4GiB 上限内に収めるため target closure は同梱せず、install 時に cache から取得する。
{
  config,
  lib,
  modulesPath,
  pkgs,
  flakeRef,
  ...
}:
let
  install = pkgs.writeShellScriptBin "install-ms-a2" ''
    set -euo pipefail
    ref=''${1:-${flakeRef}}
    cfg="$ref#nixosConfigurations.ms-a2.config.system.build"

    until ${pkgs.curl}/bin/curl -fsI https://cache.nixos.org >/dev/null; do echo "network 待ち (nmtui で接続可)"; sleep 3; done

    # copytoram が効かず NVMe 上の p4 を掴んだまま消すと live 環境ごと壊れる
    [ "$(findmnt -no FSTYPE /iso)" = tmpfs ] || { echo "copytoram 未成立: /iso が RAM 上にない"; exit 1; }
    if lsblk -no MOUNTPOINTS /dev/nvme0n1 | grep -q .; then echo "/dev/nvme0n1 がまだマウントされている"; exit 1; fi

    # 消去後にネットワークや評価で失敗しても復旧できるよう、必要な closure を先に RAM 上の store へ揃える
    echo "==> ms-a2 と disko script を事前取得 (数分〜十数分)"
    system=$(nix build --no-link --print-out-paths "$cfg.toplevel")
    disko=$(nix build --no-link --print-out-paths "$cfg.diskoScript")

    lsblk /dev/nvme0n1
    printf '/dev/nvme0n1 (Windows を含む) を完全に消去して %s を入れます。続けるなら WIPE と入力: ' "$ref"
    read -r answer
    [ "$answer" = WIPE ] || { echo aborted; exit 1; }

    "$disko"
    # 失敗しても再起動せず、この行だけ再実行すれば RAM 上の store から入れ直せる
    nixos-install --system "$system" --no-root-passwd --no-channel-copy
    echo "完了。reboot してください"
  '';
in
{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

  image.baseName = lib.mkForce "nixos-ms-a2";
  # FAT のラベル上限 11 文字に収め、Windows 側で作るパーティションのラベルと一致させる
  isoImage.volumeID = "MSA2NIXOS";
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [ "copytoram" ];
    # installer 既定の zfs は latest kernel に追従しておらず、btrfs 運用なので外す
    supportedFilesystems.zfs = lib.mkForce false;
  };
  # ISO 既定の iso9660 ではなく、Windows 側で展開した FAT32 パーティションを本体として拾う
  # installation-cd-base が fileSystems 全体を mkImageMediaOverride で固定するため、全体ごとより強く上書きする
  fileSystems = lib.mkOverride 40 (
    config.lib.isoFileSystems
    // {
      "/iso" = {
        device = "/dev/disk/by-label/MSA2NIXOS";
        fsType = "vfat";
        neededForBoot = true;
        noCheck = true;
      };
    }
  );
  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false;
  environment.systemPackages = [
    install
    pkgs.git
  ];
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  services.getty.helpLine = "Run `sudo install-ms-a2 github:HikaruEgashira/dotfiles/main`. If it fails after WIPE, do not reboot; rerun the nixos-install line.";
}
