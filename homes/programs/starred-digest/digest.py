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
from collections.abc import Iterable
from dataclasses import dataclass
from typing import Any, Literal

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
    max_summaries: int = 80,
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

    ranked = rank_by_star_delta(select_feature_releases(repos, previous, cutoff))
    fresh = newly_starred(repos, cutoff)
    log.info(
        "%d feature releases in window, %d newly starred, %d repos seen before",
        len(ranked),
        len(fresh),
        len(previous),
    )

    summaries = summarize(ranked, model, max_summaries)
    path = write_digest(
        week, ranked, fresh, summaries, top_n, window_days, bool(previous)
    )
    notify(path, len(ranked))
    return str(path)


@dataclass(frozen=True, slots=True)
class Repo:
    """A starred repository, reduced to the fields the digest actually reads."""

    name: str  # owner/name
    url: str
    description: str
    stars: int
    archived: bool
    starred_at: str
    tag: str | None
    release_name: str | None
    release_at: str | None
    release_body: str
    release_url: str | None


def fetch_starred() -> list[Repo]:
    """Every starred repo. About 17 requests, one rate-limit point each."""
    repos: list[Repo] = []
    cursor = None
    while True:
        page = fetch_page(cursor)
        repos.extend(to_repo(edge) for edge in page["edges"])
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
          nameWithOwner url description stargazerCount isArchived
          latestRelease { name tagName publishedAt description url }
        }
      }
    }
  }
}
"""


@task(retries=3, retry_delay_seconds=[5, 20, 60])
def fetch_page(cursor: str | None) -> dict:
    """One page of 100 starred repos, as GraphQL returns it."""
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


def to_repo(edge: dict) -> Repo:
    """One starred-repository edge. The only place the API's shape is assumed."""
    node = edge["node"]
    release = node.get("latestRelease") or {}
    return Repo(
        name=node["nameWithOwner"],
        url=node["url"],
        description=node.get("description") or "",
        stars=node["stargazerCount"],
        archived=node["isArchived"],
        starred_at=edge["starredAt"],
        tag=release.get("tagName"),
        release_name=release.get("name"),
        release_at=release.get("publishedAt"),
        release_body=release.get("description") or "",
        release_url=release.get("url"),
    )


def week_key(moment: dt.datetime) -> str:
    """ISO week, e.g. 2026-W36. Sorts lexicographically, new year included."""
    year, week, _ = moment.isocalendar()
    return f"{year}-W{week:02d}"


@dataclass(frozen=True, slots=True)
class Baseline:
    """What one repo looked like in the previous weekly snapshot."""

    stars: int
    tag: str | None


Snapshot = dict[str, Baseline]  # keyed by Repo.name


def load_previous(week: str) -> Snapshot:
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
    return {repo: Baseline(stars=stars, tag=tag) for repo, stars, tag in rows}


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
def save_snapshot(repos: list[Repo], week: str) -> None:
    """Record this week, and drop snapshots too old to be anyone's baseline."""
    with db() as connection:
        connection.executemany(
            "INSERT INTO repo_state (week, repo, stars, tag) VALUES (?,?,?,?) "
            "ON CONFLICT(week, repo) DO UPDATE SET "
            "stars=excluded.stars, tag=excluded.tag",
            [(week, r.name, r.stars, r.tag) for r in repos],
        )
        connection.execute(
            "DELETE FROM repo_state WHERE week NOT IN "
            "(SELECT week FROM (SELECT DISTINCT week FROM repo_state "
            " ORDER BY week DESC LIMIT ?))",
            (KEEP_WEEKS,),
        )


Bump = Literal["major", "minor", "patch", "none", "unknown"]

# What counts as worth reporting. "none" means the tag has not moved since last
# week, so the release was already in a previous digest.
FEATURE_BUMPS: frozenset[Bump] = frozenset({"major", "minor"})


@dataclass(frozen=True, slots=True)
class Highlight:
    """A release worth reporting, with the context that ranked it."""

    repo: Repo
    bump: Bump
    star_delta: int | None  # None when the repo predates the baseline
    previous_tag: str | None

    @property
    def tag_display(self) -> str:
        """`Repo.tag` is optional, but selection only keeps parseable ones."""
        return self.repo.tag or "?"


