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

  services.brocop_admin = {
    enable = true;
    port = 3002;
    environmentFile = config.age.secrets.BROCOP_ADMIN_ENV_FILE.path;
  };

  # only used at creation
  age.secrets =  {
    BROCOP_ADMIN_ENV_FILE = {
      file = ../secrets/brocop_admin.env.production.age;
    };
  };

  services.sweif = {
    enable = true;
    port = 3005;
    environmentFile = config.age.secrets.BROCOP_ENV_FILE.path;
  };
}
