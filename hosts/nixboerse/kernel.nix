{ lib
, pkgs
, ...
}:

let
  kernelPackages = pkgs.linuxPackages_latest;
in
{
  boot.kernelPackages = kernelPackages;

  # eBPF-based scheduler
  services.scx.enable = true;

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
