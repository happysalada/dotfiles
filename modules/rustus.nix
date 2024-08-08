{ config, ... }:

{
  services.rustus = {
    enable = true;
    max_body_size = "100000000"; # 100 mb
    # cors = ["sweif.com", "*.sweif.com", "immutablecoin.com", "*.immutablecoin.com"];
    storage = {
      type = "hybrid-s3";
      s3_access_key_file = config.age.secrets.R2_ACCESS_KEY.path;
      s3_secret_key_file = config.age.secrets.R2_SECRET_KEY.path;
      s3_bucket = "kyc";
      s3_url = "https://dc51d6e4b63ad20fb5b269f3685d7683.r2.cloudflarestorage.com";
    };
  };

  age.secrets =  {
    R2_ACCESS_KEY = {
      file = ../secrets/rustus.r2.access.key.age;
    };
    R2_SECRET_KEY = {
      file = ../secrets/rustus.r2.secret.key.age;
    };
  };

  services.caddy.virtualHosts."rustus.megzari.com" = {
    extraConfig = ''
      reverse_proxy 127.0.0.1:1081
    '';
  };
}
