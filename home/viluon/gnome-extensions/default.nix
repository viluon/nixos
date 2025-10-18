{ lib, ... }:

let
  filenames = builtins.attrNames (lib.filterAttrs (name: _: name != "default.nix" && name != "common.nix") (builtins.readDir ./.));
  hostnames = map (name: lib.removeSuffix ".nix" name) filenames;
  hosts = lib.genAttrs hostnames (hostname: import ./${hostname}.nix);
in
{
  getGnomeExtensions = hostname: hosts.${hostname};
}
