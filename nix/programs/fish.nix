{ pkgs, ... }: {
  enable = true;

  functions = {
    nixgc = "nix-collect-garbage -d";
    gcb = "git checkout -b $argv";
    gco = "git checkout $argv";
    gbd = "git branch -d $argv";
    gp = "git push";
    gpf = "git push --force";
    gu = "git reset --soft HEAD~1";
    grh = "git reset --hard";
    nixupgrade =
      "sudo -i sh -c 'nix-channel --update && nix-env -iA nixpkgs.nix && launchctl remove org.nixos.nix-daemon && launchctl load /Library/LaunchDaemons/org.nixos.nix-daemon.plist'";
    ls = "exa --reverse --sort=size --all --header --long";
    gl = "git pull --prune";
    b = "broot -ghi";
    rsync_backup =
      "rsync -avrzP --exclude-from=$HOME/.dotfiles/backup/exclude.txt --delete $argv";
    s3_backup =
      "s3cmd sync --preserve --delete-removed --progress --exclude-from=$HOME/.dotfiles/backup/exclude.txt $argv";
  };

  shellInit = ''
    for p in "$HOME/.nix-profile/bin" "/nix/var/nix/profiles/default/bin" "/run/current-system/sw/bin"
      if not contains $p $PATH
        set -g PATH $p $PATH
      end
    end

    for p in "$HOME/.nix-defexpr/channels" "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixpkgs" "/nix/var/nix/profiles/per-user/root/channels"
      if not contains $p $NIX_PATH
        set -g NIX_PATH $p $NIX_PATH
      end
    end
  '';
}
