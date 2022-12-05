{ config, lib, pkgs, ... }:

{
  services.macrodata = {
    enable = true;
    influxdbTokenPath = config.age.secrets.INFLUXDB_TOKEN.path;
    settings = {
      influxdb = {
        host = "http://localhost:8086";
        org = "sassy tech";
        bucket = "sassy_initial";
      };
    };
  };
  age.secrets =  {
    INFLUXDB_TOKEN = {
      file = ../secrets/influxdb.token.age;
    };
  };
}
