# Official otelcol-contrib release binary. nixpkgs' `opentelemetry-collector-contrib`
# is a Go build and is pinned at 0.155.0 on this nixpkgs - eleven releases behind
# the 0.166.0 below - and that build already failed against its own Go
# (cockroachdb/swiss uses newer runtime internals). The contrib distribution is
# the only one with the journald and hostmetrics receivers. Static binary, so no
# patchelf and no build inputs.
{ stdenvNoCC, fetchurl, lib }:

stdenvNoCC.mkDerivation rec {
  pname = "otelcol-contrib";
  version = "0.166.0";

  src = fetchurl {
    url = "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${version}/otelcol-contrib_${version}_linux_amd64.tar.gz";
    hash = "sha256-koyznBFdQoxTIRgYt+M82LJoELiJbcdOC9E7jRRXw5E=";
  };

  sourceRoot = ".";
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    install -Dm755 otelcol-contrib $out/bin/otelcol-contrib
  '';

  meta = {
    description = "OpenTelemetry Collector contrib distribution (official release binary)";
    homepage = "https://github.com/open-telemetry/opentelemetry-collector-releases";
    license = lib.licenses.asl20;
    mainProgram = "otelcol-contrib";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
