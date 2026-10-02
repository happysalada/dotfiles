---
name: condense-comments
description: Use when comments have outgrown the code they explain - a file, a diff, or a repository that reads as prose with code in it. Condenses implementation and doc comments down to the why, deletes the ones that restate the code, and collapses dashed section banners. Use when asked to condense, trim or shorten comments, cut comment bloat, or when a diff is mostly comment lines.
---

# Condense comments

A comment earns its lines by saying what the code cannot: a constraint, a
quirk, a reason the obvious version is wrong. Everything else is length the
reader pays for and skips.

Cut length, never meaning. Only explanation changes, so the diff must contain
comment lines and nothing else.

## One comment at a time

Ask what the line tells a reader that the code does not:

- **Keep to the letter** when it is a why - a platform quirk, a measured fact,
  a simpler version that fails, an order that matters, a format another
  program parses. Length is fine here; these are the lines that save an hour.
  Compress the prose around such a fact, never the fact.
- **Rewrite** when the why is real but arrives slowly: drop the build-up, the
  hedging and the example the code already shows, and lead with the fact.
- **Delete** when the next line, the name or the type already says it.

## Never cut

- `// SAFETY:` and any invariant an `unsafe` block rests on.
- Compatibility contracts: frozen wire codecs, endpoint generations, protocol
  version rationale, stable text other tools match - error messages, prompts,
  integration markers.
- References: issue and PR numbers, upstream commits, vendor patch names,
  Windows build numbers.
- `#[allow]` justifications; in herdr's AGENTS.md the comment is the price of
  the attribute.
- Structured lookups a reader scans rather than reads - encoding tables,
  accepted values, per-field meanings. A paragraph wrapped around one can go.
- Anything inside a `///` or `//!` code fence. Rust compiles those as
  doc-tests; other languages render them as documentation.

## Delete

- A line that restates the statement under it, however plainly. Half of these
  sit in test bodies, where the setup reads as obvious.
- Dashed section banners. One over a single item the item already names goes
  entirely; one over a group of items keeps a bare `// Server spawning` line.
- Narration and history - "first we", "now that", "we used to", "for now".
- Commented-out code, including the "kept for reference" kind.
- One caption per statement: three statements do not need three lines, and a
  body that reads plainly needs none at all.

## Doc comments condense too

`///` and `//!` follow the same rules with one difference: the summary line is
what a reader sees in the index, so it stays a sentence that says what the
item is for.

Cut the paragraphs explaining what the name already says, the walkthrough of
the body, and the second and third restatements of one fact. Keep the
contract: what the caller supplies, what comes back in the edge cases, what
blocks or panics.

## Scope a pass

Work from what was named - a path, a file, or the files in the current diff.
Do not sweep a whole repository on your own initiative; that is a different
request. For a repo-wide pass, go area by area and report each area as it
lands, so a half-finished sweep is never mistaken for a finished one.

`survey.nu` beside this file ranks the candidates:

```sh
nu <skill-dir>/survey.nu --paths src    # ranked files, long blocks, banners
nu <skill-dir>/survey.nu --json         # machine-readable
```

Treat its output as files to read, not as comments to cut: the longest block
in a file is often the one that has to stay.

## Prove that only comments changed

```sh
# Rust
git diff -U0 | rg '^[+-]' | rg -v '^(---|\+\+\+)' | rg -v '^[+-]\s*//'
# nix, shell, python
git diff -U0 | rg '^[+-]' | rg -v '^(---|\+\+\+)' | rg -v '^[+-]\s*#'
```

Nothing printed means no code line moved. Keep the two forms apart: `#[derive]`
is not a comment, and matching it would hide a real change. Then run the repo's
own gate - `cargo fmt --check`, `just check`, `ruff format --check` - as
confirmation that the tree is still well-formed.

## Report

A table of file to comment lines removed, then a bullet for each long comment
kept and the clause that made it worth its lines. No narrative.

## Worked examples

Restating the next line - delete the comment, not the line:

```rust
// Create the tokio runtime.
let rt = tokio::runtime::Builder::new_current_thread()
```

A banner over one item - delete both, the item below names the section:

```rust
// ---------------------------------------------------------------------------
// Server spawning
// ---------------------------------------------------------------------------

pub fn spawn_server_daemon() -> io::Result<u32> {
```

The why is real but arrives slowly - six lines to three:

```rust
// Position the cursor while it is still hidden, then restore visibility.
// Showing before moving makes slow terminals and IMEs briefly observe the
// cursor at the last painted cell, which can be an animated sidebar/status
// cell rather than the focused pane's input position. When the focused pane
// hides its cursor, still park the host cursor intentionally so IMEs do not
// anchor to whichever cell happened to be painted last.
```

```rust
// Move while still hidden: showing first lets slow terminals and IMEs observe
// the cursor on the last painted cell - an animated sidebar cell, say - and a
// focused pane that hides its cursor still needs the host cursor parked.
```

A constraint that cannot be derived from the code around it - keep it long:

```rust
// Explicit nonzero length is essential: FICLONE (or a zero range length)
// clones through EOF and source growth could exceed the reservation before
// post-validation.
// SAFETY: the request consumes a valid repr(C) range, both descriptors stay
// open throughout the call, and the source descriptor is never owned here.
```
