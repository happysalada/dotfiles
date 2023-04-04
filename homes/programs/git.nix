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

    # breaks cargo update function for some reason
    # find out how to do something about it someday
    # https://github.com/rust-lang/cargo/issues/3381
    # causing problems on servers as well
    # causing problems without on my local to push
    url = { 
      "git@github.com:happysalada" = { insteadOf = "https://github.com/happysalada"; };
      "ssh://gitea@gitea.sassy.technology" = { insteadOf = "file:///var/lib/gitea/repositories"; };
    };

    push = {
      default = "upstream";
      autoSetupRemote = true;
    };

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
