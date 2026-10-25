{ delib, ... }:
delib.host {
  name = "never-talk-to-strangers";
  type = "server";
  system = "x86_64-linux";

  nixos =
    { myconfig, ... }:
    {
      imports = [
        (
          { config, ... }:
          {
            users.users.root.openssh.authorizedKeys.keys =
              config.users.users.${myconfig.constants.username}.openssh.authorizedKeys.keys;

            swapDevices = [
              {
                device = "/var/lib/swapfile";
                size = 2048;
              }
            ];

            services.journald.extraConfig = "SystemMaxUse=256M";

            system.stateVersion = "26.05";
          }
        )
      ];
    };
}
