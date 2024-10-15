{ config, ... }:

{
  services.caddy.virtualHosts = {
    "vaultwarden.megzari.com" = {
      extraConfig = ''
        import security_headers
        reverse_proxy 127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}
      '';
    };
  };

  services.vaultwarden = {
    enable = true;
    dbBackend = "sqlite";
    config = {
      DOMAIN = "https://vaultwarden.megzari.com";
      SIGNUPS_ALLOWED = false;
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;

      ROCKET_LOG = "critical";

      SMTP_HOST = "smtp.sendgrid.net";
      SMTP_FROM = "raphael@megzari.com";
      SMTP_PORT = 465;
      SMTP_SECURITY = "force_tls";
      SMTP_USERNAME = "apikey";
      SMTP_AUTH_MECHANISM = "Login";
    };
    environmentFile = config.age.secrets.VAULTWARDEN_ENV.path;
  };
  age.secrets = {
    VAULTWARDEN_ENV = {
      file = ../secrets/vaultwarden.env.age;
    };
  };

}
