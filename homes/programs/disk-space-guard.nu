#!/usr/bin/env nu
# One toast per disk when it gets worse. The toast never expires (homes/niri/mako.nix),
# so the last level and free % are kept in $XDG_STATE_HOME and a new toast needs a
# worse level or a 2-point drop. Readings are df availability, never summed du.

# `warn`/`critical` are free-space %. The primary keeps ~15% as working headroom.
const disks = [
  { name: "primary", mount: "/", warn: 20, critical: 15, hint: "`dua i /` or `nh clean all` shrinks it" }
  { name: "backup", mount: "/mnt/backup", warn: 15, critical: 8, hint: "rustic-local-forget prunes it; check the retention in modules/rustic-local.nix" }
]

def main [] {
  for d in $disks { check $d }
}

def check [d: record] {
  let state = (state-file $d.name)
  let reading = (read-disk $d)

  if $reading.level == 0 {
    # Back above the threshold: forget, so the next crossing speaks.
    if ($state | path exists) { rm --force $state }
    return
  }

  let last = (try { open --raw $state | split row ' ' | into int } catch { [0 100] })
  if $last.0 >= $reading.level and ($last.1 - $reading.free) < 2 { return }

  let urgency = if $reading.level == 2 { "critical" } else { "normal" }
  notify-send --app-name disk --urgency $urgency $reading.title $reading.body

  mkdir ($state | path dirname)
  $"($reading.level) ($reading.free)" | save --force $state
}

def state-file [name: string] {
  ($env.XDG_STATE_HOME? | default ($env.HOME | path join '.local/state'))
  | path join disk-space-guard $"($name).last-notified"
}

# {level: 0|1|2, free: percent, title, body}. Unmounted is critical: df would
# answer for / instead.
def read-disk [d: record] {
  if (^findmnt --mountpoint $d.mount | complete).exit_code != 0 {
    return { level: 2, free: -1, title: $"($d.name) disk is not mounted", body: $"($d.mount) is missing; backups cannot run" }
  }

  let row = (^df --block-size=1 --output=avail,size $d.mount | lines | last | split row --regex '\s+' | where $it != '' | into int)
  let free = (($row.0 * 100) // $row.1)
  let level = if $free < $d.critical { 2 } else if $free < $d.warn { 1 } else { 0 }
  let left = (^df -h --output=avail $d.mount | lines | last | str trim)
  { level: $level, free: $free, title: $"($d.name) disk has ($free)% free", body: $"($left) free on ($d.mount) - ($d.hint)" }
}
