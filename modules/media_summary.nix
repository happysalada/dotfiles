{ config, lib, pkgs, ... }:

{
  services.mediaSummary = {
    enable = true;
    gcloudSecretFilePath = config.age.secrets.GCLOUD_SECRET.path;
    port = 8787;
  };

  age.secrets =  {
    GCLOUD_SECRET = {
      file = ../secrets/gcloud_secrets.env.age;
    };
  };

  services.caddy.virtualHosts."summary.sassy.technology" = {
    extraConfig = ''
      reverse_proxy 127.0.0.1:${toString config.services.mediaSummary.port}
    '';
  };
}
