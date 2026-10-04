{ delib, ... }:
delib.module {
  name = "home.server-git";

  home.always = {
    programs.difftastic = {
      enable = true;
      git = {
        enable = true;
        diffToolMode = true;
      };
      options.override = "*.mill:Scala";
    };

    programs.git = {
      enable = true;
      settings.push.autoSetupRemote = true;
      signing.signByDefault = true;
    };

    programs.mergiraf = {
      enable = true;
      enableGitIntegration = true;
    };
  };
}
