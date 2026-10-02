# A loopback SearXNG for this machine only - not modules/searx.nix, bee's
# public instance. Clients: firefox's default search and crw, whose whole
# search feature is a SearXNG proxy - with no backend URL `crw search` answers
# `search_disabled` and crw-mcp drops the `crw_search` tool
# (crates/crw-mcp/src/main.rs:113).
#
# searx/settings_loader.py shapes everything below: `engines` merges per entry
# keyed on `name` (172), leaving the other ~250 at upstream defaults, while
# `plugins`/`categories_as_tabs` are REPLACED wholesale (138-144).
{ pkgs, lib, ... }:
let
  port = 8888; # searxng's own default; bee runs on 8889

  stateDir = "/var/lib/searx-secret";
  envFile = "${stateDir}/env";

  # Kagi is metered (~$15-25 per 1000 searches), so it stays out of the default
  # fan-out. To enable: put the key in `keyFile`, then flip `enable`:
  #
  #     sudo install -m600 /dev/stdin /var/lib/searx-secret/kagi.env <<< \
  #       'KAGI_API_KEY=<key>'
  #
  # `keyFile` is a STRING, not a nix path literal - a path would copy the key
  # into the world-readable nix store on the next eval.
  #
  # Off means the engine is not defined at all. searx-secret refuses to start
  # rather than pass searxng an empty api_key, so a bad path is a clear error
  # at `systemctl status searx-secret`, not a silent 401 per query.
  kagi = {
    enable = false;
    keyFile = "${stateDir}/kagi.env";
  };
