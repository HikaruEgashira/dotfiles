# 内蔵 NVMe 1 本を丸ごと使う: ESP + LUKS2 上の btrfs subvolume
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            settings.allowDiscards = true;
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes =
                let
                  opts = [
                    "compress=zstd"
                    "noatime"
                  ];
                in
                {
                  "/root" = {
                    mountpoint = "/";
                    mountOptions = opts;
                  };
                  "/home" = {
                    mountpoint = "/home";
                    mountOptions = opts;
                  };
                  "/nix" = {
                    mountpoint = "/nix";
                    mountOptions = opts;
                  };
                };
            };
          };
        };
      };
    };
  };
}
