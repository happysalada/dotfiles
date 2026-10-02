#!/usr/bin/env nu
# Diff-scoped code-quality report: the two SlopCodeBench metrics (verbosity and
# structural erosion) before and after a change, plus per-metric complexity
# deltas from bca, the worst functions touched, named by lizard, and duplication
# this change introduced, named by jscpd.
#
# Duplication comes from jscpd rather than from scb-check's `clone_loc`: one scan
# against the base ref's tree marks the clones that are new with `isNew`, and
# each pair arrives with its file, line range and kind. `clone_loc` stays in the
# table as the aggregate it is, so the two are read together - the aggregate for
# the trend, jscpd for the pair to fix.
#
# The before side is materialised with `git archive <ref>`, never a worktree:
# worktrees are opt-in, and `git archive` reads the object store without
# touching the index or the checkout.
#
# Diff-scoping caveat: the paper defines verbosity and erosion over a whole
# codebase at one checkpoint. Here both sides are the same scope - the repo, or
# `--paths` - so the delta is between two comparable states, not a number you
# can quote next to the paper's table without saying which scope it used.

const HUMAN_VERBOSITY = 0.15
const HUMAN_EROSION = 0.31
const AGENT_VERBOSITY = 0.33
const AGENT_EROSION = 0.68

def main [
  --base (-b): string = "HEAD"  # git ref to measure the before side from
  --paths (-p): string = ""     # limit both sides to this relative path
  --json                        # emit JSON instead of markdown
] {
  require-tools
  let tmp = (mktemp -d | str trim)

  # The report has to be captured and printed: a trailing `rm` would otherwise
  # become the function's value and the report would be discarded.
  let report = (try {
    let scope = (if $paths == "" { [] } else { [$paths] })
    let before = ($tmp | path join "before")
    mkdir $before
    materialize $base $scope $before
    let after = (if $paths == "" { "." } else { $paths })

    let payload = {
      base: $base
      scope: (if $paths == "" { "whole tree" } else { $paths })
      changed_files: (changed $base $scope)
      slop: (delta (scb $before) (scb $after))
      complexity: (complexity-diff $base $paths)
      worst_functions: (worst-touched $base $scope)
      duplication: (duplication $base $after $tmp)
    }

    if $json { $payload | to json --indent 2 } else { render $payload }
  } catch {|e|
    rm -rf $tmp
    # A bare "External command failed" loses which command and where; nu keeps
    # that in `debug`. Real messages (our own error make, a missing ref) are
    # already in `msg` and must not be replaced by the debug repr.
    let msg = ($e.msg | default "unknown error")
    let detail = (if $msg == "External command failed" { $e.debug } else { $msg })
    error make { msg: $"diff-metrics: ($detail)" }
  })

  rm -rf $tmp
  print $report
}

# ---------------------------------------------------------------------------
# The report

def render [p: record] {
  let d = $p.slop
  let flag = (verdict $d.after)
  let body = [
    $"## Complexity and slop: ($p.base) -> working tree"
    ""
    $"Scope: ($p.scope). Changed files: ($p.changed_files | length)."
    ""
    "| metric | before | after | change |"
    "| --- | ---: | ---: | ---: |"
    (row "verbosity" $d.before.verbosity $d.after.verbosity)
    (row "erosion" $d.before.erosion $d.after.erosion)
    (row "cog_erosion" $d.before.cog_erosion $d.after.cog_erosion)
    (row "clone_loc" $d.before.clone_loc $d.after.clone_loc)
    (row "ast_grep_flagged_loc" $d.before.ast_grep_flagged_loc $d.after.ast_grep_flagged_loc)
    (row "total_loc" $d.before.total_loc $d.after.total_loc)
    (row "functions" $d.before.total_functions $d.after.total_functions)
    (row "high_cc_functions" $d.before.high_cc_functions $d.after.high_cc_functions)
    ""
    $"Verdict: ($flag)"
    ""
    "Reference points from the paper (whole-repo, Python): maintained human"
    $"repos sit at verbosity ($HUMAN_VERBOSITY) / erosion ($HUMAN_EROSION); agent"
    $"output at verbosity ($AGENT_VERBOSITY) / erosion ($AGENT_EROSION)."
    ""
    "### Per-metric complexity deltas (bca)"
    ""
    (if ($p.complexity.stdout | str trim) == "" { "(bca produced no output)" } else { $p.complexity.stdout })
    ""
    "### Worst functions touched, by cyclomatic complexity (lizard, CCN >= 10)"
    ""
    "```"
    (if ($p.worst_functions | str trim) == "" { "(nothing over threshold)" } else { $p.worst_functions })
    "```"
    ""
    "### Duplication introduced by this change (jscpd)"
    ""
    (duplication-section $p.duplication)
  ] | str join (char nl)
  $body
}

# jscpd scans a subset of formats and has no grammar for nix or nushell, so the
# denominators here are whatever it could parse - say which, rather than letting
# a bare percentage imply the whole tree.
def duplication-section [d: record] {
  let head = if $d.new_clones == 0 {
    $"No new clones. ($d.duplicated_lines) of ($d.lines) lines in ($d.sources) parsed files are in clones, which the diff did not add to."
  } else {
    $"($d.new_clones) new clone\(s\), ($d.new_duplicated_lines) lines, against ($d.base)."
  }
  let pairs = ($d.new_entries | each {|c|
    $"- ($c.kind), ($c.lines) lines, ($c.tokens) tokens: `($c.first)` <-> `($c.second)`"
  })
  [$head] | append $pairs | str join (char nl)
}

