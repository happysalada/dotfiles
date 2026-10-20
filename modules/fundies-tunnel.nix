# fundies.io through a locally managed Cloudflare tunnel. The credentials JSON
# is the one `cloudflared tunnel create fundies` wrote, encrypted by agenix; the
# ingress is local because the tunnel is local. No Caddy and no open ports.
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
    tunnels.fundies = {
      credentialsFile = config.age.secrets.cloudflare-tunnel-fundies.path;
      ingress = {
        "fundies.io" = "http://127.0.0.1:3001";
        "www.fundies.io" = "http://127.0.0.1:3001";
      };
      default = "http_status:404";
    };
  };
}
