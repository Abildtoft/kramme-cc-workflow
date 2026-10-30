#!/usr/bin/env python3
"""Describe where a branch sits in a Pull Request stack, for review workflows.

  python3 resolve-stack-context.py [--head <branch>]

Prints one JSON document on one line and exits 0 whenever it reaches a determination, including
`"state": "unknown"`. Exit 2 means an invalid invocation. `resolve-stack-membership.sh` fails closed
because it guards history rewrites; this helper only informs review scope and calibration, so an
undeterminable stack is reported, never fatal.

The helper is read-only: it never fetches, checks out, or writes refs, configuration, or files.

Sources, in order:

1. gh-stack local tracking (`gh stack view --json`), only for the checked-out branch. It knows the
   ordered layers before any Pull Request exists.
2. The open Pull Request chain on GitHub. A Pull Request's base is its parent layer when that base is
   itself the head of an open same-repository Pull Request, and open Pull Requests that target the head
   branch sit above it. This covers native GitHub stacks and manually chained Pull Requests alike. The
   walk down stops at a trunk-like branch: the remote default branch, `kramme.baseBranch`, or
   `CONDUCTOR_DEFAULT_BRANCH`. Each walk follows at most `MAX_WALK` layers.

Without `--head`, a detached HEAD is matched to the open Pull Request whose head commit it is.

Each layer's `ref` is a local ref reviewers can read without fetching; for a layer found through the
Pull Request chain, only a ref at or ahead of the Pull Request's head commit qualifies.

`review_base` is the base a review should use instead of the default base resolution. It is null when
the default (an open Pull Request's target) already scopes the layer, and it is set only from gh-stack
tracking: for a layer without an open Pull Request, and for a layer whose parent changed since its last
restack. Its `commit`, when present, is the newest commit known to belong to the layers below, so the
review diff holds this layer's own commits even before a restack.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from collections.abc import Sequence
from typing import Any

SCHEMA_VERSION = 1
LOCAL_TIMEOUT = 30
NETWORK_TIMEOUT = 20
MAX_WALK = 16
OID_RE = re.compile(r"[0-9a-f]{40}(?:[0-9a-f]{24})?")
GITHUB_URL_RE = re.compile(r"github\.com[:/]")
UNTRACKED_RE = re.compile(r'current branch "[^"]*" is not part of a stack')
PR_FIELDS = "number,url,headRefName,headRefOid,baseRefName,isCrossRepository"

Json = dict[str, Any]


class Unknown(Exception):
    """The stack state cannot be determined; the message is the reason."""


class Ambiguous(Unknown):
    """More than one Pull Request could represent the reviewed branch."""


def environment() -> dict[str, str]:
    return dict(os.environ, GH_PROMPT_DISABLED="1", GIT_TERMINAL_PROMPT="0", GIT_OPTIONAL_LOCKS="0", NO_COLOR="1")


def run(argv: Sequence[str], timeout: int) -> subprocess.CompletedProcess[str]:
    """Run without a shell; a timeout or launch failure becomes exit 124 or 127 with the reason on stderr."""
    try:
        return subprocess.run(
            list(argv), env=environment(), stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=timeout
        )
    except subprocess.TimeoutExpired:
        return subprocess.CompletedProcess(list(argv), 124, "", f"timed out after {timeout}s")
    except OSError as error:
        return subprocess.CompletedProcess(list(argv), 127, "", str(error))


def git(*args: str) -> str | None:
    result = run(["git", *args], LOCAL_TIMEOUT)
    return result.stdout.strip() if result.returncode == 0 else None


def gh(*args: str) -> subprocess.CompletedProcess[str]:
    return run(["gh", *args], NETWORK_TIMEOUT)


def tail(text: str) -> str:
    return " ".join(text.split())[-300:]


def valid_branch(name: Any) -> bool:
    # `check-ref-format --branch` expands `@{-N}`, so require it to echo the name unchanged.
    return isinstance(name, str) and bool(name) and git("check-ref-format", "--branch", name) == name


def object_id(value: Any) -> str | None:
    return value if isinstance(value, str) and OID_RE.fullmatch(value) else None


def commit_of(ref: str) -> str | None:
    return git("rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}")


def is_ancestor(ancestor: str, descendant: str) -> bool:
    return run(["git", "merge-base", "--is-ancestor", ancestor, descendant], LOCAL_TIMEOUT).returncode == 0


def readable_ref(branch: str, pr_head: str | None = None) -> str | None:
    """A local ref for this layer, preferring the local branch; given `pr_head`, one at or ahead of it."""
    for ref in (f"refs/heads/{branch}", f"refs/remotes/origin/{branch}"):
        commit = commit_of(ref)
        if commit and (pr_head is None or commit == pr_head or is_ancestor(pr_head, commit)):
            return ref
    return None


def layer(branch: str, pr: int | None, pr_head: str | None = None) -> Json:
    return {"branch": branch, "pr": pr, "ref": readable_ref(branch, pr_head)}


def has_github_remote() -> bool:
    remotes = git("remote")
    if remotes is None:
        raise Unknown("could not list Git remotes")
    for name in remotes.split():
        urls = git("remote", "get-url", "--all", "--", name)
        if urls is None:
            raise Unknown(f"could not read remote `{name}`")
        if GITHUB_URL_RE.search(urls):
            return True
    return False


def gh_json(*args: str, what: str) -> Any:
    result = gh(*args)
    if result.returncode != 0:
        raise Unknown(f"could not query {what}: {tail(result.stderr) or f'gh exited {result.returncode}'}")
    try:
        return json.loads(result.stdout or "null")
    except ValueError as error:
        raise Unknown(f"could not parse {what}: {error}") from error


def open_pull_requests(*, head: str = "", base: str = "", unique_head: bool = False) -> list[Json]:
    """Open same-repository Pull Requests from `head` or into `base`."""
    what = f"open Pull Requests from `{head}`" if head else f"open Pull Requests into `{base}`"
    args = ["pr", "list", "--state", "open", "--limit", "20", "--json", PR_FIELDS]
    args += ["--head", head] if head else ["--base", base]
    data = gh_json(*args, what=what)
    if not isinstance(data, list):
        raise Unknown(f"could not parse {what}: expected a list")
    pulls = []
    for item in data:
        if not isinstance(item, dict) or item.get("isCrossRepository") is not False:
            continue
        number, head_ref, base_ref = item.get("number"), item.get("headRefName"), item.get("baseRefName")
        if not (isinstance(number, int) and number > 0 and valid_branch(head_ref) and valid_branch(base_ref)):
            raise Unknown(f"could not parse {what}: malformed Pull Request entry")
        if (head and head_ref != head) or (base and base_ref != base):
            continue
        url = item["url"] if isinstance(item.get("url"), str) else None
        oid = object_id(item.get("headRefOid"))
        pulls.append({"number": number, "url": url, "head": head_ref, "base": base_ref, "oid": oid})
    if unique_head and head and len(pulls) > 1:
        raise Ambiguous(f"`{head or base}` matches {len(pulls)} open Pull Requests; pass the base explicitly")
    return pulls


def detached_pull_request(head_oid: str) -> Json | None:
    """The open same-repository Pull Request whose head commit is `head_oid`."""
    what = "the Pull Request for the detached HEAD commit"
    data = gh_json("api", f"repos/{{owner}}/{{repo}}/commits/{head_oid}/pulls", what=what)
    matches = []
    for item in data if isinstance(data, list) else []:
        if not isinstance(item, dict) or item.get("state") != "open":
            continue
        head, base = item.get("head") or {}, item.get("base") or {}
        head_repo = (head.get("repo") or {}).get("full_name")
        if head.get("sha") != head_oid or not head_repo or head_repo != (base.get("repo") or {}).get("full_name"):
            continue
        number, url = item.get("number"), item.get("html_url")
        if isinstance(number, int) and valid_branch(head.get("ref")) and valid_branch(base.get("ref")):
            matches.append(
                {
                    "number": number,
                    "url": url if isinstance(url, str) else None,
                    "head": head["ref"],
                    "base": base["ref"],
                }
            )
    if len(matches) > 1:
        raise Unknown("several open Pull Requests share the detached HEAD commit; pass --head <branch>")
    return matches[0] if matches else None


def stack_view(head: str, notes: list[str]) -> Json | None:
    """gh-stack's view when it tracks `head` locally; None when it does not or is not installed."""
    if gh("stack", "--version").returncode != 0:
        return None
    result = gh("stack", "view", "--json")
    if result.returncode == 2:
        return None
    if result.returncode != 0:
        notes.append(f"gh stack view failed ({tail(result.stderr) or f'exit {result.returncode}'}); used Pull Requests")
        return None
    text = result.stdout.strip()
    if not text or UNTRACKED_RE.search(text):
        return None
    try:
        data = json.loads(text)
    except ValueError:
        notes.append("gh stack view printed invalid JSON; used Pull Requests")
        return None
    if (
        not isinstance(data, dict)
        or not isinstance(data.get("branches"), list)
        or not valid_branch(data.get("trunk"))
        or not all(isinstance(item, dict) and valid_branch(item.get("name")) for item in data["branches"])
    ):
        notes.append("gh stack view printed an unexpected stack shape; used Pull Requests")
        return None
    # gh-stack prints the stack even from a branch outside it, so membership needs the head in the list.
    if head not in [item["name"] for item in data["branches"]]:
        return None
    return data


