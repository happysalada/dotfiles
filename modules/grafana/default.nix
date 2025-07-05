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
