{config, ...}: {
  services.atuin = {
    enable = true;
    # openRegistration = true;
  };
  services.caddy.virtualHosts."atuin.sassy.technology" = {
    extraConfig = ''
      reverse_proxy ${config.services.atuin.host}:${toString config.services.atuin.port}
    '';
  };
}