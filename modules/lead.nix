{ config, ... }:

{
  services.lead = {
    enable = true;
    port = 3003;
    # secrets removed; see git history for the original. re-add when the new deploy recreates them.
    # environmentFile = config.age.secrets.LEAD_ENV_FILE.path;
  };

  # # only used at creation
  # age.secrets =  {
  #   LEAD_ENV_FILE = {
  #     file = ../secrets/lead.env.production.age;
  #   };
  # };
}
