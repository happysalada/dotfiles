# reasonix's [statusline] command, rebuilt.
#
# reasonix prints the first stdout line in place of the footer's data row, and
# hands over one JSON object on stdin - {"model","contextUsed","contextWindow",
# "cwd"} - which carries none of that row except the context pair. Everything
# else is read back from where reasonix reads it: the compaction threshold from
# the config in play, cache/cost/rate band from the live session's own wire log,
# balance from the provider's balance_url. The directory comes from this
# process's working directory, because the payload's `cwd` is reasonix's session
# directory rather than the workspace.

def rx-home []: nothing -> string {
  $env.REASONIX_HOME? | default ($nu.home-dir | path join ".reasonix")
}

# The config reasonix itself would load: user/global, project over it - the
# precedence `reasonix doctor` reports.
def rx-config []: nothing -> record {
  let user = (rx-home | path join config.toml)
  let project = ("./reasonix.toml" | path expand)
  let base = (try { if ($user | path exists) { open $user } else { {} } } catch { {} })
  let local = (try { if ($project | path exists) { open $project } else { {} } } catch { {} })
  $base | merge deep $local
}

# reasonix does not put <home>/.env into this command's environment (measured),
# so the key reasonix itself would use is read from that file.
def api-key [name: string] {
  if ($name | is-empty) { return null }
  let keyFromEnv = ($env | get --optional $name)
  if ($keyFromEnv | is-not-empty) { return $keyFromEnv }
  let file = (rx-home | path join ".env")
  if not ($file | path exists) { return null }
  let line = (try { open $file | lines | where {|l| $l | str starts-with $"($name)=" } | get --optional 0 } catch { null })
  if $line == null { return null }
  $line | str replace $"($name)=" ""
}

# 6376 -> 6.4K, the shape reasonix prints.
def tokens [n: int] {
  if $n >= 1000000 {
    $"($n / 1000000 | math round --precision 1)M"
  } else if $n >= 1000 {
    $"($n / 1000 | math round --precision 1)K"
  } else {
    $n | into string
  }
}

