# Shared global instructions, rendered into both ~/.claude/CLAUDE.md
# (programs.claude-code.context) and ~/.config/opencode/AGENTS.md
# (programs.opencode.context).
#
# AGENTS.md is the cross-tool convention, CLAUDE.md is Claude Code's name for
# the same thing; neither tool reads the other's file. Generated from one
# source instead of symlinked, because a few paragraphs genuinely differ per
# tool (hooks and native auto-memory exist only in Claude Code).
{ lib }:
{
  # tool :: "claude-code" | "opencode"
  mkContext =
    { tool }:
    let
      isClaude = tool == "claude-code";

      selfPath = if isClaude then "~/.claude/CLAUDE.md" else "~/.config/opencode/AGENTS.md";
      selfOption = if isClaude then "programs.claude-code.context" else "programs.opencode.context";
      selfFile = if isClaude then "homes/programs/claude-code.nix" else "homes/programs/opencode.nix";
      settingsPath = if isClaude then "~/.claude/settings.json" else "~/.config/opencode/opencode.json";
      settingsOption =
        if isClaude then "programs.claude-code.settings" else "programs.opencode.settings";

      # Installers that must never be run.
      installers =
        if isClaude then
          "(`rtk init`, `icm init`, `graphify claude install`)"
        else
          "(`opencode upgrade`, `opencode plugin ...`, and any tool's `init` subcommand)";

      # `rtk hook` has no opencode backend, so under opencode rtk is manual.
      rtkSection =
        if isClaude then
          ''
            A PreToolUse hook already rewrites ordinary bash commands to their `rtk`
            equivalents, so just run commands normally. Call `rtk` explicitly only
            for its own subcommands, e.g. `rtk gain` for token-savings stats.

            If a command's output looks truncated or reformatted in a way that
            changes the answer, re-run it as `rtk proxy <cmd>` to bypass filtering
            before concluding anything about the result.
          ''
        else
          ''
            There is **no automatic rewriting here** - `rtk hook` has no opencode
            backend, so nothing intercepts your bash calls the way it does under
            Claude Code. If you want the compression you have to ask for it:

            ```sh
            rtk git status        # instead of `git status`
            rtk test              # instead of the bare test runner
            rtk grep <pattern>
            ```

            Worth doing for commands whose output is large and repetitive (test
            runs, `git status` in a dirty tree, dependency trees). Not worth doing
            for short output - the wrapper costs more than it saves.
          '';

      icmSection =
        if isClaude then
          ''
            Under Claude Code, icm's *write* side is partly automatic: a
            PostToolUse hook extracts as you work, and a SessionStart hook
            injects a wake-up pack (identity, preferences, critical decisions)
            once per session.

            Its *read* side is not automatic. Per-prompt auto-recall is
            switched off on purpose, so nothing arrives mid-session unless you
            ask: run `icm recall` at the point you actually need a fact, rather
            than assuming it was already injected.
          ''
        else
          ''
            Under Claude Code icm is also driven by session hooks, which extract
            as it works. opencode has no such wiring, so here **icm only
            remembers what you explicitly tell it to**. If you learn something
            durable in an opencode session, `icm store` it by hand or it is gone
            when the session ends.
          '';

      memorySplit =
        if isClaude then
          ''
            There are exactly two memory systems on this box: `icm` and
            mempalace. Claude Code's own native auto-memory is switched off, so
            do not look for it and do not write to it.

            They are split by *retrieval shape*, not by subject. The same topic
            can legitimately have an icm fact and a mempalace body of context;
            what must not happen is the same sentence living in both.

            **icm** - narrow, keyed, global, cheap.
            One fact per entry, phrased as a sentence. Shared across every tool
            and every project on this machine. Exact lookup, near-zero cost.
            Write here when the fact is short, standalone, and you would want it
            in an unrelated project next month: a resolved root cause, a
            settled decision, a stated preference.

            **mempalace** - broad, semantic, corpus-scoped, pull-only.
            Mined in bulk from files and transcripts rather than hand-authored a
            fact at a time. Write here by pointing it at material
            (`mempalace mine`), not by transcribing individual facts. Query it
            when the question is fuzzy, is about this corpus, and only makes
            sense with surrounding context.

            ### Rules

            1. **One entry point per fact.** Before storing, ask which of the
               two shapes it is. If you can say it in one sentence that would
               still make sense in another repo, it is icm. If it only means
               something next to the material it came from, it is mempalace.
               Never write both.
            2. **Read cheapest-first.** `icm recall` is one command against a
               local index; try it first. Reach for mempalace only when icm
               comes back empty *and* the question is genuinely semantic. Do not
               query both to be thorough - that is two lookups to answer one
               question.
            3. **Only one system may inject automatically.** icm's session-start
               wake-up pack owns that slot. mempalace is pull-only by design:
               it has no hooks installed, and it should not get any. If you find
               yourself wanting automatic mempalace injection, that is a request
               to change the nix config, not something to arrange at runtime.
            4. **Recall is not free and not authoritative.** A stored fact
               reflects what was true when it was written. If it names a file, a
               flag or a version, check that it still holds before acting on it.
          ''
        else
          ''
            There are exactly two memory systems on this box: `icm` and
            mempalace. Claude Code's own native auto-memory is switched off, so
            do not look for it and do not write to it.

            They are split by *retrieval shape*, not by subject. The same topic
            can legitimately have an icm fact and a mempalace body of context;
            what must not happen is the same sentence living in both.

            **icm** - narrow, keyed, global, cheap.
            One fact per entry, phrased as a sentence. Shared across every tool
            and every project on this machine. Exact lookup, near-zero cost.
            Write here when the fact is short, standalone, and you would want it
            in an unrelated project next month: a resolved root cause, a
            settled decision, a stated preference.

            **mempalace** - broad, semantic, corpus-scoped, pull-only.
            Mined in bulk from files and transcripts rather than hand-authored a
            fact at a time. Write here by pointing it at material
            (`mempalace mine`), not by transcribing individual facts. Query it
            when the question is fuzzy, is about this corpus, and only makes
            sense with surrounding context.

            ### Rules

            1. **One entry point per fact.** Before storing, ask which of the
               two shapes it is. If you can say it in one sentence that would
               still make sense in another repo, it is icm. If it only means
               something next to the material it came from, it is mempalace.
               Never write both.
            2. **Read cheapest-first.** `icm recall` is one command against a
               local index; try it first. Reach for mempalace only when icm
               comes back empty *and* the question is genuinely semantic. Do not
               query both to be thorough - that is two lookups to answer one
               question.
            3. **Only one system may inject automatically.** icm's session-start
               wake-up pack owns that slot. mempalace is pull-only by design:
               it has no hooks installed, and it should not get any. If you find
               yourself wanting automatic mempalace injection, that is a request
               to change the nix config, not something to arrange at runtime.
            4. **Recall is not free and not authoritative.** A stored fact
               reflects what was true when it was written. If it names a file, a
               flag or a version, check that it still holds before acting on it.

            Caveat specific to opencode: icm's session hooks are Claude
            Code-only, so nothing is injected for you at session start. Anything
            you want remembered has to be stored by hand, and anything you want
            recalled has to be asked for.
          '';
    in
    ''
      # Global instructions

      ## This file is generated - do not edit it

      This file is a read-only symlink into the nix store. Its source is
      `homes/programs/ai-context.nix` in `/home/yt/dotfiles`, rendered into
      `${selfPath}` by `${selfOption}` in `${selfFile}`.

      Any change to these global instructions must be made there, as an edit to
      the dotfiles working tree, and then reviewed by me before it is staged and
      committed - I stage and commit, per the Git section below. Never edit
      `${selfPath}` directly: the write will fail against the read-only store
      path, and if it somehow succeeded it would be silently reverted on the next
      `nixos-rebuild`.

      The same goes for `${settingsPath}`, which is generated from
      `${settingsOption}` in that same file.

      Because the prose is shared, an edit to `ai-context.nix` changes the
      instructions for *every* agent on this machine, not just you. Sections that
      are true for only one tool are already switched on the tool name inside
      that file - add to that switch rather than writing a tool-specific
      instruction into the shared body.

      This also means no tool may install itself into these files. Several of the
      tools below ship an `init` or `install` subcommand that appends to the
      context file and registers hooks or config ${installers}. Do not run them,
      and do not suggest running them - their effect is already expressed
      declaratively in nix. If one of them needs new wiring, propose the change
      to the relevant file in `/home/yt/dotfiles` instead.

      ## Git

      **Never stage. Never commit.** I stage and I commit - always, without exception.

      Do not run `git add`, `git commit`, `git push`, `git reset`, `git restore`,
      `git checkout -- <path>`, `git stash`, or anything else that touches the index,
      HEAD, or a remote. Modify files in the working tree only, then tell me what
      changed and let me review it.

      Creating a branch is fine if I ask for it. Reading git state (`git status`,
      `git diff`, `git log`) is always fine.

      If a tool genuinely needs files staged in order to run, **say so and stop** -
      tell me what to stage. Do not stage it "just to make the build work".

      ### Nix flakes specifically

      A flake inside a git repo only sees *tracked* files, so a new untracked file is
      invisible to `nix build` / `nix eval`. That is not a reason to stage it. Use a
      `path:` flake reference instead, which reads the working tree directly:

      ```sh
      nix build "path:/home/yt/dotfiles#nixosConfigurations.strix.config.system.build.toplevel"
      ```

      ## Code style

      ### Step-down order

      Define things in the order they are called: entry point first, then what
      it calls, then what those call. Reading top to bottom should descend one
      level of detail at a time, so stopping partway still leaves a coherent
      picture. Applies to functions in a file, attributes in a nix module,
      sections in a doc.

      ### Comments

      Short. Long comments never get read, so shorter is always better than
      longer - one line beats three, and no comment beats one that restates the
      code. Comment *why*, never *what*.

      ## Tooling

      These tools are installed system-wide (packages/ai.nix,
      packages/basic_cli_set.nix). Prefer them where they apply, but none of
      them override the git rules above, and none of them are worth a detour
      when a plain `rg`/read already answers the question.

      ### ast-grep - structural search and rewrite

      Invoke it as `ast-grep`, never as `sg` (`sg` is the setgid group utility
      on NixOS).

      Reach for `ast-grep` instead of `rg` when the pattern is about *code
      shape* rather than text:

      - matching a call regardless of formatting, line breaks or argument
        whitespace - `ast-grep -p 'foo($$$ARGS)'`
      - finding a construct only in a real syntactic position (a call named
        `x`, not the word `x` in a comment or string)
      - mechanical refactors across many files - `ast-grep -p '<old>' -r '<new>'`

      Stay with `rg` for prose, logs, config, filenames, and any "does this
      string appear anywhere" question. `rg` is faster and ast-grep needs a
      language it can parse.

      ### rtk - bash output compression

      ${rtkSection}
      ### icm - cross-session memory

      `icm` persists facts between sessions. Useful, not mandatory - store
      things that will still be true next week, not this session's scratch
      state.

      ```sh
      icm recall "query"            # search before re-deriving known context
      icm store -t <topic> -c "..." -i <low|high|critical>
      icm topics                    # what is already remembered
      ```

      Worth storing: resolved root causes, architecture decisions and their
      rationale, stated preferences. Not worth storing: build logs, git status,
      anything already written down in this file or in the repo.

      ${icmSection}
      ### graphify - repo knowledge graph

      Only useful once a graph exists (`graphify-out/graph.json`). Check before
      relying on it; if it is absent, use ordinary search and do not build one
      unless asked - a full build costs API calls.

      ```sh
      graphify query "<question>"   # scoped subgraph for a codebase question
      graphify path "<A>" "<B>"     # how two things connect
      graphify explain "<concept>"  # a node and its neighbours
      graphify update .             # refresh after code changes (AST-only, free)
      ```

      Good for "what calls into this / how does X reach Y" across many files.
      Not a replacement for reading the file once you know which one it is.

      ### fff - file and content search (MCP)

      Exposed as MCP tools rather than a shell command. It keeps a resident
      index, so on a large tree it answers in milliseconds where a fresh `rg`
      spawn takes seconds.

      Prefer it for "where is this file" and "which files mention X" on big
      repos, especially when the query is fuzzy or the exact spelling is
      uncertain - it is typo-tolerant and frequency-ranks results, which plain
      `rg` does not.

      Keep using `rg`/`ast-grep` directly when the pattern is precise, when the
      tree is small, or when the exact regex semantics matter - fff ranks, and
      ranking is the wrong tool when you need every single match.

      ### mempalace - long-term memory (MCP)

      Exposed as MCP tools. Stores conversation and project knowledge locally
      (SQLite + a local embedding model, no API key, nothing leaves the
      machine).

      ${memorySplit}
      When recalling, one lookup in the most likely store is enough; do not
      query every store before answering.

      ### nono - sandboxing

      `nono run -- <cmd>` confines a command's filesystem and network access.
      Suggest it for running untrusted or generated code; do not wrap ordinary
      commands in it by default.

      Caveat on NixOS: nono's ELF resolver fails to find `libc.so.6` for
      `libgcc_s.so.1`, so its `command_policies` feature does not work here.
      Filesystem and network confinement are unaffected.
    '';
}