def row [name: string, before: number, after: number] {
  let delta = ($after - $before)
  let sign = (if $delta > 0 { "+" } else { "" })
  $"| ($name) | (fmt $before) | (fmt $after) | ($sign)(fmt $delta) |"
}

# scb-check's counts are integers and would otherwise render as `112.0`.
def fmt [v: number] {
  if ($v | math floor) == $v {
    $v | into int | into string
  } else {
    $v | math round --precision 4 | into string
  }
}

# Against the paper's agent means - the number that says whether this looks
# like agent slop rather than maintained human code.
def verdict [m: record] {
  if $m.erosion >= $AGENT_EROSION and $m.verbosity >= $AGENT_VERBOSITY {
    "both metrics at or above the paper's agent mean"
  } else if $m.erosion >= $AGENT_EROSION {
    "erosion at or above the paper's agent mean"
  } else if $m.verbosity >= $AGENT_VERBOSITY {
    "verbosity at or above the paper's agent mean"
  } else {
    "both metrics below the paper's agent mean"
  }
}

# ---------------------------------------------------------------------------
# The three measurements

def delta [before: record, after: record] {
  {
    before: ($before | select verbosity erosion cog_erosion clone_loc ast_grep_flagged_loc total_loc total_functions high_cc_functions)
    after: ($after | select verbosity erosion cog_erosion clone_loc ast_grep_flagged_loc total_loc total_functions high_cc_functions)
  }
}

def scb [dir: string] {
  # Exit 0 is "no findings", 1 is "findings present" - both are a report.
  let r = (^scb-check check --report $dir | complete)
  if $r.exit_code > 1 {
    error make { msg: $"scb-check failed on ($dir): ($r.stderr | str trim)" }
  }
  $r.stdout | from json
}

def complexity-diff [base: string, paths: string] {
  let args = (if $paths == "" { [] } else { [$paths] })
  ^bca diff --since $base -O markdown ...$args | complete
}

def worst-touched [base: string, scope: list<string>] {
  let files = (changed $base $scope | where {|f| ($f | path exists) })
  if ($files | is-empty) { return "" }
  ^lizard -w -C 10 -s cyclomatic_complexity ...$files | complete | get stdout
}

def changed [base: string, scope: list<string>] {
  let tracked = (^git diff --name-only $base | complete).stdout | lines | where {|l| $l != "" }
  let untracked = (^git ls-files --others --exclude-standard | complete).stdout | lines | where {|l| $l != "" }
  let all = ($tracked | append $untracked | uniq)
  if ($scope | is-empty) {
    $all
  } else {
    $all | where {|f| ($scope | any {|s| ($f == $s) or ($f | str starts-with $s) }) }
  }
}

# One scan, not two: `--baseline-from-ref` has jscpd build an ephemeral baseline
# from the ref's own tree with this same configuration, so the subtraction
# happens inside jscpd and every entry carries `isNew`. `.gitignore` is respected
# by default, which matters for the same reason it does in scb-check - it keeps
# `target/` and `node_modules/` out of the scan.
def duplication [base: string, scope: string, tmp: string] {
  let out = ($tmp | path join "jscpd")
  mkdir $out
  let r = (^jscpd -k 50 -r json -o $out --baseline-from-ref $base $scope | complete)
  let report = ($out | path join "jscpd-report.json")
  # jscpd exits non-zero when it finds clones, so the report file - not the exit
  # code - is what says whether the run worked.
  if not ($report | path exists) {
    error make { msg: $"jscpd produced no report for ($scope): ($r.stderr | str trim)" }
  }
  let total = ((open $report).statistics.total? | default { })
  let entries = (((open $report).duplicates? | default [ ]) | where {|c| ($c.isNew? | default false) })
  {
    base: $base
    clones: ($total.clones? | default 0)
    duplicated_lines: ($total.duplicatedLines? | default 0)
    lines: ($total.lines? | default 0)
    sources: ($total.sources? | default 0)
    new_clones: ($total.newClones? | default 0)
    new_duplicated_lines: ($total.newDuplicatedLines? | default 0)
    # Capped: the point is to name the pair to fix, not to dump a report. The
    # count above stays the real one.
    new_entries: ($entries | first 10 | each {|c| {
      kind: ($c.kind? | default "?")
      lines: ($c.lines? | default 0)
      tokens: ($c.tokens? | default 0)
      first: (clone-site $c.firstFile)
      second: (clone-site $c.secondFile)
    } })
  }
}

def clone-site [file: record] {
  $"($file.name):($file.start)-($file.end)"
}

# ---------------------------------------------------------------------------
# Plumbing

def materialize [base: string, scope: list<string>, dest: string] {
  if (^git rev-parse --verify --quiet $base | complete | get exit_code) != 0 {
    error make { msg: $"no such ref: ($base)" }
  }
  let args = (if ($scope | is-empty) { [] } else { ["--" ...$scope] })
  # Piped external-to-external on purpose: `complete` would capture stdout as
  # text and corrupt the tar stream, so the exit code is checked instead.
  ^git archive $base ...$args | ^tar -x -C $dest
  if $env.LAST_EXIT_CODE != 0 {
    error make { msg: $"extracting ($base) into ($dest) failed" }
  }
}

def require-tools [] {
  let missing = ["git" "scb-check" "bca" "lizard" "jscpd" "tar"] | where {|t| (which $t | is-empty) }
  if not ($missing | is-empty) {
    error make { msg: $"not on PATH: ($missing | str join ', ')" }
  }
  if (^git rev-parse --git-dir | complete | get exit_code) != 0 {
    error make { msg: "not inside a git repository" }
  }
}
