{ delib, ... }:
delib.module {
  name = "constants";

  options.constants = with delib; {
    username = readOnly (strOption "viluon");
    userfullname = readOnly (strOption "Andrew Kvapil");
  };
}
