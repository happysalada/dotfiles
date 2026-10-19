# Meilisearch: a RESTful search API. Shared by bee and strix - on bee it is
# exposed through caddy at meilisearch.megzari.com, on strix it stays on
# localhost for local tools and agents (no caddy there, so the vhost below is
# simply never defined).
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
  };

  age.secrets.meilisearch-master-key = {
    file = ../secrets/meilisearch.master-key.age;
  };

  services.caddy.virtualHosts = lib.mkIf config.services.caddy.enable {
    "meilisearch.megzari.com" = {
      extraConfig = ''
        import security_headers
        reverse_proxy ${config.services.meilisearch.listenAddress}:${toString config.services.meilisearch.listenPort}
      '';
    };
  };
}
