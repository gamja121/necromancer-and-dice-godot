"""Durable GitHub Issue AI task ledger. No model execution or code writes."""
from __future__ import annotations
import argparse
from datetime import datetime, timedelta, timezone
import json
import os
import sys
from urllib.request import Request, urlopen
from urllib.error import HTTPError

MARKER = "<!-- ND_AI_CHECKPOINT_V1 -->"
PHASES = {"ready", "running", "checkpoint", "recoverable", "blocked", "complete"}
PREFIX = "[AI 작업]"

def now():
    return datetime.now(timezone.utc)

def timestamp(value):
    return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)

def make_record(issue, phase, step, attempt=1, branch="", commit="", note="", at=None):
    if issue < 1 or phase not in PHASES or attempt < 1 or not step.strip():
        raise ValueError("Invalid checkpoint fields")
    if any(len(v) > m for v, m in ((step, 200), (branch, 180), (commit, 40), (note, 1200))):
        raise ValueError("Checkpoint field too long")
    return dict(schema=1, issue=issue, phase=phase, step=step.strip(),
                attempt=attempt, branch=branch, commit=commit, note=note,
                updated_at=(at or now()).isoformat(timespec="seconds"))

def render(item):
    return MARKER + "\n" + json.dumps(item, ensure_ascii=False, indent=2, sort_keys=True)

def parse(body):
    pos = body.find(MARKER)
    if pos < 0:
        return None
    try:
        item = json.loads(body[pos + len(MARKER):].strip())
        if item.get("schema") != 1 or item.get("phase") not in PHASES:
            return None
        if int(item["attempt"]) < 1 or int(item["issue"]) < 1:
            return None
        timestamp(item["updated_at"])
        return item
    except (ValueError, TypeError, KeyError, AttributeError):
        return None

def latest(comments, issue):
    for comment in reversed(comments):
        item = parse(str(comment.get("body", "")))
        if item is not None and int(item["issue"]) == issue:
            return item
    return None

def stalled(item, current, timeout=20, max_attempts=3):
    if not item or item["phase"] != "running":
        return None
    if current - timestamp(item["updated_at"]) < timedelta(minutes=timeout):
        return None
    return "recoverable" if int(item["attempt"]) < max_attempts else "blocked"

def trusted(issue, owner):
    return (issue.get("state") == "open" and "pull_request" not in issue
            and str(issue.get("title", "")).startswith(PREFIX)
            and issue.get("user", {}).get("login", "").lower() == owner.lower())

def api(method, path, data=None):
    repo, token = os.getenv("GITHUB_REPOSITORY", ""), os.getenv("GITHUB_TOKEN", "")
    if len(repo.split("/")) != 2 or not token:
        raise RuntimeError("GITHUB_REPOSITORY/GITHUB_TOKEN missing")
    req = Request("https://api.github.com/repos/" + repo + path,
                  data=None if data is None else json.dumps(data).encode(),
                  method=method, headers={
                      "Authorization": "Bearer " + token,
                      "Accept": "application/vnd.github+json",
                      "X-GitHub-Api-Version": "2022-11-28",
                      "User-Agent": "necrodice-ai-checkpoints"})
    try:
        with urlopen(req, timeout=20) as response:
            return json.load(response)
    except HTTPError as exc:
        raise RuntimeError("GitHub API HTTP " + str(exc.code)) from exc

def paginate(path):
    for page in range(1, 6):
        join = "&" if "?" in path else "?"
        items = api("GET", path + join + "per_page=100&page=" + str(page))
        if not isinstance(items, list):
            raise RuntimeError("Expected GitHub list response")
        yield from items
        if len(items) < 100:
            break

def comments(number):
    return list(paginate("/issues/" + str(number) + "/comments"))

def submit(number, item):
    api("POST", "/issues/" + str(number) + "/comments", {"body": render(item)})

def valid_issue(number):
    issue = api("GET", "/issues/" + str(number))
    owner = os.environ["GITHUB_REPOSITORY"].split("/")[0]
    if not trusted(issue, owner):
        raise ValueError("Only open owner-created [AI 작업] Issues are managed")
    return issue

def record(args):
    valid_issue(args.issue)
    previous = latest(comments(args.issue), args.issue)
    attempt = args.attempt or (int(previous["attempt"]) if previous else 1)
    item = make_record(args.issue, args.phase, args.step, attempt,
                       args.branch, args.commit, args.note)
    keys = ("phase", "step", "attempt", "branch", "commit", "note")
    if previous and all(previous.get(k) == item[k] for k in keys):
        print("Already recorded")
        return
    submit(args.issue, item)
    print("Saved issue #" + str(args.issue) + ": " + args.phase)

def watchdog(args):
    if args.timeout < 10 or not 1 <= args.retries <= 10:
        raise ValueError("Invalid timeout/retries")
    owner = os.environ["GITHUB_REPOSITORY"].split("/")[0]
    detected = 0
    for issue in paginate("/issues?state=open"):
        if not trusted(issue, owner):
            continue
        number = int(issue["number"])
        item = latest(comments(number), number)
        phase = stalled(item, now(), args.timeout, args.retries)
        if phase is None:
            continue
        detected += 1
        note = ("Execution stopped. Await separate authorized AI executor."
                if phase == "recoverable" else "Maximum retries reached. Manual review required.")
        new = make_record(number, phase, item["step"], item["attempt"],
                          item.get("branch", ""), item.get("commit", ""), note)
        if not args.dry_run:
            submit(number, new)
        print(("DRY " if args.dry_run else "") + "#" + str(number) + " -> " + phase)
    print("Stalled tasks: " + str(detected))

def main():
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="cmd", required=True)
    p = commands.add_parser("record")
    p.add_argument("--issue", type=int, required=True)
    p.add_argument("--phase", required=True, choices=sorted(PHASES))
    p.add_argument("--step", required=True)
    p.add_argument("--attempt", type=int, default=0)
    p.add_argument("--branch", default="")
    p.add_argument("--commit", default="")
    p.add_argument("--note", default="")
    w = commands.add_parser("watchdog")
    w.add_argument("--timeout", type=int, default=20)
    w.add_argument("--retries", type=int, default=3)
    w.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    try:
        record(args) if args.cmd == "record" else watchdog(args)
    except (ValueError, RuntimeError, KeyError) as exc:
        print("AI ledger: " + str(exc), file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
