# Meilisearch: a RESTful search API. Shared by bee and strix - on bee it is
# exposed through caddy at meilisearch.megzari.com, on strix it stays on
# localhost for local tools and agents (its caddy only proxies fundies, so
# the public vhost below is not defined there).
#
# The master key is required: without one every route is open to whoever can
# reach the port. It lives in an agenix secret, decrypted to a root-only file
# that systemd reads via LoadCredential - the key never lands in the nix store
# or a world-readable path, and the DynamicUser service never touches the file
# directly.
{ config, lib, ... }:
{
  services.meilisearch = {
    enable = true;
    masterKeyFile = config.age.secrets.meilisearch-master-key.path;
    # Since the SSRF fix, embedder URLs resolving to non-global IPs are refused.
    settings.experimental_allowed_ip_networks = [
      "127.0.0.1/32"
      "::1/128"
    ];
    # Caches the query embeddings sent to the embedder, per embedder, so a
    # repeated search does not re-run the model. Meilisearch ships this off;
    # 1024 entries is a few MB of vectors and covers the usual query set.
    settings.experimental_embedding_cache_entries = 1024;
  };

  age.secrets.meilisearch-master-key = {
    file = ../secrets/meilisearch.master-key.age;
  };

  services.caddy.virtualHosts = lib.mkIf (lib.hasInfix "(security_headers)" config.services.caddy.extraConfig) {
    "meilisearch.megzari.com" = {
      extraConfig = ''
        import security_headers
        reverse_proxy ${config.services.meilisearch.listenAddress}:${toString config.services.meilisearch.listenPort}
      '';
    };
  };
}
