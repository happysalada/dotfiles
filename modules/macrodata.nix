{ config, lib, pkgs, ... }:

{
  services.macrodata = {
    enable = true;
    surrealdbUsernamePath = config.age.secrets.SURREALDB_USERNAME.path;
    surrealdbPasswordPath = config.age.secrets.SURREALDB_PASSWORD.path;
    settings = {
      surrealdb = {
        namespace = "test";
        database = "test";
        host = "127.0.0.1:${toString config.services.surrealdb.port}";
      };
    };
  };
}
