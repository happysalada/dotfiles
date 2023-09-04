{ config, ... }:

{
  services.qdrant = {
    enable = true;
    settings = {
      hsnw_index = {
        on_disk = true;
      };
    };
  };
}
