{ delib, host, ... }:
delib.module {
  name = "home.copilotSkills";

  options = delib.singleEnableOption host.isLaptop;

  home.ifEnabled.home.file.".copilot/skills" = {
    source = ./copilot-skills;
    recursive = true;
  };
}