in
{
  services.searx = {
    enable = true;
    environmentFile = envFile;

    # No redisCreateLocally: valkey would only back `server.limiter`, off below.
    settings = {
      use_default_settings = true;

      general = {
        instance_name = "strix";
        # Powers /stats - the only way to see which engine started returning
        # CAPTCHAs when results quietly get worse.
        enable_metrics = true;
      };

      search = {
        # SearXNG answers `?format=json` with 403 unless json is listed here,
        # and that endpoint is the point of the instance. `html` stays so a
        # query can be run by hand to see what an engine actually returned.
        formats = [
          "html"
          "json"
        ];

        # Every query leaves from one residential IP, so engines rate-limit and
        # CAPTCHA us far harder than a shared public instance. The upstream
        # penalties (15 days for a Cloudflare CAPTCHA, 7 for a reCAPTCHA) fit
        # that shared case, and the suspension is per engine, not per IP, so
        # moving networks does not clear it. An hour is long enough to stop a
        # hot loop and short enough to self-heal.
        suspended_times = {
          cf_SearxEngineCaptcha = 3600;
          recaptcha_SearxEngineCaptcha = 3600;
          cf_SearxEngineAccessDenied = 3600;
        };
      };

      server = {
        inherit port;
        bind_address = "127.0.0.1";
        # Substituted into settings.yml by searx-init, from environmentFile.
        secret_key = "$SEARX_SECRET_KEY";
        # Needs valkey, and would rate-limit nobody but us.
        limiter = false;
      };

      # An agent fans a query out to every engine and waits for the slowest; a
      # 3s timeout drops engines that were about to answer, and the ones it
      # drops are the good slow ones (scholar, crossref), not the fast thin ones.
      outgoing = {
        request_timeout = 6.0;
        max_request_timeout = 15.0;
      };

      ui = {
        theme_args.simple_style = "dark";
        hotkeys = "vim";
        # Full URLs, not the breadcrumb prettifier: a link handed to an agent
        # should be readable.
        url_formatting = "full";
      };

      # REPLACES the upstream block, so the seven defaults are restated. The
      # last two are the additions.
      plugins = {
        "searx.plugins.calculator.SXNGPlugin".active = true;
        "searx.plugins.hash_plugin.SXNGPlugin".active = true;
        "searx.plugins.self_info.SXNGPlugin".active = true;
        "searx.plugins.unit_converter.SXNGPlugin".active = true;
        "searx.plugins.ahmia_filter.SXNGPlugin".active = true;
        "searx.plugins.hostnames.SXNGPlugin".active = true;
        "searx.plugins.time_zone.SXNGPlugin".active = true;
        "searx.plugins.infinite_scroll.SXNGPlugin".active = false;

        # Strips utm_*/fbclid/... off result URLs - Firefox only strips what it
        # navigates to, not links copied out of a JSON response into a prompt.
        "searx.plugins.tracker_url_remover.SXNGPlugin".active = true;

        # Sends a DOI to oadoi.org, which redirects to a legal open-access copy
        # when one exists; without it crossref hands back a paywall.
        "searx.plugins.oa_doi_rewrite.SXNGPlugin".active = true;
      };

      # Config for the hostnames plugin: only priority nudges, no `remove:` -
      # a dropped result is invisible, a result ranked 20th is not.
      hostnames.low_priority = [
        "(.*\\.)?w3schools\\.com$"
        "(.*\\.)?geeksforgeeks\\.org$"
        "(.*\\.)?pinterest(\\..*)?$"
      ];

      # Merged per entry by name: `disabled = false` switches on one that ships
      # off; the ~250 unnamed keep their upstream default. Measured from this
      # IP, 2026-08-27/28:
      #
      #   google cse   20 rows   answers every time
      #   duckduckgo   10 rows   good when it answers, CAPTCHAs under load
      #   qwant        10 rows   same
      #   brave         0 rows   "too many requests" after a query or two
      #   startpage     0 rows   CAPTCHA on contact, then out for an hour
      #   mojeek        0 rows   "access denied" - see below
      #
      # On a bad minute only google cse answers, and results are still usable:
      # the fan-out is a redundancy pool, not a quality multiplier, and often
      # one engine deep. brave and startpage stay on because a suspended engine
      # costs nothing per query and both do come back.
      #
      # Indie engines measured and rejected: mwmbl is reliable but imprecise;
      # marginalia, stract, right dao, presearch, seekr and wiby returned
      # nothing for an ordinary technical query. All are one `!bang` away; none
      # earns a slot in every query's fan-out.
      engines = [
        # --- general web ----------------------------------------------------
        {
          name = "qwant";
          disabled = false;
        }
        # Deliberately absent: `google`, which ships `inactive: true` upstream
        # and CAPTCHAs a single residential IP on contact - `google cse` and
        # `google scholar` are separate backends and both work.
        #
        # Also absent: `mojeek`, the obvious independent-index pick, because in
        # this searxng build it answers 200 with zero parseable results for any
        # query, nothing in the log. mojeek.com is up, so the engine module is
        # stale - re-test after a nixpkgs bump.

        # --- research -------------------------------------------------------
        # crw's `categories: ["research"]` fans out to arxiv, crossref, google
        # scholar and semantic scholar. Only crossref ships disabled.
        {
          name = "crossref";
          disabled = false;
        }
        {
          # Times out against the 6s global above (measured), so it gets its own
          # budget rather than raising the global and slowing every browser
          # search; upstream does the same for crossref (`timeout: 30`).
          name = "semantic scholar";
          timeout = 12.0;
        }
      ]
      ++ lib.optional kagi.enable {
        # Paid and metered, so `disabled = true`: it never joins the default
        # fan-out and answers only when named - `!kg <query>` in the browser,
        # `engines=kagi` on the JSON API.
        name = "kagi";
        engine = "kagi";
        shortcut = "kg";
        categories = [
          "general"
          "web"
        ];
        kagi_categ = "search";
        api_key = "$KAGI_API_KEY";
        disabled = true;
      };
    };
  };

  # SearXNG will not start without a secret_key, and a literal one would be a
  # secret committed here. Generated once into /var/lib instead - it survives
  # rebuilds, and on an instance nothing else can reach it only signs a
  # preferences cookie.
  #
  # The env file is rebuilt from parts each start so flipping `kagi.enable`
  # takes effect on a rebuild without regenerating the stored secret_key.
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
      ${lib.optionalString kagi.enable ''
        if [ ! -e ${kagi.keyFile} ]; then
          echo "kagi is enabled but ${kagi.keyFile} does not exist" >&2
          exit 1
        fi
        cat ${kagi.keyFile} >> ${envFile}
      ''}
    '';
  };
}
