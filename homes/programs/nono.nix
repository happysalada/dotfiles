# nono - capability-sandboxed launchers for claude, codex and reasonix.
#
# nono confines a *process tree*: a Landlock ruleset applied to the process it
# starts, inherited by every descendant and widenable by none of them. That is
# why nothing here is per-subagent - the unit of policy is the process you type.
#
# Parallel launchers, not replacements, for three reasons: the wrapped codex
# hands its own workspace-write sandbox to nono (Landlock is allow-list only, so
# a workspace grant cannot carve out .git); reasonix's bubblewrap jail cannot
# start under nono's /proc/<pid> grant, hence ~/.reasonix-nono; and nothing
# changes behaviour until a launcher is actually typed.
#
# What nono does NOT give you here: `command_policies`, the supervisor-mediated
# per-command sandbox, is broken on NixOS - any profile carrying it fails to start
# with "failed to resolve ELF dependency 'libc.so.6' for .../libgcc_s.so.1".
# Filesystem, network and credential confinement are unaffected.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  nono = lib.getExe pkgs.nono;

  # Same package, and so the same store path, as packages/ai.nix.
  reasonix = pkgs.reasonix;

  launchers = {
    claude = mkLauncher {
      name = "claude";
      command = lib.getExe' config.programs.claude-code.finalPackage "claude";
    };

    codex = mkLauncher {
      name = "codex";
      command = lib.getExe' config.programs.codex.package "codex";
      # nono is the only boundary, so codex's own comes off. The approval flow
      # stays: on a denial what could regain authority is this profile, not a
      # prompt - which is why nono's own codex hooks deny PermissionRequest
      # upstream rather than escalating it.
      args = [
        "--sandbox"
        "danger-full-access"
        "--ask-for-approval"
        "on-request"
      ];
    };

    reasonix = mkLauncher {
      name = "reasonix";
      command = lib.getExe' reasonix "reasonix";
      # The only thing separating this from plain `reasonix`, which resolves
      # config, skills and sessions from <Reasonix home>: the wrapped one keeps
      # ~/.reasonix and the bwrap jail reasonix.nix configures there.
      env.REASONIX_HOME = ''$"($env.HOME)/.reasonix-nono"'';
    };
  };

  # `writeNuBin`, not `writeNu`: the latter writes the script at the store root and
  # yields a *file*, which `pkgs.buildEnv` cannot merge - `home.packages` goes
  # through it, so the generation fails with "The store path ... is a file and
  # can't be merged into an environment". `writeNuBin` is `writeNu "/bin/${name}"`
  # and gives the `$out/bin/<name>` it wants. (The `writeNu` uses in
  # claude-code.nix are fine: hook commands referenced by path, never merged.)
  #
  # `def --wrapped` is load-bearing. Without it nu parses the agent's own flags -
  # `--help`, `-p`, `--sandbox` - as nu's and dies on the first one it does not
  # know. Measured with `--wrapped`: argument boundaries survive intact.
  #
  # The profile is named by *path*, not by name. `--profile codex` is resolved
  # against the pack registry as well as ~/.config/nono/profiles, so with no user
  # profile installed it offers to pull `nolabs-ai/codex`, which writes into
  # ~/.codex/config.toml and ~/.codex/hooks.json, both store symlinks here.
  mkLauncher =
    {
      name,
      command,
      args ? [ ],
      env ? { },
    }:
    pkgs.writers.writeNuBin "nono-${name}" ''
      def --wrapped main [...rest: string] {
        with-env { ${
          lib.concatStringsSep ", " (lib.mapAttrsToList (entry: value: "${entry}: ${value}") env)
        } } {
          exec ${nono} run --profile ${
            renderProfile name profiles.${name}
          } --allow-cwd -- ${command} ${lib.concatStringsSep " " args} ...$rest
        }
      }
    '';

  profiles = {
    claude = mkProfile {
      name = "claude";
      description = "Claude Code: ~/.claude and the workspace, nothing else";
      filesystem = {
        allow = [ "$HOME/.claude" ];
        # The legacy global config, rewritten as projects are opened. A file grant
        # binds to the inode Landlock saw at startup, so claude's atomic save -
        # write a temp file, rename over - can go stale and lose the write. nono's
        # answer is CLAUDE_CONFIG_DIR plus a move into ~/.claude; that is a
        # machine-state change, so it waits until the cheap version is seen to fail.
        allow_file = [ "$HOME/.claude.json" ];
      };
    };

    codex = mkProfile {
      name = "codex";
      description = "Codex CLI: ~/.codex and the workspace, nothing else";
      # auth.json, sessions, caches. ~/.agents is not granted: nothing on this box
      # creates it, and nono drops a grant path that does not exist at startup
      # without saying so.
      filesystem.allow = [ "$HOME/.codex" ];
    };

    reasonix = mkProfile {
      name = "reasonix";
      description = "reasonix under nono, reading its own home";
      # Its home, and nothing of ~/.reasonix. The provider key is not inside it:
      # machines/strix/default.nix points agenix at ~/.reasonix-nono/.env, a
      # symlink into /run/user/$UID/agenix that the linux_runtime_state grant
      # covers.
      filesystem.allow = [ "$HOME/.reasonix-nono" ];
    };
  };

  mkProfile =
    {
      name,
      description,
      filesystem,
    }:
    {
      meta = { inherit name description; };
      # `default` is where the deny groups live - ~/.ssh, ~/.gnupg, ~/.aws,
      # keyrings, browser data, shell history. Without it a profile starts with
      # none of them.
      extends = "default";
      groups.include = baseGroups ++ toolchainGroups;
      # `default` declares workdir "none", so this is what gives --allow-cwd a
      # meaning. Read-write, relative to wherever the launcher was typed: run one
      # from $HOME and this hands over $HOME.
      workdir.access = "readwrite";
      # The agents are useless without their APIs, and the proxy mode that would
      # narrow this further is what breaks crw's loopback MCP server.
      network.block = false;
      inherit filesystem;
    };

  # Why these, on NixOS in particular:
  #
  #   nix_runtime         Without it nothing runs at all. A store binary's
  #                       directory has to be readable to exec it, and
  #                       /run/current-system/sw and /etc/profiles/per-user are
  #                       how the agent and every LSP server it starts resolve.
  #   linux_runtime_state /run and /var/run read-only. The systemd user bus and
  #                       the Wayland socket the Stop hooks in claude-code.nix
  #                       talk to live there, as does /run/user/$UID/agenix,
  #                       which is what ~/.reasonix-nono/.env points at.
  #   user_caches_linux   ~/.cache read-write; mise, uv, cargo and reasonix all
  #                       want it before they will start.
  #   git_config          ~/.gitconfig read-only. Every agent runs git.
  baseGroups = [
    "nix_runtime"
    "linux_runtime_state"
    "user_caches_linux"
    "git_config"
  ];

  # The LSP servers every agent starts resolve their toolchains outside the store,
  # so the matching runtime group has to be here or they never come up. nixd and
  # nushell are already covered by nix_runtime.
  toolchainGroups = [
    "rust_runtime"
    "python_runtime"
    "node_runtime"
  ];

  renderProfile = name: value: (pkgs.formats.json { }).generate "nono-profile-${name}" value;
in
{
  home.packages = lib.attrValues launchers;

  # ~/.config/nono/profiles is the user profile root, and these are store
  # symlinks - so `nono profile promote` cannot write here and every change comes
  # through this file plus a rebuild, the same posture as ~/.codex/config.toml
  # and ~/.claude/settings.json.
  home.file = lib.mapAttrs' (
    name: value:
    lib.nameValuePair ".config/nono/profiles/${name}.json" { source = renderProfile name value; }
  ) profiles;
}
