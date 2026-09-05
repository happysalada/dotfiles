---
name: orx
description: Drive automated ML research on OpenResearch with the `orx` CLI — create experiments, launch and monitor runs on compute, analyze local results and logs, and search literature. Use whenever the user wants to understand, explain, explore, or work on an OpenResearch project, run experiments, do auto-research, or mentions orx or OpenResearch.
---

# OpenResearch (`orx`)

You drive OpenResearch through the `orx` command-line tool. The authoritative
operating manual is bundled inside the CLI, so **load it at the start of every
session** instead of relying on this file or prior memory.

## 1. Load the bundled guide

```bash
orx skill
```

This prints the current manual — the cardinal rules and a command
quick-reference — followed by a **bundled index of modules**. Read it before taking
any action. For the detail on a specific area, run `orx skill <name>` to print
that module (e.g. `orx skill experiment-tree`, `orx skill compute`); the same
command reads that module directly from the installed CLI.

## 2. Carry out the user's research goal

Follow the auto-research loop from the guide: create the baseline experiment
first when the project is empty, branch variants off it, fill the user's available
GPU capacity with useful parallel runs, wait on completions, and analyze each result before deciding
to repair, refill, promote, or stop.

Local research commands do not require an OpenResearch login. If a managed
compute or account command reports `Not logged in`, ask the user to run
`orx login`.
