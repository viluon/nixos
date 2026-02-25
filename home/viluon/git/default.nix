{
  programs.difftastic = {
    enable = true;
    git = {
      enable = true;
      diffToolMode = true;
    };
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
    settings.push.autoSetupRemote = true;
    signing.signByDefault = true;
  };

  programs.mergiraf.enable = true;
}
