# OpenPanel: web and product analytics (funnels, retention, profiles, replay).
# Needs Postgres, Redis, ClickHouse and a Kafka-API broker (Redpanda); the
# wiring is in modules/openpanel.nix.
#
# One bun workspace, three runtime programs:
#   openpanel-api        api and worker (ROLE=api|worker|all), run from source by bun
#   openpanel-dashboard  the Nitro server build of apps/start, run by node
#   openpanel-migrate    `prisma migrate deploy` with nixpkgs' CLI and engines
#
# Two fixed-output installs, because the full workspace is 4 GB (docs site,
# testbed): `buildModules` has what codegen and the dashboard build need, and
# `runtimeModules` is the production closure of the api, which is what ships.
# Both hashes follow the pinned bun below, not nixpkgs': bun's isolated
# layout names store directories with a hash that changed between 1.4.3 and
# 1.4.4, so a plain nixpkgs bun bump would move them.
{
  lib,
  stdenv,
  stdenvNoCC,
  fetchFromGitHub,
  fetchurl,
  bun,
  nodejs,
  makeBinaryWrapper,
  writableTmpDirAsHomeHook,
  prisma_6,
  prisma-engines_6,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "openpanel";
  version = "3.30.0";

  src = fetchFromGitHub {
    owner = "Openpanel-dev";
    repo = "openpanel";
    tag = "v${finalAttrs.version}";
    hash = "sha256-xhpmGOdyWlWXLCsSd7fy4b+tRFbx0jILZCdVonRrEOQ=";
  };

  nativeBuildInputs = [
    finalAttrs.passthru.bun
    nodejs
    makeBinaryWrapper
    writableTmpDirAsHomeHook
  ];

  dontFixup = true; # strip and shebang rewriting would only touch prebuilt addons

  # migrations dump their SQL beside the source, which is read-only here
  postPatch = ''
      substituteInPlace packages/db/src/code-migrations/helpers.ts --replace-fail \
        'export function writeSqlDump(migrationUrl: string, sqls: string[]) {' \
        'export function writeSqlDump(migrationUrl: string, sqls: string[]) {
    return;'
  '';

  configurePhase = ''
    runHook preConfigure

    cp -R ${finalAttrs.passthru.buildModules}/. .
    chmod -R u+w .
    patchShebangs --build node_modules

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    # nixpkgs' engines are 6.19, the client is 6.14: the env points both at them
    export PRISMA_QUERY_ENGINE_LIBRARY=${prisma-engines_6}/lib/libquery_engine.node
    export PRISMA_SCHEMA_ENGINE_BINARY=${prisma-engines_6}/bin/schema-engine
    export PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1
    (
      cd packages/db
      DATABASE_URL=postgresql://x@localhost/x DATABASE_URL_DIRECT=postgresql://x@localhost/x \
        bun run prisma generate
      bun prisma/prisma-json-types.ts
    )

    # the databases `bun run codegen` would download
    tar -xzf ${finalAttrs.passthru.geoCity} -C packages/core --strip-components=1 --wildcards '*.mmdb'
    tar -xzf ${finalAttrs.passthru.geoAsn} -C packages/core --strip-components=1 --wildcards '*.mmdb'

    # the tracking script the dashboard serves
    cp apps/public/public/op1.js apps/public/public/op1-replay.js apps/start/public/
    # not `bun run build`: that wraps vite in dotenv-cli for a .env we do not have
    (cd apps/start && NITRO=1 SELF_HOSTED=1 bun run vite build)

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    app=$out/lib/openpanel
    mkdir -p $app/apps $app/tooling $out/lib/openpanel-dashboard $out/bin
    cp -R apps/api $app/apps/api
    cp -R packages $app/packages
    cp -R tooling/typescript $app/tooling/typescript
    cp package.json $app/package.json
    find $app -type d -name node_modules -prune -exec rm -rf {} +
    cp -R ${finalAttrs.passthru.runtimeModules}/. $app/
    chmod -R u+w $app

    cp -R apps/start/.output $out/lib/openpanel-dashboard/.output
    ${finalAttrs.passthru.fixEsmEnv}

    makeBinaryWrapper ${lib.getExe finalAttrs.passthru.bun} $out/bin/openpanel-api \
      --chdir $app/apps/api \
      --set-default NODE_ENV production \
      --set PRISMA_QUERY_ENGINE_LIBRARY ${prisma-engines_6}/lib/libquery_engine.node \
      --set PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING 1 \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ stdenv.cc.cc.lib ]} \
      --add-flags "run src/main.ts"

    makeBinaryWrapper ${lib.getExe nodejs} $out/bin/openpanel-dashboard \
      --chdir $out/lib/openpanel-dashboard \
      --set-default NODE_ENV production \
      --add-flags .output/server/index.mjs

    makeBinaryWrapper ${lib.getExe prisma_6} $out/bin/openpanel-migrate \
      --chdir $app/packages/db \
      --add-flags "migrate deploy"

    runHook postInstall
  '';

  passthru = {
    bun = bun.overrideAttrs (old: {
      version = "1.4.4"; # upstream's .bun-version
      __intentionallyOverridingVersion = true;
      passthru = old.passthru // {
        sources.x86_64-linux = fetchurl {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v1.4.4/bun-linux-x64-baseline.zip";
          hash = "sha256-4ERutVmVdy65iUvrrppr42jZhai5Jx7hJEhvmUbu3XY=";
        };
      };
    });

    buildModules =
      finalAttrs.passthru.mkModules "build" "--filter start --filter @openpanel/db"
        "sha256-kLJvK8KdvTvrwmWLhTrIOKwpkBS5+JqUqAySlEHpInc=";
    runtimeModules =
      finalAttrs.passthru.mkModules "runtime" "--production --filter @openpanel/api"
        "sha256-/L7KPRQ7EyZVmz1dO/9slvy+amG4eAGnxGBdon1/WZE=";

    mkModules =
      name: installArgs: hash:
      stdenvNoCC.mkDerivation {
        pname = "${finalAttrs.pname}-node_modules-${name}";
        inherit (finalAttrs) version src;

        nativeBuildInputs = [
          finalAttrs.passthru.bun
          writableTmpDirAsHomeHook
        ];

        dontConfigure = true;
        dontFixup = true; # the output holds no store references

        # a global store would leave node_modules/.bun symlinked into the cache
        env.BUN_INSTALL_GLOBAL_STORE = "0";

        buildPhase = ''
          runHook preBuild
          bun install --frozen-lockfile --ignore-scripts --linker=isolated --no-progress ${installArgs}
          runHook postBuild
        '';

        # every workspace member has its own node_modules of relative symlinks
        installPhase = ''
          runHook preInstall
          mkdir -p $out
          find . -type d -name node_modules -prune -print0 | xargs -0 cp --parents -a -t $out
          runHook postInstall
        '';

        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = hash;
      };

    # codegen downloads these from a moving branch; this is the newest commit
    # and goes stale with it (MaxMind refreshes twice a week)
    geoCity = fetchurl {
      url = "https://raw.githubusercontent.com/GitSquared/node-geolite2-redist/dc4cbe07b772340c730c39ba3ba192dcea4e9d28/redist/GeoLite2-City.tar.gz";
      hash = "sha256-M3VwYPWLmc/68UwuBKOSZeNaVCes+Cyn8Mj71trGLGU=";
    };
    geoAsn = fetchurl {
      url = "https://raw.githubusercontent.com/GitSquared/node-geolite2-redist/dc4cbe07b772340c730c39ba3ba192dcea4e9d28/redist/GeoLite2-ASN.tar.gz";
      hash = "sha256-KC0dyNrwM2tm/pKJ/hKJfbEYczJh3JEb9u120im/a30=";
    };

    # upstream's Dockerfile step: @number-flow/react imports "esm-env" at
    # runtime but Nitro only bundles it as esm-env-runtime
    fixEsmEnv = ''
      modules=$out/lib/openpanel-dashboard/.output/server/node_modules
      if [ ! -d $modules/esm-env ]; then
        mkdir -p $modules/esm-env
        cp $modules/esm-env-runtime/node.js $modules/esm-env/index.js
        echo '{"name":"esm-env","version":"1.1.4","type":"module","exports":"./index.js"}' > $modules/esm-env/package.json
      fi
    '';
  };

  meta = {
    description = "Open-source web and product analytics, a Mixpanel and Plausible alternative";
    homepage = "https://openpanel.dev";
    changelog = "https://github.com/Openpanel-dev/openpanel/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.agpl3Only;
    mainProgram = "openpanel-api";
    platforms = [ "x86_64-linux" ];
  };
})
