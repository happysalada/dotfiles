{ config, lib, pkgs, ... }:

{
  services.tremor-rs = {
    enable = true;
    troyFileList = [ "${../tremor-rs/main.troy}" ];
    tremorLibDir = "${../tremor-rs}";
    loggerSettings =  {
      appenders.stdout.kind = "console";
      root = {
        level = "warn";
        appenders = [ "stdout" ];
      };
      loggers = {
        tremor_runtime = {
          level = "debug";
          appenders = [ "stdout" ];
          additive = false;
        };
        tremor = {
          level = "debug";
          appenders = [ "stdout" ];
          additive = false;
        };
      };
    };
  };
}
