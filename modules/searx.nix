{ config, ... }:

{
  services.searx = {
    enable = true;
    environmentFile = config.age.secrets.SEARX_ENV_FILE.path;
    settings = {
      use_default_settings = true;
      server = {
        port = 8889;
        secret_key = "@SEARX_SECRET_KEY@";
      };
      engines =
        map
          (x: {
            name = x;
            disabled = false;
          })
          [
            "apk mirror"
            "annas archive"
            "anaconda"
            "media.ccc.de"
            "crossref"
            "crowdview"
            "yep"
            "yep images"
            "yep news"
            "destatis"
            "ddg definitions"
            "encyclosearch"
            "erowid"
            "duckduckgo images"
            "duckduckgo news"
            "tineye"
            "fdroid"
            "free software directory"
            "goodreads"
            "habrahabr"
            "hackernews"
            "crates.io"
            "invidious"
            "library genesis"
            "libretranslate"
            "odysee"
            "openlibrary"
            "openmeteo"
            "openrepos"
            "presearch"
            "presearch images"
            "presearch videos"
            "presearch news"
            "reddit"
            "rottentomatoes"
            "searchcode code"
            "semantic scholar"
            "tokyotoshokan"
            "tmdb"
            "yahoo"
            "yahoo news"
            "wikibooks"
            "wikiquote"
            "wikisource"
            "wikispecies"
            "wikiversity"
            "wikivoyage"
            "wolframalpha"
            "1337x"
            "mojeek"
            "mojeek images"
            "mojeek news"
            "moviepilot"
            "peertube"
            "yacy"
            "yacy images"
            "rumble"
            "seekr news"
            "seekr images"
            "seekr videos"
            "wikimini"
            "yummly"
            "sourcehut"
          ];
    };
  };

  age.secrets = {
    SEARX_ENV_FILE = {
      file = ../secrets/searx.env.file.age;
    };
  };

  services.caddy.virtualHosts = {
    "searx.megzari.com" = {
      extraConfig = ''
        import security_headers
        reverse_proxy 127.0.0.1:${toString config.services.searx.settings.server.port}
      '';
    };
  };
}
