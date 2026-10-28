{ delib, host, ... }:
delib.module {
  name = "programs.steam";

  options = delib.singleEnableOption host.gamingFeatured;

  nixos.ifEnabled = {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };

    programs.gamescope.enable = true;

    hardware.graphics.enable32Bit = true;
  };
}