def stack_pr_number(entry: Json) -> int | None:
    pr = entry.get("pr")
    number = pr.get("number") if isinstance(pr, dict) else None
    return number if isinstance(number, int) and number > 0 else None


def newest_downstack_commit(parent: str, recorded: str | None, head_oid: str, notes: list[str]) -> str | None:
    """The newest commit known to belong to the layers below: gh-stack's recorded base or the parent merge base.

    After a parent is amended or rebased, only the recorded base excludes its pre-rewrite commits; after a
    parent is merged into this layer, only the merge base excludes the merged commits. Each is an ancestor of
    HEAD, so the descendant of the two is the tighter base.
    """
    candidates = []
    if recorded and is_ancestor(recorded, head_oid):
        candidates.append(recorded)
    merge_base = git("merge-base", f"refs/heads/{parent}", head_oid) if commit_of(f"refs/heads/{parent}") else None
    if merge_base:
        candidates.append(merge_base)
    if len(candidates) < 2:
        return candidates[0] if candidates else None
    first, second = candidates
    if first == second or is_ancestor(second, first):
        return first
    if is_ancestor(first, second):
        return second
    notes.append("gh-stack's recorded base and the parent branch have diverged; used the parent's merge base")
    return merge_base


def gh_stack_context(view: Json, head: str, head_oid: str, notes: list[str]) -> Json:
    trunk = view["trunk"]
    entries = view["branches"]
    current = next(item for item in entries if item["name"] == head)
    layers = [item for item in entries if item["name"] != trunk and item.get("isMerged") is not True]
    if current not in layers:
        notes.append("gh-stack reports this layer as merged")
        return result("unstacked", head, source="gh-stack", trunk=trunk, notes=notes)
    index = layers.index(current)
    below = [layer(item["name"], stack_pr_number(item)) for item in layers[:index]]
    above = [layer(item["name"], stack_pr_number(item)) for item in layers[index + 1 :]]
    try:
        pulls = open_pull_requests(head=head, unique_head=True)
        own_pr = pulls[0] if pulls else None
    except Ambiguous as error:
        return result("unknown", head, source="gh-stack", trunk=trunk, reason=str(error), notes=notes)
    except Unknown as error:
        notes.append(f"{error}; used gh-stack's Pull Request record")
        number = stack_pr_number(current)
        pr_state = (current.get("pr") or {}).get("state")
        own_pr = {"number": number, "url": None, "head": head, "base": None} if number and pr_state == "OPEN" else None
    needs_restack = current.get("needsRebase") is True
    recorded = object_id(current.get("base"))
    review_base = None
    if own_pr is None or needs_restack:
        if below:
            parent = below[-1]["branch"]
            review_base = {"branch": parent, "commit": newest_downstack_commit(parent, recorded, head_oid, notes)}
        else:
            restack_base = recorded if needs_restack and recorded and is_ancestor(recorded, head_oid) else None
            review_base = {"branch": trunk, "commit": restack_base}
    if own_pr and own_pr.get("base") and own_pr["base"] != (below[-1]["branch"] if below else trunk):
        notes.append(f"the open Pull Request targets `{own_pr['base']}`, not the gh-stack parent")
    return result(
        "stacked" if below or above else "unstacked",
        head,
        source="gh-stack",
        trunk=trunk,
        own_pr=own_pr,
        below=below,
        above=above,
        positioned=True,
        needs_restack=needs_restack,
        review_base=review_base,
        notes=notes,
    )


