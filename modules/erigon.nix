{ config, lib, pkgs, ... }:

{
  services.erigon = {
    enable = true;
    secretJwtPath = config.age.secrets.ERIGON_JWT.path;
    settings = {
      "private.api.addr" = "localhost:9091";
      "authrpc.vhosts" = "*";
      externalcl = true;
    };
  };
  age.secrets =  {
    ERIGON_JWT = {
      file = ../secrets/erigon.jwt.age;
    };
  };
}
