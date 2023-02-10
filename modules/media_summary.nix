{ config, lib, pkgs, ... }:

{
  services.mediaSummary = {
    enable = true;
    gcloudSecretPath = config.age.secrets.GCLOUD_SECRET.path;
    openaiKeyPath = config.age.secrets.OPENAI_KEY.path;
    surrealdbUsernamePath = config.age.secrets.SURREALDB_USERNAME.path;
    surrealdbPasswordPath = config.age.secrets.SURREALDB_PASSWORD.path;
    surrealdbSeed = ''
      DEFINE TABLE media SCHEMALESS  
      PERMISSIONS
        FOR select, update, delete WHERE user_email = $auth.email, 
        FOR create NONE;
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
        database = "media_summary";
        host = "127.0.0.1:${toString config.services.surrealdb.port}";
      };
      http_port = 8787;
      gcloud_bucket = "audio_test_transcription";
    };
  };

  age.secrets =  {
    GCLOUD_SECRET = {
      file = ../secrets/gcloud_secrets.env.age;
    };
    OPENAI_KEY = {
      file = ../secrets/openai.key.age;
    };
  };

  services.caddy.virtualHosts."summary.sassy.technology" = {
    extraConfig = ''
      reverse_proxy 127.0.0.1:${toString config.services.mediaSummary.settings.http_port}
    '';
  };
}
