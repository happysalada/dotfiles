# Shared global instructions, rendered into ~/.claude/CLAUDE.md
# (programs.claude-code.context), ~/.config/opencode/AGENTS.md
# (programs.opencode.context) and ~/.codex/AGENTS.md (programs.codex.context).
#
# AGENTS.md is the cross-tool convention, CLAUDE.md is Claude Code's name for
# the same thing; no tool reads another's file. Generated from one source
# instead of symlinked, because a few paragraphs genuinely differ per tool -
# which hooks fire, and whether the tool ships a web search of its own.
{ lib }:
{
  # tool :: "claude-code" | "opencode" | "codex"
  mkContext =
    { tool }:
    let
      # The three per-tool files the prose has to name: itself, the settings
      # file beside it, and the credential file that is deliberately neither.
      paths = {
        claude-code = {
          selfPath = "~/.claude/CLAUDE.md";
          selfOption = "programs.claude-code.context";
          selfFile = "homes/programs/claude-code.nix";
          settingsPath = "~/.claude/settings.json";
          settingsOption = "programs.claude-code.settings";
          authPath = "~/.claude/.credentials.json";
          authCommand = "/login";
        };
        opencode = {
          selfPath = "~/.config/opencode/AGENTS.md";
          selfOption = "programs.opencode.context";
          selfFile = "homes/programs/opencode.nix";
          settingsPath = "~/.config/opencode/opencode.json";
          settingsOption = "programs.opencode.settings";
          authPath = "~/.local/share/opencode/auth.json";
          authCommand = "opencode auth login";
        };
        codex = {
          selfPath = "~/.codex/AGENTS.md";
          selfOption = "programs.codex.context";
          selfFile = "homes/programs/codex.nix";
          settingsPath = "~/.codex/config.toml";
          settingsOption = "programs.codex.settings";
          authPath = "~/.codex/auth.json";
          authCommand = "codex login";
        };
      };
      inherit (paths.${tool})
        selfPath
        selfOption
        selfFile
        settingsPath
        settingsOption
        authPath
        authCommand
        ;

      # Installers that must never be run.
      installers =
        {
          claude-code = "(`rtk init`, `icm init`, `graphify claude install`, `crw setup`, `cargo agents init`)";
          opencode = "(`opencode upgrade`, `opencode plugin ...`, and any tool's `init` subcommand)";
          codex = "(`codex update`, `rtk init`, `icm init`, `crw setup`, `cargo agents init`)";
        }
        .${tool};

      # `rtk hook` ships backends for claude, cursor, gemini, copilot, droid and
      # vibe - none for opencode or codex, so there the compression is manual.
      rtkManual = ''
        There is **no automatic rewriting here** - `rtk hook` has no backend for
        this tool, so nothing intercepts your bash calls the way it does under
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

      rtkSection =
        {
          claude-code = ''
            A PreToolUse hook already rewrites ordinary bash commands to their `rtk`
            equivalents, so just run commands normally. Call `rtk` explicitly only
            for its own subcommands, e.g. `rtk gain` for token-savings stats.

            If a command's output looks truncated or reformatted in a way that
            changes the answer, re-run it as `rtk proxy <cmd>` to bypass filtering
            before concluding anything about the result.
          '';
          opencode = rtkManual;
          codex = rtkManual;
        }
        .${tool};

      icmSection =
        {
          claude-code = ''
            Under Claude Code, icm's *write* side is partly automatic: a
            PostToolUse hook extracts as you work, and a SessionStart hook
            injects a wake-up pack (identity, preferences, critical decisions)
            once per session.

            Its *read* side is not automatic. Per-prompt auto-recall is
            switched off on purpose, so nothing arrives mid-session unless you
            ask: run `icm recall` at the point you actually need a fact, rather
            than assuming it was already injected.
          '';
          opencode = ''
            Under Claude Code icm is also driven by session hooks, which extract
            as it works. opencode has no such wiring, so here **icm only
            remembers what you explicitly tell it to**. If you learn something
            durable in an opencode session, `icm store` it by hand or it is gone
            when the session ends.
          '';
          codex = ''
            icm speaks codex's hook schema, so the write side is wired exactly as
            it is under Claude Code: extraction on PostToolUse and PreCompact, a
            wake-up pack on SessionStart, a final extraction on SessionEnd.

            The four icm hooks and their content-derived trust hashes are managed
            together in `homes/programs/codex.nix`. `/hooks` is useful for
            inspection, but its trust action cannot write the generated config.

            The read side is not automatic here either: `icm recall` when you
            need a fact.
          '';
        }
        .${tool};

      # Claude Code ships WebFetch/WebSearch, codex ships a cached web_search,
      # opencode has webfetch and no search. The overlap with crw differs, so
      # the "which one" advice does.
      crwSection =
        {
          claude-code = ''
            You already have WebFetch and WebSearch, and they stay the right
            default for one page. WebFetch runs a small model over the page and
            hands back its answer; crw_scrape hands back the page itself as
            markdown.

            Prefer crw when you need the *content* rather than a summary of it -
            exact API signatures, code samples, tables, anything you are going
            to quote or copy - and whenever the answer spans more than one page.

            For search specifically the split is where the query runs, not how
            good it is. Your WebSearch is server-side: the query leaves this
            machine. `crw_search` runs against a SearXNG on loopback. Either is
            fine for ordinary work; use crw_search when the query itself is
            something I would not want off the box - anything naming this
            repo's private code, a client, or my own data.
          '';
          opencode = ''
            opencode's built-in `webfetch` handles a single URL. crw is what you
            have for everything past that: markdown extraction rather than raw
            page text, and crawling a site instead of fetching one page of it.
          '';
          codex = ''
            Codex has a `web_search` tool of its own, answered from OpenAI's
            cache rather than the live page. That is the cheap default for "what
            does this error mean". Reach for crw when you need the page itself -
            exact API signatures, code samples, tables - or more than one of them.

            And for search, `crw_search` is the one that runs on this machine:
            use it when the query names this repo's private code, a client, or
            my own data.
          '';
        }
        .${tool};

      # Which *third* store exists and has been switched off differs per tool;
      # the two-system split itself does not.
      memoryIntro =
        {
          claude-code = ''
            There are exactly two memory systems on this box: `icm` and
            mempalace. Claude Code's own native auto-memory is switched off, so
            do not look for it and do not write to it.
          '';
          opencode = ''
            There are exactly two memory systems on this box: `icm` and
            mempalace. Claude Code's own native auto-memory is switched off, so
            do not look for it and do not write to it.
          '';
          codex = ''
            There are exactly two memory systems on this box: `icm` and
            mempalace. Codex's own `memories` feature is left at its default of
            off, for the reason Claude Code's native auto-memory is: a third
            store, invisible to the other two tools, covering ground they
            already cover between them.
          '';
        }
        .${tool};

      memoryCaveat =
        {
          claude-code = "";
          opencode = ''

            Caveat specific to opencode: icm's session hooks are Claude
            Code-only, so nothing is injected for you at session start. Anything
            you want remembered has to be stored by hand, and anything you want
            recalled has to be asked for.
          '';
          codex = ''

            Caveat specific to codex: the icm hooks only fire once you have
            trusted them in `/hooks`, so check there before assuming a session
            started with its wake-up pack.
          '';
        }
        .${tool};

      memorySplit = ''
        ${memoryIntro}
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
        ${memoryCaveat}'';
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

      Credentials are the one file in that directory nix does not own:
      `${authPath}` is written by the tool itself when you run
      `${authCommand}`. If a session is unauthenticated, that command is the
      fix - never an edit to `${selfFile}`, and never a key pasted into
      `${settingsPath}`.

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

      ## Multi-agent workflow

      The primary thread owns requirements, decisions, integration and the final
      answer. Delegate only when a bounded task can run independently or when
      exploration would pollute the primary context.

      Run independent read-only work in parallel. Use `explorer` to map code,
      `reviewer` to inspect an understood change, and `worker` to implement one
      bounded change. Never assign two writers to the same area, wait for every
      delegated task before integrating, and return summaries rather than raw
      logs. Do trivial or tightly coupled work in the primary thread instead of
      paying delegation overhead.

      ## Git

      **Never stage. Never commit.** I stage and I commit - always, without exception.

      Do not run `git add`, `git commit`, `git push`, `git reset`, `git restore`,
      `git checkout -- <path>`, `git stash`, or anything else that touches the index,
      HEAD, or a remote. Modify files in the working tree only, then tell me what
      changed and let me review it.

      Creating a branch is fine if I ask for it. Reading git state (`git status`,
      `git diff`, `git log`) is always fine.

      **No worktrees.** Edit the files in the checkout I am already in. Do not run
      `git worktree add`, and do not reach for a worktree tool if your harness
      offers one - a worktree hides the change from me and dies with the session,
      which is the opposite of what the rules above are for. If your harness
      refuses to edit outside a worktree, say so and stop rather than working
      around it.

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

      Concretely, and check this before calling a file done: a helper is
      defined *after* its first caller, never before, and a constant sits
      next to the function that reads it rather than in a block at the top.
      This is not a preference to weigh against others - reordering afterwards
      is cheap, so there is no excuse for handing over a file that reads
      bottom-up.

      ### Comments

      Short. Long comments never get read, so shorter is always better than
      longer - one line beats three, and no comment beats one that restates the
      code. Comment *why*, never *what*.

      ### Shell scripts

      Write them in nushell. `nu` is the login shell here, and passing
      structured data between commands removes most of the quoting discipline
      that keeps a bash script correct. Shebang `#!/usr/bin/env nu`, arguments
      via `def main [--flag]`, and `| complete` to inspect an external
      command's exit code.

      Reach for bash only when the script has to run somewhere nu is not
      installed - and say that is why when you do.

      ## Tooling

      These tools are installed system-wide (packages/ai.nix,
      packages/basic_cli_set.nix). Prefer them where they apply, but none of
      them override the git rules above, and none of them are worth a detour
      when a plain `rg`/read already answers the question.

      ### xh - HTTP client

      Prefer `xh` over `curl` for ad hoc HTTP requests and API calls. Use
      `curl` only when reproducing an exact documented command or when the
      command must run somewhere `xh` is unavailable, and say why. Translate
      ordinary `curl` examples to `xh` rather than copying them unchanged.

      ### jsongrep - structured data search

      Prefer `jg` over `jq` when selecting or searching fields in JSON, JSONL,
      YAML or TOML. It accepts files or stdin and its query language is simpler
      than a jq pipeline. `jq` is a compatibility alias for `jaq`; use either
      only when a transformation is beyond what `jg` expresses.

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

      ### crw - web scrape, crawl and search (MCP)

      fastCRW. Exposed as MCP tools (`crw_search`, `crw_scrape`, `crw_crawl`,
      `crw_check_crawl_status`, `crw_map`, `crw_extract`, `crw_parse_file`) and
      as a `crw` CLI for one-off shell use. Everything it does happens on this
      machine: no account, no API key, nothing sent to a third party except the
      fetch of the page itself.

      ${crwSection}
      Pick the tool by shape:

      - `crw_scrape` - one URL to markdown.
      - `crw_map` - what URLs a site has, without fetching each one. Cheap;
        run it first when you do not yet know which page you want.
      - `crw_crawl` - bounded BFS over a site. Async: it returns a job id and
        you poll `crw_check_crawl_status`. Bound it (`limit`, `maxDepth`) or
        it will happily walk a whole documentation site into your context.
      - `crw_extract` - structured fields across many URLs, also async.
      - `crw_parse_file` - a local PDF to markdown.

      JS rendering works: the binary is wrapped with both renderers, and the
      auto ladder runs LightPanda first (fast, no layout engine) and falls
      through to headless Chrome when a page crashes during hydration. Chrome
      is also the only one of the two that can screenshot, since LightPanda
      never rasterises anything.

      `crw_search` works, and is the only web search on this machine that
      actually runs here. It proxies a SearXNG bound to loopback
      (`modules/searx-local.nix`), which fans the query out to DuckDuckGo,
      Brave, Startpage, Mojeek, Qwant and Wikipedia and merges the results.
      `crw search "..."` is the same thing from the shell.

      Two consequences of it being *my* IP asking, rather than a public
      instance with a crowd to hide in:

      - Do not loop on it. A burst of near-identical queries earns a CAPTCHA,
        and SearXNG then suspends that engine for an hour. Search once, read
        the results, then `crw_scrape` the page you actually want.
      - Partial results are normal. If an engine is suspended the others still
        answer, so thin results mean "one engine is out", not "nothing exists".
        Say so rather than silently concluding there is no answer.

      `categories` picks the fan-out: `research` for arxiv/crossref/scholar,
      `github` for code, omitted for the general web. `!kg` and `engines=kagi`
      reach a paid, metered engine - never send those unless I ask for Kagi by
      name.

      That shared engine is a systemd user service. If *every* crw tool starts
      failing at once, it is down rather than broken - `systemctl --user status
      crw` says so, and restarting it is my call, not yours.

      And do not run `crw setup`, `crw-mcp install` or `npx crw-mcp` - like the
      other tools above, they write into the two generated files.

      ### Rust

      The toolchain is rust-overlay's `stable.latest`, not nixpkgs', so `rustc`,
      `cargo`, `clippy`, `rustfmt`, `rust-src` and `rust-analyzer` all come from
      one release and cannot drift apart. It is pinned by the `rust-overlay`
      flake input, so a version bump is `nix flake update rust-overlay` in
      `/home/yt/dotfiles` - never `rustup`, which has nothing to manage here.

      `cargo check` and `clippy` are the loop; run them rather than reasoning
      about whether something compiles. Beyond that:

      - `cargo nextest run` instead of `cargo test`. The built-in harness
        interleaves output from parallel threads, which is easy to misattribute.
      - `cargo expand` to settle what a derive or `macro_rules!` actually
        generated, instead of inferring it from the macro's documentation.
      - `cargo machete` for dependencies left in `Cargo.toml` after a refactor,
        and `cargo semver-checks` before picking a version for a published crate.

      Prefer `ast-grep` over `rg` for Rust: it parses the language, so a pattern
      matches a real call or impl rather than the same word in a doc comment.

      ### symposium - per-crate agent skills

      `cargo agents`. It reads the workspace dependency graph and installs the
      skills, hooks and MCP servers that those specific crate versions ship, so
      guidance for a library comes from its maintainers rather than from what
      the model remembers of an older release. Worth a `cargo agents sync` when
      you land in an unfamiliar Rust project.

      Two things about how it is set up here:

      - `hook-scope` is `"project"`, not the upstream default of `"global"`.
        Global scope merges hook entries into `~/.claude/settings.json`, which
        is generated and read-only, so the write fails. The cost is that
        Symposium is inert in a checkout until `cargo agents sync` has been run
        there once. (Symposium knows claude, codex and opencode; it registers
        project hooks for the first two and installs skills only for opencode.)
      - `~/.symposium/config.toml` is generated from
        `homes/programs/symposium.nix` and is read-only for the same reason as
        the two files above, so anything that would write it fails by design.
        `cargo agents plugin list` shows what the configured registries offer;
        to enable something, propose the edit to that nix file rather than
        trying to write the config.

      ### Python

      Astral's three tools cover what used to take five. `uv` owns
      environments, lockfiles and the interpreters themselves; `ruff` is lint
      and format; `ty` is the type checker. There is no pyright, poetry, pdm or
      hatch on this box - if a project's docs call for one, use the `uv`
      equivalent rather than installing it.

      - `uv run <cmd>` rather than activating a venv. It resolves and syncs
        first, so it is also the cheapest way to be sure the environment
        matches the lockfile. `uv add` / `uv remove` edit `pyproject.toml`;
        never hand-edit the lockfile.
      - `uv python install <version>` works here - `nix-ld` is enabled, which
        is what lets uv's portable interpreters find their loader.
      - `ruff check --fix` and `ruff format` are the loop. `ty check` on top of
        it; it is pre-1.0, so treat an assertion it cannot prove as a question
        rather than a verdict.
      - `py-spy dump --pid <pid>` for a process that is already hung, and
        `py-spy top` for one that is merely slow. Neither needs the program
        restarted or instrumented.
      - `marimo edit` for notebooks. They are stored as plain `.py`, so read
        and edit one as an ordinary module - no `.ipynb` JSON to pick through.

      Prefer `ast-grep` over `rg` for Python, for the same reason as Rust.

      ### nono - sandboxing

      `nono run -- <cmd>` confines a command's filesystem and network access.
      Suggest it for running untrusted or generated code; do not wrap ordinary
      commands in it by default.

      Caveat on NixOS: nono's ELF resolver fails to find `libc.so.6` for
      `libgcc_s.so.1`, so its `command_policies` feature does not work here.
      Filesystem and network confinement are unaffected.
    '';
}
