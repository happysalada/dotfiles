{ config, ... }:

{
  services.qdrant = {
    enable = true;
    settings = {
      hsnw_index = {
        on_disk = true;
      };
    };
  };

  services.caddy.virtualHosts = {
    "qdrant.megzari.com" = {
      extraConfig = ''
        import security_headers
        reverse_proxy 127.0.0.1:${toString config.services.qdrant.settings.service.http_port}
      '';
    };
  };
}
