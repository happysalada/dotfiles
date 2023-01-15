{ config, lib, pkgs, ... }:

{
  services.macrodata = {
    enable = true;
    surrealdbUsernamePath = config.age.secrets.SURREALDB_USERNAME.path;
    surrealdbPasswordPath = config.age.secrets.SURREALDB_PASSWORD.path;
    surrealdbSeed = ''
      DEFINE TABLE datapoints SCHEMALESS  
        PERMISSIONS
          FOR select FULL,
          FOR create, update WHERE $scope = 'end_user'
      ;
      DEFINE TABLE dataseries SCHEMALESS  
        PERMISSIONS
          FOR select FULL,
          FOR create, update WHERE $scope = 'end_user'
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
        database = "test";
        host = "127.0.0.1:${toString config.services.surrealdb.port}";
      };
    };
  };
}
