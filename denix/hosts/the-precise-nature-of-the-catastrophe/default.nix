{ delib, inputs, ... }:
let
  hostName = "the-precise-nature-of-the-catastrophe";
in
delib.host {
  name = hostName;
  type = "server";
  system = "aarch64-linux";

  myconfig = {
    programs.gnupg.enable = true;
    system.legacyCompat.enable = true;
    system.networking.enable = true;
    system.sysctl.enable = true;
  };

  nixos.imports = [
    inputs.nixos-hardware.nixosModules.raspberry-pi-3
    "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
    (
      { lib, pkgs, ... }:
      {
        boot = {
          kernelParams = lib.mkAfter [
            "earlycon"
            "console=ttyAMA0,115200n8"
          ];
          supportedFilesystems.zfs = false;
        };

        hardware.raspberry-pi = {
          configtxt = {
            settings.all.enable_uart = true;
            deviceTreeOverlays.all = [
              { vc4-fkms-v3d = { }; }
              { disable-bt = { }; }
            ];
          };
          firmware = {
            enable = true;
            uboot.enable = true;
          };
        };
        image.baseName = lib.mkForce hostName;

        swapDevices = [
          {
            device = "/var/lib/swapfile";
            size = 2048;
          }
        ];

        environment.systemPackages = [ pkgs.git ];

        system.stateVersion = "26.05";

        virtualisation.vmVariant = {
          boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
          hardware.raspberry-pi.firmware.enable = lib.mkForce false;
          services.qemuGuest.enable = true;
          users.users.viluon = {
            initialHashedPassword = lib.mkForce null;
            password = "";
          };
          virtualisation = {
            cores = 2;
            memorySize = 2048;
            forwardPorts = [
              {
                from = "host";
                host.port = 2222;
                guest.port = 22;
              }
            ];
          };
        };
      }
    )
  ];
}
