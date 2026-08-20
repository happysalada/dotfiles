{ pkgs }:
# returns two programs: `delta` was split out of `programs.git.delta` into its
# own top-level module in home-manager 26.x
{
  git = {
    enable = true;
    package = pkgs.gitFull;
    ignores = [
      "*~"
    ];
    settings = {
      user = {
        email = "raphael@megzari.com";
        name = "happysalada";
      };

      core.editor = "hx";
      commit.verbose = true;
      init.defaultBranch = "master";

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
      url = {
        "git@github.com:happysalada" = {
          insteadOf = "https://github.com/happysalada";
        };
        "ssh://gitea@gitea.sassy.technology" = {
          insteadOf = "file:///var/lib/gitea/repositories";
        };
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

      merge.conflictStyle = "zdiff3";

      credential = {
        # `store` wrote credentials in PLAINTEXT to ~/.git-credentials.
        # libsecret talks to gnome-keyring's Secret Service instead.
        # Note github.com goes over ssh here anyway (see url.insteadOf
        # above), so this only covers other https remotes.
        helper = "${pkgs.gitFull}/share/git/contrib/credential/libsecret/git-credential-libsecret";
      };
    };
  };

  delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      plus-color = "#012800";
      minus-color = "#340001";
      side-by-side = true;
    };
  };
}
