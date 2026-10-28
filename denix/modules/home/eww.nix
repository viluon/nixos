{ delib, host, ... }:
delib.module {
  name = "home.eww";

  options = delib.singleEnableOption host.isLaptop;

  home.ifEnabled = {
    programs.eww = {
      enable = true;
      yuckConfig = builtins.readFile ./eww-config/eww.yuck;
      scssConfig = builtins.readFile ./eww-config/eww.scss;
    };
  };
}