PRERELEASE = re.compile(r"(?i)(alpha|beta|rc\d|[-.]rc|dev|nightly|snapshot|preview)")


def select_feature_releases(
    repos: list[Repo], previous: Snapshot, cutoff: dt.datetime
) -> list[Highlight]:
    """Releases published in the window that are more than a bug-fix bump."""
    selected = []
    for repo in repos:
        if repo.archived or not repo.release_at:
            continue
        if parse_time(repo.release_at) < cutoff:
            continue
        if PRERELEASE.search(repo.tag or ""):
            continue

        was = previous.get(repo.name)
        bump = bump_kind(was.tag if was else None, repo.tag)
        if bump not in FEATURE_BUMPS:
            continue

        selected.append(
            Highlight(
                repo=repo,
                bump=bump,
                star_delta=repo.stars - was.stars if was else None,
                previous_tag=was.tag if was else None,
            )
        )
    return selected


def parse_time(value: str) -> dt.datetime:
    return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))


def bump_kind(previous_tag: str | None, current_tag: str | None) -> Bump:
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


def rank_by_star_delta(candidates: list[Highlight]) -> list[Highlight]:
    """Biggest weekly star gain first; repos with no history sink to the end."""
    return sorted(
        candidates,
        key=lambda c: (
            c.star_delta is not None,
            c.star_delta or 0,
            c.repo.stars,
        ),
        reverse=True,
    )


def newly_starred(repos: list[Repo], cutoff: dt.datetime) -> list[Repo]:
    return [r for r in repos if parse_time(r.starred_at) >= cutoff]


Summaries = dict[str, str]  # Repo.name -> one line about what the release changed


def summarize(highlights: list[Highlight], model: str, limit: int) -> Summaries:
    """One line per release, describing the release rather than the repository.

    Every release gets its own call. Batching fifteen into one prompt and asking
    for a strict line format is what the first version did, and a 12B model
    simply ignored the format - it answered with markdown sections, nothing
    parsed, and every bullet silently fell back to the repo blurb. One release
    per call needs no format at all: the reply *is* the sentence.
    """
    log = get_run_logger()
    summaries: Summaries = {}
    considered = highlights[:limit]
    from_commits = 0
    for highlight in considered:
        asked = summary_prompt(highlight)
        if asked is None:
            continue
        prompt, source = asked
        try:
            sentence = tidy_sentence(ask_ollama(prompt, model))
        except (httpx2.HTTPError, KeyError, ValueError) as error:
            log.warning("summary failed for %s: %s", highlight.repo.name, error)
            continue
        if not sentence or sentence.lower().startswith("no release notes"):
            continue
        if source == "commits":
            from_commits += 1
            sentence += " _(from commits)_"
        summaries[highlight.repo.name] = sentence
    log.info(
        "summarised %d of %d releases (%d from commits)",
        len(summaries),
        len(considered),
        from_commits,
    )
    return summaries


RULES = """Rules:
- ONE sentence, at most 30 words. Begin with a verb.
- Name only the two or three most significant changes, not every entry.
- Write about THIS RELEASE only. Never describe what the project is or who it
  is for - the reader already starred it and knows.
- No quotation marks, no bullets, no preamble."""

NOTES_PROMPT = """Summarise what changed in one software release, in a single sentence.

Repository: {repo}
Release: {tag}
Release notes:
{notes}

{rules}
- If the notes say nothing about what changed, reply exactly: no release notes"""

COMMITS_PROMPT = """Summarise what changed in one software release, in a single sentence.

This release shipped no notes, so what follows are the commit subjects it
contains. Describe the themes across them rather than listing them.

Repository: {repo}
Release: {tag}
{count} commits since {previous}:
{commits}

{rules}"""


def summary_prompt(highlight: Highlight) -> tuple[str, str] | None:
    """What to ask about this release, and which source the answer came from.

    Release notes when there are any. Otherwise the commits the release
    actually contains, which is the difference between a useful line and
    "no release notes" for the handful of projects that tag without writing
    anything - `git log` is, after all, where the notes would have come from.
    """
    notes = clean_notes(highlight.repo.release_body)
    if notes:
        return (
            NOTES_PROMPT.format(
                repo=highlight.repo.name,
                tag=highlight.tag_display,
                notes=notes,
                rules=RULES,
            ),
            "notes",
        )

    found = commits_in_release(highlight.repo)
    if found is None:
        return None
    previous, total, subjects = found
    return (
        COMMITS_PROMPT.format(
            repo=highlight.repo.name,
            tag=highlight.tag_display,
            count=total,
            previous=previous,
            commits="\n".join(f"- {subject}" for subject in subjects),
            rules=RULES,
        ),
        "commits",
    )


