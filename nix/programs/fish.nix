{ pkgs, ... }: {
  enable = true;

  shellAliases = {
    nixgc = "nix-collect-garbage -d";
    gcb = "git checkout -b";
    gco = "git checkout";
    gp = "git push";
    nixupgrade =
      "sudo -i sh -c 'nix-channel --update && nix-env -iA nixpkgs.nix && launchctl remove org.nixos.nix-daemon && launchctl load /Library/LaunchDaemons/org.nixos.nix-daemon.plist'";
    ls = "exa --reverse --sort=size --all --header --long";
    gl = "git pull --prune";
    broot = "broot -ghi";
  };

  shellInit = ''
    for p in "$HOME/.nix-profile/bin" "/nix/var/nix/profiles/default/bin" "/run/current-system/sw/bin"
      if not contains $p $PATH
        set -g PATH $p $PATH
      end
    end

    for p in "$HOME/.nix-defexpr/channels" "darwin-config=$HOME/.dotfiles/nix/darwin.nix" "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixpkgs" "/nix/var/nix/profiles/per-user/root/channels" "nixpkgs-unstable=/nix/var/nix/profiles/per-user/root/channels/nixpkgs-unstable"
      if not contains $p $NIX_PATH
        set -g NIX_PATH $p $NIX_PATH
      end
    end
  '';
}
