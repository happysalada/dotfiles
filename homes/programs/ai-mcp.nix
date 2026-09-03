# The one registry of MCP servers on this machine.
#
# home-manager's tool-agnostic `programs.mcp`: declare a server once, and every
# client with `enableMcpIntegration = true` gets it in its own dialect (Claude
# Code wants `mcpServers.<n> = { command, args }`, opencode wants
# `mcp.<n> = { type, command = [cmd args...] }`). Add a server here and it
# appears in both on the next rebuild.
#
# Not everything lives here: homes/programs/crw.nix registers its own server,
# because that entry has to name the port its systemd unit listens on and
# splitting the two across files is how they drift apart.
{ pkgs, lib, ... }:
let
  # Same callPackage call as packages/ai.nix, so it is the same store path -
  # listing it twice does not duplicate anything.
  mempalace = pkgs.callPackage ../../packages/ai/mempalace.nix { };
in
{
  programs.mcp = {
    enable = true;

    # All speak stdio and are pinned to absolute store paths, so they do not
    # depend on PATH when the agent spawns them.
    servers = {
      mempalace = {
        # Defaults to stdio and ~/.mempalace; both are what we want.
        command = "${mempalace}/bin/mempalace-mcp";
        args = [ ];
      };

      fff = {
        command = lib.getExe pkgs.fff-mcp;
        args = [ ];
      };
    };
  };
}
