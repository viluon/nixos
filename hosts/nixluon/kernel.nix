{ lib
, pkgs
, ...
}:
let
  kernelPackages = pkgs.linuxPackages_latest;
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
}
