{ withSystem }:
{ flake-parts-lib, ... }:
{
  flake.homeModules.idea = { pkgs, ... }:
    let
      idea = pkgs.jetbrains.idea-ultimate;
    in
    {
      home.packages = [ idea ];

      # run on Wayland
      xdg.configFile."JetBrains/IntelliJIdea${idea.version}/idea64.vmoptions".text = "-Dawt.toolkit.name=WLToolkit";
    };
}
