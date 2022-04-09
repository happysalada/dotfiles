{ config, lib, pkgs, ... }:

{
  
  age.secrets =  {
    SECRET_KEY_BASE = {
      file = ./secrets/plausible.secretKeybase.age;
    };
    ADMIN_USER_PWD = {
      file = ./secrets/plausible.passwordFile.age;
    };
    RELEASE_COOKIE = {
      file = ./secrets/plausible.releaseCookie.age;
    };
  };
  services.plausible = {
    enable = true;
    adminUser = {
      activate = true;
      email = "raphael@megzari.com";
      passwordFile = "/run/agenix/ADMIN_USER_PWD";
    };
    server = {
      baseUrl = "https://plausible.union.rocks";
      secretKeybaseFile = "/run/agenix/SECRET_KEY_BASE";
    };
    releaseCookiePath = "/run/agenix/RELEASE_COOKIE";
  };
  
  services.caddy.virtualHosts."plausible.union.rocks" = {
    extraConfig = ''
      reverse_proxy 127.0.0.1:${toString config.services.plausible.server.port}
    '';
  };
}