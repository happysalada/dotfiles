# One crw engine for the machine, not one per agent session: embedded `crw-mcp`
# holds a headless Chromium and a LightPanda per process
# (crates/crw-mcp/src/main.rs:509) and every session starts its own MCP server,
# so it multiplies across `wt` worktrees - CRW_API_URL flips it to proxy mode.
# The renderers are their own units handed to `crw serve` as CDP endpoints; it
# owns no browser (crw-cli/src/main.rs:198) and resolves a plain host:port.
{ pkgs, lib, ... }:
let
  crw = pkgs.callPackage ../../packages/ai/crw.nix { };
  lightpanda = pkgs.callPackage ../../packages/ai/lightpanda.nix { };

  # Loopback only. Nothing here authenticates, and `crw serve` defaults to
  # 0.0.0.0, which would put an unauthenticated scraper on the LAN.
  host = "127.0.0.1";
  ports = {
    api = 13000; # crw's own default is 3000, squarely in dev-server territory
    lightpanda = 9222;
    chrome = 9223;
  };

  # Copied from crw's LIGHTPANDA_EXTRA_BLOCK_CIDRS: ranges crw_core's URL check
  # rejects but LightPanda's --block-private-networks does not cover. crw applies
  # these when spawning LightPanda; as a unit, the hardening lives here.
  blockedCidrs = lib.concatStringsSep "," [
    "0.0.0.0/8"
    "10.0.0.0/8"
    "127.0.0.0/8"
    "169.254.0.0/16"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "100.64.0.0/10"
    "224.0.0.0/4"
    "240.0.0.0/4"
    "192.0.0.0/24"
    "192.0.2.0/24"
    "198.18.0.0/15"
    "198.51.100.0/24"
    "203.0.113.0/24"
    "fc00::/7"
    "fe80::/10"
    "fec0::/10"
    "ff00::/8"
    "::/96"
    "64:ff9b:1::/48"
    "2002::/16"
  ];

  # No [Install]: crw.service's Wants= pulls these in, and PartOf sends its
  # stop/restart back down. Enabling them separately is a second place to drift.
  unit = description: {
    Unit = {
      Description = description;
      PartOf = [ "crw.service" ];
    };
  };
in
{
  # Registered here, not ai-mcp.nix: client and server must agree on the endpoint.
  programs.mcp.servers.crw = {
    command = "${crw}/bin/crw-mcp";
    args = [ ];
    env = {
      # Proxy mode. Without this the MCP server spawns its own browsers.
      CRW_API_URL = "http://${host}:${toString ports.api}";
      # Self-hosted has no credit ledger, so the creditCost/creditsUsed fields
      # in every tool response are dead weight in the context. Must be
      # "true"/"false": clap parses this one as a bool and exits on "1".
      CRW_MCP__HIDE_CREDITS = "true";
    };
  };

  systemd.user.services = {
    crw = {
      Unit = {
        Description = "crw scraping engine";
        # The renderers are Wants, not Requires: crw resolves them lazily, so a
        # browser that is down costs JS rendering, not the whole API.
        Wants = [
          "crw-lightpanda.service"
          "crw-chromium.service"
        ];
        After = [
          "crw-lightpanda.service"
          "crw-chromium.service"
        ];
      };

      Service = {
        # `always`, not `on-failure`: a SIGTERM is a clean exit, so on-failure
        # leaves the engine down and nothing brings it back - it sat stopped for
        # three days that way, while the SIGKILLed browsers restarted immediately.
        ExecStart = "${lib.getExe crw} serve --host ${host} --port ${toString ports.api}";
        Environment = [
          "CRW_RENDERER__LIGHTPANDA__WS_URL=ws://${host}:${toString ports.lightpanda}/"
          "CRW_RENDERER__CHROME__WS_URL=ws://${host}:${toString ports.chrome}/"
          # crw's search is a SearXNG proxy: this line turns `crw_search` from
          # `search_disabled` into a working tool (the modules/searx-local.nix one).
          "CRW_SEARCH__SEARCH_BACKEND_URL=http://127.0.0.1:8888"
          # Ollama ignores the key, but fastCRW requires a non-empty value before
          # it enables its LLM-backed extraction routes.
          "CRW_EXTRACTION__LLM__PROVIDER=openai-compatible"
          "CRW_EXTRACTION__LLM__API_KEY=ollama"
          "CRW_EXTRACTION__LLM__MODEL=mistral-nemo"
          "CRW_EXTRACTION__LLM__BASE_URL=http://127.0.0.1:11434/v1"
        ];
        Restart = "always";
        RestartSec = 2;
      };

      Install.WantedBy = [ "default.target" ];
    };

    crw-lightpanda = (unit "LightPanda CDP endpoint for crw") // {
      Service = {
        ExecStart = lib.concatStringsSep " " [
          (lib.getExe lightpanda)
          "serve"
          "--host ${host}"
          "--port ${toString ports.lightpanda}"
          "--block-private-networks"
          "--block-cidrs ${blockedCidrs}"
        ];
        Restart = "always";
        RestartSec = 2;
      };
    };

    crw-chromium = (unit "Headless Chromium CDP endpoint for crw") // {
      Service = {
        # Same flags crw uses when it spawns Chrome itself, minus --no-sandbox:
        # that exists for containers, and this browser renders untrusted pages
        # all day. Verified to start sandboxed on this machine.
        ExecStart = lib.concatStringsSep " " [
          (lib.getExe pkgs.chromium)
          "--headless"
          "--disable-gpu"
          "--disable-dev-shm-usage"
          "--no-first-run"
          # RuntimeDirectory is tmpfs, so the profile is RAM, re-fetched per
          # restart, and none of Chrome's background fetches (Safe Browsing lists,
          # CRX cache, TTS engine, suggest models) render a page. Off: 2.4M vs 105M.
          "--disable-background-networking"
          "--disable-component-update"
          "--safebrowsing-disable-auto-update"
          "--disable-sync"
          "--metrics-recording-only"
          # This starts at boot under linger, before login unlocks the keyring.
          # Chrome's default store woke a locked gnome-keyring that then failed
          # to prompt with no display. A throwaway profile needs no secrets.
          "--password-store=basic"
          "--remote-debugging-address=${host}"
          "--remote-debugging-port=${toString ports.chrome}"
          "--remote-allow-origins=*"
          "--user-data-dir=%t/crw-chromium"
        ];
        # Auto-created and wiped with the unit, so a crashed browser never
        # leaves a locked profile behind for the next start.
        RuntimeDirectory = "crw-chromium";
        Restart = "always";
        RestartSec = 2;
      };
    };
  };
}
