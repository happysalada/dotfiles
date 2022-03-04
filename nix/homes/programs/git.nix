{ pkgs, ... }: {
  enable = true;
  userEmail = "raphael@megzari.com";
  userName = "happysalada";
  ignores = [ "*~" ".DS_Store" ];
  package = pkgs.gitAndTools.gitFull;
  extraConfig = {
    core = {
      editor = "hx";
      pager = "delta";
    };
    init = { defaultBranch = "master"; };

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
    credential.helper = "store";
  };
}
