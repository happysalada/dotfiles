{config, ...}: {
  services.meilisearch = {
    enable = true;
  };
  services.caddy.virtualHosts."meilisearch.sassy.technology" = {
    extraConfig = ''
      reverse_proxy ${config.services.meilisearch.listenAddress}:${toString config.services.meilisearch.listenPort}
    '';
  };
}
