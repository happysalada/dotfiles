"""Weekly digest of what shipped in the GitHub repos I have starred.

Roughly 1700 stars, of which ~70% see a push in any given week and ~40% cut a
release, so "released recently" is not a digest - it is a wall. Two filters do
the cutting: only feature releases survive, a patch bump being noise, and what
survives is ranked by the stars the repo gained since last week, the one signal
saying other people noticed too.

Star deltas mean last week has to be on disk. Every run reads the most recent
snapshot older than the current ISO week, then records its own under that week
- so a second run inside the same week still diffs against last week rather
than against itself, and reproduces the same digest.
"""

from __future__ import annotations

import datetime as dt
import functools
import os
import pathlib
import re
import sqlite3
import subprocess

import httpx2
from prefect import flow, task
from prefect.logging import get_run_logger

STATE_DIR = (
    pathlib.Path(os.environ["STARRED_DIGEST_STATE"])
    if os.environ.get("STARRED_DIGEST_STATE")
    else pathlib.Path(
        os.environ.get("XDG_STATE_HOME") or pathlib.Path.home() / ".local/state"
    )
    / "starred-digest"
)


@flow(name="starred-digest", log_prints=True)
def starred_digest(
    window_days: int = 7,
    top_n: int = 15,
    model: str = "mistral-nemo",
) -> str:
    """Fetch every starred repo, pick the highlights, write the digest."""
    log = get_run_logger()
    now = dt.datetime.now(dt.UTC)
    cutoff = now - dt.timedelta(days=window_days)

    repos = fetch_starred()
    log.info("fetched %d starred repos", len(repos))

    week = week_key(now)
    previous = load_previous(week)
    save_snapshot(repos, week)

    candidates = select_feature_releases(repos, previous, cutoff)
    ranked = rank_by_star_delta(candidates)
    fresh = newly_starred(repos, cutoff)
    log.info(
        "%d feature releases in window, %d newly starred, %d repos seen before",
        len(ranked),
        len(fresh),
        len(previous),
    )

    sentences = summarize(ranked[:top_n], model) if ranked else {}
    path = write_digest(
        week, ranked, fresh, sentences, top_n, window_days, bool(previous)
    )
    notify(path, len(ranked))
    return str(path)


def fetch_starred() -> list[dict]:
    """Every starred repo, flattened to one dict each. About 17 requests."""
    repos: list[dict] = []
    cursor = None
    while True:
        page = fetch_page(cursor)
        repos.extend(flatten(edge) for edge in page["edges"])
        if not page["pageInfo"]["hasNextPage"]:
            return repos
        cursor = page["pageInfo"]["endCursor"]


STARRED_QUERY = """
query($cursor: String) {
  viewer {
    starredRepositories(first: 100, after: $cursor,
                        orderBy: {field: STARRED_AT, direction: DESC}) {
      pageInfo { hasNextPage endCursor }
      edges {
        starredAt
        node {
          nameWithOwner url description stargazerCount pushedAt isArchived
          primaryLanguage { name }
          latestRelease { name tagName publishedAt description url }
        }
      }
    }
  }
}
"""


@task(retries=3, retry_delay_seconds=[5, 20, 60])
def fetch_page(cursor: str | None) -> dict:
    """One page of 100 starred repos. Costs a single rate-limit point."""
    response = http().post(
        "https://api.github.com/graphql",
        headers={"Authorization": f"bearer {github_token()}"},
        json={"query": STARRED_QUERY, "variables": {"cursor": cursor}},
    )
    response.raise_for_status()
    body = response.json()
    # GraphQL reports failure inside a 200 body, so raise_for_status is not enough.
    if "errors" in body:
        raise RuntimeError(f"github graphql: {body['errors']}")
    return body["data"]["viewer"]["starredRepositories"]


@functools.cache
def http() -> httpx2.Client:
    """One HTTP/2 client, so the paginated requests share a single connection.

    Seventeen round trips to the same host is exactly the case h2 multiplexing
    is for. It falls back to HTTP/1.1 per connection via ALPN, which is what
    the local ollama gets.
    """
    return httpx2.Client(http2=True, timeout=60)


@functools.cache
def github_token() -> str:
    """An explicit token if there is one, otherwise the one gh already holds.

    `gh auth token` reaches the login keyring from a systemd user unit while
    the session is unlocked, which beats minting a PAT that then needs its own
    rotation. GITHUB_TOKEN still wins, for a headless run with no keyring.
    """
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        return token
    try:
        result = subprocess.run(
            ["gh", "auth", "token"],
            capture_output=True,
            text=True,
            check=True,
            timeout=15,
        )
    except (FileNotFoundError, subprocess.SubprocessError) as error:
        raise RuntimeError(
            "no github token: run `gh auth login`, or set GITHUB_TOKEN"
        ) from error
    return result.stdout.strip()


