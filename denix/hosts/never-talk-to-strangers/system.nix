{ config, ... }:
{
  users.users.root.openssh.authorizedKeys.keys =
    config.users.users.${config.myconfig.constants.username}.openssh.authorizedKeys.keys;

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 2048;
    }
  ];

  services.journald.extraConfig = "SystemMaxUse=256M";

  system.stateVersion = "26.05";
}