def trunk_like() -> set[str]:
    names = set()
    remote_head = git("symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD")
    if remote_head and remote_head.startswith("origin/"):
        names.add(remote_head[len("origin/") :])
    else:
        default = gh("repo", "view", "--json", "defaultBranchRef", "--jq", ".defaultBranchRef.name")
        if default.returncode == 0:
            names.add(default.stdout.strip())
    names.add(git("config", "--local", "--get", "kramme.baseBranch") or "")
    names.add(os.environ.get("CONDUCTOR_DEFAULT_BRANCH", "").strip())
    return {name for name in names if valid_branch(name)}


def walk_up(head: str, notes: list[str]) -> list[Json]:
    above: list[Json] = []
    seen, branch = {head}, head
    while True:
        children = open_pull_requests(base=branch)
        if not children:
            return above
        # Checked only once another layer exists, so a stack exactly MAX_WALK layers tall is not cut off.
        if len(above) >= MAX_WALK:
            notes.append(f"stopped after {MAX_WALK} layers above")
            return above
        if len(children) > 1:
            notes.append(f"{len(children)} open Pull Requests target `{branch}`, so the stack branches above it")
            return above + [layer(child["head"], child["number"], child["oid"]) for child in children]
        child = children[0]
        if child["head"] in seen:
            notes.append("the Pull Request chain loops; stopped walking it")
            return above
        seen.add(child["head"])
        above.append(layer(child["head"], child["number"], child["oid"]))
        branch = child["head"]


