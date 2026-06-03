{ ...
}:

{
  networking.firewall.enable = true;
  networking.networkmanager.enable = true;

  # sshd
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # systemd-resolved
  services.resolved = {
    enable = true;
    settings.Resolve.DNSOverTLS = false;
  };

  # Enable CUPS printing
  services.printing.enable = true;

  # The notion of "online" is a broken concept
  systemd.services.NetworkManager-wait-online.enable = false;
  systemd.network.wait-online.enable = false;
}
