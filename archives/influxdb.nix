{ config, lib, pkgs, ... }:

{
  services.influxdb2 = {
    enable = true;
  };

  services.caddy.virtualHosts."influxdb.sassy.technology" = {
    extraConfig = ''
      reverse_proxy 127.0.0.1:8086
    '';
  };
}