def walk_down(own_pr: Json, notes: list[str]) -> tuple[list[Json], str | None]:
    trunks = trunk_like()
    below: list[Json] = []
    seen, base = {own_pr["head"]}, own_pr["base"]
    while True:
        if base in trunks or base in seen:
            return below, base
        parents = open_pull_requests(head=base)
        if not parents:
            return below, base
        # Checked only once another layer exists, so a stack exactly MAX_WALK layers deep still reaches its trunk.
        if len(below) >= MAX_WALK:
            notes.append(f"stopped after {MAX_WALK} layers below")
            return below, None
        if len(parents) > 1:
            notes.append(f"`{base}` heads {len(parents)} open Pull Requests; stopped walking down there")
            return [layer(base, None), *below], None
        seen.add(base)
        below.insert(0, layer(base, parents[0]["number"], parents[0]["oid"]))
        base = parents[0]["base"]


def pull_request_context(head: str, own_pr: Json | None, notes: list[str]) -> Json:
    above = walk_up(head, notes)
    below, trunk = walk_down(own_pr, notes) if own_pr else ([], None)
    return result(
        "stacked" if below or above else "unstacked",
        head,
        source="pull-requests",
        trunk=trunk,
        own_pr=own_pr,
        below=below,
        above=above,
        positioned=own_pr is not None,
        notes=notes,
    )


