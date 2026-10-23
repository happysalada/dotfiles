#!/usr/bin/env nu
# Rustic backups of /home and /var/lib/fundies onto the second drive. Config is
# environment from modules/rustic-local.nix; design in docs/rustic-local-backup.md.

def main [] {
  help main
}

# Create the repository, once, on the verified backup drive.
def "main init" [] {
  require-backup-disk
  if ($env.RUSTIC_REPOSITORY | path join config | path exists) {
    error make { msg: $"($env.RUSTIC_REPOSITORY) is already a repository" }
  }
  for dir in [$env.RUSTIC_REPOSITORY $env.RUSTIC_CACHE_DIR] {
    mkdir $dir
    # Already compressed and encrypted; zstd would only burn CPU. New dirs only.
    ^btrfs property set $dir compression none
  }
  ^rustic init
}

# One run: temporary read-only snapshots, rustic over them, snapshots removed.
def "main backup" [--preflight] {
  require-backup-disk --repo
  sweep-stale
  audit-nested-subvolumes

  let run = ($env.SNAP_DIR | path join $"rustic-(date now | format date '%Y%m%dT%H%M%S')")
  mkdir $run
  let failure = try {
    snapshot-sources $run
    if $preflight { preflight $run } else { backup-all $run }
    null
  } catch {|e| $e.msg }
  remove-run $run
  if $failure != null { error make { msg: $failure } }
}

# Retention, then reclaim what no kept snapshot references.
def "main forget" [] {
  require-backup-disk --repo
  (^rustic forget --prune --max-unused 5%
    --keep-daily $env.KEEP_DAILY --keep-weekly $env.KEEP_WEEKLY --keep-monthly $env.KEEP_MONTHLY)
}

# Structure always, plus a random slice of pack data read back.
def "main check" [] {
  require-backup-disk --repo
  ^rustic check --read-data-subset $env.CHECK_SUBSET
}

# Remove snapshots a killed run left behind.
def "main sweep" [] {
  sweep-stale
}

# The drive must be mounted, be the expected filesystem, and hold the repository.
def require-backup-disk [--repo] {
  let mount = $env.BACKUP_MOUNT
  let found = (^findmnt --noheadings --output UUID,FSTYPE --mountpoint $mount | complete)
  if $found.exit_code != 0 {
    error make { msg: $"($mount) is not mounted; refusing to write a backup" }
  }
  let fields = ($found.stdout | str trim | split row --regex '\s+')
  if ($fields | first) != $env.BACKUP_FS_UUID {
    error make { msg: $"($mount) has filesystem UUID ($fields | first), expected ($env.BACKUP_FS_UUID)" }
  }
  if ($fields | get 1) != "btrfs" {
    error make { msg: $"($mount) is ($fields | get 1), expected btrfs" }
  }
  if not ($env.RUSTIC_REPOSITORY | str starts-with $"($mount)/") {
    error make { msg: $"($env.RUSTIC_REPOSITORY) is not under ($mount)" }
  }
  if $repo and not ($env.RUSTIC_REPOSITORY | path join config | path exists) {
    error make { msg: $"no repository at ($env.RUSTIC_REPOSITORY); start rustic-local-init first" }
  }
}

# Anything named like our runs is stale: the module's flock serialises runs.
# btrbk's snapshots live elsewhere and never match.
def sweep-stale [] {
  if not ($env.SNAP_DIR | path exists) { return }
  let stale = (ls --full-paths $env.SNAP_DIR | where type == dir | get name
    | where {|p| ($p | path basename) =~ '^rustic-\d{8}T\d{6}$' })
  for run in $stale { remove-run $run }
}

# Only subvolumes are deleted, and only one level down: never `rm -r`.
def remove-run [run: string] {
  let entries = (ls --all --full-paths $run | get name | each {|entry|
    if (is-subvolume $entry) {
      try { ^btrfs subvolume delete $entry; null } catch {|e| $"($entry): ($e.msg)" }
    } else {
      $"($entry) is not a snapshot subvolume, left alone"
    }
  } | compact)
  let errors = if ($entries | is-empty) {
    try { ^rmdir $run; [] } catch {|e| [$"($run): ($e.msg)"] }
  } else { $entries }
  if not ($errors | is-empty) {
    error make { msg: $"could not remove ($run): ($errors | str join '; ')" }
  }
}

