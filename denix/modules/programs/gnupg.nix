{ delib, host, ... }:
delib.module {
  name = "programs.gnupg";

  options = delib.singleEnableOption host.isLaptop;

  nixos.ifEnabled = {
    programs.gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };
}
