{ config, lib, pkgs, ... }:

{
  # TODO figure out how to set alertmanager properly
  # https://gist.github.com/globin/02496fd10a96a36f092a8e7ea0e6c7dd
  services.prometheus = {
    enable = true;
    globalConfig = {
      scrape_interval = "5s";
      evaluation_interval = "5s";
    };

    scrapeConfigs = [
      {
        job_name = "prometheus";
        static_configs = [{
          targets = [ "localhost:9090" ];
          labels = { alias = "prometheus.forunion.com"; };
        }];
      }

      # {
      #   job_name = "postgres";
      #   static_configs = [{
      #     targets = [ "localhost:9187" ];
      #     labels = { alias = "postgres.forunion.com"; };
      #   }];
      # }

      {
        job_name = "node";
        static_configs = [{
          targets = [ "localhost:9100" ];
          labels = { alias = "forunion.com"; };
        }];
      }

    ];

    exporters = {
      node = {
        enable = true;
        enabledCollectors = [
          "conntrack"
          "diskstats"
          "entropy"
          "filefd"
          "filesystem"
          "loadavg"
          "mdadm"
          "meminfo"
          "netdev"
          "netstat"
          "stat"
          "time"
          "vmstat"
          "systemd"
          "logind"
          "interrupts"
          "ksmd"
        ];
      };

      # postgres = {
      #   enable = true;
      #   dataSourceName = "user=postgres-exporter database=union_1 host=/var/run/postgresql sslmode=disable";
      # };
    };
  };
  # services.postgresql = {
  #   ensureUsers = [{
  #     name = "postgres-exporter";

  #     ensurePermissions = {
  #       "DATABASE ${config.services.union.dbName}" = "ALL PRIVILEGES";
  #     };
  #   }];
  # };
}