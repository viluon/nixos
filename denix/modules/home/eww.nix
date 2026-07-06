{ delib, ... }:
delib.module {
  name = "home.eww";

  home.always = {
    programs.eww = {
      enable = true;
      yuckConfig = builtins.readFile ./eww-config/eww.yuck;
      scssConfig = builtins.readFile ./eww-config/eww.scss;
    };
  };
}
