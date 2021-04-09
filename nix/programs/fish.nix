{
  enable = true;

  functions = {
    nixgc = "nix-collect-garbage -d";
    gcb = "git checkout -b $argv";
    gco = "git checkout $argv";
    gbd = "git branch -d $argv";
    gp = "git push";
    gb = "git branch";
    gpf = "git push --force";
    gu = "git reset --soft HEAD~1";
    grh = "git reset --hard";
    gl = "git log --pretty=oneline --abbrev-commit";
    gf = "git pull --prune";
    nixupgrade =
      "sudo -i sh -c 'nix-channel --update && nix-env -iA nixpkgs.nix && launchctl remove org.nixos.nix-daemon && launchctl load /Library/LaunchDaemons/org.nixos.nix-daemon.plist'";
    ls = "exa --reverse --sort=size --all --header --long";
    b = "broot -ghi";
    rsync_backup =
      "rsync -avrzP --exclude-from=$HOME/.dotfiles/backup/exclude.txt --delete $argv";
    s3_backup =
      "s3cmd sync --preserve --delete-removed --progress --exclude-from=$HOME/.dotfiles/backup/exclude.txt $argv";
    "..." = "../..";
    "...." = "../../..";
    "....." = "../../../..";
  };
}
