{ ... }:

{
  services.prefect = {
    enable = true;
    database = "sqlite";
    workerPools = [ "default" ];
    uiApiUrl = "https://prefect.megzari.com/api";
    uiServeBase = "/";
    uiUrl = "https://prefect.megzari.com";
  };

  services.caddy.virtualHosts = {
    "prefect.megzari.com" = {
      extraConfig = ''
        import security_headers
        reverse_proxy 127.0.0.1:4200
      '';
    };
  };
}
