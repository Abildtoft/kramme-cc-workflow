# Start Issues in Conductor Cloud Workspaces

Follow this only after `detect` returned `ok` in Step 10. Nothing here runs without the user's explicit yes in this run. `{cloud-launch-helper}` is the helper path named in SKILL.md Step 10.

## 1. Choose the issues an agent can finish

Start from the ranked shortlist. Offer an issue only when it is `agent-ready` with startability `ready-to-start` under the autonomous agent-readiness checklist in `scoring-rubric.md`; classify it now when `--agent-ready` was not requested. Judge startability for a Linux cloud workspace: an issue whose work or verification needs the user's Mac, admin or account settings, credentials the workspace lacks, or a person's decision or sign-off is not ready to start there.

List every shortlisted issue you leave out with the checklist item it fails. If no issue qualifies, say so and end.

## 2. Ask once

Ask both questions in one message and wait for the answer:

1. Whether to start the offered issues (all of them, a named subset, or none), each in its own new Conductor cloud workspace whose first message runs `kramme:linear:issue-to-pr {ISSUE-ID} --ship`. Say that each workspace implements the issue, reviews it, and opens and stabilizes a Pull Request. Name every offered issue whose state type is not `backlog`, such as a To-do issue: `kramme:linear:issue-to-pr` asks once in that workspace before moving such an issue to its started status, and waits there for a yes. Repeat any coordination caveat from the report, such as two issues that edit the same files.
2. Only when at least one offered issue has Medium or High UI/UX work: whether those issues should use a different model than the None and Low ones. Name the default, this session's agent and `session_model` from `detect`. Run `conductor model` and show its output so the user can pick a model id and its agent.

Treat anything other than a clear yes with a selection as no, and start nothing. When `session_model` is null, also ask which model the other issues should use. Accept only the `claude` and `codex` agents, because other agents cannot run this plugin's skills.

## 3. Start the confirmed issues

Run the helper once with every confirmed issue, in ranked order:

```bash
python3 "{cloud-launch-helper}" launch --project-id '{project_id}' --item '{ISSUE-ID}' '{agent}' '{model}' [--item ...]
```

- The default agent is `claude` when this session runs in Claude Code and `codex` when it runs in Codex, with `session_model` or the model the user named.
- Medium and High UI/UX issues use the agent and model the user picked for them; every other issue uses the default.
- Validate each issue identifier and model id before interpolating it, and pass every value as its own single-quoted argument.

The helper builds each first message for its agent, creates the workspaces one at a time, and stops at the first failure. Conductor does not deduplicate workspace creation, so a lost response may still have created a workspace. The helper retries only an HTTP 429 rate limit, which creates nothing, after the wait Conductor names, and waits at most one minute in total across the run. Run it in the foreground with the longest command timeout the host allows, at least 10 minutes, because a killed helper reports nothing. Never run `launch` again for the same issues in this run, and never create workspaces with `conductor` directly.

## 4. Report

```text
Conductor cloud workspaces: {started} of {confirmed} started
| Issue | UI/UX work | Agent and model | Workspace | Outcome |
| --- | --- | --- | --- | --- |
| ... | ... | ... | ... | ... |
```

- `created`: link the workspace through its `deep_link`.
- `unknown`: say that the workspace may exist and to check Conductor before starting that issue again.
- `auth_error`: say that this workspace's Conductor credential cannot create workspaces, and that a user API key in `CONDUCTOR_API_KEY` may allow it.
- `rejected`: report the CLI's `detail`.
- `rate_limited`: say that Conductor kept rate-limiting workspace creation, that no workspace was created for that issue, and that it can be started again later.
- `not_started`: list the issue as not started, because an earlier issue failed.
