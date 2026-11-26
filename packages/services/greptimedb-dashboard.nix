# GreptimeDB's web dashboard, built from source.
#
# The OSS `greptime` binary does not embed the dashboard - the landing page it
# serves links `/dashboard`, which 404s on a standalone install. The dashboard
# is a separate app (GreptimeTeam/dashboard) that talks to the DB over HTTP, so
# it is packaged here as static files and served next to it.
#
# Build shape: Vue 3 + Vite, pnpm, and `pnpm run build` is
# `update:github-stars && vite build --config config/vite.config.prod.ts`. The
# first half asks the GitHub API for the greptimedb star count used as a UI
# fallback; with no network it warns, keeps the committed constant and exits 0,
# so the sandbox build is fine.
{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  nodejs_22,
  pnpm_10,
  pnpmConfigHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "greptimedb-dashboard";
  version = "0.14.7";

  src = fetchFromGitHub {
    owner = "GreptimeTeam";
    repo = "dashboard";
    tag = "v${finalAttrs.version}";
    hash = "sha256-D3cIyKIVytrEyUnDs6n7MO9WJfrN6id5S2X6EbwVNHc=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 5;
    hash = "sha256-hFUaffn2pSeTZwUHIDUL5Q/Hujk6IG2eCF2cSjjgtxs=";
  };

  nativeBuildInputs = [
    nodejs_22
    pnpm_10
    pnpmConfigHook
  ];

  # `prepare: husky install` fails outside a git checkout, and esbuild's
  # postinstall would download a binary; neither is needed to build the bundle.
  env.npm_config_ignore_scripts = "1";

  # package.json pins `packageManager: pnpm@9.12.1`; left in, pnpm 10 downloads
  # exactly that release into ~/.local/share/pnpm before running any script,
  # which cannot work in the sandbox. nixpkgs has no pnpm 9 to pin instead, and
  # the lockfile (v9.0) is the same format pnpm 10 reads.
  postPatch = ''
    sed -i '/"packageManager":/d' package.json
  '';

  buildPhase = ''
    runHook preBuild

    export HOME=$TMPDIR
    pnpm run build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/greptimedb-dashboard
    cp -r dist/. $out/share/greptimedb-dashboard/

    runHook postInstall
  '';

  meta = {
    description = "Web dashboard for GreptimeDB";
    homepage = "https://github.com/GreptimeTeam/dashboard";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
  };
})
