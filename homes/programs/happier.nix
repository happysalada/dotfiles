# Happier: one control room for the agent sessions on this machine, from the
# phone or a browser. Two user services -
#
#   happier-relay   the self-hosted sync relay (SQLite light flavor), reachable
#                   only across NetBird. It holds a sleep inhibitor for as long
#                   as it runs: a suspended laptop is an offline relay, and the
#                   phone cannot start anything on it.
#   happier-daemon  the local process that launches and mirrors claude, codex
#                   and opencode sessions. It talks to the relay above.
#
# Sign-in and relay selection are still interactive (`happier setup --relay ...`
# writes ~/.happier); nothing here fakes credentials.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cli = pkgs.callPackage ../../packages/ai/happier.nix { };
  relay = pkgs.callPackage ../../packages/ai/happier-relay.nix { };

  port = 3005;
  # The name modules/netbird.nix gives this peer; both the phone and the CLI
  # reach the relay through it, and it is what QR/deep links carry.
  relayUrl = "http://strix.netbird.cloud:${toString port}";

  # StateDirectory puts this under ~/.local/state for a user unit.
  dataDir = "${config.home.homeDirectory}/.local/state/happier-relay";

  relayDir = "${relay}/lib/happier-relay";
in
{
  systemd.user.services.happier-relay = {
    Unit = {
      Description = "Happier relay (self-hosted, SQLite light flavor)";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      Type = "simple";
      StateDirectory = "happier-relay";
      StateDirectoryMode = "0700";
      UMask = "0077";
      WorkingDirectory = dataDir;

      # The server only creates the database; these two are where attachments
      # and the per-provider database copies go.
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${dataDir}/files ${dataDir}/db";

      # The inhibitor is the point: systemd-inhibit holds the lock for exactly
      # the lifetime of the child, so lid close and idle sleep stop while the
      # relay is up and resume the moment it is stopped.
      ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=sleep:handle-lid-switch --mode=block --why=\"Happier relay is running\" -- ${relayDir}/happier-server";

      Restart = "on-failure";
      RestartSec = 5;

      # Upstream's managed install writes this same set, minus the paths that
      # only make sense for its own payload copy. Prisma cannot load the engine
      # it shipped for this host (`linux-nixos`), so the engine is named
      # explicitly; the Bun binary itself gets no rpath (see the package).
      Environment = [
        "PORT=${toString port}"
        "HAPPIER_SERVER_HOST=0.0.0.0"
        "HAPPIER_PUBLIC_SERVER_URL=${relayUrl}"
        "HAPPIER_WEBAPP_URL=${relayUrl}"
        "HAPPIER_DB_PROVIDER=sqlite"
        "DATABASE_URL=file:${dataDir}/happier-server-light.sqlite"
        "HAPPIER_FILES_BACKEND=local"
        "HAPPIER_SERVER_LIGHT_DATA_DIR=${dataDir}"
        "HAPPIER_SERVER_LIGHT_FILES_DIR=${dataDir}/files"
        "HAPPIER_SERVER_LIGHT_DB_DIR=${dataDir}/db"
        "HAPPIER_SQLITE_AUTO_MIGRATE=1"
        "HAPPIER_SQLITE_MIGRATIONS_DIR=${relayDir}/prisma/sqlite/migrations"
        "HAPPIER_SERVER_UI_DIR=${relayDir}/ui-web/current"
        "NODE_PATH=${relayDir}/node_modules"
        "PRISMA_CLIENT_ENGINE_TYPE=library"
        "PRISMA_QUERY_ENGINE_LIBRARY=${relayDir}/generated/sqlite-client/libquery_engine-debian-openssl-3.0.x.so.node"
        "METRICS_ENABLED=false"
        "LD_LIBRARY_PATH=${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib pkgs.openssl ]}"
      ];
    };

    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.happier-daemon = {
    Unit = {
      Description = "Happier daemon (remote control for agent sessions)";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      Type = "simple";
      WorkingDirectory = "%h";
      KillMode = "process";
      ManagedOOMPreference = "avoid";

      ExecStart = "${cli}/bin/happier daemon start-sync --takeover";
      Restart = "on-failure";
      RestartSec = 2;

      # The markers upstream's generated unit sets are what make `happier
      # service status` and the daemon agree that this is the installed
      # background service. PATH matters for the same reason as opencode's:
      # the daemon launches the agent CLIs and their tools.
      Environment = [
        "PATH=/run/wrappers/bin:%h/.nix-profile/bin:/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin"
        "HAPPIER_PUBLIC_RELEASE_CHANNEL=stable"
        "HAPPIER_DAEMON_STARTUP_SOURCE=background-service"
        "HAPPIER_DAEMON_SERVICE_LABEL=com.happier.cli.daemon.default"
        "HAPPIER_DAEMON_SERVICE_TARGET_MODE=default-following"
        "HAPPIER_DAEMON_SERVICE_AUTOSTART=at-login"
        "HAPPIER_NO_BROWSER_OPEN=1"
        "HAPPIER_DAEMON_WAIT_FOR_AUTH=1"
        "HAPPIER_DAEMON_WAIT_FOR_AUTH_TIMEOUT_MS=0"
      ];
    };

    Install.WantedBy = [ "default.target" ];
  };
}
