{ delib, ... }:
delib.host {
  name = "never-talk-to-strangers";
  type = "server";
  system = "x86_64-linux";

  nixos.imports = delib.umport {
    path = ./.;
    exclude = [ ./default.nix ];
  };
}
