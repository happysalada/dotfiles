{ config, ... }:

{
  services.windmill = {
    enable = true;
    baseUrl = "https://windmill.megzari.com";
    database.urlPath = config.age.secrets.WINDMILL_DATABASE_URL_FILE.path;
    logLevel = "debug";
  };

  # only used at creation
  age.secrets = {
    WINDMILL_DATABASE_URL_FILE = {
      file = ../secrets/windmill.database.url.age;
    };
  };

  services.caddy.virtualHosts = {
    "windmill.megzari.com" = {
      extraConfig = ''
        encode gzip
        import security_headers
        reverse_proxy /ws/* 127.0.0.1:${toString config.services.windmill.lspPort}
        reverse_proxy /* 127.0.0.1:${toString config.services.windmill.serverPort}
      '';
    };
  };
}
