{ pkgs, ... }: {
  enable = true;
  plugins = [{
    name = "foreign-env";
    src = pkgs.fetchFromGitHub {
      owner = "oh-my-fish";
      repo = "plugin-foreign-env";
      rev = "dddd9213272a0ab848d474d0cbde12ad034e65bc";
      sha256 = "00xqlyl3lffc5l0viin1nyp819wf81fncqyz87jx8ljjdhilmgbs";
    };
  }];

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
    fenv source /nix/var/nix/profiles/default/etc/profile.d/nix.sh  
    fenv source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh  

    for p in "$HOME/.nix-defexpr/channels" "darwin-config=$HOME/.dotfiles/nix/darwin.nix"
      if not contains $p $NIX_PATH
        set -g NIX_PATH $p $NIX_PATH
      end
    end
  '';
}
