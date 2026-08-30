# bee's public SearXNG, behind caddy at searx.megzari.com.
#
# Not modules/searx-local.nix - that one is strix's loopback instance, whose
# clients are firefox and crw and whose threat model is "nobody else can reach
# it". This one is on the open internet, which changes three things: the secret
# key has to be a secret, the limiter has to be on, and searxng has to know its
# own public URL.
{ config, pkgs, ... }:

let
  stateDir = "/var/lib/searx-secret";
  envFile = "${stateDir}/env";

  domain = "searx.megzari.com";
  port = 8889; # strix runs on searxng's default 8888

  # Engines that ship in searxng's own settings.yml and only need switching on.
  # An entry here with no `engine:` key is merged onto the upstream definition
  # by name (searx/settings_loader.py:172); a name upstream has since dropped is
  # NOT an error, it just logs `The "engine" field is missing` on every start
  # and does nothing. 18 such corpses were removed from this list - checked
  # against searxng 2026-08-13, recheck after a nixpkgs bump.
  enabled = [
    "adobe stock"
    "adobe stock video"
    "adobe stock audio"
    "alpine linux packages"
    "apk mirror"
    "annas archive"
    "anaconda"
    "arch linux wiki"
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
    "library genesis"
    "libretranslate"
    "lobste.rs"
    "mwmbl"
    "npm"
    "odysee"
    "openlibrary"
    "openmeteo"
    "openrepos"
    "pub.dev"
    "qwant"
    "qwant news"
    "qwant images"
    "qwant videos"
    "rottentomatoes"
    "searchmysite"
    "discuss.python"
    "pi-hole.community"
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
    "wikimini"
    "lib.rs"
    "sourcehut"
  ];
in
{
  services.searx = {
    enable = true;
    environmentFile = envFile;
    # Only reason valkey is here: server.limiter below needs it.
    redisCreateLocally = true;

    settings = {
      use_default_settings = true;

      general.instance_name = domain;

      server = {
        inherit port;
        # Without this searxng builds absolute links from the Host header it
        # sees from caddy, so /opensearch.xml advertises the wrong origin and
        # the browser "add search engine" button produces a dead engine.
        base_url = "https://${domain}/";

        # envsubst, which searx-init runs over settings.yml, expands $VAR and
        # ${VAR} - not @VAR@. The old value was `@SEARX_SECRET_KEY@`, which was
        # never substituted by anything, so this public instance signed its
        # session cookies with that literal string.
        secret_key = "$SEARX_SECRET_KEY";

        # A public searxng with the limiter off is a free scraping proxy, and
        # the bill lands as CAPTCHAs on every engine above. The packaged
        # limiter.toml defaults already trust 127.0.0.0/8, which is caddy, so
        # X-Forwarded-For gives per-client buckets rather than one bucket for
        # the whole proxy.
        limiter = true;

        # Deliberately not `public_instance = true`: it also forces link_token
        # (a browser must fetch a CSS beacon before a query counts as human,
        # which breaks every non-browser client) and image_proxy (every result
        # thumbnail routed through bee's bandwidth).
      };

      # Upstream's 3s drops slow-but-good engines. Not raised as far as strix's
      # 6s/15s - this instance answers to strangers, so a slow engine holds a
      # public worker rather than just my own browser tab.
      outgoing.request_timeout = 5.0;

      # suspended_times is left at upstream's 15-day/7-day penalties on
      # purpose. Those are sized for exactly this case: a shared instance on a
      # server IP, where sitting out a ban costs nothing per query. strix
      # shortens them because there one bad afternoon takes the engine away
      # from a single user.

      engines = [
        {
          name = "ebay";
          engine = "ebay";
          base_url = "https://www.ebay.ca";
          disabled = false;
        }
        # Deliberately absent: the `meilisearch` entry that used to be here.
        # searx/engines/meilisearch.py defines no `about`, and
        # update_engine_attributes reads engine.about unconditionally
        # (searx/engines/__init__.py:192) *before* it checks `disabled`. So the
        # entry raised AttributeError during webapp init and took the whole
        # service down on start - disabled or not. Re-add once upstream gives
        # that module an `about`, and only with a meilisearch actually running.
      ]
      ++ map (name: { inherit name; disabled = false; }) enabled;
    };
  };

  # searxng will not start without a secret_key, and the agenix secret this
  # used to reference is still commented out below. Generated once into
  # /var/lib instead: survives rebuilds, never enters the store, and unlike the
  # old @SEARX_SECRET_KEY@ it is actually secret. Same pattern as
  # modules/searx-local.nix on strix; the two are never imported together.
  systemd.services.searx-secret = {
    description = "Assemble SearXNG's environment file";
    before = [ "searx-init.service" ];
    requiredBy = [ "searx-init.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "searx-secret";
      StateDirectoryMode = "0700";
      UMask = "0077";
    };
    script = ''
      if [ ! -e ${stateDir}/secret_key ]; then
        ${pkgs.openssl}/bin/openssl rand -hex 32 > ${stateDir}/secret_key
      fi

      echo "SEARX_SECRET_KEY=$(cat ${stateDir}/secret_key)" > ${envFile}
    '';
  };

  # age.secrets = {
  #   SEARX_ENV_FILE = {
  #     file = ../secrets/searx.env.file.age;
  #   };
  # };

  services.caddy.virtualHosts.${domain}.extraConfig = ''
    encode gzip
    import security_headers
    reverse_proxy 127.0.0.1:${toString config.services.searx.settings.server.port}
  '';
}
