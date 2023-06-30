{ config, ... }:

{
  services.ntfy-sh = {
    enable = true;
    settings = {
      base-url = "http://ntfy.sassy.technology";
      behind-proxy = true;
    };
  };

  services.caddy.virtualHosts."ntfy.sassy.technology" = {
    # config found at https://docs.ntfy.sh/config/
    extraConfig = ''
      reverse_proxy ${config.services.ntfy-sh.settings.listen-http}

      # Redirect HTTP to HTTPS, but only for GET topic addresses, since we want
      # it to work with curl without the annoying https:// prefix
      @httpget {
          protocol http
          method GET
          path_regexp ^/([-_a-z0-9]{0,64}$|docs/|static/)
      }
      redir @httpget https://{host}{uri}
    '';
  };
}