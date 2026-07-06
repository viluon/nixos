{ delib, ... }:
delib.module {
  name = "system.networking";

  nixos.always = {
    networking.firewall.enable = true;
    networking.networkmanager.enable = true;

    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
      };
    };

    services.resolved = {
      enable = true;
      settings.Resolve.DNSOverTLS = false;
    };

    services.printing.enable = true;

    systemd.services.NetworkManager-wait-online.enable = false;
    systemd.network.wait-online.enable = false;
  };
}
