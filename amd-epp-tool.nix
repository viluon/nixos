localFlake:
{ self
, inputs
, lib
, config
, ...
}:
{
  perSystem = { system, ... }:
    let
      packages.amd-epp-tool = localFlake.withSystem system ({ pkgs, ... }:
        pkgs.rustPlatform.buildRustPackage (finalAttrs: {
          pname = "amd-epp-tool";
          version = "v0.6.0";

          src = pkgs.fetchFromGitHub {
            owner = "jayv";
            repo = "amd-epp-tool";
            tag = finalAttrs.version;
            hash = "sha256-X2akhXi5p2hviD5lQGDwRJqeRh5jtbcOaH6qLSu/kY4=";
          };

          cargoHash = "sha256-UvbKMimRxeD5C86OFtX1PrRG+NDKTN/4RTzCSAd+1kc=";

          # tests need sysfs access, unavailable in the sandbox
          doCheck = false;

          meta = {
            description = ''
              A simple CLI and TUI to configure the scaling_governor and energy_performance_preference settings of the amd_pstate_epp driver.
            '';
            homepage = "https://github.com/jayv/amd-epp-tool";
            license = lib.licenses.asl20;
            maintainers = [ ];
          };
        })
      );
    in
    {
      inherit packages;
    };
}
