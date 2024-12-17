{
  config,
  ...
}:
{
  services.uptime-kuma = {
    enable = true;
    appriseSupport = true;
  };

  services.caddy.virtualHosts = {
    "uptime.megzari.com" = {
      extraConfig = ''
        import security_headers
        reverse_proxy ${config.services.uptime-kuma.settings.HOST}:${config.services.uptime-kuma.settings.PORT}
      '';
    };
  };
}
