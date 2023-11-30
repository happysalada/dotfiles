{ config, ... }:

{
  services.windmill = {
    enable = true;
    baseUrl = "https://windmill.sassy.technology";
    database.urlPath = config.age.secrets.WINDMILL_DATABASE_URL_FILE.path;
    logLevel = "debug";
  };

  # only used at creation
  age.secrets =  {
    WINDMILL_DATABASE_URL_FILE = {
      file = ../secrets/windmill.database.url.age;
    };
  };
}
