{ delib, ... }:
delib.host {
  name = "nixluon";

  nixos.imports = [
    (
      { pkgs, ... }:
      let
        kernelPackages = pkgs.linuxPackages_latest;
      in
      {
        boot.kernelPackages = kernelPackages;
        boot.extraModulePackages = with kernelPackages; [ acpi_call ];
      }
    )
  ];
}
