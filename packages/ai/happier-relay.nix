# The self-hosted Happier relay (server), light flavor: SQLite and local files,
# one process, no Postgres or Redis. The CLI is packages/ai/happier.nix and both
# units are homes/programs/happier.nix.
#
# A prebuilt Bun binary plus Prisma engines and the web UI. Prisma calls this
# host `linux-nixos` and refuses to load the engine upstream shipped for
# `debian-openssl-3.0.x`, so the unit points PRISMA_QUERY_ENGINE_LIBRARY at that
# file explicitly. Both that engine and sharp's libvips need OpenSSL 3 and
# libstdc++, which is what the rpaths and the unit's LD_LIBRARY_PATH add.
{
  lib,
  stdenv,
  fetchurl,
  openssl,
  patchelf,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "happier-relay";
  version = "0.2.16";

  src = fetchurl {
    url = "https://github.com/happier-dev/happier/releases/download/server-v${finalAttrs.version}/happier-server-v${finalAttrs.version}-linux-x64.tar.gz";
    hash = "sha256-FQ52yBxZBX7BpmCcdWksd0/oD3jP1IlPLMMefn/I+s4=";
  };

  nativeBuildInputs = [ patchelf ];

  # Same Bun binary, same reason as packages/ai/happier.nix: the fixup phase's
  # own patchelf pass corrupts it, and the rpaths set below are the ones that
  # matter.
  dontPatchELF = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib
    cp -a . $out/lib/happier-relay
    cd $out/lib/happier-relay

    # The Bun-compiled launchers get one patchelf rewrite and nothing more: a
    # second one leaves them segfaulting (packages/ai/happier.nix hits the same
    # loader bug), so their OpenSSL and libstdc++ come from the unit's
    # LD_LIBRARY_PATH instead of an rpath.
    for f in happier-server happier-server-migrate runtime/prisma-migrate; do
      patchelf --set-interpreter "${stdenv.cc.bintools.dynamicLinker}" "$f"
    done

    # schema-engine is Rust, not Bun, so it can carry its rpath.
    patchelf --set-interpreter "${stdenv.cc.bintools.dynamicLinker}" runtime/schema-engine
    patchelf --add-rpath "${lib.makeLibraryPath [ stdenv.cc.cc.lib openssl ]}" runtime/schema-engine

    for f in \
      generated/sqlite-client/libquery_engine-debian-openssl-3.0.x.so.node \
      node_modules/.prisma/client/libquery_engine-debian-openssl-3.0.x.so.node \
      node_modules/@img/sharp-libvips-linux-x64/lib/libvips-cpp.so.8.17.3 \
      node_modules/@img/sharp-linux-x64/lib/sharp-linux-x64.node; do
      patchelf --add-rpath "${lib.makeLibraryPath [ stdenv.cc.cc.lib openssl ]}" "$f"
    done

    runHook postInstall
  '';

  meta = {
    description = "Self-hosted Happier relay (SQLite light flavor)";
    homepage = "https://happier.dev";
    license = lib.licenses.mit;
    mainProgram = "happier-server";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
})
