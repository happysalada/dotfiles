{ config, pkgs, lib, ... }:
let
  rtk = lib.getExe pkgs.rtk;
  icm = lib.getExe pkgs.icm;
  starship = lib.getExe pkgs.starship;
  jaq = lib.getExe pkgs.jaq;
  systemctl = "${pkgs.systemd}/bin/systemctl";
  systemdRun = "${pkgs.systemd}/bin/systemd-run";
  systemdInhibit = "${pkgs.systemd}/bin/systemd-inhibit";

  # herdr's Claude Code integration: a SessionStart hook reporting the session id
  # to the local socket so herdr can reopen this conversation after a restart.
  # Both halves must match what `herdr integration install claude` writes - herdr
  # finds the integration by this file and this command string, and reads the
  # version embedded in it.
  herdrClaudeHook = "${config.home.homeDirectory}/.claude/hooks/herdr-agent-state.sh";
  herdrClaudeCommand = "bash '${herdrClaudeHook}' session";

  # Keep the laptop awake while Claude is actually working. "Is the agent busy" is
  # not answerable from the process table - claude is alive whether thinking or
  # waiting on you - but UserPromptSubmit and Stop *are* the started/finished
  # edges, and a lock held between them stays held while Claude sits on a
  # permission prompt. RuntimeMaxSec is the fuse, so a Stop hook that never fires
  # (crash, SIGKILL) cannot pin the machine awake for more than four hours.
  claudeAwake = pkgs.writeShellScript "claude-awake-start" ''
    set -uo pipefail
    unit="claude-awake-$(${jaq} -r '.session_id // "nosession"')"
    ${systemctl} --user stop "$unit" 2>/dev/null
    ${systemdRun} --user --quiet --collect --unit="$unit" \
      --property=RuntimeMaxSec=4h \
      ${systemdInhibit} --what=sleep:handle-lid-switch --mode=block \
        --who=claude --why="agent working" -- ${pkgs.coreutils}/bin/sleep infinity
    exit 0
  '';

  claudeRelease = pkgs.writeShellScript "claude-awake-stop" ''
    set -uo pipefail
    unit="claude-awake-$(${jaq} -r '.session_id // "nosession"')"
    ${systemctl} --user stop "$unit" 2>/dev/null || true
    exit 0
  '';

  # Clickable "Claude is done" notification that focuses the niri window AND the
  # zellij pane the session runs in. The window is found by title, not at
  # SessionStart - `niri msg focused-window` only names the terminal if you
  # happened to be looking at it - and zellij's session-name prefix
  # ("main | <tab>") is focus-independent, where ghostty is single-instance and
  # PIDs cannot tell windows apart. No zellij (`claude --bg`) falls back to focus.
  stopNotify = pkgs.writers.writeNu "claude-stop-notify" ''
    def main [] {
      let zsession = $env.ZELLIJ_SESSION_NAME? | default ""
      let pane = $env.ZELLIJ_PANE_ID? | default ""

      let by_title = if $zsession == "" { null } else {
        try { ${niri} msg --json windows | from json } catch { [] }
        | where {|w| ($w.title? | default "") | str starts-with $"($zsession) | " }
        | get -o 0.id
      }
      let wid = $by_title | default (
        try { ${niri} msg --json focused-window | from json | get -o id } catch { null }
      )

      # -f: notify-send -A blocks until answered, so the waiter must outlive us
      ${setsid} -f ${focusWaiter} ($wid | default "" | into string) $pane $zsession ($env.PWD | path basename) o+e> /dev/null
    }
  '';

  # Blocks on the notification; a click focuses, a dismissal does nothing.
  focusWaiter = pkgs.writers.writeNu "claude-focus-waiter" ''
    def main [wid: string, pane: string, zsession: string, body: string] {
      let answer = ${notifySend} -a claude -A default=Focus "Claude is done" $body | complete | get stdout | str trim
      if $answer != "default" { return }

      if $wid != "" { ${niri} msg action focus-window --id $wid | complete | ignore }
      # zellij resolves the target session from the env, so this works from
      # outside the pane
      if $pane != "" {
        with-env { ZELLIJ_SESSION_NAME: $zsession } { ${zellij} action focus-pane-id $pane | complete | ignore }
      }
    }
  '';

  niri = "^${lib.getExe pkgs.niri}";
  zellij = "^${lib.getExe pkgs.zellij}";
  notifySend = "^${pkgs.libnotify}/bin/notify-send";
  setsid = "^${pkgs.util-linux}/bin/setsid";

  # Global instructions, shared with opencode.
  aiContext = import ./ai-context.nix { inherit lib; };

  # Subagent roles, shared with codex and opencode.
  aiAgents = import ./ai-agents.nix { inherit lib pkgs; };

  # One hook entry, matcher-less (fires on every event of its kind).
  cmd = command: {
    hooks = [
      {
        type = "command";
        inherit command;
      }
    ];
  };
  # One hook entry scoped to a tool matcher.
  cmdFor = matcher: command: (cmd command) // { inherit matcher; };
