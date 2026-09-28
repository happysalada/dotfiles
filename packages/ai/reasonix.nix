{
  bash,
  lib,
  buildGoModule,
  coreutils,
  fetchFromGitHub,
  gitMinimal,
  glibcLocales,
  makeWrapper,
  stdenv,
  versionCheckHook,
}:

buildGoModule (finalAttrs: {
  pname = "reasonix";
  version = "1.39.2";

  src = fetchFromGitHub {
    owner = "esengine";
    repo = "DeepSeek-Reasonix";
    tag = "v${finalAttrs.version}";
    hash = "sha256-ULSfLElpLzm9lugJPAuGku7Q50mhOK9BvsGUvj53afc=";
  };

  vendorHash = "sha256-EgR0La/yk5CeMOASJl8q/GxchLmpt1yRQ1hz/jazONE=";

  postPatch = ''
    substituteInPlace cmd/e2ebench/segmentrun_test.go \
      --replace-fail '#!/usr/bin/env bash' '#!${lib.getExe bash}'
    substituteInPlace internal/cli/clipboard_wsl_process_test.go \
      --replace-fail '/bin/cat' '${lib.getExe' coreutils "cat"}'
  ''
  + lib.optionalString stdenv.hostPlatform.isLinux ''
    substituteInPlace internal/localeenv/locale.go \
      --replace-fail '"/usr/bin/locale"' '"${stdenv.cc.libc.bin}/bin/locale"'
  '';

  subPackages = [ "cmd/reasonix" ];
  env.CGO_ENABLED = 0;
  ldflags = [
    "-s"
    "-w"
    "-X main.version=v${finalAttrs.version}"
  ];

  nativeBuildInputs = [ makeWrapper ];
  nativeCheckInputs = [ gitMinimal ] ++ lib.optionals stdenv.hostPlatform.isLinux [ glibcLocales ];
  preCheck = ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    export GOFLAGS="''${GOFLAGS/-trimpath/}"
  '';
  checkPhase = ''
    runHook preCheck
    go test ./...
    runHook postCheck
  '';

  postFixup = ''
    wrapProgram $out/bin/reasonix --set-default REASONIX_TELEMETRY 0
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";
  doInstallCheck = true;

  meta = {
    description = "DeepSeek-native coding agent for the terminal";
    homepage = "https://github.com/esengine/DeepSeek-Reasonix";
    changelog = "https://github.com/esengine/DeepSeek-Reasonix/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "reasonix";
    platforms = lib.platforms.unix;
  };
})
