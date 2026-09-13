#!/usr/bin/env nu

# Clear the GitHub "Releases only" watches that were drowning the inbox.
#
# GitHub exposes no way to enumerate a custom watch: /user/subscriptions omits
# them and GET .../subscription answers 404. Notification history is the only
# place they are observable, so the queue is mined from there - which also
# means a repo stays hidden until it actually publishes a release.
#
#   gh-release-unwatch                # what is queued
#   gh-release-unwatch list           # rebuild the queue
#   gh-release-unwatch reset --apply  # reset them

# Report the queue without touching anything.
def main [] {
  let dir = state-dir
  let queued = read-lines $"($dir)/repos.txt"
  let done = read-lines $"($dir)/done.log"
  let remaining = $queued | where {|repo| $repo not-in $done}

  print $"queued ($queued | length), reset ($done | length), remaining ($remaining | length)"
  print $"state in ($dir)"
}

# Rebuild the queue, minus the repos held as full "All activity" watches -
# those are deliberate, and a release from one would otherwise sweep it up.
def "main list" [] {
  let dir = state-dir
  let watched = gh api /user/subscriptions --paginate -q '.[].full_name' | lines
  let targets = release-repos | where {|repo| $repo not-in $watched} | sort

  $targets | str join "\n" | save --force $"($dir)/repos.txt"
  print $"($targets | length) repos queued in ($dir)/repos.txt"
}

# Reset each queued repo to "Participating and @mentions". Dry by default;
# done.log makes a re-run skip whatever already succeeded.
def "main reset" [--apply] {
  let dir = state-dir
  let done = read-lines $"($dir)/done.log"
  let todo = read-lines $"($dir)/repos.txt" | where {|repo| $repo not-in $done}

  if not $apply {
    $todo | each {|repo| print $"dry-run  ($repo)"} | ignore
    print $"($todo | length) would be reset, ($done | length) already done"
    return
  }

  let failed = $todo | enumerate | each {|it|
    let ok = reset-watch $it.item
    if $ok { $"($it.item)\n" | save --append $"($dir)/done.log" }
    let status = if $ok { "ok  " } else { "FAIL" }
    print $"[($it.index + 1)/($todo | length)] ($status) ($it.item)"
    if $ok { null } else { $it.item }
  } | compact

  print $"done: (($todo | length) - ($failed | length)) ok, ($failed | length) failed"
}

# State cannot live beside the script: this file is read-only in the store.
def state-dir []: nothing -> string {
  let dir = [($env.XDG_DATA_HOME? | default $"($env.HOME)/.local/share") "gh-release-unwatch"] | path join
  mkdir $dir
  $dir
}

def read-lines [file: string]: nothing -> list<string> {
  if ($file | path exists) { open $file | lines } else { [] }
}

def release-repos []: nothing -> list<string> {
  gh api '/notifications?all=true&per_page=100' --paginate -q '.[] | select(.subject.type=="Release") | .repository.full_name' | lines | uniq
}

# A custom watch is invisible to the API, so DELETE alone is a no-op. PUT
# forces a real subscription record that DELETE can then remove.
#
# The body goes through the pipeline rather than via `-F`: gh reads piped
# stdin as the request body, and an empty pipe makes it fail on every call.
def reset-watch [repo: string]: nothing -> bool {
  let put = {subscribed: true} | to json | gh api -X PUT $"repos/($repo)/subscription" --input - | complete
  if $put.exit_code != 0 { return false }
  let del = gh api -X DELETE $"repos/($repo)/subscription" | complete
  $del.exit_code == 0
}
