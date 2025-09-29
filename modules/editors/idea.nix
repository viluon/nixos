{ withSystem }:
{ flake-parts-lib, ... }:
{
  flake.homeModules.idea = { unstable-pkgs, ... }:
    let
      idea = unstable-pkgs.jetbrains.idea-ultimate;
    in
    {
      home.packages = [ idea ];

      # run on Wayland
      xdg.configFile."JetBrains/IntelliJIdea${idea.version}/idea64.vmoptions".text = "-Dawt.toolkit.name=WLToolkit";
    };
}
