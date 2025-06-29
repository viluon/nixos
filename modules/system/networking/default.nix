{ ...
}:

{
  networking.firewall.enable = true;

  # systemd-resolved
  services.resolved = {
    enable = true;
    dnsovertls = "true";
  };

  # MagicDNS
  networking.nameservers = [ "100.100.100.100" "8.8.8.8" "1.1.1.1" ];
  networking.search = [ "werewolf-torino.ts.net" ];

  services.tailscale.enable = true;

  # Enable CUPS printing
  services.printing.enable = true;
}
