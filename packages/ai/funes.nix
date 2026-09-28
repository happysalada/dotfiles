# funes - searchable memory of past agent sessions, exposed over MCP.
#
# The prebuilt release binary rather than a source build: that needs protoc
# and compiles lance, for no difference in the result. The binary targets
# glibc >= 2.35 and needs nothing beyond libgcc_s.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "funes";
  version = "1.4.0";

  src = fetchurl {
    url = "https://github.com/huggingface/funes/releases/download/v${finalAttrs.version}/funes-x86_64-linux";
    hash = "sha256-hxEH7qrqsf7rza5HDBOdafmhaGZWlfgrLtvmSwF7hUM=";
  };

  dontUnpack = true;

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/funes
    runHook postInstall
  '';

  meta = {
    description = "Durable, searchable memory of your past agent sessions";
    homepage = "https://github.com/huggingface/funes";
    changelog = "https://github.com/huggingface/funes/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "funes";
    platforms = [ "x86_64-linux" ];
  };
})
