{ config, lib, pkgs, ... }:

{
  services.erigon = {
    enable = true;
    secretJwtPath = config.age.secrets.ERIGON_JWT.path;
    settings = {
      "private.api.addr" = "localhost:9091";
      "authrpc.vhosts" = "*";
      externalcl = true;
      "database.verbosity" = 3;
    };
  };
  age.secrets =  {
    ERIGON_JWT = {
      file = ../secrets/erigon.jwt.age;
    };
  };
}
