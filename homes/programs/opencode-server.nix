# A long-lived `opencode serve` for the phone to talk to over NetBird.
#
# `opencode serve` is the headless twin of `opencode web` - same HTTP server,
# same UI at `/`, minus the "open a browser on this machine" step that makes
# `web` wrong for a unit. So the phone gets the full web client at
# http://strix.netbird.cloud:4096 with nothing installed on it.
#
# Auth is opencode's own: with OPENCODE_SERVER_PASSWORD set, every request
# needs HTTP Basic `opencode:<password>`, and without it the server logs a
# warning and serves to anyone who asks. That is the whole reason the password
# below is generated rather than optional - an unsecured opencode server is a
# remote shell on this laptop.
#
# Reachability is NetBird's job (modules/netbird.nix): the port is open on the
# mesh interface only.
{ pkgs, config, ... }:
let
  port = 4096; # must match `opencodePort` in modules/netbird.nix

  # Not an agenix secret: it is generated on this machine, never leaves it,
  # and has no meaning on any other. Written on first start rather than
  # declared, so the store never holds it. Read it with
  #   cat ~/.local/state/opencode/server-password
  # and delete it to mint a new one on the next restart.
  start = pkgs.writeShellScript "opencode-server" ''
    set -eu

    pwfile="$HOME/.local/state/opencode/server-password"
    if [ ! -e "$pwfile" ]; then
      mkdir -p "$(dirname "$pwfile")"
      # hex rather than base64: this gets typed into a phone keyboard
      (umask 077; head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$pwfile")
    fi
    OPENCODE_SERVER_PASSWORD="$(cat "$pwfile")"
    export OPENCODE_SERVER_PASSWORD

    # 0.0.0.0, not the mesh address: NetBird assigns that at runtime and it
    # changes if the peer is re-enrolled. The firewall is what keeps this off
    # every other interface.
    exec ${config.programs.opencode.package}/bin/opencode serve \
      --port ${toString port} --hostname 0.0.0.0
  '';
in
{
  systemd.user.services.opencode-server = {
    Unit = {
      Description = "opencode server, reachable over NetBird";
      After = [ "network.target" ];
    };

    Service = {
      ExecStart = "${start}";
      WorkingDirectory = "%h";
      Restart = "on-failure";
      RestartSec = 5;

      # A user unit starts with almost no PATH, and opencode shells out for
      # nearly everything it does - git, rg, the language servers, every Bash
      # tool call. Without this the agent comes up and then fails at its first
      # command.
      Environment = [
        "PATH=/run/wrappers/bin:%h/.nix-profile/bin:/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin"
      ];
    };

    Install.WantedBy = [ "default.target" ];
  };
}
