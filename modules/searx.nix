{ config, ... }:

{
  services.searx = {
    enable = true;
    environmentFile = config.age.secrets.SEARX_ENV_FILE.path;
    settings = {
      use_default_settings = true;
      server.secret_key = "@SEARX_SECRET_KEY@";
      engines = [
        {
          engine = "apkmirror";
          disabled = false;
        }
      ];
    };
  };

  age.secrets = {
    SEARX_ENV_FILE = {
      file = ../secrets/searx.env.file.age;
    };
  };

  services.caddy.virtualHosts = {
    "searx.megzari.com" = {
      extraConfig = ''
        import security_headers
        reverse_proxy 127.0.0.1:${toString config.services.searx.settings.server.port}
      '';
    };
  };
}
