{ pkgs }:
let
  # force_installed via enterprise policy, so no NUR / firefox-addons input is
  # needed. GUIDs were taken from the AMO API (v5 `.guid`), not guessed - a
  # wrong GUID makes the extension silently fail to install.
  ext = id: slug: {
    name = id;
    value = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/${slug}/latest.xpi";
      installation_mode = "force_installed";
    };
  };
in
{
  enable = true;

  policies = {
    ExtensionSettings = builtins.listToAttrs [
      (ext "uBlock0@raymondhill.net" "ublock-origin")
      (ext "{446900e4-71c2-419f-a6a7-df9c091e268b}" "bitwarden-password-manager")
      # tab workspaces: panels, save/restore, tree view
      (ext "{3c078156-979c-498b-8990-85f7987dd929}" "sidebery")
      (ext "{74145f27-f039-47ce-a470-a662b129930a}" "clearurls")
      (ext "@testpilot-containers" "multi-account-containers")
      (ext "sponsorBlocker@ajay.app" "sponsorblock")
      (ext "addon@darkreader.org" "darkreader")

      # vim keys in the browser. It grabs keypresses globally, which fights
      # claude.ai's composer - tridactylrc.nix drops it into ignore mode there.
      (ext "tridactyl.vim@cmcaine.co.uk" "tridactyl-vim")
    ];

    DisableTelemetry = true;
    DisableFirefoxStudies = true;
    DisablePocket = true;
    DontCheckDefaultBrowser = true;

    # Bitwarden owns credentials; don't have two password managers fighting
    OfferToSaveLogins = false;
    PasswordManagerEnabled = false;

    EnableTrackingProtection = {
      Value = true;
      Locked = false;
      Cryptomining = true;
      Fingerprinting = true;
      EmailTracking = true;
    };

    FirefoxHome = {
      Pocket = false;
      SponsoredPocket = false;
      SponsoredTopSites = false;
      Highlights = false;
    };

    UserMessaging = {
      ExtensionRecommendations = false;
      FeatureRecommendations = false;
      MoreFromMozilla = false;
      SkipOnboarding = true;
    };

    # same resolver the servers use
    DNSOverHTTPS = {
      Enabled = true;
      ProviderURL = "https://dns.quad9.net/dns-query";
      Locked = false;
    };
  };

  # Tridactyl cannot read ~/.config/tridactyl/tridactylrc on its own - the
  # extension has no filesystem access and shells out to this helper for it.
  # Without it Tridactyl still works, but only from config set interactively,
  # and homes/programs/tridactylrc.nix is never applied.
  nativeMessagingHosts = [ pkgs.tridactyl-native ];

  profiles.yt = {
    id = 0;
    isDefault = true;

    settings = {
      # ---------------------------------------------------------------
      # privacy
      #
      # NOTE: `privacy.resistFingerprinting` is deliberately NOT set. RFP
      # normalises timezone/screen/canvas in ways Cloudflare's bot management
      # scores as automation, and claude.ai sits behind Cloudflare. Strict ETP
      # plus uBlock Origin gets most of the benefit without that breakage.
      # ---------------------------------------------------------------
      "browser.contentblocking.category" = "strict";
      "privacy.trackingprotection.enabled" = true;
      "privacy.trackingprotection.socialtracking.enabled" = true;
      "privacy.trackingprotection.emailtracking.enabled" = true;
      "privacy.globalprivacycontrol.enabled" = true;
      "privacy.query_stripping.enabled" = true;
      "dom.security.https_only_mode" = true;
      # The default search engine below is http://127.0.0.1:8888. Loopback is
      # already exempt from the upgrade, but the pref that decides that is
      # pinned rather than assumed - a silent flip upstream would break every
      # search in the address bar.
      "dom.security.https_only_mode.upgrade_local" = false;
      "network.trr.mode" = 2; # DoH with plain-DNS fallback

      # no sponsored anything
      "browser.urlbar.suggest.sponsored" = false;
      "browser.urlbar.suggest.quicksuggest.sponsored" = false;
      "browser.newtabpage.activity-stream.showSponsored" = false;
      "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
      "browser.newtabpage.activity-stream.feeds.section.topstories" = false;

      "toolkit.telemetry.enabled" = false;
      "toolkit.telemetry.unified" = false;
      "datareporting.healthreport.uploadEnabled" = false;
      "browser.aboutConfig.showWarning" = false;

      # ---------------------------------------------------------------
      # tabs: Sidebery owns the tab list.
      #
      # `sidebar.revamp` stays on - that is the sidebar rail Sidebery is
      # pinned into. `verticalTabs` is off because it is the *native* vertical
      # tab strip, and running it next to Sidebery means two tab lists
      # competing for the same job. Turning it off brings the horizontal strip
      # back, which the userChrome below collapses.
      #
      # Native tab groups are left enabled: they are independent of Sidebery's
      # panels and cost nothing if unused.
      # ---------------------------------------------------------------
      "sidebar.revamp" = true;
      "sidebar.verticalTabs" = false;
      "browser.tabs.groups.enabled" = true;
      "browser.startup.page" = 3; # 3 = restore previous session
      "browser.sessionstore.resume_from_crash" = true;

      # ---------------------------------------------------------------
      # theme: as black as firefox will go
      # ---------------------------------------------------------------
      "extensions.activeThemeID" = "firefox-compact-dark@mozilla.org";
      "browser.theme.toolbar-theme" = 0; # 0 = dark
      "browser.theme.content-theme" = 0; # 0 = dark
      "ui.systemUsesDarkTheme" = 1;
      "browser.display.background_color_dark" = "#000000";
      "layout.css.prefers-color-scheme.content-override" = 0; # dark
    };

    # Firefox's built-in Dark theme is grey, not black. This pushes the chrome
    # to #000000 with the same carbon accents as helix/ghostty. Best-effort:
    # internal IDs do shift between Firefox releases, so if a bar goes grey
    # after a major update, that's what to re-check.
    # The local SearXNG from modules/searx-local.nix becomes the address bar's
    # default, with the engines it replaces kept a bang away.
    #
    # `force` is required because this profile already has a search.json.mozlz4
    # - Firefox rewrites that file on every launch, so without it home-manager's
    # copy is ignored. It also means engines added through the browser UI are
    # discarded on the next activation: new ones go here, not in Settings.
    search = {
      force = true;
      default = "searxng";
      privateDefault = "searxng";
      order = [
        "searxng"
        "ddg"
      ];

      engines = {
        searxng = {
          name = "SearXNG";
          urls = [
            {
              template = "http://127.0.0.1:8888/search";
              params = [
                {
                  name = "q";
                  value = "{searchTerms}";
                }
              ];
            }
            # SearXNG speaks the opensearch suggestion format on its own
            # endpoint, so the address bar keeps completing - the completions
            # just come from the local instance now.
            {
              type = "application/x-suggestions+json";
              template = "http://127.0.0.1:8888/autocompleter";
              params = [
                {
                  name = "q";
                  value = "{searchTerms}";
                }
              ];
            }
          ];
          definedAliases = [ "@sx" ];
        };

        # Kagi through the normal web UI, which the subscription covers - as
        # opposed to the metered API the SearXNG `!kg` bang would call. This is
        # the free half of the A/B: `@k <query>` against `@sx <query>`.
        kagi = {
          name = "Kagi";
          urls = [
            {
              template = "https://kagi.com/search";
              params = [
                {
                  name = "q";
                  value = "{searchTerms}";
                }
              ];
            }
          ];
          iconMapObj."16" = "https://kagi.com/favicon.ico";
          definedAliases = [ "@k" ];
        };
      };
    };

    userChrome = ''
      :root {
        --lwt-accent-color: #000000 !important;
        --lwt-toolbar-field-background-color: #0d0d0d !important;
        --lwt-toolbar-field-focus: #161616 !important;
        --toolbar-bgcolor: #000000 !important;
        --toolbar-color: #c8ccd4 !important;
        --tab-selected-bgcolor: #161616 !important;
        --arrowpanel-background: #000000 !important;
        --arrowpanel-color: #c8ccd4 !important;
        --panel-separator-color: #262626 !important;
        --sidebar-background-color: #000000 !important;
      }

      #navigator-toolbox,
      #titlebar,
      #nav-bar,
      #PersonalToolbar,
      #tabbrowser-tabs,
      #sidebar-box,
      #sidebar-header,
      #sidebar-main {
        background-color: #000000 !important;
        border-color: #262626 !important;
      }

      #urlbar,
      #urlbar-background,
      #searchbar {
        background-color: #0d0d0d !important;
        border-color: #262626 !important;
      }

      .tab-background[selected] {
        background-color: #161616 !important;
      }

      /* Sidebery is the tab list, so collapse the native horizontal strip.
       *
       * This hides the tabs but deliberately keeps #TabsToolbar itself, so the
       * titlebar buttonbox and the window drag area survive - on this GNOME/
       * niri setup Firefox draws its own decorations, and collapsing the whole
       * toolbar takes the close button with it. The cost is one slim empty
       * row; to reclaim it, hide #TabsToolbar outright AND set
       * `browser.tabs.inTitlebar = 0` so the compositor draws a real titlebar.
       */
      #tabbrowser-tabs {
        visibility: collapse !important;
      }
    '';

    userContent = ''
      @-moz-document url-prefix("about:") {
        :root {
          --in-content-page-background: #000000 !important;
          --in-content-box-background: #0d0d0d !important;
        }
      }
    '';
  };
}
