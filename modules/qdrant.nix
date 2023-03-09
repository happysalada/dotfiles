{ config, lib, pkgs, ... }:

{
  services.qdrant = {
    enable = true;
    settings = {
      hsnw_index = {
        on_disk = true;
      };
    };
  };

  services.caddy.virtualHosts."qdrant.sassy.technology" = {
    extraConfig = ''
      reverse_proxy 127.0.0.1:${toString config.services.qdrant.settings.service.http_port}
    '';
  };
}
