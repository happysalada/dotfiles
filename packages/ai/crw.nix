# fastCRW - web scraper/crawler/search engine for agents, exposed over MCP.
#
# The build is nixpkgs' `fastcrw` (pkgs/by-name/fa/fastcrw), so it comes out of
# the binary cache instead of compiling an 11-crate Rust workspace here. This
# file is only the renderer wiring nixpkgs deliberately leaves out.
#
# Four binaries: `crw` for the shell, `crw-mcp` for the MCP server registered in
# homes/programs/crw.nix, plus `crw-server` and `crw-browse`.
#
# `crw-mcp` defaults to *embedded* mode - the whole scraping engine in-process,
# no server and no account. It only talks to a remote when CRW_API_URL is set.
{
  lib,
  symlinkJoin,
  makeBinaryWrapper,
  fastcrw,
  chromium,
  lightpanda ? callPackage ./lightpanda.nix { },
  callPackage,
}:

# Both renderers, which is what upstream's own config.default.toml calls for:
# the auto ladder runs LightPanda first and falls through to Chrome when a page
# crashes during hydration. LightPanda has no layout engine, so Chrome is also
# the only one of the two that can take a screenshot.
#
# Without this, crw downloads a LightPanda nightly into ~/.crw at first use and
# finds no Chrome at all. CRW_CHROME_PATH is the first thing its browser lookup
# checks; LightPanda is found by name on PATH.
#
# symlinkJoin rather than overrideAttrs: a postInstall would change fastcrw's
# derivation hash and cost a full source rebuild for two environment variables.
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
