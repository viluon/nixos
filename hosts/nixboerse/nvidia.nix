{ config
, lib
, pkgs
, ...
}:

# magic nvidia config, courtesy of TLATER (https://discourse.nixos.org/t/nvidia-open-breaks-hardware-acceleration/58770/3)
# see https://github.com/TLATER/dotfiles/blob/561931560d2c12e81f139ef8c681e6d99fc6c54e/nixos-modules/nvidia/

{
  environment.variables = {
    NVD_BACKEND = "direct";
    LIBVA_DRIVER_NAME = "nvidia";

    # Required to run the correct GBM backend for nvidia GPUs on wayland
    GBM_BACKEND = "nvidia-drm";
    # Apparently, without this nouveau may attempt to be used instead
    # (despite it being blacklisted)
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    # Hardware cursors are currently broken on wlroots
    WLR_NO_HARDWARE_CURSORS = "1";

    MOZ_DISABLE_RDD_SANDBOX = "1";
  };

  programs.firefox.preferences = {
    "media.ffmpeg.vaapi.enabled" = true;
    "media.rdd-ffmpeg.enabled" = true;
    "media.av1.enabled" = true;
    "gfx.x11-egl.force-enabled" = true;
    "widget.dmabuf.force-enabled" = true;
  };

  hardware = {
    graphics.extraPackages = with pkgs; [
      nvidia-vaapi-driver
    ];

    nvidia = {
      open = true;
      dynamicBoost.enable = true;
      package =
        # workaround for https://github.com/NixOS/nixpkgs/issues/489947
        let
          base = config.boot.kernelPackages.nvidiaPackages.mkDriver {
            version = "590.48.01";
            sha256_64bit = "sha256-ueL4BpN4FDHMh/TNKRCeEz3Oy1ClDWto1LO/LWlr1ok=";
            openSha256 = "sha256-hECHfguzwduEfPo5pCDjWE/MjtRDhINVr4b1awFdP44=";
            settingsSha256 = "sha256-4SfCWp3swUp+x+4cuIZ7SA5H7/NoizqgPJ6S9fm90fA=";
            persistencedSha256 = "";
          };
          cachyos-nvidia-patch = pkgs.fetchpatch {
            url = "https://raw.githubusercontent.com/CachyOS/CachyOS-PKGBUILDS/576f5c9e131607d4040b654ee68602c6b9e1e776/nvidia/nvidia-utils/kernel-6.19.patch";
            sha256 = "sha256-YuJjSUXE6jYSuZySYGnWSNG5sfVei7vvxDcHx3K+IN4=";
          };
        in
        base // {
          open = base.open.overrideAttrs (oldAttrs: {
            patches = (oldAttrs.patches or [ ]) ++ [ cachyos-nvidia-patch ];
          });
        };
      prime.offload.enable = true;
      powerManagement = {
        enable = true;
        finegrained = true;
      };
    };
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  boot.extraModprobeConfig = "options nvidia " + lib.concatStringsSep " " [
    # nvidia assume that by default your CPU does not support PAT,
    # but this is effectively never the case in 2023
    "NVreg_UsePageAttributeTable=1"
    # This is sometimes needed for ddc/ci support, see
    # https://www.ddcutil.com/nvidia/
    "NVreg_RegistryDwords=RMUseSwI2c=0x01;RMI2cSpeed=100"
    "NVreg_PreserveVideoMemoryAllocations=1"
  ];
}
