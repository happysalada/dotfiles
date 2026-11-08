# OpenPanel analytics with its dependencies provisioned on the same machine:
# Postgres (peer auth over the socket), a Redis instance, ClickHouse and
# Redpanda (modules/redpanda.nix). Everything listens on loopback only.
#
# Public side: the dashboard and the api get a hostname each, as OpenPanel
# Cloud does (dashboard.* and api.*), so whatever fronts them - the tunnel -
# needs no path routing. Keep both under one registrable domain: the session
# cookie is scoped to it.
#
# environmentFile (an agenix secret) holds COOKIE_SECRET (`openssl rand -hex
# 16`), AUTH_SECRET and ENCRYPTION_KEY (`openssl rand -hex 32` each), plus
# RESEND_API_KEY and ADMIN_USERNAME / ADMIN_PASSWORD if wanted. Registration
# is closed, as upstream ships it: open it with settings.ALLOW_REGISTRATION =
# "true" for the first account.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.openpanel;
  inherit (lib) mkOption types;

  service =
    {
      description,
      exec,
      environment ? { },
      after ? [ ],
      requires ? [ ],
      preStart ? null,
    }:
    {
      inherit description requires;
      wantedBy = [ "multi-user.target" ];
      wants = dependencies;
      after = dependencies ++ after;
      environment = env // { HOME = "/var/lib/openpanel"; } // environment;
      serviceConfig = {
        ExecStart = exec;
        ExecStartPre = lib.optional (preStart != null) preStart;
        User = "openpanel";
        Group = "openpanel";
        StateDirectory = "openpanel";
        EnvironmentFile = cfg.environmentFile;
        Restart = "on-failure";
        RestartSec = "5s";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
      };
    };

  dependencies = [
    "network.target"
    "postgresql.service"
    "redis-openpanel.service"
    "clickhouse.service"
    "redpanda.service"
  ];

  databaseUrl = "postgresql://openpanel@localhost/openpanel?host=/run/postgresql";

  env = {
    NODE_ENV = "production";
    SELF_HOSTED = "true";
    AUTOMATIC_MIGRATIONS = "true";
    BATCH_SIZE = "5000";
    BATCH_INTERVAL = "10000";
    ALLOW_REGISTRATION = "false";
    ALLOW_INVITATION = "true";
    # no calls home
    DISABLE_PING = "true";

    DATABASE_URL = databaseUrl;
    DATABASE_URL_DIRECT = databaseUrl;
    REDIS_URL = "redis://127.0.0.1:${toString config.services.redis.servers.openpanel.port}";
    CLICKHOUSE_URL = "http://127.0.0.1:8123/openpanel";
    KAFKA_BROKERS = "127.0.0.1:9092";

    DASHBOARD_URL = "https://${cfg.domain}";
    API_URL = "https://${cfg.apiDomain}";
    API_URL_SSR = "http://127.0.0.1:${toString cfg.apiPort}";
  }
  // cfg.settings;
in
{
  imports = [ ./redpanda.nix ];

  options.services.openpanel = {
    enable = lib.mkEnableOption "OpenPanel";

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ../packages/services/openpanel.nix { };
    };

    domain = mkOption {
      type = types.str;
      example = "analytics.example.com";
      description = "Public hostname of the dashboard.";
    };

    apiDomain = mkOption {
      type = types.str;
      example = "analytics-api.example.com";
      description = "Public hostname of the api, which the tracking script posts to.";
    };

    environmentFile = mkOption {
      type = types.path;
      description = "Secrets, as KEY=value lines.";
    };

    settings = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Environment merged over the defaults.";
    };

    dashboardPort = mkOption {
      type = types.port;
      default = 3300;
    };

    apiPort = mkOption {
      type = types.port;
      default = 3301;
    };

    workerPort = mkOption {
      type = types.port;
      default = 3302;
      description = "The worker serves health checks and the queue dashboard.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        users.users.openpanel = {
          isSystemUser = true;
          group = "openpanel";
        };
        users.groups.openpanel = { };

        systemd.services = {
          openpanel-api = service {
            description = "OpenPanel API";
            after = [ "openpanel-clickhouse-init.service" ];
            requires = [ "openpanel-clickhouse-init.service" ];
            environment = {
              ROLE = "api";
              API_PORT = toString cfg.apiPort;
            };
            # the api applies the ClickHouse migrations itself once it listens
            preStart = "${cfg.package}/bin/openpanel-migrate";
            exec = "${cfg.package}/bin/openpanel-api";
          };

          openpanel-worker = service {
            description = "OpenPanel worker";
            after = [ "openpanel-api.service" ];
            environment = {
              ROLE = "worker";
              API_PORT = toString cfg.workerPort;
            };
            exec = "${cfg.package}/bin/openpanel-api";
          };

          openpanel-dashboard = service {
            description = "OpenPanel dashboard";
            after = [ "openpanel-api.service" ];
            environment = {
              HOST = "127.0.0.1";
              PORT = toString cfg.dashboardPort;
            };
            exec = "${cfg.package}/bin/openpanel-dashboard";
          };

          openpanel-clickhouse-init = {
            description = "Create the OpenPanel ClickHouse database";
            after = [ "clickhouse.service" ];
            requires = [ "clickhouse.service" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              TimeoutStartSec = 120;
            };
            script = ''
              client=${config.services.clickhouse.package}/bin/clickhouse-client
              until $client --query 'SELECT 1' >/dev/null 2>&1; do sleep 1; done
              $client --query 'CREATE DATABASE IF NOT EXISTS openpanel'
            '';
          };
        };
      }

      {
        services.postgresql = {
          enable = true;
          ensureDatabases = [ "openpanel" ];
          ensureUsers = [
            {
              name = "openpanel";
              ensureDBOwnership = true;
            }
          ];
        };

        services.redis.servers.openpanel = {
          enable = true;
          port = 6380;
          bind = "127.0.0.1";
          # the queues must never lose a job to eviction
          settings.maxmemory-policy = "noeviction";
        };

        services.clickhouse = {
          enable = true;
          usersConfig.profiles.default = {
            log_queries = 0;
            log_query_threads = 0;
          };
        };

        services.redpanda = {
          enable = true;
          # applied once; raising it later reshuffles the per-key ordering of
          # the events topic (see upstream's docs/SCALING.md)
          bootstrapSettings = {
            default_topic_partitions = 24;
            default_topic_replications = 1;
            auto_create_topics_enabled = true;
            log_compression_type = "lz4";
            log_retention_ms = 172800000;
          };
        };
      }
    ]
  );
}
