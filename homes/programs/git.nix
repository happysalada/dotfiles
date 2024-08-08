{ pkgs, ... }: {
  enable = true;
  userEmail = "raphael@megzari.com";
  userName = "happysalada";
  ignores = [ "*~" ".DS_Store" ];
  package = pkgs.gitAndTools.gitFull;
  # this doesn't change anything in gitui
  # difftastic = {
  #   enable = true;
  #   background = "dark";
  # };
  delta = {
    enable = true;
    options = {
      plus-color = "#012800";
      minus-color = "#340001";
      side-by-side = true;
    };
  };
  extraConfig = {
    core = {
      editor = "hx";
    };
    commit.verbose = true;
    init = { defaultBranch = "master"; };

    diff = {
      colorMoved = true;
      algorithm = "histogram";
      submodule = "log";
    };
    
    status.submoduleSummary = true;
    submodule.recurse = true;

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
      updateRefs = true;
    };

    merge.conflicstyle = "zdiff3";

    credential.helper = "store";
  };
}
