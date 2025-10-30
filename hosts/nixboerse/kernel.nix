{ lib
, pkgs
, ...
}:

let
  kernelPackages = pkgs.linuxPackages_cachyos-lto.cachyOverride { mArch = "GENERIC_V4"; };
in
{
  boot.kernelPackages = kernelPackages;

  # eBPF-based scheduler
  services.scx.enable = true;

  # workaround for 25.05, see https://github.com/chaotic-cx/nyx/issues/1158#issuecomment-3216945109
  system.modulesTree = [ (lib.getOutput "modules" kernelPackages.kernel) ];

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
