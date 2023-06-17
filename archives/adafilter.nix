{ config, lib, pkgs, ... }:

{
  services.adafilter = {
    enable = true;
    openaiKeyPath = config.age.secrets.OPENAI_KEY.path;
    twitterBearerTokenPath = config.age.secrets.TWITTER_BEARER_TOKEN.path;
    surrealdbUsernamePath = config.age.secrets.SURREALDB_USERNAME.path;
    surrealdbPasswordPath = config.age.secrets.SURREALDB_PASSWORD.path;
    surrealdbSeed = ''
      DEFINE TABLE tweets SCHEMALESS  
        PERMISSIONS
          FOR select, update FULL,
          FOR create NONE
      ;
      DEFINE TABLE authors SCHEMALESS  
        PERMISSIONS
          FOR select FULL,
          FOR create, update NONE
      ;
      DEFINE TABLE user SCHEMALESS
         PERMISSIONS 
           FOR select, update, delete WHERE id = $auth.id, 
           FOR create NONE;
      DEFINE SCOPE end_user SESSION 24h
          SIGNUP ( CREATE user SET email = $email, pass = crypto::argon2::generate($pass) )
          SIGNIN ( SELECT * FROM user WHERE email = $email AND crypto::argon2::compare(pass, $pass) )
      ;
    '';

    settings = {
      surrealdb = {
        namespace = "test";
        database = "adafilter";
        host = "127.0.0.1:${toString config.services.surrealdb.port}";
      };
      http_port = 8787;
    };
  };

  age.secrets =  {
    OPENAI_KEY = {
      file = ../secrets/openai.key.age;
    };
    TWITTER_BEARER_TOKEN = {
      file = ../secrets/twitter.bearer_token.age;
    };
  };

  services.caddy.virtualHosts."adafilter.sassy.technology" = {
    extraConfig = ''
      reverse_proxy 127.0.0.1:${toString config.services.adafilter.settings.http_port}
    '';
  };
}


