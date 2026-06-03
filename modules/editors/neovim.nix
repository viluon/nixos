{ ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    withPython3 = true;
    withRuby = true;

    initLua = ''
      vim.opt.number = true
      vim.opt.relativenumber = true
    '';
  };
}
