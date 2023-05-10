{
  config,
  ...
}: {
  services.uptime-kuma = {
    enable = true;
    appriseSupport = true;
  };
  services.caddy.virtualHosts."uptime.sassy.technology" = {
    extraConfig = ''
      reverse_proxy ${config.services.uptime-kuma.settings.HOST}:${config.services.uptime-kuma.settings.PORT}
    '';
  };
}
