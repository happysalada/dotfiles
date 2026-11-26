# GreptimeDB standalone: one local engine for metrics, logs and traces.
# Written against 1.3.x, but the config keys used here also exist in 1.2.1, so
# it evaluates before the nixpkgs bump lands. The cluster topology (metasrv +
# frontend + datanode) is a separate deployment, not a flag on this unit.
{ config, lib, pkgs, ... }:
let
  cfg = config.services.greptimedb;

  settings = lib.recursiveUpdate {
    default_timezone = "UTC";
    enable_telemetry = false;

    http.addr = "127.0.0.1:4000";
    grpc.bind_addr = "127.0.0.1:4001";
    mysql.addr = "127.0.0.1:4002";
    postgres.addr = "127.0.0.1:4003";

    storage = {
      type = "File";
      data_home = "/var/lib/greptimedb";
    };
    wal = {
      provider = "raft_engine";
      dir = "/var/lib/greptimedb/wal";
    };
    logging.dir = "/var/lib/greptimedb/logs";
  } cfg.settings;

  configFile = (pkgs.formats.toml { }).generate "greptimedb.toml" settings;

  # One origin for the dashboard and the DB, with the app at the root: the
  # build routes with a hash (`#/dashboard/query`), so a path prefix only
  # duplicates what the route already says. The app also infers its API host by
  # appending window.location.pathname to the origin, which is the origin
  # itself here, and axios normalises that base against `/v1/...`.
  dashboardCaddyfile = pkgs.writeText "greptimedb-dashboard.Caddyfile" ''
    {
    	admin off
    	auto_https off
    }

    http://127.0.0.1:${toString cfg.dashboard.port} {
    	# The address the app was served at while it needed a prefix.
    	redir /dashboard* /

    	@static path / /index.html /assets/*
    	handle @static {
    		root * ${cfg.dashboard.package}/share/greptimedb-dashboard
    		file_server {
    			precompressed gzip
    		}
    	}

    	# Everything else is the DB: /v1/*, /status, /metrics, /config, and any
    	# endpoint a later release adds.
    	handle {
    		reverse_proxy ${settings.http.addr}
    	}
    }
  '';
in
{
  options.services.greptimedb = {
    enable = lib.mkEnableOption "GreptimeDB standalone";
    package = lib.mkPackageOption pkgs "greptimedb" { };
    settings = lib.mkOption {
      type = (pkgs.formats.toml { }).type;
      default = { };
      description = "Merged over the module defaults and rendered as the standalone TOML.";
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the HTTP, gRPC, MySQL and Postgres ports.";
    };

    # The dashboard is a separate app upstream (GreptimeTeam/dashboard): the
    # OSS `greptime` binary serves a landing page whose `/dashboard` link 404s.
    # So it is packaged here (packages/services/greptimedb-dashboard.nix) and
    # served at the root of a loopback port that proxies the DB's own API,
    # loopback only like the DB itself - reaching it from another machine means
    # an SSH tunnel or a Caddy host, not a firewall port.
    dashboard = {
      enable = lib.mkEnableOption "the GreptimeDB web dashboard on loopback";

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.callPackage ../packages/services/greptimedb-dashboard.nix { };
        defaultText = lib.literalExpression "pkgs.callPackage ../packages/services/greptimedb-dashboard.nix { }";
        description = "Static build of the GreptimeDB dashboard.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 4004;
        description = "Loopback port serving the dashboard at `/` and proxying every other path to the DB's HTTP addr.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    system.build.greptimedbConfig = configFile;

    # The binary is the admin CLI (`greptime cli`, `greptime user`); queries
    # go through the HTTP API, MySQL/Postgres wire, or the MCP server.
    environment.systemPackages = [ cfg.package ];

    users.groups.greptimedb = { };
    users.users.greptimedb = {
      isSystemUser = true;
      group = "greptimedb";
      home = "/var/lib/greptimedb";
    };

    systemd.services.greptimedb = {
      description = "GreptimeDB standalone";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        ExecStartPre = "${lib.getExe' pkgs.coreutils "mkdir"} -p /var/lib/greptimedb/wal /var/lib/greptimedb/logs";
        ExecStart = "${lib.getExe cfg.package} standalone start -c ${configFile}";
        User = "greptimedb";
        Group = "greptimedb";
        WorkingDirectory = "/var/lib/greptimedb";
        StateDirectory = "greptimedb";
        StateDirectoryMode = "0750";
        Restart = "on-failure";
        RestartSec = 5;
        LimitNOFILE = 1048576;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK" ];
      };
    };

    # The dashboard has to share an origin with the DB. It infers its API host
    # from window.location (appending the pathname to the origin), so on a port
    # of its own every query goes back to the static server and 404s - `Route
    # /v1/sql could not be found` in the log. One Caddy listener answers the
    # app's files and proxies everything else to the DB's HTTP addr.
    systemd.services.greptimedb-dashboard = lib.mkIf cfg.dashboard.enable {
      description = "GreptimeDB dashboard and HTTP proxy";
      wantedBy = [ "multi-user.target" ];
      after = [ "greptimedb.service" ];
      wants = [ "greptimedb.service" ];
      serviceConfig = {
        ExecStart = "${lib.getExe pkgs.caddy} run --config ${dashboardCaddyfile} --adapter caddyfile";
        DynamicUser = true;
        # auto_https is off and admin is off, but Caddy still opens its storage
        # for the TLS cache app; %S is the only writable place under DynamicUser.
        StateDirectory = "greptimedb-dashboard";
        Environment = [
          "XDG_DATA_HOME=%S/greptimedb-dashboard"
          "XDG_CONFIG_HOME=%S/greptimedb-dashboard"
        ];
        Restart = "on-failure";
        RestartSec = 5;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [
      4000
      4001
      4002
      4003
    ];
  };
}
