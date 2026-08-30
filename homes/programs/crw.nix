# One crw engine for the whole machine, instead of one per agent session.
#
# `crw-mcp` in embedded mode calls `browser::spawn_all_headless()` before it
# serves a single request (crates/crw-mcp/src/main.rs:509) and holds the
# browsers for the process lifetime. Every Claude Code and opencode session
# starts its own MCP server, so embedded mode means a headless Chromium and a
# LightPanda resident per session - which, with several `wt` worktrees open at
# once, multiplies fast.
#
# Setting CRW_API_URL flips crw-mcp to proxy mode, which skips the spawn
# entirely and forwards to the server below. Same tools, same capabilities,
# one browser pair.
#
# `crw serve` owns no browser of its own (crw-cli/src/main.rs:198), so the two
# renderers are their own units and are handed to it as CDP endpoints. crw
# resolves each `ws_url` to a browser-level endpoint via /json/version at first
# use, so a plain host:port is all it wants.
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

  # Copied from crw's LIGHTPANDA_EXTRA_BLOCK_CIDRS: the ranges crw_core's URL
  # safety check rejects that LightPanda's own --block-private-networks group
  # does not cover. crw applies these when it spawns LightPanda itself; running
  # it as a unit moves that hardening here.
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
  # stop/restart back down. Enabling them separately would just be a second
  # place for the dependency to drift.
  unit = description: {
    Unit = {
      Description = description;
      PartOf = [ "crw.service" ];
    };
  };
in
{
  # crw registers itself here rather than in ai-mcp.nix, because the client and
  # the server have to agree on the endpoint and one file should own it.
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
        # `always`, not `on-failure`: a plain SIGTERM is a clean exit, so
        # on-failure leaves the engine down and nothing brings it back. That is
        # not hypothetical - it sat stopped for three days that way, while the
        # two browsers (SIGKILLed, so "failed") restarted immediately.
        ExecStart = "${lib.getExe crw} serve --host ${host} --port ${toString ports.api}";
        Environment = [
          "CRW_RENDERER__LIGHTPANDA__WS_URL=ws://${host}:${toString ports.lightpanda}/"
          "CRW_RENDERER__CHROME__WS_URL=ws://${host}:${toString ports.chrome}/"
          # crw's search is nothing but a SearXNG proxy, so this line is what
          # turns `crw_search` from `search_disabled` into a working tool.
          # The system instance from modules/searx-local.nix.
          "CRW_SEARCH__SEARCH_BACKEND_URL=http://127.0.0.1:8888"
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
          # RuntimeDirectory is tmpfs, so the profile is RAM and is re-fetched
          # on every restart. None of what Chrome pulls in the background -
          # Safe Browsing lists, component CRX cache, a TTS engine, on-device
          # suggest models - is used to render a page. Off, this profile idles
          # at 2.4M instead of 105M.
          "--disable-background-networking"
          "--disable-component-update"
          "--safebrowsing-disable-auto-update"
          "--disable-sync"
          "--metrics-recording-only"
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
