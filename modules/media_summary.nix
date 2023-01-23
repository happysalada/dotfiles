{ config, lib, pkgs, ... }:

{
  services.mediaSummary = {
    enable = true;
    gcloudSecretPath = config.age.secrets.GCLOUD_SECRET.path;
    openaiKeyPath = config.age.secrets.OPENAI_KEY.path;
    port = 8787;
  };

  age.secrets =  {
    GCLOUD_SECRET = {
      file = ../secrets/gcloud_secrets.env.age;
    };
    OPENAI_KEY = {
      file = ../secrets/openai.key.age;
    };
  };

  services.caddy.virtualHosts."summary.sassy.technology" = {
    extraConfig = ''
      reverse_proxy 127.0.0.1:${toString config.services.mediaSummary.port}
    '';
  };
}
