{ config, ... }:

{
  services.searx = {
    enable = true;
    environmentFile = config.age.secrets.SEARX_ENV_FILE.path;
    redisCreateLocally = true;
    settings = {
      use_default_settings = true;
      server = {
        port = 8889;
        secret_key = "@SEARX_SECRET_KEY@";
      };
      engines =
        [
          {
            name = "meilisearch";
            engine = "meilisearch";
            shortcut = "mes";
            base_url = "http://localhost:7700";
            index = "rag-search-engine";
            enable_http = true;
            disabled = true;
          }
          {
            name = "ebay";
            disabled = false;
            base_url = "https://www.ebay.ca";
            engine = "ebay";
          }
        ]
        ++ (map
          (x: {
            name = x;
            disabled = false;
          })
          [
            "adobe stock"
            "adobe stock video"
            "adobe stock audio"
            "alpine linux packages"
            "apk mirror"
            "annas archive"
            "anaconda"
            "arch linux wiki"
            "ask"
            "bilibili"
            "bing"
            "bing images"
            "bing news"
            "bing videos"
            "bpb"
            "openverse"
            "media.ccc.de"
            "crossref"
            "crowdview"
            "chefkoch"
            "currency"
            "yep"
            "yep images"
            "yep news"
            "curlie"
            "destatis"
            "ddg definitions"
            "docker hub"
            "encyclosearch"
            "erowid"
            "duckduckgo images"
            "duckduckgo news"
            "duckduckgo videos"
            "duckduckgo weather"
            "apple maps"
            "emojipedia"
            "etymonline"
            "tineye"
            "1x"
            "fdroid"
            "findthatmeme"
            "free software directory"
            "fyyd"
            "goodreads"
            "gitlab"
            "codeberg"
            "gitea.com"
            "habrahabr"
            "hackernews"
            "crates.io"
            "material icons"
            "imdb"
            "imgur"
            "ina"
            "jisho"
            "invidious"
            "library genesis"
            "libretranslate"
            "lobste.rs"
            "mwmbl"
            "npm"
            "odysee"
            "openlibrary"
            "openmeteo"
            "openrepos"
            "presearch"
            "presearch images"
            "presearch videos"
            "presearch news"
            "pub.dev"
            "qwant"
            "qwant news"
            "qwant images"
            "qwant videos"
            "reddit"
            "right dao"
            "rottentomatoes"
            "searchmysite"
            "discuss.python"
            "pi-hole.community"
            "searchcode code"
            "semantic scholar"
            "startpage"
            "tokyotoshokan"
            "tmdb"
            "yandex"
            "yandex images"
            "yandex music"
            "yahoo"
            "yahoo news"
            "youtube"
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
            "naver"
            "peertube"
            "mediathekviewweb"
            "yacy"
            "yacy images"
            "rumble"
            "seekr news"
            "seekr images"
            "seekr videos"
            "wikimini"
            "yummly"
            "stract"
            "lib.rs"
            "sourcehut"
            "goo"
          ]
        );
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
        encode gzip
        import security_headers
        reverse_proxy 127.0.0.1:${toString config.services.searx.settings.server.port}
      '';
    };
  };
}
