{ delib, ... }:
delib.module {
  name = "user";

  nixos.always =
    { myconfig, ... }:
    let
      inherit (myconfig.constants) username userfullname;
    in
    {
      imports = [
        (
          { config, pkgs, ... }:
          let
            githubKeys = pkgs.stdenv.mkDerivation {
              name = "github-keys-${username}";

              dontUnpack = true;
              nativeBuildInputs = with pkgs; [ cacert curl jq ];

              outputHashMode = "flat";
              outputHashAlgo = "sha256";
              outputHash = "sha256-yTZogYWwpAJVONDLOmwU1v1TrN4XxBJd88p0PaVco+M=";

              buildPhase = ''
                curl "https://api.github.com/users/${username}/keys" | \
                  jq 'map(.key) | sort' > keys.json
              '';

              installPhase = ''
                cp keys.json $out
              '';
            };
          in
          {
            users.users.${username} = {
              isNormalUser = true;
              description = userfullname;
              extraGroups = [
                "audio"
                "cdrom"
                "docker"
                "libvirtd"
                "networkmanager"
                "uinput"
                "wheel"
                "wireshark"
                config.hardware.i2c.group
              ];
              openssh.authorizedKeys.keys = builtins.fromJSON (builtins.readFile githubKeys);
              shell = pkgs.zsh;
              initialHashedPassword = "$6$rounds=2000000$9V4QeLdb.yXDzOEM$37G75PGikc2/v2pogHnjnNp4By3aCwlPEWyVa1wD/myF1wo8Ur7WWFlsZ6atN.43wJdfi9pwebd.PqPDEw0WF1";
            };

            programs.zsh.enable = true;

            security.sudo.extraRules = [{
              users = [ username ];
              commands = [
                {
                  command = "/run/current-system/sw/bin/nixos-rebuild test -L --flake /home/${username}/nixos";
                  options = [ "NOPASSWD" ];
                }
                {
                  command = "/run/current-system/sw/bin/tee /proc/acpi/ibm/fan";
                  options = [ "NOPASSWD" ];
                }
                {
                  command = "/run/current-system/sw/bin/compsize";
                  options = [ "NOPASSWD" ];
                }
              ];
            }];

            security.pam.loginLimits = [
              { domain = "@audio"; item = "memlock"; type = "-"; value = "unlimited"; }
              { domain = "@audio"; item = "rtprio"; type = "-"; value = "99"; }
              { domain = "@audio"; item = "nofile"; type = "soft"; value = "99999"; }
              { domain = "@audio"; item = "nofile"; type = "hard"; value = "99999"; }
            ];
          }
        )
      ];
    };
}
