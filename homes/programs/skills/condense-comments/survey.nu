#!/usr/bin/env nu
# Comment survey for a condense pass: which files carry the most comment lines,
# where the long comment blocks are, and where the dashed banners are.
#
# The ranking is volume, not badness - read a block before cutting it, because
# the longest one in a file is often the constraint that has to stay.
#
# Tracked files only, so vendored trees and build output stay out. Prefixes are
# inferred from the extension and runs are counted per line, not per syntax
# tree: a comment-looking line inside a string still counts, which is why the
# output is a candidate list rather than a verdict.

const FAMILIES = {
  slash: [rs go ts tsx js jsx mjs cjs c h cc cpp cxx hpp hh java kt swift cs zig dart scala proto]
  hash: [nu sh bash zsh fish py pyi rb pl r nix toml yaml yml tf hcl mk tcl ini cfg]
  dash: [sql hs lua elm]
}

const SKIP_DIRS = [vendor node_modules target dist build third_party generated .venv .git]

def main [
  --paths (-p): string = ""   # limit the survey to this path or directory
  --min-block (-m): int = 4   # shortest comment run listed as a block
  --limit (-l): int = 20      # files shown in the volume ranking
  --blocks (-b): int = 40     # blocks listed
  --json                      # emit JSON instead of markdown
] {
  let surveyed = (
    candidate-files $paths
    | each {|file| { file: $file, stats: (try { file-stats $file $min_block } catch { null }) } }
  )
  let rows = ($surveyed | where {|row| $row.stats != null } | get stats)
  let skipped = ($surveyed | where {|row| $row.stats == null } | get file)
  if $json {
    { skipped: $skipped, files: $rows } | to json --indent 2
  } else {
    report $rows $skipped $min_block $limit $blocks
  }
}

def is-repo [] {
  ((^git rev-parse --is-inside-work-tree | complete).exit_code == 0)
}

def ext-family [file: string] {
  let ext = ($file | path parse | get extension? | default "" | str lowercase)
  if $ext in $FAMILIES.slash {
    "//"
  } else if $ext in $FAMILIES.hash {
    "#"
  } else if $ext in $FAMILIES.dash {
    "--"
  } else {
    null
  }
}

def candidate-files [paths: string] {
  let tracked = (if (is-repo) {
    (^git ls-files | lines)
  } else {
    (glob --no-dir **/* | each {|p| $p | path relative-to $env.PWD })
  })
  $tracked
  | where {|file| (ext-family $file) != null }
  | where {|file| not ($file | path split | any {|part| $part in $SKIP_DIRS }) }
  | where {|file| $paths == "" or ($file | str starts-with $paths) }
}

def file-stats [file: string, min_block: int] {
  let prefix = (ext-family $file)
  let lines = (open --raw $file | lines)
  let total = ($lines | length)
  let test_start = (
    $lines
    | enumerate
    | where {|row| $row.item =~ '(?i)^\s*(pub )?mod tests' }
    | get index
    | last
    | default $total
  )

  mut index = 0
  mut comments = 0
  mut docs = 0
  mut banners = 0
  mut blocks = []
  while $index < $total {
    if ($lines | get $index | str trim | str starts-with $prefix) {
      mut end = $index
      mut run_docs = 0
      while ($end < $total) and ($lines | get $end | str trim | str starts-with $prefix) {
        let text = ($lines | get $end | str trim)
        let body = ($text | str substring ($prefix | str length)..)
        $comments = $comments + 1
        if ($prefix == "//") and (($body | str starts-with "/") or ($body | str starts-with "!")) {
          $docs = $docs + 1
          $run_docs = $run_docs + 1
        }
        if ($body | str trim | str starts-with "---") {
          $banners = $banners + 1
        }
        $end = $end + 1
      }
      let run = ($end - $index)
      if $run >= $min_block {
        $blocks = ($blocks | append {
          line: ($index + 1)
          lines: $run
          doc_only: ($run_docs == $run)
          tests: ($index > $test_start)
        })
      }
      $index = $end
    } else {
      $index = $index + 1
    }
  }

  {
    file: $file
    comments: $comments
    docs: $docs
    banners: $banners
    blocks: $blocks
  }
}

def report [rows: list, skipped: list, min_block: int, limit: int, blocks: int] {
  let ranked = ($rows | where {|row| $row.comments > 0 } | sort-by comments --reverse)
  let found = (
    $ranked
    | each {|row|
      $row.blocks | each {|block| { file: $row.file, line: $block.line, lines: $block.lines, doc_only: $block.doc_only, tests: $block.tests } }
    }
    | flatten
    | sort-by lines --reverse
  )
  let banner_rows = ($ranked | where {|row| $row.banners > 0 } | sort-by banners --reverse)
  let sum = {|column| $ranked | get $column | math sum }

  print $"# Comment survey"
  print ""
  print $"($ranked | length) files, (do $sum comments) comment lines \((do $sum docs) documentation\), (do $sum banners) banner lines"
  if not ($skipped | is-empty) {
    print $"($skipped | length) unreadable files skipped: ($skipped | str join ', ')"
  }
  print ""
  print "| comments | docs | banners | longest | file |"
  print "| ---: | ---: | ---: | ---: | --- |"
  for row in ($ranked | first $limit) {
    let longest = (if ($row.blocks | is-empty) { 0 } else { $row.blocks | get lines | math max })
    print $"| ($row.comments) | ($row.docs) | ($row.banners) | ($longest) | ($row.file) |"
  }

  print ""
  print $"## Blocks of ($min_block)+ lines — ($found | length)"
  for block in ($found | first $blocks) {
    let kind = (if $block.tests { "tests" } else if $block.doc_only { "doc" } else { "code" })
    print $"- ($block.file):($block.line) — ($block.lines) lines, ($kind)"
  }

  if not ($banner_rows | is-empty) {
    print ""
    print $"## Dashed banners — ($banner_rows | length) files"
    for row in ($banner_rows | first $limit) {
      print $"- ($row.file) — ($row.banners) lines"
    }
  }
}