# A btrfs subvolume's root is always inode 256.
def is-subvolume [path: string] {
  (^stat --format '%i' $path | str trim) == "256"
}

# Snapshots do not recurse, so a subvolume nested in a protected path is backed
# up as an empty directory - unless the path is skipped, where nothing under it
# is read at all.
def audit-nested-subvolumes [] {
  let paths = (^btrfs subvolume list $env.TOPLEVEL | lines | parse --regex 'path (?<path>.+)$' | get path)
  let strays = (protected | each {|d| strays-in $paths $d } | flatten)
  if not ($strays | is-empty) {
    error make { msg: $"subvolumes nested in a protected path would be skipped: ($strays | str join ', ')" }
  }
}

# [{name, volume, path, tree, globs, excludes}]: `volume` is snapshotted and its
# copy of `path` is stored as `path`. `tree` is `path` from the filesystem root,
# as `btrfs subvolume list` prints it. `globs` is the exclusion glob file for
# `--glob-file`; `excludes` is the list it is written from.
def protected [] {
  $env.PROTECTED | from json
}

# A stray under an excluded tree is not a stray: rustic reads nothing there.
def strays-in [paths: list<string>, d: record] {
  let skipped = ($d.excludes | each {|g| glob-regex $g })
  $paths
  | where {|p| $p | str starts-with $"($d.tree)/" }
  | where {|p|
      let rel = ($p | str substring (($d.tree | str length)..))
      not ($skipped | any {|r| $rel =~ $r })
    }
}

# rustic's globs: `**` is any depth, `*` is one path segment, the rest is literal.
def glob-regex [pattern: string] {
  let segments = ($pattern | split row '**' | each {|part|
    $part
    | split row '*'
    | each {|literal| regex-escape $literal }
    | str join '[^/]*'
  })
  let joined = ($segments | str join '.*')
  $"^($joined)$"
}

# `\` first: replacing it later would escape the backslashes the others insert.
def regex-escape [text: string] {
  ['\' '.' '^' '$' '+' '?' '(' ')' '[' ']' '{' '}' '|']
  | reduce -f $text {|c, escaped| $escaped | str replace --all --no-expand $c ('\' + $c) }
}

# `/` first, so its snapshot does not carry the other snapshots as nested subvolumes.
def snapshot-sources [run: string] {
  for d in (protected | sort-by volume) {
    ^btrfs subvolume snapshot -r $d.volume ($run | path join $d.name)
  }
}

# Paths exist and are populated, and the repository opens; no data moves.
def preflight [run: string] {
  for d in (protected) {
    if (ls --all (snapshot-path $run $d) | is-empty) {
      error make { msg: $"($d.path) is empty in its snapshot" }
    }
  }
  ^rustic repoinfo | ignore
}

def snapshot-path [run: string, d: record] {
  $run | path join $d.name | path join ($d.path | path relative-to $d.volume)
}

# Every dataset is attempted, so one failure does not hide the other's. Runs
# inside the snapshot with `.` as source because globs anchor to the working
# directory; --as-path keeps the stored path, and so the parent, stable.
def backup-all [run: string] {
  let writers = if (writers-active) { "writers-active" } else { "writers-idle" }
  let failed = (protected | each {|d|
    cd (snapshot-path $run $d)
    try {
      (^rustic backup --as-path $d.path --tag $d.name --tag $writers
        --glob-file $d.globs --one-file-system --no-scan --skip-if-unchanged .)
      null
    } catch { $d.name }
  } | compact)
  if not ($failed | is-empty) {
    error make { msg: $"rustic backup failed for: ($failed | str join ', ')" }
  }
}

def writers-active [] {
  (^pgrep -f '(^|/)(fundies-archiver|fundies-reconcile|fundies-publish|esef-release)( |$)' | complete).exit_code == 0
}
