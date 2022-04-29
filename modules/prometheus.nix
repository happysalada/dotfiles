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

    remoteWrite = [ {
      url = "http://localhost:9009/api/v1/push";
    }];

    scrapeConfigs = [
      {
        job_name = "prometheus";
        static_configs = [{
          targets = [ "localhost:9090" ];
          labels = { alias = "prometheus"; };
        }];
      }

      # {
      #   job_name = "postgres";
      #   static_configs = [{
      #     targets = [ "localhost:9187" ];
      #     labels = { alias = "postgres"; };
      #   }];
      # }

      {
        job_name = "node";
        static_configs = [{
          targets = [ "localhost:9100" ];
          labels = { alias = "node"; };
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