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
    dnsovertls = "false";
  };

  # MagicDNS
  # networking.nameservers = [ "100.100.100.100" "8.8.8.8" "1.1.1.1" ];
  # networking.search = [ "werewolf-torino.ts.net" ];

  services.tailscale.enable = false;

  # Enable CUPS printing
  services.printing.enable = true;
}
