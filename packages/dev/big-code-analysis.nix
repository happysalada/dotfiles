# `bca` reports per-function metrics - cognitive and cyclomatic complexity,
# Halstead, maintainability index, ABC - over ~18 languages via tree-sitter.
# It is a hard fork of Mozilla's rust-code-analysis, which has not cut a release
# since 2023-01; this one still does. Not in nixpkgs, so it lives here for now.
{
  fetchCrate,
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "big-code-analysis";
  version = "2.2.0";

  # The published CLI crate rather than the git tag: the repo pulls its
  # tree-sitter grammars in as git submodules, which fetchFromGitHub would leave
  # empty. crates.io resolves them to the separately published bca-tree-sitter-*
  # crates, so this source is self-contained.
  src = fetchCrate {
    pname = "big-code-analysis-cli";
    inherit (finalAttrs) version;
    hash = "sha256-cINNc+1rO1AtyWbIHijWv5QXyrKRQ7wAnO2Dv/EjwF4=";
  };

  cargoHash = "sha256-s2juVtQHAZh+2OIOQeWPBq5qMKGuYdldQgfhSKGMpOo=";

  # The published crate ships tests/ but not tests/fixtures/, and
  # tests/common/validators.rs include_str!s a schema out of it, so the test
  # targets cannot compile from this source. Re-enable against the git tree if
  # upstream ever ships the fixtures in the crate.
  doCheck = false;

  meta = {
    description = "Compute code metrics (complexity, Halstead, maintainability) via tree-sitter";
    homepage = "https://github.com/dekobon/big-code-analysis";
    changelog = "https://github.com/dekobon/big-code-analysis/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.mpl20;
    mainProgram = "bca";
  };
})