# Fixed decimals, because nushell prints 99.8 as 99.8 and would drop the trailing
# zero the row wants: reasonix renders both money and the cache rates this way.
def fixed [value: float, digits: int] {
  let unit = (10 ** $digits)
  let scaled = (($value * $unit) | math round | into int)
  let whole = ($scaled // $unit)
  let zeros = ("0000" | str substring 0..<$digits)
  let full = ($zeros + ($scaled mod $unit | into string))
  let frac = ($full | str substring (($full | str length) - $digits)..)
  $"($whole).($frac)"
}

# Four decimals under a dollar (the receipts' own scale), two above it.
def money [amount: float, symbol: string] {
  let digits = (if ($amount | math abs) >= 1 { 2 } else { 4 })
  $"($symbol)(fixed $amount $digits)"
}

# Cache hit rates, spend and rate band, straight out of the live session's wire
# log - the same usage records the receipts are built from. The session* token
# counts are cumulative, so the last record settles the average; that record's
# own cacheHitTokens/cacheMissTokens pair is the turn's rate, which is what
# reasonix's `turn hit` counts. Cost is per attempt, so it is summed.
def session-usage [dir: string] {
  if ($dir | is-empty) { return null }
  # The payload names the session *directory*, not the session, so the live one
  # is the newest wire log in it - reasonix writes one per session and keeps
  # appending to the log of the session that is running.
  let log = (
    (try { ls $dir } catch { [] })
    | where {|f| $f.name | str ends-with ".wire.jsonl" }
    | sort-by modified --reverse
    | get --optional 0
  )
  if $log == null { return null }
  # Wire logs are JSONL, and this nushell has no `from jsonl`, so the records
  # are parsed one line at a time; a half-written last line is skipped rather
  # than allowed to take the row down with it.
  let usage = (
    (try { open --raw $log.name | lines } catch { [] })
    | where {|l| ($l | str trim | is-not-empty) }
    | each {|l| try { $l | from json } catch { null } }
    | where {|r| ($r != null) and (($r.usage? | is-not-empty)) }
    | each {|r| $r.usage }
  )
  if ($usage | is-empty) { return null }
  let last = ($usage | last)
  {
    turnHit: ($last.cacheHitTokens? | default 0),
    turnMiss: ($last.cacheMissTokens? | default 0),
    hit: ($last.sessionCacheHitTokens? | default 0),
    miss: ($last.sessionCacheMissTokens? | default 0),
    spent: ($usage | each {|u| $u.costUsd? | default 0 } | math sum),
    currency: ($last.currency? | default "$"),
    band: ($last.costQuote?.rateBand? | default ""),
  }
}

def symbol-for [code: string] {
  match $code { "USD" => "$", "CNY" => "¥", _ => $"($code) " }
}

# The wallet endpoint the provider in play declares, asked with its own key.
# Silent on any failure: a statusline may not break a session over a slow API.
def balance-text [cfg: record, model: string] {
  let provider = (
    $cfg.providers? | default []
    | where {|p| ($p.name? == $model) or ($p.model? == $model) }
    | get --optional 0
  )
  if $provider == null { return null }
  let url = ($provider.balance_url?)
  let key = (api-key ($provider.api_key_env? | default ""))
  if ($url == null) or ($key == null) { return null }
  try {
    let infos = (^curl -s -m 2 -H $"Authorization: Bearer ($key)" $url | from json | get --optional balance_infos | default [])
    if ($infos | is-empty) { return null }
    let info = (($infos | where {|i| $i.currency? == "USD" } | get --optional 0) | default ($infos | first))
    let total = (($info.total_balance? | default "0") | into float)
    $"BALANCE (money $total (symbol-for ($info.currency? | default "")))"
  } catch { null }
}

def main [] {
  # `from json` hands back its input unchanged when the text does not parse, so
  # the shape is checked rather than the parse trusted; anything else and the
  # row is built from the config and the directory alone.
  let payload = (do {
    let raw = (try { open --raw /dev/stdin | into string } catch { "" })
    let parsed = (try { $raw | from json } catch { null })
    if (($parsed | describe) | str starts-with "record") { $parsed } else { {} }
  })
  let cfg = (rx-config)
  let cwd = ($env.PWD? | default ("." | path expand))
  let model = ($payload.model? | default "")

  # Directory first: outside a git repo reasonix's own row shows no location at
  # all, and inside one only the repository name. Rendered by starship, so it
  # carries the same colour and truncation as the shell prompt's own segment.
  # `module directory`, not `prompt --profile`: a profile that is not installed
  # still exits 0 with a bare `>` on stdout (measured), and a statusline cannot
  # tell that from a directory. The module reads this process's cwd rather than
  # --path, which is the workspace because reasonix runs the command there.
  let dir = (do {
    let run = (^starship module directory | complete)
    let out = ($run.stdout? | default "" | str trim)
    if ($run.exit_code? == 0) and ($out | is-not-empty) {
      $out
    } else {
      $cwd
    }
  })

  let used = ($payload.contextUsed? | default 0)
  let window = ($payload.contextWindow? | default 0)
  let ctx = (
    if $window > 0 {
      let pct = ($used * 100 / $window | math round)
      $"CTX (tokens $used) \(($pct)%\)"
    } else {
      null
    }
  )

  let ratio = ($cfg.agent?.compact_ratio? | default 0.8)
  let compact = (if $ratio > 0 { $"COMPACT (($ratio * 100) | math round)%" } else { null })

  # Every read is allowed to fail without taking the row with it: a statusline
  # that prints nothing is worse than one that prints fewer numbers.
  let usage = (try { session-usage ($payload.cwd? | default "") } catch { null })
  # `CACHE turn hit 99.81% · avg 99.08%`, reasonix's own two figures: the
  # turn's rate from the last request, the average over the session so far.
  let cache = (do {
    let parts = (
      [
        (if ($usage != null) and (($usage.turnHit + $usage.turnMiss) > 0) {
          $"turn hit (fixed ($usage.turnHit * 100 / ($usage.turnHit + $usage.turnMiss)) 2)%"
        } else {
          null
        })
        (if ($usage != null) and (($usage.hit + $usage.miss) > 0) {
          $"avg (fixed ($usage.hit * 100 / ($usage.hit + $usage.miss)) 2)%"
        } else {
          null
        })
      ]
      | where {|part| $part != null }
    )
    if ($parts | is-empty) { null } else { $"CACHE ($parts | str join " · ")" }
  })
  let cost = (if ($usage != null) and ($usage.spent > 0) { $"COST (money $usage.spent $usage.currency)" } else { null })
  let band = (
    if ($usage != null) and (($usage.band | is-not-empty)) {
      match $usage.band { "off_peak" => "off-peak", _ => ($usage.band | str lowercase) }
    } else { null }
  )

  let bal = (try { balance-text $cfg $model } catch { null })

  let segments = ([ $dir $ctx $compact $cache $bal $cost $band ] | where {|s| ($s | is-not-empty) })
  print -n ($segments | str join "  ")
}

