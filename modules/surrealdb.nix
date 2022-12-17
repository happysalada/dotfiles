{ config, lib, pkgs, ... }:

{
  services.surrealdb = {
    enable = true;
    userNamePath = config.age.secrets.SURREALDB_USERNAME.path;
    passwordPath = config.age.secrets.SURREALDB_PASSWORD.path;
  };

  age.secrets =  {
    SURREALDB_USERNAME = {
      file = ../secrets/surreal.username.age;
    };
    SURREALDB_PASSWORD = {
      file = ../secrets/surreal.password.age;
    };
  };

  services.caddy.virtualHosts."surrealdb.sassy.technology" = {
    extraConfig = ''
      reverse_proxy 127.0.0.1:${toString config.services.surrealdb.port}
    '';
  };
}