in
{
  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;

    # NOTE: settings.json and CLAUDE.md become mode-444 store symlinks - the point
    # (reviewable, reproducible), but `/config` and the in-TUI auto-memory toggle
    # can no longer write them. `rtk init`, `icm init` and `graphify claude
    # install` mutate exactly these two files, so they must never be run.
    settings = {
      model = "sonnet";
      theme = "dark";
      # `default` appends the transcript to the terminal, so the pane's scrollback
      # does hold the conversation - measured, 49 of 50 lines of a local command's
      # output landed there; `fullscreen` is the alternate screen, which has no
      # scrollback in Zellij. Claude Code's own pager for long panels still
      # repaints in place, and `axScreenReader` would put even those in the
      # scrollback but is the screen-reader UI (number-picker menus). Not enabled.
      tui = "default";
      effortLevel = "high";
      agentPushNotifEnabled = true;

      # Every interactive session registers for Remote Control, so the phone can
      # pick up what the terminal is already doing without typing
      # `/remote-control` first - the session still runs here, claude.ai/code is
      # only a window onto this machine. Costs one remote session per `claude`
      # process. A `false` in a repo's .claude/settings.json still wins over this;
      # a `true` there is ignored, which is why it has to live here.
      remoteControlAtStartup = true;

      # Model, context gauge and session cost via starship (>= 1.25), whose
      # profile lives beside the shell prompt in homes/common.nix.
      statusLine = {
        type = "command";
        command = "${starship} statusline claude-code";
      };

      # Off deliberately: per-project and invisible to opencode, so it is the odd
      # one out now that icm (keyed, global, cross-tool) and funes (semantic,
      # session history) cover the same ground. Its directory has been empty since
      # it was created, so nothing is discarded by turning it off. True would give
      # readable, diffable per-project memory - and reopen which store owns it.
      autoMemoryEnabled = false;

      # Not auto: its classifier is a server round-trip per call, and an outage
      # blocks every tool that is not allowlisted below. The deny list still applies
      # in this mode.
      permissions.defaultMode = "bypassPermissions";
      # Bypass is ignored until its disclaimer is accepted, and accepting it
      # writes here - which fails against the read-only store path.
      skipDangerousModePermissionPrompt = true;

      # The Git section of ai-context.nix, enforced rather than merely asked for -
      # the same denies opencode.nix carries. Deny beats allow and beats a narrower
      # rule, and claude-code matches each subcommand of a compound command
      # independently, so `foo && git commit` is caught. Not airtight: the pattern
      # is literal up to the first `*`, so `git -c user.name=x commit` slips past,
      # and the prose in ai-context.nix is still what carries the rule.
      permissions.deny = [
        "Bash(git add *)"
        "Bash(git commit *)"
        "Bash(git push *)"
        "Bash(git reset *)"
        "Bash(git restore *)"
        "Bash(git stash *)"
        # opencode.nix's secret-file block. Not `.env.*`: deny beats allow
        # here, so that would also hide .env.example.
        "Read(**/.env)"
        "Read(**/.env.local)"
      ];

      # `git checkout -b` is fine when asked for, `git checkout -- path` destroys
      # work. One pattern cannot tell them apart, so this one prompts.
      permissions.ask = [ "Bash(git checkout *)" ];

      permissions.allow = [
        "Bash(ast-grep *)"
        "Bash(rtk *)"
        "Bash(icm *)"
        "Bash(graphify *)"
        "Bash(nono *)"
        "Bash(crw *)"
        "Bash(mcptoon *)"
        # Read-only search. Unlisted, every call waits on the auto-mode
        # classifier, and a classifier outage blocks it outright.
        "mcp__plugin_hm_fff"
        # Session recall, same reason: recall and get only read the index.
        "mcp__plugin_hm_funes"
        # Web research, same reason: fetch and search only, nothing written.
        "mcp__plugin_hm_crw"
        "WebSearch"
        "WebFetch"
        # Git reads, same reason. Writes are in deny above.
        "Bash(git status*)"
        "Bash(git diff*)"
        "Bash(git log*)"
        "Bash(git show*)"
        "Bash(git -C * status*)"
        "Bash(git -C * diff*)"
        "Bash(git -C * log*)"
        "Bash(git -C * show*)"
        # Packaging loop: builds are sandboxed and only write the store and
        # ./result. nix run/shell/develop and flake update stay unlisted - they
        # run fetched code or rewrite flake.lock.
        "Bash(nix build *)"
        "Bash(nix eval *)"
        "Bash(nix log *)"
        "Bash(nix flake prefetch *)"
        "Bash(nix flake metadata *)"
        "Bash(nix flake show *)"
        "Bash(nix store prefetch-file *)"
        "Bash(nix hash *)"
        "Bash(nix path-info *)"
        "Bash(nix why-depends *)"
        "Bash(nix derivation show *)"
        "Bash(nix search *)"
        "Bash(nix-prefetch-url *)"
        "Bash(nix-locate *)"
        # Read-only file inspection, e.g. of a prefetched source in the store.
        "Bash(ls *)"
        "Bash(cat *)"
        "Bash(head *)"
        "Bash(tail *)"
        "Bash(wc *)"
        "Bash(tree *)"
        "Bash(fd *)"
        "Bash(jg *)"
        # Read-only diagnostics, same reason.
        "Bash(rg *)"
        "Bash(bluetoothctl show*)"
        "Bash(bluetoothctl devices*)"
        "Bash(bluetoothctl info *)"
        "Bash(systemctl status *)"
        "Bash(systemctl --user status *)"
        "Bash(journalctl *)"
        "Bash(lsmod*)"
        "Bash(lsusb*)"
        "Bash(ip addr*)"
        # Deliberately NOT "Bash(sg *)": on NixOS `sg` resolves to
        # /run/wrappers/bin/sg, the setgid run-as-group utility, not ast-grep.
        # Always spell out `ast-grep`.
      ];

      hooks = {
        # Clickable "Claude is done" notification, see stopNotify above.
        Stop = [
          {
            hooks = [
              {
                type = "command";
                command = "${stopNotify}";
                timeout = 5;
              }
            ];
          }
          # drop the keep-awake lock: the turn is over, so normal idle applies
          (cmd "${claudeRelease}")
        ];

        PreToolUse = [
          # rtk rewrites bash invocations to their compact equivalents
          # (`git status` -> `rtk git status`) before the output is captured.
          (cmdFor "Bash" "${rtk} hook claude")

          # graphify's hook-guard nudges search/read toward the knowledge graph.
          # Off: it intercepts every Read and Glob, pure latency where no
          # graphify-out/graph.json exists, and the CLAUDE.md section below
          # already carries the instruction. Uncomment for the hard guard.
          # (cmdFor "Bash|Grep" "${lib.getExe pkgs.graphify} hook-guard search")
          # (cmdFor "Read|Glob" "${lib.getExe pkgs.graphify} hook-guard read")

          # `icm hook pre` returns permission decisions - it can approve calls that
          # would otherwise prompt, a permission bypass driven by a third-party
          # binary. Off; icm's memory features work fine without it.
          # (cmdFor "Bash" "${icm} hook pre")
        ];

        # icm's post/compact/end extraction hooks are off: their rule-based
        # extraction stored hundreds of sentence fragments and repo restatements,
        # which crowded the wake-up pack below. `icm store` by hand instead.

        # icm's wake-up pack: identity/preferences plus critical decisions, once
        # per session - the *only* automatic memory injection left on. See the
        # memory-split section in ai-context.nix for why one system owns the path.
        SessionStart = [
          (cmd "${icm} hook start")

          # herdr's session-identity hook, described at herdrClaudeCommand above.
          # The matcher and the timeout are part of the entry herdr writes, and
          # it is silent outside herdr: the script returns unless HERDR_ENV=1.
          {
            matcher = "^(startup|resume|clear|compact|fork)$";
            hooks = [
              {
                type = "command";
                command = herdrClaudeCommand;
                timeout = 10;
              }
            ];
          }
        ];

        # `icm hook prompt` (auto-recall) is off: it fires on every user prompt and
        # appends to the conversation, so one recall block per turn accumulates for
        # the whole session - undoing what rtk is here to do - and it re-injects on
        # turns unrelated to the recalled topic. `icm recall` covers the same
        # ground on demand.
        # (cmd "${icm} hook prompt")

        # Take the keep-awake lock; Stop below drops it again.
        UserPromptSubmit = [ (cmd "${claudeAwake}") ];

        # Drop it here too, in case Stop never fired - a session torn down
        # mid-turn would otherwise leave the lock to its 4h fuse.
        SessionEnd = [ (cmd "${claudeRelease}") ];

        # TODO funes: per-turn indexing. Copy the events and commands from the
        # claude integration in huggingface/funes-integrations, pinned to a
        # tag, instead of running `funes add claude`. It converts transcripts
        # with jq >= 1.6 - pass real jq by store path, not the jaq alias.
      };
    };

    # funes + fff come from the shared registry in ai-mcp.nix, so opencode
    # gets identical servers. `mcpServers` still works for Claude-only ones.
    enableMcpIntegration = true;

    # Real code intelligence instead of grep: claude-code speaks
    # textDocument/definition, /references and /documentSymbol, and surfaces
    # publishDiagnostics. Same servers and store paths as helix.nix, so the editor
    # and the agent cannot disagree on a version. `ty` rather than `ruff server` on
    # .py: ruff's server is lint and format, which ai-context.nix already covers
    # with `ruff check --fix`. The marketplace's twelve `*-lsp` plugins are nothing
    # but this attrset plus a README, and there is no Nix one.
    lspServers = with pkgs; {
      nixd = {
        command = "${nixd}/bin/nixd";
        extensionToLanguage.".nix" = "nix";
      };
      rust-analyzer = {
        command = "${rust-analyzer-unwrapped}/bin/rust-analyzer";
        extensionToLanguage.".rs" = "rust";
      };
      ty = {
        command = "${ty}/bin/ty";
        args = [ "server" ];
        extensionToLanguage.".py" = "python";
      };
      typescript-language-server = {
        command = "${typescript-language-server}/bin/typescript-language-server";
        args = [ "--stdio" ];
        extensionToLanguage = {
          ".ts" = "typescript";
          ".tsx" = "typescriptreact";
          ".js" = "javascript";
          ".jsx" = "javascriptreact";
        };
      };
      svelteserver = {
        command = "${svelte-language-server}/bin/svelteserver";
        args = [ "--stdio" ];
        extensionToLanguage.".svelte" = "svelte";
      };
      # nushell is the scripting language here, and ships its own server.
      nu = {
        command = "${nushell}/bin/nu";
        args = [ "--lsp" ];
        extensionToLanguage.".nu" = "nushell";
      };
      taplo = {
        command = "${taplo}/bin/taplo";
        args = [
          "lsp"
          "stdio"
        ];
        extensionToLanguage.".toml" = "toml";
      };
    };

    # Cherry-picked upstream skills, shared with opencode.
    skills = import ./ai-skills.nix { inherit pkgs; };

    # -> ~/.claude/agents/, same roles codex and opencode get.
    agents = aiAgents.mkAgents { tool = "claude-code"; };

    # -> ~/.claude/CLAUDE.md, same prose as opencode's AGENTS.md.
    context = aiContext.mkContext { tool = "claude-code"; };
  };

  # The hook file itself, straight out of the herdr store path: same bytes and
  # same version marker as the installer would write at that path, and only
  # there - a store symlink, so `herdr integration install claude` cannot
  # rewrite it. See the note in packages/ai.nix.
  home.file.".claude/hooks/herdr-agent-state.sh".source =
    "${pkgs.herdr}/share/herdr/integrations/claude/herdr-agent-state.sh";
}
