# Symposium - "AI the Rust way". Ships as `cargo agents`, a cargo subcommand.
#
# It reads the workspace dependency graph (`cargo metadata`), matches each
# crate against plugin manifests from the symposium-dev/recommendations
# registry, and installs the skills/hooks/MCP servers those plugins declare
# into whichever agents you use. An agent working in a project that depends on
# tokio then gets guidance written for the tokio version actually in the lock
# file, rather than whatever the model remembers.
#
# Not in nixpkgs (checked 2026-08-30), so it is built here from the crates.io
# release. The crate is named `symposium` but its only binary is
# `cargo-agents`, which is what cargo dispatches to for `cargo agents`.
#
# Wrapped with cargo and git on PATH: it shells out to `cargo metadata` for the
# dependency graph and to `git` for git-backed plugin registries. Neither is a
# build input, so unwrapped it would pick up whatever is in the ambient PATH.
{
  lib,
  rustPlatform,
  fetchCrate,
  makeBinaryWrapper,
  versionCheckHook,
  cargo,
  git,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "symposium";
  version = "0.4.0";

  src = fetchCrate {
    inherit (finalAttrs) pname version;
    hash = "sha256-m2xJbC7CtrCVqG7ZhJO6rB4Th+hxwQWCOcxFEz9Sgzs=";
  };

  cargoHash = "sha256-jWfzYKzGdfzQlPtNUOpllXAtd5UcjogkE14RIJvUXSI=";

  nativeBuildInputs = [ makeBinaryWrapper ];

  postInstall = ''
    wrapProgram $out/bin/cargo-agents \
      --prefix PATH : ${
        lib.makeBinPath [
          cargo
          git
        ]
      }
  '';

  # The test suite drives real init/sync runs against crates.io and the
  # recommendations registry, which the sandbox has no network for.
  doCheck = false;

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgram = "${placeholder "out"}/bin/cargo-agents";
  versionCheckProgramArg = "--version";
  doInstallCheck = true;

  meta = {
    description = "Installs agent skills, hooks and MCP servers from a Rust project's dependencies";
    homepage = "https://symposium.dev";
    changelog = "https://github.com/symposium-dev/symposium/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "cargo-agents";
    platforms = lib.platforms.unix;
  };
})
