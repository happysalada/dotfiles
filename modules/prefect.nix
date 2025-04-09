{ config, ... }:

{
  services.prefect = {
    enable = true;
    database = "sqlite";
    workerPools.default = {
      installPolicy = "if-not-present";
    };
    baseUrl = "https://prefect.megzari.com";
  };

  systemd.services.prefect-worker-default.environment.systemPackages =
    config.services.prefect.package;

  services.caddy.virtualHosts = {
    "prefect.megzari.com" = {
      extraConfig = ''
        import security_headers
        reverse_proxy 127.0.0.1:4200
      '';
    };
  };
}
