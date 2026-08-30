# LightPanda - headless browser for scraping: DOM + JS + network, no layout,
# no rasterization. crw tries it before Chrome, which is what makes the pair
# worth having (see packages/ai/crw.nix).
#
# Upstream ships prebuilt binaries and no supported source build (the Zig tree
# needs a custom v8), so this unpacks a release asset. The asset is a plain
# glibc dynamic binary - autoPatchelfHook rewrites its interpreter to the
# store's. Note that crw's own auto-download drops the *unpatched* asset in
# ~/.crw, which then runs only where nix-ld happens to be enabled; that
# accident is exactly what this package exists to avoid.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  versionCheckHook,
}:

let
  # sha256 of the per-platform release asset.
  hashes = {
    x86_64-linux = "sha256-iVM5sCIFFxoYHd50OuAGi7RWSIQHb+rISCusqcISqlo=";
    aarch64-linux = "sha256-TA7LKLT8+21bzoLshuFfxs3onOoWjPOEBJTw7iZ1WFI=";
    x86_64-darwin = "sha256-XhGLbpHCzMsc5/DTT8OdqyYrlH5N6impCxp1uTmdeGI=";
    aarch64-darwin = "sha256-rplULYGvIwhyluwDersNV6VwAlAvX/TBsLBd+khLebg=";
  };

  # Asset names are <arch>-<os>, with upstream's own spelling of the OS.
  asset =
    let
      inherit (stdenv.hostPlatform) parsed;
      os = if stdenv.hostPlatform.isDarwin then "macos" else parsed.kernel.name;
    in
    "lightpanda-${parsed.cpu.name}-${os}";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "lightpanda";
  version = "0.3.7";

  src = fetchurl {
    url = "https://github.com/lightpanda-io/browser/releases/download/${finalAttrs.version}/${asset}";
    hash =
      hashes.${stdenv.hostPlatform.system}
        or (throw "lightpanda: no release asset for ${stdenv.hostPlatform.system}");
  };

  dontUnpack = true;

  # Only libc and libm are NEEDED, both of which come from stdenv.
  nativeBuildInputs = lib.optional stdenv.hostPlatform.isLinux autoPatchelfHook;

  # The binary calls itself `lp`, but crw looks up `lightpanda` on PATH.
  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/lightpanda
    runHook postInstall
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "version"; # a subcommand, not a flag
  doInstallCheck = true;

  meta = {
    description = "Headless browser for AI agents and scraping, with no rendering engine";
    homepage = "https://lightpanda.io";
    license = lib.licenses.agpl3Only;
    mainProgram = "lightpanda";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.attrNames hashes;
  };
})
