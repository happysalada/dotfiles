---
name: cli-toolbox
description: Use when the work is text, file or data plumbing from the shell - convert, query, count, bulk-edit - or when it needs a terminal tool for reviewing a change, running agents in parallel, querying a repo by meaning, or driving a page. The installed tools whose job is not guessable from their name, with the traps.
---

# CLI toolbox

Everything here is installed system-wide and already on `PATH`. The Tooling
table in the global instructions holds the substitutions that fire constantly
(`sd`, `choose`, `fd`, `bat`, `nu -c`, `jg`, `ast-grep`, `xh`, `rga`, `tokei`,
`dua`, `tldr`). This file is the tail: the tools whose *job* is not guessable
from the name.

## Data and files

| tool | job | first command |
| --- | --- | --- |
| `qsv` | SQL, joins and stats over CSV, no import step; the file's basename is the table | `qsv sqlp d.csv 'select b, count(*) from d group by b'` |
| | infer a JSON Schema from a CSV, written to `<file>.schema.json` | `qsv schema d.csv` |
| | CSV to JSONL, for the JSON tools | `qsv tojsonl d.csv` |
| `tokei` | per-language line counts | `tokei -o json` |
| `dua` | `du` that finishes; `dua diff` compares two snapshots | `dua aggregate .` |
| `jscpd` | duplicated blocks, named as pairs rather than a percentage | `jscpd src/` |
| `sqlite3` | query a SQLite file directly - `icm` and `funes` both keep one | `sqlite3 db.sqlite '.tables'` |
| `numbat` | units-aware calculator, so conversions stop being arithmetic | `numbat -e '2 GiB / (30 MiB/s)'` |
| `ouch` | one interface for every archive, listing included | `ouch list x.tar.zst` |
| `rga` | ripgrep that reads PDFs, .docx, ebooks and zip members | `rga pattern docs/` |

`file`, `tree`, `zip`/`unzip` and `b3sum` do what they say.

## Query a repo by meaning

Both index the tree they search, and neither index belongs in the repo's
history: `codegraph init` writes `.codegraph/` and `ck --sem` writes `.ck/`
into the root they index. `ck`'s is not relocatable - `CK_INDEX_DIR` does
nothing - so a read-only checkout fails outright. Ask before creating one.

| tool | job |
| --- | --- |
| `ck --sem "error handling" src/` | semantic search; `ck --hybrid` fuses it with grep |
| `codegraph init`, then `codegraph query` | per-project structural graph |

Both are also MCP servers, so prefer the registered MCP tool where there is
one. `graphify`, `fff` and `funes` are described in the global instructions.

## Review a change

| tool | job |
| --- | --- |
| `revdiff` | annotate a diff, quit, and the annotations come back as `## file:line` markdown to act on |
| `tuicr -w` | the human's review tool: one continuous diff, comments pushed to the forge through `gh` |
| `plannotator-tui <file.md>` | annotate markdown - plans and reports, which the two above do not cover |

All three want a terminal. `revdiff` and `plannotator-tui` open in a Zellij
floating pane, so hand the command to the human rather than launching it from
a tool call.

## Run several agents

| tool | job |
| --- | --- |
| `wt switch --create <branch>` | worktree per agent, branch included; `wt list` aggregates their status |
| `orx` | claude-code/codex/opencode over one repo, each in its own worktree, every run recorded against the commit it ran on; `orx up` serves the dashboard |
| `herdr` | owns the terminals: pane idle/working/blocked, prompt a neighbour, wait for blocked instead of firing keystrokes |
| `agent-browser` | drives a real Chrome; start with `agent-browser skills get core` |

`terminal-browser` has a skill of its own.

## Run something long or repeatable

| tool | job |
| --- | --- |
| `pueue add -- <cmd>` | queue it on a daemon, outliving the session; `pueue status` |
| `watchexec -e rs <cmd>` | re-run on change, instead of polling in a loop |
| `just --list` | a repo's intended entry points, when it ships a justfile |
| `hyperfine '<a>' '<b>'` | compare two commands, warmup and statistics included |
| `prek run` | the repo's `.pre-commit-config.yaml`, without installing hook shims |

## Traps

- **The binary name is not the package name.** `tw` is tabiew, `ig` is igrep,
  `btm` is bottom, `sk` is skim, `difft` is difftastic. `--help` on the package
  name reports "not found".
- **A TUI blocks a tool call.** `tw`, `ig`, `sk`, `btm`, `jjui`, `yazi`,
  `tuicr` and `herdr` all want a keyboard; launched from a non-interactive call
  they hang or fail. Use the CLI surface where there is one (`herdr api`,
  `tuicr review`, `plannotator-tui --export`) or hand the command over.
- **Do not run the installers.** `orx install-skills`, `orx update`,
  `herdr integration install`, `tuicr update`, `cargo agents init` and
  `crw setup` each write agent config that nix generates, or target the
  read-only store.
