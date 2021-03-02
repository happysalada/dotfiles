{
  custom_plugins = [{
    merged = false;
    name = "lilydjwg/colorizer";
  }];
  layers = [
    { name = "default"; }
    {
      enable = true;
      name = "colorscheme";
    }
    { name = "fzf"; }
    {
      default_height = 30;
      default_position = "top";
      name = "shell";
    }
    { name = "edit"; }
    { name = "VersionControl"; }
    { name = "git"; }
    {
      auto-completion-return-key-behavior = "complete";
      auto-completion-tab-key-behavior = "cycle";
      autocomplete_method = "coc";
      name = "autocomplete";
    }
    { name = "lang#nix"; }
    { name = "lang#sh"; }
    { name = "lang#html"; }
    { name = "lang#c"; }
    { name = "lang#dockerfile"; }
    { name = "lang#elixir"; }
    { name = "lang#javascript"; }
    { name = "lang#rust"; }
    { name = "lang#sql"; }
    { name = "lang#zig"; }
    { name = "vim"; }
  ];
  options = {
    buffer_index_type = 4;
    colorscheme = "gruvbox";
    colorscheme_bg = "dark";
    enable_guicolors = true;
    enable_statusline_mode = true;
    enable_tabline_filetype_icon = true;
    statusline_separator = "fire";
    timeoutlen = 500;
  };
}
