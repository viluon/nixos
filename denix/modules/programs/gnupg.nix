{ delib, ... }:
delib.module {
  name = "programs.gnupg";

  nixos.always = {
    programs.gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };
}