def label(entry: Json) -> str:
    return f"`{entry['branch']}`" + (f" (#{entry['pr']})" if entry.get("pr") else "")


def summarize(context: Json) -> str:
    state = context["state"]
    if state == "unknown":
        return f"Stack status unknown: {context['reason']}."
    if state == "unstacked":
        return "Not part of a Pull Request stack."
    above = ", ".join(label(entry) for entry in context["upstack"])
    if context["position"] is None:
        return (
            f"Open Pull Requests build on this branch: {above}. "
            "It has no open Pull Request, so layers below it are unknown."
        )
    kind = "gh-stack stack" if context["source"] == "gh-stack" else "chain of stacked Pull Requests"
    trunk = f" on `{context['trunk']}`" if context["trunk"] else ""
    parent = (
        label(context["parent"])
        if context["parent"]
        else f"the trunk `{context['trunk']}`"
        if context["trunk"]
        else "unknown"
    )
    text = f"Layer {context['position']} of {context['size']} in a {kind}{trunk}. Parent: {parent}."
    text += f" Above: {above}." if above else " Top of the stack."
    if context["needs_restack"]:
        text += " Needs a restack: the layers below changed after this layer was last rebased."
    return text


def result(
    state: str,
    head: str | None,
    *,
    source: str | None = None,
    reason: str = "",
    trunk: str | None = None,
    own_pr: Json | None = None,
    below: Sequence[Json] = (),
    above: Sequence[Json] = (),
    positioned: bool = False,
    needs_restack: bool | None = None,
    review_base: Json | None = None,
    notes: Sequence[str] = (),
) -> Json:
    context: Json = {
        "schema_version": SCHEMA_VERSION,
        "state": state,
        "source": source,
        "reason": reason,
        "head": head,
        "trunk": trunk,
        "position": len(below) + 1 if positioned and state == "stacked" else None,
        "size": len(below) + 1 + len(above) if positioned and state == "stacked" else None,
        "pr": {"number": own_pr["number"], "url": own_pr["url"], "base": own_pr["base"]} if own_pr else None,
        "parent": below[-1] if below else None,
        "downstack": list(below),
        "upstack": list(above),
        "needs_restack": needs_restack,
        "review_base": review_base,
        "notes": list(notes),
    }
    context["summary"] = summarize(context)
    return context


def resolve(head_arg: str | None) -> Json:
    notes: list[str] = []
    head_oid = commit_of("HEAD")
    current = git("symbolic-ref", "--quiet", "--short", "HEAD")
    head = head_arg or current
    if not head_oid:
        return result("unknown", head, reason="HEAD does not resolve to a commit")
    try:
        if not has_github_remote():
            return result("unstacked", head, reason="no GitHub remote")
        if not shutil.which("gh"):
            raise Unknown("the GitHub CLI (gh) is unavailable")
        own_pr = None
        if not head:
            own_pr = detached_pull_request(head_oid)
            if own_pr is None:
                return result("unstacked", None, reason="the detached HEAD is not the head of an open Pull Request")
            head = own_pr["head"]
        elif head == current:
            view = stack_view(head, notes)
            if view:
                return gh_stack_context(view, head, head_oid, notes)
        if own_pr is None:
            pulls = open_pull_requests(head=head, unique_head=True)
            if len(pulls) > 1:
                raise Unknown(f"`{head}` heads {len(pulls)} open Pull Requests; pass the base explicitly")
            own_pr = pulls[0] if pulls else None
        return pull_request_context(head, own_pr, notes)
    except Unknown as error:
        return result("unknown", head, reason=str(error), notes=notes)


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Describe where a branch sits in a Pull Request stack.")
    parser.add_argument("--head", help="branch to describe (default: the checked-out branch)")
    args = parser.parse_args(argv)
    if args.head is not None and not valid_branch(args.head):
        print(f"--head must be a valid branch name: {args.head!r}", file=sys.stderr)
        return 2
    print(json.dumps(resolve(args.head), separators=(",", ":")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
