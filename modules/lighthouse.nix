{ config, lib, pkgs, ... }:

{
  services.lighthouse = {
    beacon = {
      enable = true;
      http.enable = true;
      execution.address = "localhost";
      execution.jwtPath = config.age.secrets.ERIGON_JWT.path;
      openFirewall = true;
      disableDepositContractSync = true;
    };
    validator = {
      enable = false;
    };
  };
}