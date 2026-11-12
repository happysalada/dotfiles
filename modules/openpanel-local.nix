# OpenPanel analytics for the fundies sites: the dashboard at
# openpanel.megzari.com and the api the tracking script posts to at
# openpanel-api.megzari.com, both published by the Cloudflare tunnel
# (modules/fundies-tunnel.nix) with a DNS route each:
#   cloudflared tunnel route dns d354dbea-f3af-4b02-b16f-4a19fa141f27 openpanel.megzari.com
#   cloudflared tunnel route dns d354dbea-f3af-4b02-b16f-4a19fa141f27 openpanel-api.megzari.com
# The hostnames sit one level under megzari.com, which Cloudflare's free
# certificate covers.
#
# The secrets file is KEY=value lines, written with `agenix -e
# openpanel.env.age` from secrets/: COOKIE_SECRET (`openssl rand -hex 16`),
# AUTH_SECRET and ENCRYPTION_KEY (`openssl rand -hex 32`). Back up the
# ENCRYPTION_KEY: it encrypts the stored integration credentials.
#
# Inert until that file exists, so the tree still evaluates before it is made.
# Registration is closed (upstream's default). To add the next account, either
# invite them from the dashboard or set settings.ALLOW_REGISTRATION = "true"
# for one deploy.
{ config, lib, ... }:
let
  secrets = ../secrets/openpanel.env.age;
in
{
  imports = [ ./openpanel.nix ];

  config = lib.mkIf (builtins.pathExists secrets) {
    age.secrets.openpanel.file = secrets;

    services.openpanel = {
      enable = true;
      domain = "openpanel.megzari.com";
      apiDomain = "openpanel-api.megzari.com";
      environmentFile = config.age.secrets.openpanel.path;
    };
  };
}
