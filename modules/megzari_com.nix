{ config, ... }:
{
  services.caddy.virtualHosts = {
    "megzari.com" = {
      extraConfig = ''
        encode gzip
        import security_headers
        reverse_proxy 127.0.0.1:${toString config.services.megzari_com.port}
      '';
    };
  };
  services.megzari_com = {
    enable = true;
    port = 3006;
  };
}
