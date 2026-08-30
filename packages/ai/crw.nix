# fastCRW - web scraper/crawler/search engine for agents, exposed over MCP.
#
# Two binaries out of an 11-crate workspace: `crw` (crw-cli) for the shell and
# `crw-mcp` (crw-mcp) for the MCP server in homes/programs/ai-mcp.nix. The
# other nine crates are libraries those two link in.
#
# `crw-mcp` defaults to *embedded* mode - the whole scraping engine in-process,
# no server and no account. It only talks to a remote when CRW_API_URL is set.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  versionCheckHook,
  makeBinaryWrapper,
  chromium,
  lightpanda ? callPackage ./lightpanda.nix { },
  callPackage,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "crw";
  version = "0.32.0";

  src = fetchFromGitHub {
    owner = "us";
    repo = "crw";
    tag = "v${finalAttrs.version}";
    hash = "sha256-zk8xjKPPifNiHqx/B01ZG3r9xgoG1p1D1M7LhQoHD5Y=";
  };

  cargoHash = "sha256-yVh3B9Xl5yB9YWG0+lDOudnD1qi2VpAWBnItFZiRr3c=";

  nativeBuildInputs = [
    pkg-config
    makeBinaryWrapper
  ];

  # reqwest is pinned to rustls with default-features off, so there is no
  # openssl anywhere in the tree - hence no buildInputs.

  cargoBuildFlags = [
    "-p"
    "crw-cli"
    "-p"
    "crw-mcp"
  ];

  # The suite includes conformance tests that fetch live URLs.
  doCheck = false;

  # Both renderers, which is what upstream's own config.default.toml calls for:
  # the auto ladder runs LightPanda first and falls through to Chrome when a
  # page crashes during hydration. LightPanda has no layout engine, so Chrome
  # is also the only one of the two that can take a screenshot.
  #
  # Without this, crw downloads a LightPanda nightly into ~/.crw at first use
  # and finds no Chrome at all. CRW_CHROME_PATH is the first thing its browser
  # lookup checks; LightPanda is found by name on PATH.
  postInstall = ''
    for bin in crw crw-mcp; do
      wrapProgram $out/bin/$bin \
        --set-default CRW_CHROME_PATH ${lib.getExe chromium} \
        --prefix PATH : ${lib.makeBinPath [ lightpanda ]}
    done
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";
  doInstallCheck = true;

  meta = {
    description = "Fast web scraper, crawler and search API for AI agents, with an MCP server";
    homepage = "https://github.com/us/crw";
    license = lib.licenses.agpl3Only;
    mainProgram = "crw";
    platforms = lib.platforms.unix;
  };
})
