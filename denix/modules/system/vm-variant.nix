{ delib, ... }:
delib.module {
  name = "system.vmVariant";

  nixos.always.imports = [
    ({ pkgs, lib, ... }: {
      virtualisation.vmVariant = {
        virtualisation = {
          cores = 2;
          memorySize = 4096;
          forwardPorts = [
            {
              from = "host";
              host.port = 2222;
              guest.port = 22;
            }
          ];
          qemu = {
            options = [
              "-enable-kvm"
              "-display gtk,grab-on-hover=on"
            ];
            package = pkgs.qemu_kvm;
          };
        };

        services.qemuGuest.enable = true;

        boot.kernelModules = [
          "virtio_pci"
          "virtio_net"
          "virtio_blk"
          "virtio_scsi"
          "virtio_balloon"
        ];

        users.users.viluon = {
          initialHashedPassword = lib.mkForce null;
          password = "";
        };

        services.displayManager = {
          autoLogin = {
            enable = true;
            user = "viluon";
          };

          defaultSession = lib.mkForce "gnome";
        };
      };
    })
  ];
}
