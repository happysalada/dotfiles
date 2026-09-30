# nono - capability-sandboxed launchers for claude, codex and reasonix.
#
# nono confines a *process tree*. On Linux it applies a Landlock ruleset to the
# process it starts, every descendant inherits it, and a descendant cannot widen
# it. That is why there is nothing per-subagent anywhere in this file: a subagent
# is not a process you can address. reasonix's subagent profiles, codex's threads
# and claude's Task tool are all spawned by the agent's own runtime rather than
# by you, and `codex exec` / `claude -p` are children of it - either way they land
# inside the tree nono confined. The unit of policy is the process you type.
#
# Parallel launchers, not replacements, and three findings forced that shape:
#
#   - The wrapped codex has no .git protection. nono refuses to start when a
#     `deny` overlaps an `allow` ("Landlock deny-overlap is not enforceable on
#     Linux") and Landlock is allow-list only, so a workspace grant cannot carve
#     out .git. Plain codex keeps the workspace-write sandbox codex.nix gives it;
#     the wrapped one hands the whole boundary to nono and passes
#     `--sandbox danger-full-access`.
#   - reasonix's bubblewrap jail cannot start inside a nono session at all. nono
#     grants /proc/<pid> read-only and bwrap has to write /proc/self/uid_map, so
#     it dies with "bwrap: setting up uid map: Permission denied" - and a profile
#     asking for `[sandbox] bash = "enforce"` then refuses to run bash rather
#     than falling back. Hence ~/.reasonix-nono, which reasonix.nix renders with
#     exactly that one value changed.
#   - Nothing existing changes behaviour until a launcher is actually typed.
#
# What nono does NOT give you here: `command_policies`, the supervisor-mediated
# per-command sandbox that would let one tool carry authority another does not,
# is broken on NixOS. Any profile carrying it fails to start with "failed to
# resolve ELF dependency 'libc.so.6' for .../libgcc_s.so.1" - see the skip in
# nixpkgs' pkgs/by-name/no/nono/package.nix. Filesystem, network and credential
# confinement are unaffected; per-command differentiation is simply unavailable.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  nono = lib.getExe pkgs.nono;

  # Same package as packages/ai.nix gets, from the llm-agents overlay in
  # machines/strix/default.nix, so it is the same store path.
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
      # The only thing separating this from plain `reasonix`. reasonix resolves
      # config, skills and sessions from <Reasonix home>, so the wrapped one gets
      # its own and the unwrapped one keeps ~/.reasonix and the bwrap jail that
      # reasonix.nix configures there.
      env.REASONIX_HOME = ''$"($env.HOME)/.reasonix-nono"'';
    };
  };

  # `writeNuBin`, not `writeNu`: they differ in whether the output is a
  # directory. `writeNu name script` writes the script at the store root and
  # yields a *file*, which `pkgs.buildEnv` cannot merge - `home.packages` goes
  # through it, so the generation fails with "The store path ...-nono-claude is a
  # file and can't be merged into an environment". `writeNuBin` is defined as
  # `writeNu "/bin/${name}"` and gives the `$out/bin/<name>` that buildEnv wants.
  # (The `writeNu` uses in claude-code.nix are fine: they are hook commands
  # referenced by path and never merged into an environment.)
  #
  # `def --wrapped` is load-bearing. Without it nu parses the agent's own flags -
  # `--help`, `-p`, `--sandbox` - as nu's and dies on the first one it does not
  # know. Measured with `--wrapped`: argument boundaries survive intact,
  # including empty strings, runs of spaces and embedded quotes.
  #
  # The profile is named by *path*, not by name. `--profile codex` is resolved
  # against the pack registry as well as ~/.config/nono/profiles, so with no user
  # profile installed - before the first rebuild, or if one is ever removed - it
  # offers to pull `nolabs-ai/codex`, which writes into ~/.codex/config.toml and
  # ~/.codex/hooks.json, both of them store symlinks here. Measured: with the
  # file present the user profile wins outright, but naming the store path
  # removes the lookup and the prompt with it. The ~/.config/nono/profiles copy
  # stays, so `nono profile show claude` and `nono why` still answer by name.
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
        # The legacy global config, rewritten as projects are opened. A file
        # grant binds to the inode Landlock saw at startup, so claude's atomic
        # save - write a temp file, rename over - can go stale and lose the
        # write. nono's own answer is to move this into ~/.claude and set
        # CLAUDE_CONFIG_DIR; that is a machine-state change, so it stays out
        # until the cheap version is actually seen to fail.
        allow_file = [ "$HOME/.claude.json" ];
      };
    };

    codex = mkProfile {
      name = "codex";
      description = "Codex CLI: ~/.codex and the workspace, nothing else";
      # auth.json, sessions, caches. ~/.agents is not granted: nothing on this
      # box creates it. nono drops a grant path that does not exist at startup
      # without saying so, so listing it would buy nothing and read as intent.
      filesystem.allow = [ "$HOME/.codex" ];
    };

    reasonix = mkProfile {
      name = "reasonix";
      description = "reasonix under nono, reading its own home";
      # Its home, and nothing of ~/.reasonix. The provider key is not inside it:
      # machines/strix/default.nix points agenix at ~/.reasonix-nono/.env, which
      # is a symlink into /run/user/$UID/agenix - reading through it needs the
      # /run grant linux_runtime_state already carries.
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
      # from $HOME and this hands over $HOME. They belong in a repo.
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
  #                       Omitting it fails as "The executable 'bash' was
  #                       resolved at /run/current-system/sw/bin/bash but its
  #                       directory is not readable inside the sandbox", exit 127.
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

  # The LSP servers every agent starts as children - nixd, rust-analyzer, ty,
  # typescript-language-server, svelteserver, nu --lsp, taplo - resolve their
  # toolchains outside the store, so the matching runtime group has to be here or
  # they never come up. nixd and nushell are already covered by nix_runtime.
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
