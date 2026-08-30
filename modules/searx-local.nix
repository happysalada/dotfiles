# A SearXNG bound to loopback, for this machine only.
#
# Not modules/searx.nix - that one is bee's public instance: caddy vhost, a
# ~150-engine list pasted in by hand, and a redis-backed limiter. None of it
# applies to a single-user laptop whose only clients are firefox and crw.
#
# Two consumers:
#   - firefox's default search engine (homes/programs/firefox.nix)
#   - crw, whose entire search feature is a SearXNG proxy. With no backend URL
#     `crw search` answers `search_disabled` and crw-mcp does not even
#     advertise the `crw_search` tool (crates/crw-mcp/src/main.rs:113), which
#     is why the agents currently have no web search at all.
#
# Two merge rules from searx/settings_loader.py decide the shape of everything
# below, and they are NOT the same rule:
#   - `engines` merges per entry, keyed on `name` (line 172). Naming one engine
#     leaves the other ~250 at their upstream defaults.
#   - `plugins` and `categories_as_tabs` are REPLACED wholesale (lines 138-144).
#     Setting either means restating every entry, including the defaults.
{ pkgs, lib, ... }:
let
  port = 8888; # searxng's own default; bee runs on 8889

  stateDir = "/var/lib/searx-secret";
  envFile = "${stateDir}/env";

  # Kagi is metered per query through its API - roughly $15-25 per 1000
  # searches, i.e. not a thing to leave in the default engine fan-out.
  #
  # To turn it on: put the key in `keyFile`, then flip `enable`.
  #
  #     sudo install -m600 /dev/stdin /var/lib/searx-secret/kagi.env <<< \
  #       'KAGI_API_KEY=<key>'
  #
  # `keyFile` is a STRING, not a nix path literal - a path literal would copy
  # the key into the world-readable nix store on the next eval. Eventually an
  # agenix secret, like the rest of this repo will be.
  #
  # Off means the engine is not defined at all: no `!kg`, no `engines=kagi`,
  # and nothing reads the key file. searx-secret refuses to start rather than
  # hand searxng an empty api_key, so a typo in the path is a clear error at
  # `systemctl status searx-secret` instead of a silent 401 per query.
  kagi = {
    enable = false;
    keyFile = "${stateDir}/kagi.env";
  };