def flatten(edge: dict) -> dict:
    """One starred-repository edge, with the bits actually used pulled up."""
    node = edge["node"]
    release = node.get("latestRelease") or {}
    language = node.get("primaryLanguage") or {}
    return {
        "repo": node["nameWithOwner"],
        "url": node["url"],
        "description": node.get("description") or "",
        "stars": node["stargazerCount"],
        "pushed_at": node.get("pushedAt"),
        "archived": node["isArchived"],
        "language": language.get("name"),
        "starred_at": edge["starredAt"],
        "tag": release.get("tagName"),
        "release_name": release.get("name"),
        "release_at": release.get("publishedAt"),
        "release_body": release.get("description") or "",
        "release_url": release.get("url"),
    }


def week_key(moment: dt.datetime) -> str:
    """ISO week, e.g. 2026-W36. Sorts lexicographically, new year included."""
    year, week, _ = moment.isocalendar()
    return f"{year}-W{week:02d}"


def load_previous(week: str) -> dict[str, dict]:
    """The most recent snapshot taken before `week`. Empty on the first run.

    Keying by week rather than by run is what makes "week over week" mean what
    it says: a second run inside the same week still diffs against last week,
    so re-running never silently reports that nothing changed.
    """
    with db() as connection:
        baseline = connection.execute(
            "SELECT max(week) FROM repo_state WHERE week < ?", (week,)
        ).fetchone()[0]
        if baseline is None:
            return {}
        rows = connection.execute(
            "SELECT repo, stars, tag FROM repo_state WHERE week = ?", (baseline,)
        ).fetchall()
    return {repo: {"stars": stars, "tag": tag} for repo, stars, tag in rows}


SCHEMA = """
CREATE TABLE IF NOT EXISTS repo_state (
  week  TEXT NOT NULL,
  repo  TEXT NOT NULL,
  stars INTEGER NOT NULL,
  tag   TEXT,
  PRIMARY KEY (week, repo)
);
"""


def db() -> sqlite3.Connection:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(STATE_DIR / "state.db")
    connection.executescript(SCHEMA)
    return connection


KEEP_WEEKS = 8


@task
def save_snapshot(repos: list[dict], week: str) -> None:
    """Record this week, and drop snapshots too old to be anyone's baseline."""
    with db() as connection:
        connection.executemany(
            "INSERT INTO repo_state (week, repo, stars, tag) VALUES (?,?,?,?) "
            "ON CONFLICT(week, repo) DO UPDATE SET "
            "stars=excluded.stars, tag=excluded.tag",
            [(week, r["repo"], r["stars"], r["tag"]) for r in repos],
        )
        connection.execute(
            "DELETE FROM repo_state WHERE week NOT IN "
            "(SELECT week FROM (SELECT DISTINCT week FROM repo_state "
            " ORDER BY week DESC LIMIT ?))",
            (KEEP_WEEKS,),
        )


PRERELEASE = re.compile(r"(?i)(alpha|beta|rc\d|[-.]rc|dev|nightly|snapshot|preview)")


def select_feature_releases(
    repos: list[dict], previous: dict[str, dict], cutoff: dt.datetime
) -> list[dict]:
    """Releases published in the window that are more than a bug-fix bump."""
    selected = []
    for repo in repos:
        if repo["archived"] or not repo["release_at"]:
            continue
        if parse_time(repo["release_at"]) < cutoff:
            continue
        if PRERELEASE.search(repo["tag"] or ""):
            continue

        was = previous.get(repo["repo"])
        bump = bump_kind(was["tag"] if was else None, repo["tag"])
        if bump not in ("major", "minor"):
            continue

        selected.append(
            repo
            | {
                "bump": bump,
                "star_delta": repo["stars"] - was["stars"] if was else None,
                "previous_tag": was["tag"] if was else None,
            }
        )
    return selected


def parse_time(value: str) -> dt.datetime:
    return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))


def bump_kind(previous_tag: str | None, current_tag: str | None) -> str:
    """major/minor/patch for this release, against the one seen last week.

    With no previous tag - a repo's first appearance - the tag has to speak for
    itself, and a zero patch component is the best available tell that it is a
    feature release rather than a fix.
    """
    current = parse_version(current_tag)
    if current is None:
        return "unknown"
    prior = parse_version(previous_tag)
    if prior is None:
        return "patch" if current[2] else "minor"
    if current[0] != prior[0]:
        return "major"
    if current[1] != prior[1]:
        return "minor"
    if current[2] != prior[2]:
        return "patch"
    return "none"


VERSION = re.compile(r"(\d+)\.(\d+)(?:\.(\d+))?")


def parse_version(tag: str | None) -> tuple[int, int, int] | None:
    match = VERSION.search(tag or "")
    if not match:
        return None
    return (int(match[1]), int(match[2]), int(match[3] or 0))


