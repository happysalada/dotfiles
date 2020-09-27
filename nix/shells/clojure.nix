with import <nixpkgs> {};

let
  # define packages to install with special handling for OSX
  basePackages = [
    /* Core runtime libraries */
    clojure
    jdk11
    leiningen
  ];

  inputs = basePackages
    ++ lib.optional stdenv.isLinux inotify-tools
    ++ lib.optionals stdenv.isDarwin (with darwin.apple_sdk.frameworks; [
        CoreFoundation
        CoreServices
      ]);

  # define shell startup command
  hooks = ''
    # this allows mix to work on the local directory
  '';

in mkShell {
  buildInputs = inputs;
  shellHook = hooks;
}