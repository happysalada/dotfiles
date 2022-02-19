{ agenix }:
[
  {
    environment.systemPackages = [ agenix.defaultPackage.x86_64-linux ];
    nixpkgs.overlays = [ ];
  }
  agenix.nixosModules.age
  # `home-manager` module
  home-manager.nixosModules.home-manager
  {
    # `home-manager` config
    home-manager.useGlobalPkgs = true;
    home-manager.users.yt = import ./home.nix { username = "yt"; };
  }
  {
    _module.args.nixinate = {
      host = "";
      sshUser = "yt";
      buildOn = "remote"; # valid args are "local" or "remote"
    };
  }
]
