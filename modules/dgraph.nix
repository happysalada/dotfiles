{ config, lib, pkgs, ... }:
{
  services.dgraph.enable = true;

  services.caddy.virtualHosts."dgraph.sassy.technology" = {
    extraConfig = ''
      reverse_proxy 127.0.0.1:8080
    '';
  };
}
