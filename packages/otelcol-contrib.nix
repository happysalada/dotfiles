# Official otelcol-contrib release binary. nixpkgs' 0.155.0 Go build fails
# against its own Go (cockroachdb/swiss uses newer runtime internals), and the
# contrib distribution is the only one with the journald and hostmetrics
# receivers. Static binary, so no patchelf and no build inputs.
{ stdenvNoCC, fetchurl, lib }:

stdenvNoCC.mkDerivation rec {
  pname = "otelcol-contrib";
  version = "0.155.0";

  src = fetchurl {
    url = "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${version}/otelcol-contrib_${version}_linux_amd64.tar.gz";
    hash = "sha256-Ipz93rBiHSoBG/0ciJQzVHnkY0m5Ogz7zL5lNEOj7JU=";
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
