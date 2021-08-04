{
  enable = true;

  functions = {
    # nix
    nixgc = "nix store gc -v";
    snixgc = "sudo nix store gc -v";
    # git 
    gcb = "git checkout -b $argv";
    gc = "git checkout $argv";
    gbd = "git branch --delete --force $argv";
    gp = "git push";
    gps = "git push --set-upstream origin HEAD";
    gb = "git branch";
    gpf = "git push --force";
    gu = "git reset --soft HEAD~1";
    grh = "git reset --hard";
    gl = "git log --pretty=oneline --abbrev-commit";
    gpp = "git pull --prune";
    gsi = "git stash --include-untracked";
    gsp = "git stash pop";
    gsa = "git stage --all";
    gcm = "git commit -m $argv";
    # misc
    ls = "exa --reverse --sort=size --all --header --long $argv";
    b = "broot -ghi";
    rsync_backup =
      "rsync -avrzP --exclude-from=$HOME/.dotfiles/backup/exclude.txt --delete $argv";
    "..." = "../..";
    "...." = "../../..";
    "....." = "../../../..";
  };
}
