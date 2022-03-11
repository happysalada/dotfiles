{
  enable = true;

  functions = {
    # git 
    gp = "git push";
    gcb = "git checkout -b $argv";
    gcm = "git commit -m $argv";
    ggc = ''
      git reflog expire --all --expire=now
      git gc --prune=now --aggressive
    '';
    rsync_backup =
      "rsync -avrzP --exclude-from=$HOME/.dotfiles/backup/exclude.txt --delete $argv";
    "..." = "../..";
    "...." = "../../..";
    "....." = "../../../..";
  };

  shellAliases = {
    # nix
    nixgc = "nix store gc -v";
    snixgc = "sudo nix-collect-garbage -d";
    # git
    gps = "git push --set-upstream origin HEAD";
    gl = "git log --pretty=oneline --abbrev-commit";
    gbd = "git branch --delete --force";
    gc = "git checkout";
    gpp = "git pull --prune";
    gsi = "git stash --include-untracked";
    gsp = "git stash pop";
    gsa = "git stage --all";
    gfu = "git fetch upstream";
    gmu = "git merge upstream/master master";
    gb = "git branch";
    gpf = "git push --force";
    gu = "git reset --soft HEAD~1";
    grh = "git reset --hard";
    # misc
    ls = "exa --reverse --sort=size --all --header --long $argv";
    b = "broot -ghi";
  };

  # put installed binaries before local binaries
  interactiveShellInit = ''
    for path in /Users/raphael/.nix-profile/bin /run/current-system/sw/bin
      set -x PATH $path $PATH
    end
  '';
}

