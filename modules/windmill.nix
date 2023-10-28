{ config }:

{
  services.windmill = {
    enable = true;
    baseUrl = "https://windmill.sassy.technology";
    databaseUrlPath = config.age.secrets.DATABASE_URL_FILE.path;
  };

  # only used at creation
  age.secrets =  {
    DATABASE_URL_FILE = {
      file = ../secrets/database.url.age;
    };
  };
}
