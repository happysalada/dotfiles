# sccache's server, owned by systemd instead of by whichever client compiled
# first.
#
# Left alone, the server is spawned lazily by the first `cargo build`, and it
# inherits that caller's environment and mount namespace - so a build started
# inside an agent's jail leaves behind a server whose /tmp is that jail's, which
# every cache-miss compile on the machine then fails against while cache hits,
# needing no temp file, keep succeeding. Pinning the scratch dir and owning the
# lifetime is the fix.
#
# The default 127.0.0.1:4226 rather than a unix socket, so that jail clients need
# no wiring: a socket path can be unlinked and rebound by a second server - a
# squatter silently takes the endpoint over - while a port can only be held by
# one process.
#
# Strix-only, like the cargo config it backs (homes/programs/cargo.nix).
{ config, lib, pkgs, ... }:
let
  home = config.home.homeDirectory;
in
{
  systemd.user.services.sccache = {
    Unit.Description = "sccache compile cache server";

    Service = {
      Type = "simple";

      # SCCACHE_START_SERVER=1 alone forks and the invoking process exits, which
      # is why `--start-server` needs Type=forking and a PIDFile it never writes.
      # With SCCACHE_NO_DAEMON=1 the server *is* the process systemd supervises:
      # upstream's recipe for running one locally, and on 0.18.0 it binds, serves
      # a miss then a hit, and stays put.
      ExecStart = "${pkgs.coreutils}/bin/env SCCACHE_START_SERVER=1 SCCACHE_NO_DAEMON=1 ${lib.getExe pkgs.sccache}";

      # A lazily-spawned server can still hold 4226 from an earlier session, and
      # binding a taken port fails outright - which under Restart=always is a
      # failure loop rather than a working unit. The connection-refused line this
      # leaves in the journal when there is nothing to stop is the normal case.
      ExecStartPre = "-${lib.getExe pkgs.sccache} --stop-server";

      Environment = [
        # Never a session's /tmp: the server is what execs the compiler, and the
        # temp files that come out of that have to outlive the build that asked
        # for them. CacheDirectory= creates this one, 0700, before ExecStart.
        "TMPDIR=${home}/.cache/sccache-tmp"
        # Spelled out rather than left to sccache's default so that the server
        # and every client agree on it, whatever each one's environment is.
        "SCCACHE_DIR=${home}/.cache/sccache"
        # 0 = never exit on idle. With Restart=always below, this is what keeps a
        # client from ever being the one to start a server.
        "SCCACHE_IDLE_TIMEOUT=0"
        # The linker rustc reaches for (`linker = "clang"` above, in cargo.nix)
        # is a bare name it resolves through PATH, in the server's environment -
        # and a unit started at boot has no session environment to inherit one
        # from.
        "PATH=/run/wrappers/bin:${home}/.nix-profile/bin:/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin"
      ];
      CacheDirectory = "sccache-tmp";

      # `always`, not `on-failure`: a clean exit is what leaves no supervised
      # server, and that is the state that hands the endpoint back to a client.
      # Stop it with `systemctl --user stop sccache`, which this honours.
      Restart = "always";
      RestartSec = 2;
    };

    Install.WantedBy = [ "default.target" ];
  };
}
