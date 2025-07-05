{ config, pkgs, ... }:
{
  services = {
    paperless = {
      enable = true;
      passwordFile = config.age.secrets.PAPERLESS_PASSWORD.path;
      database.createLocally = true;
      configureTika = true;
      settings = {
        PAPERLESS_OCR_LANGUAGE = "eng+fra";
        PAPERLESS_CONSUMER_IGNORE_PATTERN = [
          ".DS_STORE/*"
          "desktop.ini"
        ];
        PAPERLESS_OCR_USER_ARGS = {
          optimize = 1;
          pdfa_image_compression = "lossless";
        };
        PAPERLESS_ENABLE_NLTK = true;
      };
    };
    gotenberg.port = 3032;
    caddy.virtualHosts = {
      "paperless.megzari.com" = {
        extraConfig = ''
          encode gzip
          import security_headers
          reverse_proxy ${config.services.paperless.address}:${toString config.services.paperless.port}
        '';
      };
    };
  };
  environment.systemPackages = with pkgs; [
    ghostscript
    qpdf
    tesseract5
    unpaper
    libxml2
    poppler_utils
    imagemagick
  ];
}
