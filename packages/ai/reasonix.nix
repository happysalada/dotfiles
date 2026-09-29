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

  # TERMUX_VERSION is not about Termux here. reasonix has exactly one renderer
  # that stays out of the alternate screen and appends to the terminal's own
  # scrollback, and that is the one it picks when it detects Termux. Unset, a
  # zellij pane running reasonix has no scrollback at all: the pane keeps
  # alt-screen content only, so Ctrl+S and the wheel stop at the top of the
  # current frame. Set, reasonix renders inline and leaves the mouse to the pane
  # - `?1049h` and `?1002h` both absent, versus both present when unset.
  #
  # EXPERIMENTAL. Upstream has no supported switch for this: no flag, no [ui]
  # key, and it ignores ZELLIJ / TMUX / TERM_PROGRAM. What riding the Termux
  # path also changes, per its own docs, is subagent progress - a status line on
  # phase changes instead of live previews. Copy falls back to OSC52, so the
  # clipboard should survive it.
  #
  # Replace this with the real flag when reasonix grows one (codex's
  # --no-alt-screen is the shape to ask for), or delete the line to revert.
  # `TERMUX_VERSION= reasonix` opts a single run back out.
  postFixup = ''
    wrapProgram $out/bin/reasonix \
      --set-default REASONIX_TELEMETRY 0 \
      --set-default TERMUX_VERSION 1
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
