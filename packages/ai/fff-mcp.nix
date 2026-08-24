# fff - fast file/content search built for agents, exposed over MCP.
#
# NOT the `fff` attribute in nixpkgs: that name is taken by dylanaraps' bash
# file manager, which is an unrelated project. This is dmtrKovalenko/fff.
#
# Only the `fff-mcp` binary is built. The workspace also contains a Neovim FFI
# crate, a C library and Python/Node SDKs, none of which are wanted here.
# fff-mcp's default feature set is `ripgrep`; the `zlob` feature is what pulls
# in the Zig toolchain, and it is deliberately left off.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  perl,
  cmake,
  openssl,
  versionCheckHook,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "fff-mcp";
  version = "0.10.5";

  src = fetchFromGitHub {
    owner = "dmtrKovalenko";
    repo = "fff";
    tag = "v${finalAttrs.version}";
    hash = "sha256-STWQVXZCTlXteuojY2L8dN5Hy+gcUYqn/FqxV4YbieA=";
  };

  cargoHash = "sha256-NtTSkpzv4N7yUdYY4h2uNcDNrdia+GHc7sxr1pk+h0k=";

  nativeBuildInputs = [
    pkg-config
    perl # git2's vendored libgit2 build
    cmake
  ];

  buildInputs = [ openssl ];

  env.OPENSSL_NO_VENDOR = "1";

  cargoBuildFlags = [
    "-p"
    "fff-mcp"
    "--bin"
    "fff-mcp"
  ];

  # Workspace tests cover the Neovim/C/Python crates that are not built here.
  doCheck = false;

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";
  doInstallCheck = true;

  meta = {
    description = "MCP server for the fff file search engine, for AI code assistants";
    homepage = "https://github.com/dmtrKovalenko/fff";
    license = lib.licenses.mit;
    mainProgram = "fff-mcp";
    platforms = lib.platforms.unix;
  };
})
