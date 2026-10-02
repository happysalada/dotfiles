---
name: diff-metrics
description: Use when reviewing a change for quality regressions. Measures complexity deltas (lizard, bca), duplication introduced by the change (jscpd) and the two SlopCodeBench metrics - verbosity and structural erosion - before and after a diff, so "this change is clean" is a number rather than an impression.
---

# Diff metrics

Measures a change rather than a repository: the same tree measured at `<base>`
and in the working tree, so the report is a delta. Four tools, each with a
different job:

| tool | question it answers |
| --- | --- |
| `scb-check` | verbosity and erosion - the two SlopCodeBench metrics |
| `bca` | per-file, per-metric complexity changes across the diff |
| `lizard` | which functions are too complex, by name |
| `jscpd` | which blocks are duplicated, and which of those this change added |

## Run it

The script sits next to this file:

```sh
nu <skill-dir>/measure.nu --base HEAD
nu <skill-dir>/measure.nu --base main --paths src   # scope both sides
nu <skill-dir>/measure.nu --json                    # machine-readable
```

It needs `git`, `scb-check`, `bca`, `lizard`, `jscpd` and `tar` on `PATH`, and
refuses to run outside a git repository. It touches nothing: no staging, no
commits, and the before side is `git archive <base>` extracted to a temp dir -
never a worktree, which stays opt-in.

## What the two paper metrics are

Verbatim from the paper (arXiv:2603.24755) and its `scb-check` implementation:

- **verbosity** = `|ast-grep flagged lines ∪ clone lines| / LOC`, bounded [0,1].
  Its two halves are reported separately as `ast_grep_flagged_loc` and
  `clone_loc`, which is more useful than the blended score - check which half
  moved before blaming "verbosity".
- **erosion** = the share of total complexity mass concentrated in functions
  with cyclomatic complexity > 10, where mass(f) = `CC(f) * sqrt(SLOC(f))`.
  `cog_erosion` is the same with cognitive complexity.

Reference points from the paper's calibration (whole-repo Python): maintained
human repositories sit at **verbosity 0.15 / erosion 0.31**, agent output at
**verbosity 0.33 / erosion 0.68**. Treat those as the scale, not as a threshold
to trip - the sample here is a diff, not a repository.

## Caveats that would otherwise mislead you

- **This is a diff-scoped number.** The paper defines both metrics over a whole
  codebase at one checkpoint. Both sides here use the same scope, so the *delta*
  is meaningful, but the absolute values are not comparable to the paper's table
  unless the scope is a whole repo. Say which scope you used.
- **On Rust, verbosity's rule half is thin.** The rule pack here is five
  hand-written Rust rules; the paper's 137 are Python-only. Expect
  `ast_grep_flagged_loc` of 0 on most real Rust until the pack grows, and do not
  read "0 flagged lines" as "no verbose code".
- **`.gitignore` is respected and `info`-severity rules are excluded**, because
  `--include-all` is deliberately not passed (it would also pull in `target/`
  and `node_modules/`). Several of the bundled Python rules are `info`.
- **`scb-check` exits 1 whenever it finds anything** - that is a finding, not a
  failure, and the script handles it. Exit 2 is a real error.
- **The one metric that overlaps** between `scb-check` and the other two is
  cyclomatic complexity: erosion is built on it, `bca` reports it, `lizard`
  ranks by it. Use `lizard`'s output to name the function, not to re-derive the
  number.
- **jscpd sees only the formats it has a grammar for.** Supported ones include
  rust, python, typescript, javascript and go; there is **no nix and no
  nushell**, so in this repo its scan covers the python, bash, json and markdown
  files and nothing else. Say that when quoting its percentage - and note that
  data files it does parse (a grafana dashboard JSON, a checked-in lockfile)
  inflate it, so `-i` is worth passing by hand when that is what filled the
  report.
- **jscpd's duplication and `scb-check`'s `clone_loc` are not the same number.**
  `clone_loc` is the aggregate the verbosity metric is built from; jscpd's
  `duplicatedLines` counts the lines in the pairs it detects and classifies.
  Read the aggregate for the trend and jscpd for the pair to fix, and do not
  expect them to agree.
- **New clones are marked against the ref's tree, not the working tree's
  parent.** `--baseline-from-ref <base>` has jscpd build the baseline from
  `<base>` itself, so uncommitted work that predates the session counts as new -
  pass the ref you actually branched from when that matters.

## Reporting the result

Lead with the delta, not the table: which metric moved, by how much, and whether
that is the half you expected. Then point at the function. Erosion rising with
`clone_loc` unchanged means a function got bigger or branchier rather than
duplicated - `bca` names the file, `lizard` names the function, and the fix is
usually to extract rather than to reformat.

Duplication is the one section that names both halves of the problem: a new
clone is a pair of line ranges, so the fix is to keep one of them and point the
other at it. When the report says new clones are zero while `clone_loc` rose,
the lines went into an *existing* clone - the aggregate moved and jscpd has
nothing new to show, which is a different fix (make the new caller use the
existing helper).
