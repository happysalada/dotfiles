{ config, ... }:

{
  services.cloudflare-dyndns = {
    enable = true;
    apiTokenFile = config.age.secrets.CLOUDFLARE_API_TOKEN.path;
    deleteMissing = true;
    domains = [
      "vaultwarden.megzari.com"
      "git.megzari.com"
      "gitea.megzari.com"
      "grafana.megzari.com"
      "atuin.megzari.com"
      "qdrant.megzari.com"
      "meilisearch.megzari.com"
      "uptime.megzari.com"
      "surrealdb.megzari.com"
      "megzari.com"
      "windmill.megzari.com"
      # "rustus.megzari.com"
      "ntfy.megzari.com"
      "hass.megzari.com"
      "adgh.megzari.com"
      "owu.megzari.com"
      "searx.megzari.com"
      "prefect.megzari.com"
    ];
  };
}
