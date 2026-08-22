{ config, ... }:

{
  services.brocop = {
    enable = true;
    port = 3002;
    # secrets removed; see git history for the original. re-add when the new deploy recreates them.
    # environmentFile = config.age.secrets.BROCOP_ENV_FILE.path;
    # 
    #
    # only used at creation
    # e.secrets =  {
    # BROCOP_ENV_FILE = {
    #   file = ../secrets/brocop.env.production.age;
    # };
    # 

  services.brocop_admin = {
    enable = true;
    port = 3003;
    # secrets removed; see git history for the original. re-add when the new deploy recreates them.
    # environmentFile = config.age.secrets.BROCOP_ADMIN_ENV_FILE.path;
    # 
    #
    # only used at creation
    # e.secrets =  {
    # BROCOP_ADMIN_ENV_FILE = {
    #   file = ../secrets/brocop_admin.env.production.age;
    # };
    # 

  services.sweif = {
    enable = true;
    port = 3005;
    # secrets removed; see git history for the original. re-add when the new deploy recreates them.
    # environmentFile = config.age.secrets.BROCOP_ENV_FILE.path;
  };
}
