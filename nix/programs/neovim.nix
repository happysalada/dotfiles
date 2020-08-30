{ pkgs, ... }:
{
  enable = true;
  viAlias = true;
  vimAlias = true;
  extraConfig = builtins.readFile ./extraConfig.vim;
  plugins = with pkgs.vimPlugins; [
    coc-nvim
    rust-vim
    vim-repeat
    vim-easymotion
    fzf-vim
    nerdtree
    vim-fish
    vim-elixir
    vim-which-key
    vim-gitgutter
  ];
}