def rank_by_star_delta(candidates: list[dict]) -> list[dict]:
    """Biggest weekly star gain first; repos with no history sink to the end."""
    return sorted(
        candidates,
        key=lambda c: (c["star_delta"] is not None, c["star_delta"] or 0, c["stars"]),
        reverse=True,
    )


def newly_starred(repos: list[dict], cutoff: dt.datetime) -> list[dict]:
    return [r for r in repos if parse_time(r["starred_at"]) >= cutoff]


def summarize(highlights: list[dict], model: str) -> dict[str, str]:
    """One sentence per repo, keyed by repo.

    The model gets no say over links, tags or counts: it hallucinates version
    numbers, and every one of those facts is already known here. Never fatal -
    the ranked data is the deliverable and the prose is a bonus.
    """
    log = get_run_logger()
    releases = "\n\n".join(
        f"- {h['repo']} ({h['tag']}, {h['bump']} bump, "
        f"{fmt_delta(h['star_delta'])} stars this week, {h['stars']} total)\n"
        f"  about: {h['description'][:300]}\n"
        f"  notes: {(h['release_body'] or '(none)')[:1200]}"
        for h in highlights
    )
    try:
        raw = call_ollama(PROMPT.format(releases=releases), model)
    except (httpx2.HTTPError, KeyError, ValueError) as error:
        log.warning("ollama summary failed, writing digest without prose: %s", error)
        return {}
    return parse_sentences(raw, {h["repo"] for h in highlights})


PROMPT = """You are writing the highlights of a weekly digest for a developer, \
covering new releases in repositories they have starred.

Write exactly one line per release, in the order given, formatted as:

owner/name :: one sentence on what actually changed and why it might matter

Name the concrete feature. If the release notes say nothing substantive, say \
that plainly rather than padding. Do not add links, version numbers, bullets, \
numbering, preamble or closing text - only those lines.

Releases:

{releases}
"""


@task(retries=2, retry_delay_seconds=10)
def call_ollama(prompt: str, model: str) -> str:
    ollama = os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434")
    response = http().post(
        f"{ollama}/api/generate",
        json={"model": model, "prompt": prompt, "stream": False},
        timeout=600,
    )
    response.raise_for_status()
    return response.json()["response"].strip()


def parse_sentences(raw: str, expected: set[str]) -> dict[str, str]:
    """Pull `repo :: sentence` lines out, ignoring whatever else it emitted."""
    sentences = {}
    for line in raw.splitlines():
        repo, _, sentence = line.partition("::")
        repo = repo.strip().lstrip("-*# ").strip("`*")
        if repo in expected and sentence.strip():
            sentences[repo] = sentence.strip()
    return sentences


def write_digest(
    week: str,
    ranked: list[dict],
    fresh: list[dict],
    sentences: dict[str, str],
    top_n: int,
    window_days: int,
    had_history: bool,
) -> pathlib.Path:
    lines = [
        f"# Starred digest - {week}",
        "",
        (
            f"{len(ranked)} feature releases in the last {window_days} days, "
            f"{len(fresh)} repos newly starred."
        ),
    ]
    if not had_history:
        lines += [
            "",
            (
                "> First run: there is no previous snapshot to diff against, so "
                "star deltas are absent and releases were classified by tag shape "
                "alone. Next week's digest will rank properly."
            ),
        ]

    if ranked:
        lines += ["", "## Highlights", ""] + [
            bullet(h, sentences.get(h["repo"], "")) for h in ranked[:top_n]
        ]
    if len(ranked) > top_n:
        lines += ["", "## Also shipped", ""] + [bullet(h) for h in ranked[top_n:]]
    if fresh:
        lines += ["", "## Newly starred", ""] + [
            f"- [{r['repo']}]({r['url']}) - {r['description'][:160]}" for r in fresh
        ]

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    path = STATE_DIR / f"{week}.md"
    path.write_text("\n".join(lines) + "\n")

    latest = STATE_DIR / "latest.md"
    latest.unlink(missing_ok=True)
    latest.symlink_to(path.name)
    return path


def bullet(h: dict, sentence: str = "") -> str:
    """Every fact here is the API's; only `sentence` comes from the model."""
    return (
        f"- [{h['repo']}]({h['release_url'] or h['url']}) `{h['tag']}` "
        f"({h['bump']}, {fmt_delta(h['star_delta'])} stars) - "
        f"{sentence or h['description'][:160]}"
    )


def fmt_delta(delta: int | None) -> str:
    return "new" if delta is None else f"{delta:+d}"


def notify(path: pathlib.Path, count: int) -> None:
    """Desktop notification, if there is a session listening for one."""
    try:
        subprocess.run(
            [
                "notify-send",
                "--app-name=starred-digest",
                f"{count} releases in your starred repos",
                str(path),
            ],
            check=False,
            timeout=10,
        )
    except (FileNotFoundError, subprocess.SubprocessError):
        pass


if __name__ == "__main__":
    print(starred_digest())
