{ config, ... }:
{
  services = {
    invidious = {
      enable = true;
      database.createLocally = true;
      domain = "invidious.megzari.com";
      address = "127.0.0.1";
      port = 3031;
      settings = {
        https_only = true;
        hsts = true;
      };
    };
    caddy.virtualHosts = {
      "invidious.megzari.com" = {
        extraConfig = ''
          encode gzip
          import security_headers
          reverse_proxy ${config.services.paperless.address}:${toString config.services.invidious.port} {
            header_up X-Real-IP {remote_host}
          }
        '';
      };
    };
  };
}
