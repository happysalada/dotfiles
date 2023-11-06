{ ... }:

{
  services.surrealdb = {
    enable = true;
    dbPath = "file:///var/lib/surrealdb";
    # TODO enable "--strict" at some point
    extraFlags = [ "--auth" "--allow-all" ];
  };

  # only used at creation
  # age.secrets =  {
  #   SURREALDB_USERNAME = {
  #     file = ../secrets/surreal.username.age;
  #   };
  #   SURREALDB_PASSWORD = {
  #     file = ../secrets/surreal.password.age;
  #   };
  # };
}
