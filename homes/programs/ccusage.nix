# ccusage as one prompt segment: the active Claude usage block, which is what a
# subscription is measured in - five hours of usage, then a reset.
#
# The block is the half worth a prompt; `ccusage daily` changes once a day and
# belongs on a command line. Time until reset changes what you do next, and the
# cost beside it is the share of the window already spent. Both are notional:
# ccusage prices the tokens the local logs record, and a subscription was not
# charged for them.
#
# A starship custom module rather than `ccusage statusline`, which would replace
# the starship profile Claude Code already uses. Add `$custom` to
# profiles.claude-code in homes/common.nix to show this segment there too.
{ pkgs, lib, ... }:
let
  # Named by store path: a prompt does not always inherit the shell's PATH (a
  # hook, a systemd unit or another agent's sandbox may not have it).
  ccusage = lib.getExe pkgs.ccusage;

  # Measured: 17ms for nu to start, 19ms for this script against a warm cache,
  # and 50-260ms for the ccusage run that fills it. Hence the cache - one refresh
  # a minute instead of one per prompt - and `writeNu`, not `writeNuBin`: the
  # module below references this by path and never merges it into an environment.
  block = pkgs.writers.writeNu "ccusage-block" ''
    const TTL = 60sec

    def main [] {
      let cache = (cache-path)
      if (fresh $cache) {
        print --no-newline (open --raw $cache)
        return
      }
      let text = (segment)
      mkdir ($cache | path dirname)
      $text | save --force $cache
      print --no-newline $text
    }

    # The active block, rendered, or an empty string when there is none - which
    # is the usual case, since a block only exists while it is being used.
    def segment [] {
      let r = (^${ccusage} blocks --json --offline --active | complete)
      if $r.exit_code != 0 { return "" }
      let blocks = (try { $r.stdout | from json | get blocks } catch { [] })
      if ($blocks | is-empty) { return "" }

      let b = ($blocks | first)
      let left = (($b.endTime | into datetime) - (date now))
      # --active means one block, but nothing stops that block's end time from
      # having passed; a stale number is worse than no number.
      if $left < 0sec { return "" }

      let cost = ($b.costUSD? | default 0)
      let dollars = (if ($cost | math round --precision 2) > 0 {
        (["$" (($cost | math round --precision 2) | into string)] | str join)
      } else {
        ""
      })
      [$dollars (left-text $left)] | where {|part| $part != "" } | str join " · "
    }

    def left-text [d: duration] {
      let mins = ($d / 1min | math floor | into int)
      let hours = ($mins / 60 | math floor)
      let rest = ($mins mod 60)
      if $hours > 0 { $"($hours)h($rest)m" } else { $"($rest)m" }
    }

    def cache-path [] {
      # An empty XDG_CACHE_HOME is treated as unset: `default` only catches a
      # missing variable, and an empty one would otherwise put the cache under
      # the root directory, where the write fails and every prompt recomputes.
      let xdg = ($env.XDG_CACHE_HOME? | default "")
      let base = (if $xdg == "" { $env.HOME | path join ".cache" } else { $xdg })
      $base | path join "ccusage" "block"
    }

    # The cache file's modification time is the timestamp, so there is no second
    # file to keep in step with it.
    def fresh [cache: string] {
      if not ($cache | path exists) { return false }
      ((date now) - (ls $cache | get 0.modified)) < $TTL
    }
  '';
in
{
  programs.starship.settings.custom.ccusage = {
    command = "${block}";
    format = "[$output]($style) ";
    style = "bold yellow";
    description = "Active Claude block: notional cost and time until reset";
  };
}
