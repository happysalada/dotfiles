{ config, ... }:

{
  services.surrealdb = {
    enable = true;
    userNamePath = config.age.secrets.SURREALDB_USERNAME.path;
    passwordPath = config.age.secrets.SURREALDB_PASSWORD.path;
    dbPath = "file:///var/lib/surrealdb";
  };

  age.secrets =  {
    SURREALDB_USERNAME = {
      file = ../secrets/surreal.username.age;
    };
    SURREALDB_PASSWORD = {
      file = ../secrets/surreal.password.age;
    };
  };

}
