{
  networking.useNetworkd = true;
  networking.useDHCP = false;

  systemd.network.networks."10-oci-vnic" = {
    matchConfig.Type = "ether";
    networkConfig.DHCP = "ipv4";
    dhcpV4Config.UseMTU = true;
  };

  services.openssh = {
    enable = true;
    hostKeys = [
      {
        type = "ed25519";
        path = "/etc/ssh/ssh_host_ed25519_key";
      }
    ];
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  services.tailscale = {
    enable = true;
    openFirewall = true;
  };
}
