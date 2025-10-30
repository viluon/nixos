{ lib
, pkgs
, ...
}:
let
  kernelPackages = pkgs.linuxPackages_cachyos-lto.cachyOverride { mArch = "ZEN4"; };
in
{
  boot.kernelPackages = kernelPackages;

  # workaround for https://github.com/NixOS/nixos-hardware/issues/1581
  hardware.framework.enableKmod = false;
  boot.kernelModules = [ "cros_ec" "cros_ec_lpcs" ];

  # extra modules
  boot.extraModulePackages = with kernelPackages; [ acpi_call framework-laptop-kmod ];

  # eBPF-based scheduler
  services.scx.enable = true;

  # workaround for 25.05, see https://github.com/chaotic-cx/nyx/issues/1158#issuecomment-3216945109
  system.modulesTree = [ (lib.getOutput "modules" kernelPackages.kernel) ];
}
