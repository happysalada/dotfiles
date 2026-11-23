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

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [
      4000
      4001
      4002
      4003
    ];
  };
}
