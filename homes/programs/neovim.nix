{ pkgs }:
# let
#   copilotVim = pkgs.vimUtils.buildVimPluginFrom2Nix {
#     name = "vim-easygrep";
#     src = pkgs.fetchFromGitHub {
#       owner = "github";
#       repo = "copilot.vim";
#       rev = "1358e8e45ecedc53daf971924a0541ddf6224faf";
#       hash = "sha256-6xIOngHzmBrgNfl0JI5dUkRLGlq2Tf+HsUj5gha/Ppw=";
#     };
#   };
# in
{
  enable = true;
  viAlias = true;
  vimAlias = true;
  # extraConfig = builtins.readFile ./extraConfig.vim;
  # plugins = with pkgs.vimPlugins; [
  #   coc-nvim
  #   rust-vim
  #   vim-repeat
  #   vim-easymotion
  #   fzf-vim
  #   nerdtree
  #   alchemist-vim
  #   vim-which-key
  #   vim-gitgutter
  #   papercolor-theme
  #   vim-nix
  #   copilotVim
  # ];
}
