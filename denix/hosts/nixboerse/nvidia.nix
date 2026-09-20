{ delib, ... }:
delib.host {
  name = "nixboerse";

  nixos.imports = [
    (
      { config, lib, pkgs, unstable-pkgs, ... }:
      {
        environment.variables = {
          NVD_BACKEND = "direct";
          LIBVA_DRIVER_NAME = "nvidia";
          GBM_BACKEND = "nvidia-drm";
          __GLX_VENDOR_LIBRARY_NAME = "nvidia";
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
          graphics.extraPackages = [ pkgs.nvidia-vaapi-driver ];
          nvidia = {
            open = true;
            dynamicBoost.enable = true;
            package =
              (unstable-pkgs.linuxPackagesFor config.boot.kernelPackages.kernel).nvidiaPackages.stable;
            prime.offload.enable = true;
            powerManagement = {
              enable = true;
              finegrained = true;
            };
          };
        };

        services.xserver.videoDrivers = [ "nvidia" ];

        boot.extraModprobeConfig = "options nvidia " + lib.concatStringsSep " " [
          "NVreg_UsePageAttributeTable=1"
          "NVreg_RegistryDwords=RMUseSwI2c=0x01;RMI2cSpeed=100"
          "NVreg_PreserveVideoMemoryAllocations=1"
        ];
      }
    )
  ];
}