in
{
  services.searx = {
    enable = true;
    environmentFile = envFile;

    # No redisCreateLocally. Valkey is here to back `server.limiter`, and the
    # limiter is off below - there is one client and it is on loopback.
    settings = {
      use_default_settings = true;

      general = {
        instance_name = "strix";
        # Powers /stats, which is the only way to see *which* engine started
        # returning CAPTCHAs when results quietly get worse. Worth the cost on
        # an instance with one user.
        enable_metrics = true;
      };

      search = {
        # SearXNG answers `?format=json` with 403 unless json is listed here,
        # and that endpoint is the whole point of the instance. `html` stays so
        # a query can still be run by hand in the browser to see what an engine
        # actually returned.
        formats = [
          "html"
          "json"
        ];

        # Every query leaves from one residential IP with nothing to blend
        # into, so engines will rate-limit and CAPTCHA us in a way they never
        # would a public instance. The upstream penalties are sized for a
        # shared instance where a ban is cheap to sit out: 15 days for a
        # Cloudflare CAPTCHA and 7 for a reCAPTCHA. Here that is one bad
        # afternoon costing a fortnight of an engine, and moving networks does
        # not clear it - the suspension is per engine, not per IP. An hour is
        # long enough to stop a hot loop and short enough to self-heal.
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

      # An agent fans a query out to every engine at once and waits for the
      # slowest. 3s drops engines that were about to answer, and the ones it
      # drops are the good slow ones (scholar, crossref) rather than the fast
      # thin ones.
      outgoing = {
        request_timeout = 6.0;
        max_request_timeout = 15.0;
      };

      ui = {
        theme_args.simple_style = "dark";
        hotkeys = "vim";
        # Full URLs rather than the breadcrumb prettifier: when the point of a
        # result is to hand a link to an agent, the link should be readable.
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

        # Strips utm_*/fbclid/... off result URLs. Firefox already does this
        # for what it navigates to; this catches the links that get copied out
        # of a JSON response into a prompt instead.
        "searx.plugins.tracker_url_remover.SXNGPlugin".active = true;

        # Sends a DOI to oadoi.org, which redirects to a legal open-access copy
        # when one exists. Pairs with the research engines enabled below -
        # otherwise crossref hands back a paywall.
        "searx.plugins.oa_doi_rewrite.SXNGPlugin".active = true;
      };

      # Config for the hostnames plugin above. Deliberately only priority
      # nudges, no `remove:` - a dropped result is invisible, and a result
      # ranked 20th is not. This list is taste, and it is the knob to turn when
      # results feel wrong.
      hostnames.low_priority = [
        "(.*\\.)?w3schools\\.com$"
        "(.*\\.)?geeksforgeeks\\.org$"
        "(.*\\.)?pinterest(\\..*)?$"
      ];

      # Merged per entry by name, so `disabled = false` switches on one that
      # ships off and the ~250 unnamed keep their upstream default.
      # Measured against this instance, from this IP, 2026-08-27/28:
      #
      #   google cse   20 rows   answers every time
      #   duckduckgo   10 rows   good when it answers, CAPTCHAs under load
      #   qwant        10 rows   same
      #   brave         0 rows   "too many requests" after a query or two
      #   startpage     0 rows   CAPTCHA on contact, then out for an hour
      #   mojeek        0 rows   "access denied" - see below
      #
      # On a bad minute only google cse answers, and the results are still
      # usable. That is the honest shape of a one-IP instance: the fan-out is a
      # redundancy pool, not a quality multiplier, and it is often one engine
      # deep. brave and startpage stay on exactly because a suspended engine
      # costs nothing per query and both do come back.
      #
      # Indie engines were measured as a way to widen that pool and rejected:
      # mwmbl answers reliably but with low precision, and marginalia, stract,
      # right dao, presearch, seekr and wiby returned nothing between them for
      # an ordinary technical query. All are one `!bang` away if a query wants
      # them; none earns a slot in every query's fan-out.
      engines = [
        # --- general web ----------------------------------------------------
        {
          name = "qwant";
          disabled = false;
        }
        # Deliberately absent: `google`, which ships `inactive: true` upstream.
        # It CAPTCHAs a single residential IP almost on contact. `google cse`
        # and `google scholar` are separate backends and both work.
        #
        # Also deliberately absent: `mojeek`. It looks like the obvious pick
        # here - an independent index rather than another Bing reseller - but
        # in this searxng build it answers 200 with zero parseable results, for
        # any query, with nothing in the log. mojeek.com itself is up, so it is
        # the engine module that is stale. Re-test after a nixpkgs bump before
        # adding it back.

        # --- research -------------------------------------------------------
        # crw's `categories: ["research"]` fans out to arxiv, crossref, google
        # scholar and semantic scholar. Only crossref ships disabled.
        {
          name = "crossref";
          disabled = false;
        }
        {
          # Times out against the 6s global above - measured, not guessed. Given
          # its own budget rather than raising the global, which would slow down
          # every browser search to accommodate one research engine. This is how
          # upstream already treats crossref (`timeout: 30`).
          name = "semantic scholar";
          timeout = 12.0;
        }
      ]
      ++ lib.optional kagi.enable {
        # Paid and metered, so `disabled = true`: it never joins the default
        # fan-out and only answers when asked for by name - `!kg <query>` in
        # the browser, `engines=kagi` on the JSON API. That is what makes it an
        # A/B rather than a bill.
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

  # SearXNG will not start without a secret_key, and a literal one here would
  # be a secret committed to this repo. Generated once into /var/lib instead,
  # which survives rebuilds and needs no agenix ceremony - on an instance
  # nothing else can reach, that key only signs a preferences cookie.
  #
  # The env file is rebuilt from parts on every start so that flipping
  # `kagi.enable` above takes effect on a rebuild, without regenerating (and
  # so invalidating) the stored secret_key.
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
