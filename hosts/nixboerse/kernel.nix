{ lib
, pkgs
, ...
}:

let
  kernelPackages = pkgs.linuxPackages_latest;
in
{
  boot.kernelPackages = kernelPackages;

  boot.kernelPatches = [
    {
      name = "cgroups-v1-for-jvm";
      patch = null;
      structuredExtraConfig = {
        CPUSETS_V1 = lib.kernel.yes;
        MEMCG_V1 = lib.kernel.yes;
      };
    }
  ];
}
