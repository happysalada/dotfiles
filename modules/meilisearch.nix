{ config, ... }:
{
  services.meilisearch = {
    enable = true;
    # The old top-level `dumplessUpgrade` still maps here, but nixpkgs marks it
    # obsolete and warns on every evaluation, so the settings spelling is the
    # one to keep.
    settings.experimental_dumpless_upgrade = true;
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
