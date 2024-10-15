{ config, ... }:
{
  services.surrealdb = {
    # enable = true;
    dbPath = "file:///var/lib/surrealdb";
    # TODO enable "--strict" at some point
    extraFlags = [
      "--auth"
      "--allow-all"
    ];
  };

  services.caddy.virtualHosts = {

    "surrealdb.megzari.com" = {
      extraConfig = ''
        import security_headers
        reverse_proxy 127.0.0.1:${toString config.services.surrealdb.port}
      '';
    };
  };

  # only used at creation
  # age.secrets =  {
  #   SURREALDB_USERNAME = {
  #     file = ../secrets/surreal.username.age;
  #   };
  #   SURREALDB_PASSWORD = {
  #     file = ../secrets/surreal.password.age;
  #   };
  # };
}
