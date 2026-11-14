# Minisforum MS-A2 (Ryzen 9 9955HX / Radeon iGPU) の bare-metal NixOS。Wayland は niri のみ
{ pkgs, ... }:
{
  imports = [
    ./disko.nix
    ./gh-runner.nix
    ./deck-cast.nix
    ./gypxy.nix
  ];

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    # Zen5 / RDNA3.5 は新しい kernel でないと amdgpu が安定しない
    kernelPackages = pkgs.linuxPackages_latest;
    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "thunderbolt"
      "usb_storage"
      "sd_mod"
    ];
    kernelModules = [ "kvm-amd" ];
  };

  hardware = {
    cpu.amd.updateMicrocode = true;
    enableRedistributableFirmware = true;
    graphics.enable = true;
    # NuPhy 等の BT キーボード用。bluetoothctl は bluez に同梱
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  networking = {
    hostName = "ms-a2";
    networkmanager.enable = true;
    firewall.enable = true;
  };

  time.timeZone = "Asia/Tokyo";
  i18n = {
    defaultLocale = "ja_JP.UTF-8";
    inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5.waylandFrontend = true;
      fcitx5.addons = [ pkgs.fcitx5-mozc ];
    };
  };

  programs = {
    niri.enable = true;
    zsh.enable = true;
    # claude 等の汎用 Linux 向け動的リンクバイナリを ~/.local/bin から実行するため
    nix-ld.enable = true;
  };
  services = {
    greetd = {
      enable = true;
      settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd niri-session";
    };
    pipewire = {
      enable = true;
      pulse.enable = true;
    };
    tailscale.enable = true;
    fwupd.enable = true;
    fstrim.enable = true;
  };
  security.rtkit.enable = true;

  users.users.hikae = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
    ];
    # 初回ログイン後に passwd で変更する
    initialPassword = "hikae";
  };

  environment.systemPackages = with pkgs; [
    # niri 既定設定の Mod+T が alacritty を起動する
    alacritty
    foot
    fuzzel
    firefox
    git
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [ "@wheel" ];
  };

  system.stateVersion = "26.05";
}
