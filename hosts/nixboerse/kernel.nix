{ lib
, ...
}:

{
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
