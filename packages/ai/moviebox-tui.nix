# moviebox-tui - terminal UI to find, download and stream movies and TV.
#
# Not in nixpkgs (checked 2026-11-02), so it is built here from the GitHub tag.
# mpv/vlc/yt-dlp/ffmpeg are runtime tools it shells out to, so they go on PATH.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  makeWrapper,
  mpv,
  yt-dlp,
  ffmpeg,
  vlc,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "moviebox-tui";
  version = "0.1.28";

  src = fetchFromGitHub {
    owner = "mesamirh";
    repo = "MovieBox-Tui";
    tag = "v${finalAttrs.version}";
    hash = "sha256-9eJeEzrG0PdCeXqbjfcGNbOZc4lKqqERQG5Cm0JndqQ=";
  };

  cargoHash = "sha256-mJXYzMY54bL+feG/t1ANhwPiQVxCsxx9MY3A/E0VmnI=";

  nativeBuildInputs = [ makeWrapper ];

  # Tests hit the network.
  doCheck = false;

  postInstall = ''
    wrapProgram $out/bin/moviebox-tui \
      --prefix PATH : ${
        lib.makeBinPath [
          mpv
          vlc
          yt-dlp
          ffmpeg
        ]
      }
  '';

  meta = {
    description = "Terminal interface to find, download and stream movies and TV shows";
    homepage = "https://github.com/mesamirh/MovieBox-Tui";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "moviebox-tui";
  };
})
