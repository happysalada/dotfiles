# funes - searchable memory of past agent sessions, exposed over MCP.
#
# Built from source; lance's build scripts need protoc.
#
# rust-overlay's toolchain, not nixpkgs': nixpkgs links rustc against a newer
# system LLVM, and lance-linalg's AVX-512 VNNI calls then fail with
# "intrinsic signature mismatch". Upstream binaries bundle their own LLVM.
# Needs the overlay, so strix only.
{
  lib,
  makeRustPlatform,
  rust-bin,
  fetchFromGitHub,
  protobuf,
}:

let
  toolchain = rust-bin.stable.latest.minimal;
  rustPlatform = makeRustPlatform {
    cargo = toolchain;
    rustc = toolchain;
  };
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "funes";
  version = "1.4.0";

  src = fetchFromGitHub {
    owner = "huggingface";
    repo = "funes";
    tag = "v${finalAttrs.version}";
    hash = "sha256-ksK6FPv2ST4MH9lvHwq6zcRx3gCKvcs9BtGQA0Wr8qU=";
  };

  cargoHash = "sha256-fajclmCP4TVaFcaazI4aCtOGwyefKRiRmb0788GJCA8=";

  # the tag still says 1.3.3+dev (release CI stamps it), and that label makes
  # funes nag for a `funes update` the read-only store cannot take
  postPatch = ''
    substituteInPlace Cargo.toml \
      --replace-fail 'version = "1.3.3+dev"' 'version = "${finalAttrs.version}"'
  '';

  nativeBuildInputs = [ protobuf ];

  # lance's test suite is slow and wants network fixtures
  doCheck = false;

  meta = {
    description = "Durable, searchable memory of your past agent sessions";
    homepage = "https://github.com/huggingface/funes";
    changelog = "https://github.com/huggingface/funes/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "funes";
  };
})
