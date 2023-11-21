{ config, ... }:

{
  services.lead = {
    enable = true;
    port = 3003;
    environmentFile = config.age.secrets.LEAD_ENV_FILE.path;
  };

  # only used at creation
  age.secrets =  {
    LEAD_ENV_FILE = {
      file = ../secrets/lead.env.production.age;
    };
  };
}
