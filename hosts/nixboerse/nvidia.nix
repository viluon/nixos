{ lib
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
