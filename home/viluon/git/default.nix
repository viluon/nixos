{
  programs.difftastic = {
    enable = true;
    git = {
      enable = true;
      diffToolMode = true;
    };
    options.override = "*.yuck:Emacs Lisp";
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
    settings.push.autoSetupRemote = true;
    signing.signByDefault = true;
  };

  programs.mergiraf.enable = true;
}
