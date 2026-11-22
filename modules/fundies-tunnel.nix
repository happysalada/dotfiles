# fundies.io, Komga at comic.megzari.com (modules/komga.nix) and OpenPanel
# (modules/openpanel-local.nix), through a locally managed Cloudflare tunnel. The credentials JSON
# is the one `cloudflared tunnel create fundies` wrote, encrypted by agenix; the
# ingress is local because the tunnel is local. The hop in front of it is the
# fundies module's Caddy on 127.0.0.1:8080, so no port is opened.
#
# The tunnel is keyed by its UUID, not by the name `fundies`: cloudflared needs
# cert.pem to resolve a name, and the generated service has no $HOME to find it.
# Its own help says the cert is not needed when the tunnel is identified by UUID.
#
# Inert until the credentials file exists, so the tree still evaluates and the
# weekly upgrade does not fail on a machine that has not created the tunnel yet.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  credentials = ../secrets/cloudflare-tunnel-fundies.age;
in
lib.mkIf (builtins.pathExists credentials) {
  age.secrets.cloudflare-tunnel-fundies.file = credentials;

  # DNS can be unavailable during a switch; keep retrying without a restart burst.
  systemd.services."cloudflared-tunnel-d354dbea-f3af-4b02-b16f-4a19fa141f27" = {
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig.RestartSec = "10s";
  };

  services.cloudflared = {
    enable = true;
    tunnels."d354dbea-f3af-4b02-b16f-4a19fa141f27" = {
      credentialsFile = config.age.secrets.cloudflare-tunnel-fundies.path;
      ingress = {
        "fundies.io" = "http://127.0.0.1:8080";
        "www.fundies.io" = "http://127.0.0.1:8080";
        "comic.megzari.com" = "http://127.0.0.1:${toString config.services.komga.settings.server.port}";
      }
      // lib.optionalAttrs config.services.openpanel.enable {
        ${config.services.openpanel.domain} =
          "http://127.0.0.1:${toString config.services.openpanel.dashboardPort}";
        ${config.services.openpanel.apiDomain} =
          "http://127.0.0.1:${toString config.services.openpanel.apiPort}";
      };
      default = "http_status:404";
    };
  };

  # Crawlers across every locale drove fundies-server to 500% CPU and pages past 30s. People are
  # never matched; the crawlers share one budget and get a 429 with Retry-After beyond it.
  services.caddy.virtualHosts."http://fundies.io:8080, http://www.fundies.io:8080".extraConfig = ''
    rate_limit {
      zone crawlers {
        match {
          header_regexp User-Agent (?i)(bot|crawl|spider|slurp|scrape|python-requests|go-http|curl|wget|headless|bytespider|ccbot|semrush|ahrefs)
          not path /_app/* /health /robots.txt /sitemap*
        }
        key static
        events 5
        window 1s
      }
    }
  '';

  # The directive comes from a plugin, so it needs an order and a Caddy built with it.
  services.caddy.globalConfig = "order rate_limit before basicauth";
  services.caddy.package = pkgs.caddy.withPlugins {
    plugins = [ "github.com/mholt/caddy-ratelimit@v0.1.1-0.20260612195517-5625512f24f6" ];
    hash = "sha256-mfY+ldXq435FoilK6fdnwk7IXWvfNi74VRAs0FtCoAE=";
  };
}
