{ ... }:

{
  services.designhub = {
    enable = true;
    port = 3004;
    # environmentFile = config.age.secrets.LEAD_ENV_FILE.path;
  };
}
