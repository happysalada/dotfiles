# Redpanda broker: a Kafka-API log in one native binary, no JVM or ZooKeeper.
# OpenPanel sends every tracked event through it.
#
# GitHub releases carry only rpk (nixpkgs' redpanda-client), and the broker is a
# Bazel build, so this unpacks the .deb from upstream's apt repo. The deb ships
# its own glibc and ld.so, and the broker's interpreter is the absolute
# /opt/redpanda/lib/ld.so; patchelf repoints that into the store and the rest of
# the bundle runs as shipped (the binary's RUNPATH is already $ORIGIN/../lib).
#
# The layout stays under $out/opt/redpanda because `rpk redpanda start
# --install-dir` expects <dir>/bin/redpanda.
{
  lib,
  stdenvNoCC,
  fetchurl,
  dpkg,
  patchelf,
  runtimeShell,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "redpanda";
  version = "26.2.6";

  src = fetchurl {
    # The pool path carries a build hash: a bump needs the new Filename and
    # SHA256 from dists/redpanda-apt/main/binary-amd64/Packages.
    url = "https://linux.pkg.redpanda.com/apt/pool/redpanda-apt/redpanda_${finalAttrs.version}-1_amd64_1d6c464a0a963a29255ae06c84f5930d.deb";
    hash = "sha256-ScXx2noL6+1Gi2rz+FWW8vL4V/qgN72BecJ80BsK47c=";
  };

  nativeBuildInputs = [
    dpkg
    patchelf
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src .
    runHook postUnpack
  '';

  dontConfigure = true;
  dontBuild = true;
  dontFixup = true; # patchelf below is the whole fixup, and strip would rewrite the bundle

  installPhase = ''
    runHook preInstall

    install_dir=$out/opt/redpanda
    mkdir -p $out/opt $out/bin
    cp -r opt/redpanda $install_dir
    chmod -R u+w $install_dir

    # FIPS rpk and OpenSSL's FIPS module: unused, and half the size of lib/
    rm -r $install_dir/lib/rpk-fips $install_dir/lib/ossl-modules

    patchelf --set-interpreter $install_dir/lib/ld.so $install_dir/libexec/redpanda

    # upstream's wrapper hardcodes /opt/redpanda and sets LD_LIBRARY_PATH
    cat > $install_dir/bin/redpanda <<EOF
    #!${runtimeShell}
    exec -a redpanda $install_dir/libexec/redpanda "\$@"
    EOF
    chmod +x $install_dir/bin/redpanda
    ln -s $install_dir/bin/redpanda $out/bin/redpanda

    runHook postInstall
  '';

  meta = {
    description = "Kafka-compatible streaming broker in a single native binary";
    homepage = "https://redpanda.com";
    license = lib.licenses.bsl11; # source-available, not free software
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "redpanda";
    platforms = [ "x86_64-linux" ];
  };
})
