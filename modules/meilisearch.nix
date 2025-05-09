{ config, ... }:
{
  services.meilisearch = {
    enable = true;
    dumplessUpgrade = true;
  };

  services.caddy.virtualHosts = {
    "meilisearch.megzari.com" = {
      extraConfig = ''
        import security_headers
        reverse_proxy ${config.services.meilisearch.listenAddress}:${toString config.services.meilisearch.listenPort}
      '';
    };
  };
}
