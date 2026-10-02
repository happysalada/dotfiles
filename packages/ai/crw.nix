# fastCRW - web scraper/crawler/search engine for agents, exposed over MCP.
#
# The build is nixpkgs' `fastcrw`, so it comes from the binary cache instead of
# compiling an 11-crate Rust workspace; this file is only the renderer wiring
# nixpkgs leaves out. Four binaries: `crw`, `crw-mcp` (registered in
# homes/programs/crw.nix), plus `crw-server` and `crw-browse`. `crw-mcp`
# defaults to *embedded* mode - the engine in-process, no account - and only
# talks to a remote when CRW_API_URL is set.
{
  lib,
  symlinkJoin,
  makeBinaryWrapper,
  fastcrw,
  chromium,
  lightpanda ? callPackage ./lightpanda.nix { },
  callPackage,
}:

# Both renderers, as upstream's config.default.toml calls for: the auto ladder
# runs LightPanda first and falls through to Chrome when a page crashes during
# hydration, and only Chrome can screenshot (LightPanda has no layout engine).
# Without this, crw downloads a LightPanda nightly into ~/.crw and finds no
# Chrome. symlinkJoin rather than overrideAttrs: a postInstall would change
# fastcrw's derivation hash and cost a source rebuild for two environment
# variables.
symlinkJoin {
  name = "crw-${fastcrw.version}";
  paths = [ fastcrw ];

  nativeBuildInputs = [ makeBinaryWrapper ];

  postBuild = ''
    for bin in $out/bin/*; do
      wrapProgram $bin \
        --set-default CRW_CHROME_PATH ${lib.getExe chromium} \
        --prefix PATH : ${lib.makeBinPath [ lightpanda ]}
    done
  '';

  inherit (fastcrw) version;

  meta = fastcrw.meta // {
    platforms = lib.platforms.unix;
  };
}
