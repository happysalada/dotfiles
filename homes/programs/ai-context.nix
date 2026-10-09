# Shared global instructions, rendered into ~/.claude/CLAUDE.md
# (programs.claude-code.context), ~/.config/opencode/AGENTS.md
# (programs.opencode.context), ~/.codex/AGENTS.md (programs.codex.context) and
# ~/.reasonix/REASONIX.md (home.activation in homes/programs/reasonix.nix).
#
# AGENTS.md is the cross-tool convention, CLAUDE.md and REASONIX.md its
# per-tool names; no tool reads another's file. Generated from one source, not
# symlinked, because a few paragraphs genuinely differ per tool - which hooks
# fire, and whether the tool ships a web search or a memory of its own.
{ lib }:
{
  # tool :: "claude-code" | "opencode" | "codex" | "reasonix"
  mkContext =
    { tool }:
    let
      # The per-tool files the prose names: itself, its settings file, and the
      # credential file that is deliberately neither.
      paths = {
        claude-code = {
          selfPath = "~/.claude/CLAUDE.md";
          selfOption = "programs.claude-code.context";
          selfFile = "homes/programs/claude-code.nix";
          settingsPath = "~/.claude/settings.json";
          settingsOption = "programs.claude-code.settings";
        };
        opencode = {
          selfPath = "~/.config/opencode/AGENTS.md";
          selfOption = "programs.opencode.context";
          selfFile = "homes/programs/opencode.nix";
          settingsPath = "~/.config/opencode/opencode.json";
          settingsOption = "programs.opencode.settings";
        };
        codex = {
          selfPath = "~/.codex/AGENTS.md";
          selfOption = "programs.codex.context";
          selfFile = "homes/programs/codex.nix";
          settingsPath = "~/.codex/config.toml";
          settingsOption = "programs.codex.settings";
        };
        reasonix = {
          selfPath = "~/.reasonix/REASONIX.md";
          selfOption = "home.activation.reasonixInstructions";
          selfFile = "homes/programs/reasonix.nix";
          settingsPath = "~/.reasonix/config.toml";
          settingsOption = "the settings attrset";
        };
      };
      inherit (paths.${tool})
        selfPath
        selfOption
        selfFile
        settingsPath
        settingsOption
        ;

      # Three are store symlinks like everything else home-manager writes;
      # reasonix's is a copy, because it ignores a document whose symlink
      # resolves outside its home - see the activation in reasonix.nix.
      fileKind =
        {
          claude-code = "symlink into the nix store";
          opencode = "symlink into the nix store";
          codex = "symlink into the nix store";
          reasonix = "copy of a nix store file";
        }
        .${tool};

      # Separate prose rather than a path plus a command, because reasonix's is
      # the one not written by the tool at all - agenix decrypts it.
      credentials =
        {
          claude-code = ''
            Credentials are the one file in that directory nix does not own:
            `~/.claude/.credentials.json` is written by the tool itself when you run
            `/login`. If a session is unauthenticated, that command is the
            fix - never an edit to `homes/programs/claude-code.nix`, and never a key pasted into
            `~/.claude/settings.json`.'';

          opencode = ''
            Credentials are the one file in that directory nix does not own:
            `~/.local/share/opencode/auth.json` is written by the tool itself when you run
            `opencode auth login`. If a session is unauthenticated, that command is the
            fix - never an edit to `homes/programs/opencode.nix`, and never a key pasted into
            `~/.config/opencode/opencode.json`.'';

          codex = ''
            Credentials are the one file in that directory nix does not own:
            `~/.codex/auth.json` is written by the tool itself when you run
            `codex login`. If a session is unauthenticated, that command is the
            fix - never an edit to `homes/programs/codex.nix`, and never a key pasted into
            `~/.codex/config.toml`.'';

          reasonix = ''
            Credentials are the one file in the Reasonix home nix does not write
            either: `~/.reasonix/.env` is a symlink to the agenix-decrypted
            `DEEPSEEK_API_KEY`, and `~/.reasonix-nono/.env` is the same secret
            for the sandboxed launcher. There is no login command and no key in
            `~/.reasonix/config.toml` - a provider there only names the variable
            (`api_key_env`). If a session is unauthenticated, the secret or its
            `secrets/agenix-rules.nix` rule is what to look at, never a key
            pasted into the config and never a `reasonix setup` run.'';
        }
        .${tool};

      # Installers that must never be run.
      installers =
        {
          claude-code = "(`rtk init`, `icm init`, `graphify claude install`, `crw setup`, `cargo agents init`)";
          opencode = "(`opencode upgrade`, `opencode plugin ...`, and any tool's `init` subcommand)";
          codex = "(`codex update`, `rtk init`, `icm init`, `crw setup`, `cargo agents init`)";
          reasonix = "(`reasonix setup`, `reasonix mcp add`, `reasonix subagent create --scope global`, `reasonix upgrade`)";
        }
        .${tool};

      # `rtk hook` ships backends for claude, cursor, gemini, copilot, droid and
      # vibe - none for opencode or codex, so there the compression is manual.
      rtkManual = ''
        There is **no automatic rewriting here** - `rtk hook` has no backend for
        this tool, so nothing intercepts your bash calls the way it does under
        Claude Code. Prefix the commands whose output is large by nature:

        ```sh
        rtk git status        # instead of `git status`
        rtk test              # instead of the bare test runner
        rtk grep <pattern>
        ```

        Do that without judging the size first: you cannot see the output until
        after the command has run, and a dirty tree, a failing suite and a
        dependency tree are large every time. Everything else runs unwrapped -
        on short output the wrapper costs more than it saves.
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
          reasonix = rtkManual;
        }
        .${tool};

      icmSection =
        {
          claude-code = ''
            Under Claude Code a SessionStart hook injects a wake-up pack
            (identity, preferences, critical decisions) once per session.
            Nothing extracts automatically - the extraction hooks filled the
            store with fragments - so `icm store` anything durable by hand.

            Its *read* side is not automatic. Per-prompt auto-recall is
            switched off on purpose, so nothing arrives mid-session unless you
            ask: run `icm recall` at the point you actually need a fact, rather
            than assuming it was already injected.
          '';
          opencode = ''
            **icm only remembers what you explicitly tell it to** - no tool on
            this box extracts automatically. If you learn something
            durable in an opencode session, `icm store` it by hand or it is gone
            when the session ends.
          '';
          codex = ''
            icm speaks codex's hook schema, so it is wired exactly as it is
            under Claude Code: a wake-up pack on SessionStart, and no automatic
            extraction - `icm store` anything durable by hand.

            The icm hook and its content-derived trust hash are managed together
            in `homes/programs/codex.nix`. `/hooks` is useful for
            inspection, but its trust action cannot write the generated config.

            The read side is not automatic here either: `icm recall` when you
            need a fact.
          '';
          reasonix = ''
            **icm only remembers what you explicitly tell it to** - no tool on
            this box extracts automatically, and icm's hooks speak the Claude
            Code and Codex event schemas, not reasonix's, so nothing is injected
            at session start either. `icm store` anything durable by hand or it
            is gone when the session ends, and `icm recall` when you need it
            back.
          '';
        }
        .${tool};

      # Claude Code ships WebFetch/WebSearch, codex a cached web_search, opencode
      # webfetch and no search. The overlap with crw differs, so the advice does.
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
          reasonix = ''
            You have a `web_search` tool of your own, answered by DeepSeek
            server-side - the query leaves this machine, and the page never
            enters your context as content. That is the cheap default for "what
            does this error mean". Reach for crw when you need the page itself -
            exact API signatures, code samples, tables - or more than one of them.

            And for search, `crw_search` is the one that runs on this machine:
            use it when the query names this repo's private code, a client, or
            my own data.
          '';
        }
        .${tool};

      # Which *third* store exists and is switched off differs per tool; the
      # two-system split itself does not.
      memoryIntro =
        {
          claude-code = ''
            There are exactly two memory systems on this box: `icm` and
            funes. Claude Code's own native auto-memory is switched off, so
            do not look for it and do not write to it.
          '';
          opencode = ''
            There are exactly two memory systems on this box: `icm` and
            funes. Claude Code's own native auto-memory is switched off, so
            do not look for it and do not write to it.
          '';
          codex = ''
            There are exactly two memory systems on this box: `icm` and
            funes. Codex's own `memories` feature is left at its default of
            off, for the reason Claude Code's native auto-memory is: a third
            store, invisible to the other two tools, covering ground they
            already cover between them.
          '';
          reasonix = ''
            There are exactly two memory systems on this box: `icm` and
            funes. Reasonix's own background memory is a third, and unlike
            Claude Code's native auto-memory it is left on: one Markdown file
            per fact, scoped to a workspace or to this machine, and recalled
            automatically ahead of a turn. It does not replace either store -
            standing rules belong in this file and one-sentence facts belong in
            `icm` - but it is what holds a fact mid-session without me having to
            approve the write.
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
          reasonix = ''

            Caveat specific to reasonix: background memory is a second
            automatic injection path - the one thing rule 3 below reserves for
            icm - and it is bounded but real (four facts, 2,400 characters
            appended to a turn, and it never outranks this file or your current
            request). Treat what it hands you the way rule 4 says: a stored fact
            is what was true when it was written, not an instruction and not
            proof. `/memory recall` shows exactly which facts were selected and
            why; `forget` archives one that is wrong. Nothing here extracts into
            `icm` or `funes`, and neither of those is written by reasonix.
          '';
        }
        .${tool};

      memorySplit = ''
        ${memoryIntro}
        They are split by *retrieval shape*, not by subject. The same topic
        can legitimately have an icm fact and the funes sessions it came
        from; what must not happen is icm restating a session verbatim.

        **icm** - narrow, keyed, global, cheap.
        One fact per entry, phrased as a sentence. Shared across every tool
        and every project on this machine. Exact lookup, near-zero cost.
        Write here when the fact is short, standalone, and you would want it
        in an unrelated project next month: a resolved root cause, a
        settled decision, a stated preference.

        **funes** - broad, semantic, session history, pull-only.
        Indexed from past Claude Code and Codex transcripts, never written
        by hand. Query it with `recall` when the question is "what did we
        decide, find or try before" and the answer only makes sense with
        the session around it; `get` returns a cited turn in full.

        ### Rules

        1. **Only icm is written by hand.** funes is filled from
           transcripts, so what was said in a session is already there.
           Store in icm only the one-sentence version that would still
           make sense in another repo.
        2. **Read cheapest-first.** `icm recall` is one command against a
           local index; try it first. Reach for funes only when icm
           comes back empty *and* the question is about past sessions. Do
           not query both to be thorough - that is two lookups to answer
           one question.
        3. **Only one system may inject automatically.** icm's session-start
           wake-up pack owns that slot. funes is pull-only: its hook only
           indexes, it never adds to the context. If you find yourself
           wanting automatic funes injection, that is a request to change
           the nix config, not something to arrange at runtime.
        4. **Recall is not free and not authoritative.** A stored fact
           reflects what was true when it was written. If it names a file, a
           flag or a version, check that it still holds before acting on it.
        ${memoryCaveat}'';
    in
    ''
      # Global instructions

      ## This file is generated - do not edit it

      This file is a read-only ${fileKind}. Its source is
      `homes/programs/ai-context.nix` in `/home/yt/dotfiles`, rendered into
      `${selfPath}` by `${selfOption}` in `${selfFile}`.

      Any change to these global instructions must be made there, as an edit to
      the dotfiles working tree, and then reviewed by me before it is staged and
      committed - I stage and commit, per the Git section below. Never edit
      `${selfPath}` directly: it is read-only, so the write fails, and if one
      somehow succeeded it would be silently reverted on the next
      `nixos-rebuild`.

      The same goes for `${settingsPath}`, which is generated from
      `${settingsOption}` in that same file.

      ${credentials}

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

      **Worktrees only when I ask for one, never by default.** Edit the files in
      the checkout I am already in. Do not run `git worktree add`, and do not
      reach for a worktree tool if your harness offers one - a worktree hides the
      change from me and dies with the session, so making one is my call, not
      yours. When I do ask for one, say which path it is at. If your harness
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

      `nu -c '<pipeline>'` is the same thing as a one-liner, and is what the
      Tooling table below reaches for when a command has to convert or filter
      structured data.

      ## Tooling

      Installed system-wide (packages/ai.nix, packages/basic_cli_set.nix) and
      preferred over the POSIX command in the same slot. Each row below is a
      *substitution*, so using one is fewer steps and not a detour - but none
      of them overrides the git rules above.

      | you are about to | use instead |
      | --- | --- |
      | `sed -i`, or a loop over files | `sd 'old' 'new' <files>` - in place, `-p` previews |
      | `cut -f`, `awk '{print $2}'` on delimited output | `choose 1 -f ','` - 0-indexed, `-f` is a regex, reads stdin or `-i` |
      | `find . -name '*.py'` | `fd -e py` |
      | `cat`, or `cat -n`, on a file | `read_file`, or `bat` when line numbers matter |
      | `python -c` to convert or filter JSON/YAML/TOML/CSV | `nu -c` - `open x.yaml \| to json` |
      | `jq` field selection | `jg` |
      | `grep` for a code *shape* rather than a string | `ast-grep -p 'foo($$$ARGS)'` |
      | `curl` | `xh` |
      | `grep` inside a PDF or .docx | `rga` |
      | per-language line counts, disk usage, a flag you have forgotten | `tokei`, `dua`, `tldr <cmd>` |

      Never reach for `python -c`, `awk`, `sed -i` or a heredoc script to do
      text or structured-data plumbing: the rows above cover it in one step.
      `rg` stays the default for "does this string appear anywhere", and these
      are for the shapes where it is not enough. The rest of the installed
      toolbox - the tools whose job is not guessable from the name - is the
      `cli-toolbox` skill.

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
      ### mcptoon - MCP tool results and catalog

      `rtk` filters bash output; MCP results arrive as tool results, so nothing
      filters those - a long `crw_scrape` or a wide `fff` grep lands whole.
      `mcptoon` calls the same servers from a shell and hands back a compressed
      result, or the catalog without the schemas:

      ```sh
      mcptoon manifest --slim               # every tool, its params on one line
      mcptoon search <query>                # which server has a tool for this
      mcptoon inspect <server> <tool>       # the real schema before calling
      mcptoon call <server> <tool> '{"k":"v"}' --toon
      ```

      Worth it when the result is large *and* multi-field - `--toon` cut a
      `crw_search` result on this machine by 18%, and did nothing measurable to
      a single long text field. Not worth it for one small call: the server
      spawn costs more than the compression saves. `--slim` drops the parameter
      descriptions `inspect` restores, so use it to find a tool, not to call one.

      Its server list is its own, at `~/.mcptoon/config.json`. Nothing in nix
      writes it, and it is not the file your client reads. Seed it once from the
      registry the rest of the machine uses:

      ```sh
      mcptoon import --file ~/.config/mcp/mcp.json --write   # the stdio servers
      mcptoon add <name> --http <url>                        # the HTTP ones
      mcptoon update                                         # cache the tool surface
      ```

      Anything that rewrites *agent* config rather than mcptoon's own -
      `quickstart`, `discover --write`, `skills sync`, `sync --self` and
      `--takeover`, `off`/`restore`/`uninstall` - stays off-limits: that config
      belongs to `homes/programs/ai-mcp.nix`.

      Where bash is jailed it cannot run at all: mcptoon creates `~/.mcptoon` as
      it starts, and codex's `workspace-write` sandbox and reasonix's bubblewrap
      jail both leave `$HOME` read-only, so every invocation dies with
      `OSError: [Errno 30] Read-only file system` before it reads an argument.
      `MCPTOON_CONFIG_FILE` does not move that directory - it is derived from
      `$HOME`. Use your own MCP tools where you are jailed, and treat wanting
      the compression as a change to propose rather than to arrange at runtime.

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

      ### funes - session memory (MCP)

      Exposed as MCP tools (`recall`, `get`) and a `funes` CLI. Indexes past
      agent sessions locally (Lance + pinned local embedding and reranking
      models, no API key). Nothing leaves the machine unless `funes push`
      runs - never run it, nor `funes add` or `funes update`, which write
      into generated config or the read-only store.

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
      - `cargo modules structure` (also `orphans`, `dependencies`) for the crate's
        real shape; it parses with rust-analyzer, so it resolves through macros
        and generics that reading the source cannot.
      - `cargo hack check --each-feature` after adding anything behind a
        `#[cfg(feature = "...")]`. A plain `cargo check` compiles the default
        feature set only, so a feature-gated mistake passes it.
      - `cargo mutants` when the question is whether the tests assert anything,
        `cargo deny check` for advisories and licenses, `cargo insta` for `insta`
        snapshots, `cargo llvm-cov` for line coverage.
      - `cargo watch -x check` rebuilds on save, for interactive use only.

      There is no nightly toolchain here and no `rustup`, only the stable one
      above, so the subcommands needing either do not run at all - `cargo udeps`,
      `cargo public-api` and `cargo careful` fail outright rather than degrade.
      For dead dependencies reach for `cargo machete` and `cargo modules orphans`.

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

      Three launchers wrap the agents themselves, as sandboxed alternatives to
      the plain binaries rather than replacements:

      - `nono-claude`, `nono-codex`, `nono-reasonix`

      They exist because nono confines a *process tree*: the process you type and
      every descendant of it, subagents included, under one profile - there is
      nothing per-subagent to configure. Two things follow that are worth
      knowing before suggesting one. Each launcher grants read-write on the
      directory you type it from, so type it in a repository and not in `$HOME`.
      And a child cannot widen what its parent was given, so an agent started
      inside one of these cannot spawn another agent outside it.

      `nono-reasonix` runs with `REASONIX_HOME=~/.reasonix-nono`, a second
      rendered home whose config differs from `~/.reasonix/config.toml` in one
      value: reasonix's own `bubblewrap` jail cannot start inside a nono session,
      so `[sandbox] bash` is `"off"` there. Plain `reasonix` is unchanged and
      keeps its jail.

      Definitions are in `homes/programs/nono.nix`; profiles at
      `~/.config/nono/profiles/<name>.json`, generated - a read-only store
      symlink, so `nono profile promote` cannot write one.

      Caveat on NixOS: nono's ELF resolver fails to find `libc.so.6` for
      `libgcc_s.so.1`, so its `command_policies` feature does not work here -
      any profile carrying it fails to start. Filesystem, network and credential
      confinement are unaffected; only per-command differentiation is missing.
    '';
}
