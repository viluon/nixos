_:
_:
{
  flake.homeModules.idea = { unstable-pkgs, ... }:
    let
      shutdownTimeout = "8s";
      systemd-run = "${unstable-pkgs.systemd}/bin/systemd-run";

      idea = unstable-pkgs.jetbrains.idea.overrideAttrs (old: {
        postFixup = (old.postFixup or "") + ''
          apps=$out/share/applications
          src=$(readlink -f "$apps")
          rm "$apps"
          mkdir -p "$apps"
          cp "$src"/* "$apps"/
          chmod -R +w "$apps"
          substituteInPlace "$apps/idea.desktop" \
            --replace-fail 'Exec=idea' \
              'Exec=${systemd-run} --user --scope --collect --property=TimeoutStopSec=${shutdownTimeout} idea'
        '';
      });

      m = builtins.match "^([^.]*\\.[^.]*).*$" idea.version;
      version-suffix = if m == null then idea.version else builtins.head m;
    in
    {
      home.packages = [ idea ];

      # run on Wayland
      xdg.configFile."JetBrains/IntelliJIdea${version-suffix}/idea64.vmoptions".text = ''
        -Xmx6144m
        -Dawt.toolkit.name=WLToolkit
        -Dsun.java2d.vulkan=true
      '';
    };
}
