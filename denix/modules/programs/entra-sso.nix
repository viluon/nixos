{ delib, ... }:
delib.module {
  name = "programs.entraSso";

  options.programs.entraSso.enable = delib.boolOption false;

  nixos.always = { cfg, ... }: {
    imports = [
      ({ pkgs, lib, ... }: lib.mkIf cfg.enable {
        environment.systemPackages = [ pkgs.linux-entra-sso ];

        environment.etc = {
          "firefox/native-messaging-hosts/linux_entra_sso.json".source = "${pkgs.linux-entra-sso}/lib/mozilla/native-messaging-hosts/linux_entra_sso.json";
          "opt/chrome/native-messaging-hosts/linux_entra_sso.json".source = "${pkgs.linux-entra-sso}/etc/opt/chrome/native-messaging-hosts/linux_entra_sso.json";
          "chromium/native-messaging-hosts/linux_entra_sso.json".source = "${pkgs.linux-entra-sso}/etc/chromium/native-messaging-hosts/linux_entra_sso.json";
        };

        programs.chromium = {
          enable = true;
          extensions =
            let
              id = builtins.readFile "${pkgs.linux-entra-sso}/chrome/extension-id.txt";
              expression = "${id};file://${pkgs.linux-entra-sso}/chrome/linux-entra-sso.zip";
            in
            [
              (builtins.replaceStrings [ "\n" ] [ "" ] expression)
            ];
        };

        programs.firefox.policies.ExtensionSettings."linux-entra-sso@example.com" = {
          default_area = "menupanel";
          install_url = "file://${pkgs.linux-entra-sso}/firefox/linux-entra-sso.xpi";
          installation_mode = "force_installed";
          updates_disabled = true;
        };
      })
    ];
  };
}
