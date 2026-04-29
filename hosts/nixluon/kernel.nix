{ lib
, pkgs
, ...
}:
let
  kernelPackages = pkgs.linuxPackages_latest;
in
{
  boot.kernelPackages = kernelPackages;

  # extra modules
  boot.extraModulePackages = with kernelPackages; [ acpi_call ];
}
