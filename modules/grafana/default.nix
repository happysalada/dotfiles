{ ... }:

{
  services.caddy.virtualHosts = {
    "grafana.megzari.com" = {
      extraConfig = ''
        encode gzip
        import security_headers
        reverse_proxy 127.0.0.1:3000
      '';
    };
  };
  services.grafana = {
    enable = true;

    settings = { };
    provision = {
      enable = true;
      datasources.settings = {
        apiVersion = 1;
        # Loki and Mimir were retired with the observability swap. GreptimeDB
        # serves the Prometheus query API under /v1/prometheus; logs are read
        # through its SQL API or MCP server, not a Grafana datasource.
        datasources = [
          {
            name = "greptimedb";
            type = "prometheus";
            url = "http://127.0.0.1:4000/v1/prometheus/";
          }
          {
            name = "prometheus";
            type = "prometheus";
            url = "http://127.0.0.1:9090";
          }
        ];
      };
      dashboards.settings = {
        apiVersion = 1;
        providers = [
          {
            name = "Node Exporter";
            options.path = ./node-exporter-full_rev26.json;
            disableDeletion = true;
          }
        ];
      };
    };
  };
}
