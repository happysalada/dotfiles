{
  enable = true;
  userEmail = "raphael@megzari.com";
  userName = "happysalada";
  ignores = [ "*~" ".DS_Store" ];
  extraConfig = {
    core = {
      editor = "emacs";
      pager = "delta";
    };

    url = { "git@github.com:" = { insteadOf = "https://github.com/"; }; };

    push.default = "upstream";

    pull.rebase = true;

    rebase = {
      autoSquash = true;
      autoStash = true;
    };

    delta = {
      plus-color = "#012800";
      minus-color = "#340001";
      side-by-side = true;
    };

    interactive = { diffFilter = "delta --color-only"; };
  };
}
