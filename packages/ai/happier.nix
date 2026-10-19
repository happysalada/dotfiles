# Happier - the CLI half of the multi-device control room: it wraps claude,
# codex and opencode, mirrors those sessions to the phone/browser, and ships the
# daemon that makes remote start work (declared as a user unit in
# homes/programs/happier.nix).
#
# No nixpkgs package and no usable upstream flake, so this unpacks the signed
# release payload. The whole tree is kept: `package-dist` and `scripts` are what
# the daemon and agent launchers read from beside the executable, and the CLI
# resolves that directory from the real binary's path.
{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  patchelf,
  versionCheckHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "happier";
  version = "0.2.16";

  src = fetchurl {
    url = "https://github.com/happier-dev/happier/releases/download/cli-v${finalAttrs.version}/happier-v${finalAttrs.version}-linux-x64.tar.gz";
    hash = "sha256-UAGPMGyOmF6hvQUSjXPxKKKfIp64p7Mqe7QpTObKejI=";
  };

  nativeBuildInputs = [
    makeWrapper
    patchelf
  ];

  # A second patchelf pass leaves the Bun binary failing in the loader with
  # "unsupported version 0 of Verdef record", so the fixup phase's shrink and
  # strip runs stay off; the one interpreter rewrite below is all it needs.
  dontPatchELF = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib
    cp -a . $out/lib/happier

    # The embedded Bun runtime NEEDs only libc; the node-pty prebuilds the
    # daemon loads need libstdc++, which the wrapper supplies to every child.
    # One patchelf pass only: a second one, or makeBinaryWrapper's, leaves this
    # binary failing in the loader with "unsupported version 0 of Verdef record".
    patchelf --set-interpreter "${stdenv.cc.bintools.dynamicLinker}" $out/lib/happier/happier

    # A wrapper at bin/ rather than in lib/ keeps the real executable's
    # directory as the install root the CLI looks for its payload in. Updates
    # belong to nix here, so the check would only ever be noise.
    makeWrapper $out/lib/happier/happier $out/bin/happier \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ stdenv.cc.cc.lib ]} \
      --set HAPPIER_CLI_UPDATE_CHECK 0

    runHook postInstall
  '';

  # A fresh HOME, because the binary creates ~/.happier before parsing argv.
  preInstallCheck = "export HOME=$TMPDIR";
  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "Multi-device control room for coding agent sessions";
    homepage = "https://happier.dev";
    license = lib.licenses.mit;
    mainProgram = "happier";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
})