# GitHub's auto-generated notes are mostly scaffolding: image tags, changelog
# links, "by @user in #123". The signal is the pull request titles underneath.
MD_LINK = re.compile(r"\[([^\]]*)\]\([^)]*\)")
ATTRIBUTION = re.compile(r"\s+by\s+@[\w-]+(?:\s+in\s+(?:#\d+|https?://\S+))?")
FULL_CHANGELOG = re.compile(r"(?im)^\s*\*{0,2}Full Changelog\*{0,2}\s*:.*$")
# A list item of one whitespace-free token is an image ref or a bare url, never
# prose - which is what strips the container-tag blocks big projects open with.
LONE_TOKEN = re.compile(r"(?im)^\s*(?:[-*+]\s*)?(?:!\[|<img)?\S+$")
HEADING = re.compile(r"(?m)^#{1,6}\s*")


def clean_notes(body: str, limit: int = 1500) -> str:
    """Strip the scaffolding so the model sees changes rather than boilerplate."""
    text = FULL_CHANGELOG.sub("", body or "")
    text = MD_LINK.sub(r"\1", text)
    text = ATTRIBUTION.sub("", text)
    text = LONE_TOKEN.sub("", text)
    text = HEADING.sub("", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return re.sub(r"[ \t]{2,}", " ", text).strip()[:limit]


COMMIT_SUBJECTS = 60  # what the model sees; a big release ships far more


def commits_in_release(repo: Repo) -> tuple[str, int, list[str]] | None:
    """The commits a release contains: (previous tag, total, subjects).

    None when there is no sane base to compare against - a first release, or a
    monorepo component whose previous tag is not in reach. Comparing against
    another component's tag would describe the wrong software, so not answering
    is the better failure.
    """
    log = get_run_logger()
    previous = previous_release_tag(repo)
    if previous is None or not repo.tag:
        return None
    compare = github_rest(f"repos/{repo.name}/compare/{previous}...{repo.tag}")
    if compare is None:
        return None
    subjects = clean_commits(
        commit["commit"]["message"].splitlines()[0]
        for commit in compare.get("commits", [])
    )
    if not subjects:
        return None
    log.info("%s: %s..%s, %d commits", repo.name, previous, repo.tag, len(subjects))
    return (
        previous,
        compare.get("total_commits", len(subjects)),
        subjects[:COMMIT_SUBJECTS],
    )


RELEASES_SCANNED = 50


def previous_release_tag(repo: Repo) -> str | None:
    """Highest released version below this one that shares its tag prefix.

    Neither "the next entry in the list" nor "the previous by date" works.
    GitHub orders releases by creation, and a project backporting to stable
    branches publishes v259.9 after v261.3; a monorepo interleaves tags for
    components that share no history at all. Prefix plus version order is what
    picks v261.2 over v260.5, and refuses rather than crossing components.
    """
    releases = github_rest(
        f"repos/{repo.name}/releases", {"per_page": str(RELEASES_SCANNED)}
    )
    current = parse_version(repo.tag)
    if releases is None or current is None:
        return None

    prefix = tag_prefix(repo.tag)
    best: tuple[tuple[int, int, int], str] | None = None
    for release in releases:
        if release.get("draft") or release.get("prerelease"):
            continue
        tag = release.get("tag_name") or ""
        if tag_prefix(tag) != prefix:
            continue
        version = parse_version(tag)
        # "latest" and other rolling tags do not parse, and must not be a base.
        if version is None or version >= current:
            continue
        if best is None or version > best[0]:
            best = (version, tag)
    return best[1] if best else None


def github_rest(path: str, params: dict[str, str] | None = None) -> Any:
    """A REST call, for the two things the GraphQL API cannot express.

    Never fatal: this whole path exists to improve bullets that would otherwise
    read "no release notes", so a failure here costs one line, not the digest.
    """
    log = get_run_logger()
    try:
        response = http().get(
            f"https://api.github.com/{path}",
            headers={
                "Authorization": f"bearer {github_token()}",
                "Accept": "application/vnd.github+json",
            },
            params=params,
        )
        response.raise_for_status()
        return response.json()
    except (httpx2.HTTPError, ValueError) as error:
        log.warning("github rest %s: %s", path, error)
        return None


def tag_prefix(tag: str | None) -> str | None:
    """Everything before the version number: "v", "rust-v", "beam-worker-".

    Two tags sharing a prefix are the same release series; two that do not may
    be unrelated components of one repository.
    """
    match = VERSION.search(tag or "")
    return tag[: match.start()] if match and tag else None


# Commits that say nothing about what the release does.
NOISE_COMMIT = re.compile(
    r"(?i)^(merge (pull request|branch|remote)"
    r"|(chore|build|ci|docs)(\([^)]*\))?:\s*(bump|release|prepare|version)"
    r"|bump version|prepare release|release v?\d|version bump|update changelog)"
)


def clean_commits(subjects: Iterable[str]) -> list[str]:
    """Drop merges and release chores, and collapse repeats, keeping order."""
    kept: list[str] = []
    seen: set[str] = set()
    for subject in subjects:
        text = ATTRIBUTION.sub("", subject).strip()
        text = re.sub(r"\s*\(#\d+\)$", "", text)
        if not text or NOISE_COMMIT.match(text) or text in seen:
            continue
        seen.add(text)
        kept.append(text[:160])
    return kept


@task(retries=2, retry_delay_seconds=10)
def ask_ollama(prompt: str, model: str) -> str:
    ollama = os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434")
    response = http().post(
        f"{ollama}/api/generate",
        json={"model": model, "prompt": prompt, "stream": False},
        timeout=600,
    )
    response.raise_for_status()
    return response.json()["response"]


# Markdown the model adds no matter how the prompt is worded.
BOLD = re.compile(r"\*\*|__")
LABEL = re.compile(r"(?i)^(?:released?|summary|answer)\s*:\s*")


def tidy_sentence(raw: str) -> str:
    """First line, stripped of the markdown and labels it adds regardless.

    Bold is deleted outright rather than balanced: the model often emits
    `**Implemented** the thing`, and trimming only the ends takes the opener
    and leaves the closer stranded mid-sentence, inside a markdown bullet.
    """
    first = next((line for line in raw.strip().splitlines() if line.strip()), "")
    first = BOLD.sub("", first).strip().strip('`"“”‘’ -')
    return LABEL.sub("", first).strip()


def write_digest(
    week: str,
    ranked: list[Highlight],
    fresh: list[Repo],
    summaries: Summaries,
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
            bullet(h, summaries.get(h.repo.name, "")) for h in ranked[:top_n]
        ]
    if len(ranked) > top_n:
        lines += ["", "## Also shipped", ""] + [
            bullet(h, summaries.get(h.repo.name, "")) for h in ranked[top_n:]
        ]
    if fresh:
        lines += ["", "## Newly starred", ""] + [
            f"- [{r.name}]({r.url}) - {r.description[:160]}" for r in fresh
        ]

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    path = STATE_DIR / f"{week}.md"
    path.write_text("\n".join(lines) + "\n")

    latest = STATE_DIR / "latest.md"
    latest.unlink(missing_ok=True)
    latest.symlink_to(path.name)
    return path


def bullet(h: Highlight, sentence: str = "") -> str:
    """Every fact here is the API's; only `sentence` comes from the model."""
    return (
        f"- [{h.repo.name}]({h.repo.release_url or h.repo.url}) `{h.tag_display}` "
        f"({h.bump}, {fmt_delta(h.star_delta)} stars) - "
        f"{sentence or release_headline(h.repo)}"
    )


def release_headline(repo: Repo) -> str:
    """The best non-model line about the release, for when the model had none.

    Deliberately never the repo description: a digest that tells you what a
    project is has told you the one thing you already knew when you starred it.
    """
    if repo.release_name and repo.release_name.strip() not in ("", repo.tag):
        return repo.release_name.strip()[:160]
    notes = clean_notes(repo.release_body, limit=400)
    first = next((ln.strip(" -*+") for ln in notes.splitlines() if ln.strip()), "")
    return first[:160] or "no release notes"


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
