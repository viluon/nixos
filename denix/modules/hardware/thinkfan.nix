{ delib, ... }:
delib.module {
  name = "hardware.thinkfan";

  options.hardware.thinkfan.enable = delib.boolOption false;

  nixos.ifEnabled.services.thinkfan =
    let
      low = 1;
      medium = 3;
      medium-high = 4;
      high = 7;
      max = "level full-speed";
    in
    {
      enable = true;
      levels = [
        [ 0 0 56 ]
        [ low 51 71 ]
        [ medium 70 81 ]
        [ medium-high 79 91 ]
        [ high 90 101 ]
        [ max 96 255 ]
      ];
    };
}
