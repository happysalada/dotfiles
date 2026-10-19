#!/usr/bin/env nu
# One reading of /, one notification if it got worse. The toast never expires
# (homes/niri/mako.nix), so an hourly timer must not repeat itself: the last
# percentage it spoke about is kept in $XDG_STATE_HOME and a new toast needs a
# 2-point rise or a new threshold.

const warn = 90
const critical = 95

def main [] {
  let used = (df --output=pcent / | lines | last | str trim | str replace --all '%' '' | into int)
  let state = (
    ($env.XDG_STATE_HOME? | default ($env.HOME | path join '.local/state'))
    | path join disk-space-guard last-notified
  )
  let last = (try { open --raw $state | into int } catch { 0 })

  if $used < $warn {
    # Below the threshold again: forget, so the next crossing speaks.
    if ($state | path exists) { rm --force $state }
    return
  }

  let level = if $used >= $critical { $critical } else { $warn }
  if $last >= $level and ($used - $last) < 2 { return }

  let free = (df --output=avail -h / | lines | last | str trim)
  let urgency = if $used >= $critical { "critical" } else { "normal" }
  notify-send --app-name disk --urgency $urgency $"Root filesystem is ($used)% full" $"($free) free on / - `dua i /` or `nh clean all` shrinks it"

  mkdir ($state | path dirname)
  $used | save --force $state
}
