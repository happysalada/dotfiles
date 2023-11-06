{ config, ... }:

{
  services.brocop = {
    enable = true;
    port = 3001;
    environmentFile = config.age.secrets.BROCOP_ENV_FILE.path;
  };

  # only used at creation
  age.secrets =  {
    BROCOP_ENV_FILE = {
      file = ../secrets/brocop.env.production.age;
    };
  };
}
