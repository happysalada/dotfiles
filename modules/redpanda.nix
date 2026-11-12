# Redpanda broker, started directly rather than through `rpk redpanda start`
# (rpk only checks the host and execs the same command line). Everything binds
# to loopback; nothing is opened in the firewall.
#
# The broker reads cluster properties from /etc/redpanda/.bootstrap.yaml, next
# to the config file, and only when the data directory is empty. Changing
# bootstrapSettings later does nothing: use `rpk cluster config set`.
#
# Upstream wants xfs or ext4 under the data directory. On btrfs the broker logs
# an error at startup and runs anyway.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.redpanda;
  yaml = pkgs.formats.yaml { };

  settings = lib.recursiveUpdate {
    redpanda = {
      data_directory = "/var/lib/redpanda/data";
      node_id = 0;
      seed_servers = [ ];
      rpc_server = {
        address = "127.0.0.1";
        port = 33145;
      };
      kafka_api = [
        {
          address = "127.0.0.1";
          port = 9092;
        }
      ];
      admin = [
        {
          address = "127.0.0.1";
          port = 9644;
        }
      ];
    };
  } cfg.settings;

  # the broker reports usage to Redpanda unless told not to
  bootstrap = {
    enable_metrics_reporter = false;
  }
  // cfg.bootstrapSettings;
in
{
  options.services.redpanda = {
    enable = lib.mkEnableOption "the Redpanda broker";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../packages/services/redpanda.nix { };
    };

    memory = lib.mkOption {
      type = lib.types.str;
      default = "1G";
      description = "Memory the broker allocates for itself (seastar --memory).";
    };

    settings = lib.mkOption {
      type = yaml.type;
      default = { };
      description = "redpanda.yaml, merged over the loopback-only defaults.";
    };

    bootstrapSettings = lib.mkOption {
      type = yaml.type;
      default = { };
      description = "Cluster properties applied once, on first start.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."redpanda/redpanda.yaml".source = yaml.generate "redpanda.yaml" settings;
    environment.etc."redpanda/.bootstrap.yaml".source = yaml.generate "bootstrap.yaml" bootstrap;

    systemd.services.redpanda = {
      description = "Redpanda broker";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      restartTriggers = [ config.environment.etc."redpanda/redpanda.yaml".source ];

      serviceConfig = {
        # the broker sends READY=1 itself once it serves the Kafka API
        Type = "notify";
        ExecStart = lib.concatStringsSep " " [
          "${cfg.package}/bin/redpanda --redpanda-cfg /etc/redpanda/redpanda.yaml"
          "--smp=1 --memory=${cfg.memory} --reserve-memory=0M"
          # share the machine instead of busy-polling a dedicated core
          "--overprovisioned --lock-memory=false"
          "--default-log-level=info"
        ];
        Restart = "on-failure";
        RestartSec = "5s";
        TimeoutStartSec = 300;

        DynamicUser = true;
        # the broker will not create its own data directory
        StateDirectory = [
          "redpanda"
          "redpanda/data"
        ];
        LimitNOFILE = 262144;
        AmbientCapabilities = "CAP_SYS_NICE";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
      };
    };

    # seastar reserves aio contexts up front; the kernel default is 64k
    boot.kernel.sysctl."fs.aio-max-nr" = lib.mkDefault 1048576;
  };
}
