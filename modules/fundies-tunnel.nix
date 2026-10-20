# fundies.io through a locally managed Cloudflare tunnel. The credentials JSON
# is the one `cloudflared tunnel create fundies` wrote, encrypted by agenix; the
# ingress is local because the tunnel is local. No Caddy and no open ports.
#
# The tunnel is keyed by its UUID, not by the name `fundies`: cloudflared needs
# cert.pem to resolve a name, and the generated service has no $HOME to find it.
# Its own help says the cert is not needed when the tunnel is identified by UUID.
#
# Inert until the credentials file exists, so the tree still evaluates and the
# weekly upgrade does not fail on a machine that has not created the tunnel yet.
{ config, lib, ... }:
let
  credentials = ../secrets/cloudflare-tunnel-fundies.age;
in
lib.mkIf (builtins.pathExists credentials) {
  age.secrets.cloudflare-tunnel-fundies.file = credentials;

  services.cloudflared = {
    enable = true;
    tunnels."d354dbea-f3af-4b02-b16f-4a19fa141f27" = {
      credentialsFile = config.age.secrets.cloudflare-tunnel-fundies.path;
      ingress = {
        "fundies.io" = "http://127.0.0.1:3001";
        "www.fundies.io" = "http://127.0.0.1:3001";
      };
      default = "http_status:404";
    };
  };
}
