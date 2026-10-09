{ pkgs }:
let
  # force_installed via enterprise policy, so no NUR / firefox-addons input.
  # GUIDs came from the AMO API (v5 `.guid`) - a wrong one installs nothing.
  ext = id: slug: {
    name = id;
    value = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/${slug}/latest.xpi";
      installation_mode = "force_installed";
    };
  };

  # Shared by all three profiles; only the startup tabs differ.
  baseSettings = {
    # privacy
    #
    # `privacy.resistFingerprinting` is deliberately NOT set: its
    # timezone/screen/canvas normalisation scores as automation with
    # Cloudflare's bot management, and claude.ai sits behind Cloudflare.
    "browser.contentblocking.category" = "strict";
    "privacy.trackingprotection.enabled" = true;
    "privacy.trackingprotection.socialtracking.enabled" = true;
    "privacy.trackingprotection.emailtracking.enabled" = true;
    "privacy.globalprivacycontrol.enabled" = true;
    "privacy.query_stripping.enabled" = true;
    "dom.security.https_only_mode" = true;
    # The default engine below is http://127.0.0.1:8888 and loopback is already
    # exempt from the upgrade, so this is pinned rather than assumed - a silent
    # flip upstream would break every address-bar search.
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

    # tabs: Sidebery owns the tab list.
    #
    # `sidebar.revamp` is the rail Sidebery is pinned into. `verticalTabs` is the
    # *native* vertical strip, and running both means two tab lists competing for
    # one job - off, which is what leaves the horizontal strip the userChrome
    # below collapses. Native tab groups stay on: free if unused.
    "sidebar.revamp" = true;
    "sidebar.verticalTabs" = false;
    "browser.tabs.groups.enabled" = true;
    "browser.startup.page" = 3; # 3 = restore previous session
    "browser.sessionstore.resume_from_crash" = true;

    # theme: as black as firefox will go
    "extensions.activeThemeID" = "firefox-compact-dark@mozilla.org";
    "browser.theme.toolbar-theme" = 0; # 0 = dark
    "browser.theme.content-theme" = 0; # 0 = dark
    "ui.systemUsesDarkTheme" = 1;
    "browser.display.background_color_dark" = "#000000";
    "layout.css.prefers-color-scheme.content-override" = 0; # dark
  };

  # The local SearXNG from modules/searx-local.nix becomes the address bar's
  # default, the engines it replaces kept a bang away.
  #
  # `force` is required because Firefox rewrites the existing search.json.mozlz4
  # on every launch, so home-manager's copy would otherwise be ignored - which
  # also means engines added in the browser UI are discarded on the next
  # activation. New ones go here.
  searchConfig = {
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
          # SearXNG serves the opensearch suggestion format itself, so the
          # address bar keeps completing - from the local instance now.
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

      # Kagi through the normal web UI, which the subscription covers - not the
      # metered API the SearXNG `!kg` bang would call. The free half of the A/B.
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

  # Firefox's Dark theme is grey, not black; this pushes the chrome to #000000
  # with the same carbon accents as helix/ghostty. Internal IDs shift between
  # releases, so a bar that goes grey after an update is what to re-check.
  chromeCss = ''
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

  contentCss = ''
    @-moz-document url-prefix("about:") {
      :root {
        --in-content-page-background: #000000 !important;
        --in-content-box-background: #0d0d0d !important;
      }
    }
  '';

  # Firefox has no named sessions - a profile is the only thing it names and
  # restores separately, and the only thing giving a window its own `--name`
  # app-id for niri to place. `startupPage` 1 reopens exactly `urls`; 3 restores
  # what was left open and falls back to `urls` only on a first run.
  taskProfile =
    {
      id,
      urls,
      startupPage,
    }:
    {
      inherit id;
      settings = baseSettings // {
        "browser.startup.page" = startupPage;
        "browser.startup.homepage" = builtins.concatStringsSep "|" urls;
        # Otherwise a first launch shows about:welcome and an upgrade swaps in
        # its what's-new page.
        "browser.startup.homepage_override.mstone" = "ignore";
      };
      search = searchConfig;
      userChrome = chromeCss;
      userContent = contentCss;
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

  # Tridactyl has no filesystem access, so it shells out to this helper to read
  # ~/.config/tridactyl/tridactylrc - without it homes/programs/tridactylrc.nix
  # is never applied.
  nativeMessagingHosts = [ pkgs.tridactyl-native ];

  profiles.yt = {
    id = 0;
    isDefault = true;
    settings = baseSettings;
    search = searchConfig;
    userChrome = chromeCss;
    userContent = contentCss;
  };

  # Workspace 3. Restores what you leave open, so a tab opened while reading
  # survives a logout; the three below only seed the very first launch.
  profiles.trading = taskProfile {
    id = 1;
    startupPage = 3;
    urls = [
      "https://github.com/rolling-panda-san/notebooks"
      "https://github.com/stefan-jansen/machine-learning-for-trading/blob/main/01_process_is_edge/macro_regimes.ipynb"
      "https://github.com/HKUDS/Vibe-Trading"
    ];
  };

  # Workspace 6, the bottom one. Deliberately *not* restore-on-start: every
  # launch comes back to these three and nothing else, whatever was open when
  # it closed.
  profiles.kids = taskProfile {
    id = 2;
    startupPage = 1;
    urls = [
      "https://pbskids.org/"
      "https://www.starfall.com/h/me/index.php?mg=k"
      "https://www.mathplayground.com/kindergarten_games.html"
    ];
  };

  # Workspace 2, beside the notebooks shell. Restores like trading.
  profiles.research = taskProfile {
    id = 3;
    startupPage = 3;
    urls = [
      "TODO-timeseries-momentum-url"
    ];
  };

  # Workspace 5. The Microsoft RustTraining books plus rust-exercises, the set
  # that used to live as ad-hoc tabs in the default `yt` profile - which had no
  # window rule, so they landed on whatever workspace was focused. Restores
  # like trading and research, so reading position survives a logout.
  profiles.rust = taskProfile {
    id = 4;
    startupPage = 3;
    urls = [
      "https://microsoft.github.io/RustTraining/"
      "https://microsoft.github.io/RustTraining/async-book/"
      "https://microsoft.github.io/RustTraining/rust-patterns-book/ch01-generics-the-full-picture.html"
      "https://microsoft.github.io/RustTraining/type-driven-correctness-book/"
      "https://microsoft.github.io/RustTraining/engineering-book/"
      "https://rust-exercises.com/100-exercises/04_traits/09_from.html"
    ];
  };
}
