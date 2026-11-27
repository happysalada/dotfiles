#!/usr/bin/env nu
# Import these dashboards into GreptimeDB's dashboard store, which is what the
# Visualization tab lists and renders.
#
# Requires a greptimedb built with the `dashboard` cargo feature: the
# /v1/dashboards routes are behind `#[cfg(feature = "dashboard")]`, and nixpkgs
# builds 1.2.1 with no features, so it answers 404 today.
#
# The UI itself saves through POST /v1/dashboards/<name> with the dashboard as
# a JSON string in `content`; this does the same, one file at a time.
def main [
    --base-url: string = "http://127.0.0.1:4000" # greptimedb's HTTP API; the dashboard UI proxies here
    --dry-run # print what would be sent, send nothing
] {
    let here = ($env.CURRENT_FILE | path dirname)
    let files = (glob $"($here)/*.json" | sort)

    let results = ($files | each {|file|
        let doc = (open $file)
        let name = $doc.metadata.name
        if $dry_run {
            print $"would POST ($name) \(($file | path basename))"
            return { name: $name, code: "dry-run" }
        }

        let payload = ({ content: ($doc | to json) } | to json)
        let code = (^curl -sS -o /dev/null -w '%{http_code}' -X POST
            -H 'content-type: application/json' --data-binary $payload
            $"($base_url)/v1/dashboards/($name)" | str trim)
        print $"($name): HTTP ($code)"
        { name: $name, code: $code }
    })

    let failed = ($results | where code != "200" and code != "dry-run")
    if $dry_run {
        print $"($results | length) dashboards ready \(dry run, nothing sent\)"
    } else if ($failed | is-empty) {
        print $"($results | length) dashboards stored"
    } else {
        print -e $"($failed | length) failed. If every code is 404, this greptimedb lacks the dashboard feature."
    }
}
