with import <nixpkgs-unstable> { };

let
  # define packages to install with special handling for OSX
  basePackages =
    [ git beam.packages.erlangR23.elixir_1_10 nodejs-14_x yarn postgresql_12 ];

  inputs = basePackages ++ lib.optional stdenv.isLinux inotify-tools
    ++ lib.optionals stdenv.isDarwin
    (with darwin.apple_sdk.frameworks; [ CoreFoundation CoreServices ]);

  # define shell startup command
  hooks = ''
    # this allows mix to work on the local directory
    mkdir -p .nix-mix
    mkdir -p .nix-hex
    export MIX_HOME=$PWD/.nix-mix
    export HEX_HOME=$PWD/.nix-hex
    export PATH=$MIX_HOME/bin:$PATH
    export PATH=$HEX_HOME/bin:$PATH
    export LANG=en_US.UTF-8
    export ERL_AFLAGS="-kernel shell_history enabled"
    export PGDATA="$PWD/db"
  '';

in mkShell {
  buildInputs = inputs;
  shellHook = hooks;
}
