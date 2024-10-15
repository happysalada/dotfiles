{ config, ... }:
{
  services.caddy.virtualHosts = {
    "atuin.megzari.com" = {
      extraConfig = ''
        import security_headers
        reverse_proxy ${config.services.atuin.host}:${toString config.services.atuin.port}
      '';
    };
  };
  services.atuin = {
    enable = true;
    # openRegistration = true;
  };
}
