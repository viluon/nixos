_:
_:
{
  flake.homeModules.idea = { unstable-pkgs, ... }:
    let
      idea = unstable-pkgs.jetbrains.idea;
      m = builtins.match "^(.*)\\.[^.]*$" idea.version;
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
