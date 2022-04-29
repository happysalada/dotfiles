{ config, lib, pkgs, ... }:

{
  services.grafana = {
    enable = true;

    provision = {
      enable = true;
      datasources = [
        {
          name = "loki";
          type = "loki";
          url = "http://127.0.0.1:3100";
        }
        {
          name = "mimir";
          type = "prometheus";
          url = "http://127.0.0.1:9009/prometheus";
        }
        {
          name = "prometheus";
          type = "prometheus";
          url = "http://127.0.0.1:9090";
        }
      ];
       dashboards = [
        {
          name = "Node Exporter";
          options.path = ./node-exporter-full_rev26.json;
          disableDeletion = true;
        }
      ];
    };
  };

  services.caddy.virtualHosts."grafana.sassy.technology" = {
    extraConfig = ''
      reverse_proxy 127.0.0.1:3000
    '';
  };
}