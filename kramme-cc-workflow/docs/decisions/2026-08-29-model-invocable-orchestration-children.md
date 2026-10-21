# Permit Guarded Model-Invocable Orchestration Children

- Status: ACCEPTED
- Date: 2026-08-29
- Amended: 2026-10-15, 2026-10-21
- Deciders: repository maintainers
- First safety review: 2026-11-29

## Context

Claude Code rejects Skill-tool invocation of any skill with `disable-model-invocation: true`, even when a directly invoked parent skill supplies the call. This made `kramme:pr:create --auto` unable to invoke its required `kramme:git:recreate-commits` and `kramme:pr:generate-description` phases.

A 2026-10-21 review of every skill that hands work to another skill found parents whose instructions still invoke a model-disabled child. Claude Code rejects those calls, and the parent then reads the child's `SKILL.md` and follows it outside the child's own model contract or loses the step. Between 2026-10-06 and 2026-10-20 it rejected 36 calls from `kramme:code:plan-to-pr` to `kramme:code:work-from-plan`, plus calls from `kramme:pr:github-review-reply` to `kramme:pr:resolve-review` and from `kramme:pr:github-review` to the former `kramme:pr:ux-review`.

## Decision

Permit a narrow exception to the default rule that side-effecting skills are model-disabled. Apply it only to these exact parent-child relationships:

- `kramme:git:recreate-commits` is model-invocable only for direct user requests and delegation from `pr:create`. The parent always supplies `--require-unstacked`, `--no-push`, a pinned base commit, and a retry-safe backup ref. The child revalidates unstacked membership at the reset boundary, and the parent repeats that check at publication. The directly invoked parent owns the authorization represented by its `--auto` or `--authorize-history-rewrite` mode and remains the sole remote publisher. Model callers cannot invent `--force-backup`; only `pr:create` may automatically supply its exact derived `--backup-ref`.
- `kramme:pr:generate-description` is model-invocable, but every model caller must supply `--no-update`, including a caller of its `--check` mode. Only a direct user invocation may omit that guard and update an existing Pull Request.
- `kramme:linear:issue-implement` is model-invocable only as the child of `kramme:linear:issue-to-pr`, which must pass `--auto` and, for a fresh run, `--set-in-progress` with its validated status handoff, or, for continuation, its validated `--resume-current-branch` handoff. The child owns the status-only Linear write, applies it before branch setup, repeats the parent's confirmation race close, and verifies the result by reading the issue back. A model caller cannot invent `--set-in-progress`, cannot pass it without the parent-owned handoff, and cannot pass it with `--resume-current-branch`; only a direct user invocation may supply it bare, and it then answers the child's own non-backlog confirmation. The child keeps all Linear, branch, planning, scope, and verification gates.
- `kramme:pr:review-convergence` is model-invocable only as a child of `kramme:linear:issue-to-pr` or `kramme:code:plan-to-pr`, which must pass their exact internal work ID, allowlisted archive key, and sentinel-last requirements handoff. Validation-only and plan-scope flags remain caller-owned and validated by the child.
- `kramme:workflow-artifacts:cleanup` is model-invocable only as the child of `kramme:linear:issue-to-pr --ship`, with `--auto`; its destructive inventory, Trash requirement, dirty-artifact checks, and permanent-specification protections remain mandatory. Its `--siw` mode, merged from the former `kramme:siw:remove` on 2026-10-15, is direct-user-only: the child honors `--siw` only when the user typed the slash command or `$` mention with `--siw`, or explicitly asked in this session to retire the SIW workspace or to run cleanup with `--siw`. A model caller must never pass it on its own initiative, including after `kramme:siw:transfer-to-linear` prints its removal suggestion inside an autonomous loop; the child stops without scanning when `--siw` arrives without that user request, a direct user request still goes through every SIW confirmation, and `--siw` combined with `--auto` fails closed before any scan or deletion.
- `kramme:pr:create` is model-invocable only as a child of `kramme:linear:issue-to-pr` or `kramme:code:plan-to-pr`, with the caller's `--auto` authorization and required generated-description and issue/scope flags. It remains the sole owner of Pull Request publication and its existing backup and lease gates.
- `kramme:pr:fix-ci` is model-invocable only as a child of `kramme:linear:issue-to-pr`, `kramme:code:plan-to-pr`, or `kramme:pr:rebase`, with the parent's bounded `--no-consolidate`/scope or explicit rebase-mode arguments. It retains all CI, review-feedback, retry, and publication checks.
- `kramme:pr:rebase` is model-invocable only as a child of `kramme:pr:fix-ci`, which must pass the exact `--force-push` argument and must not invent `--auto`, `--fix-ci`, or a base override. It retains all branch, stack, conflict, red-flag, verification, lease, and publication gates and remains the sole owner of the validated rebase push.
- `kramme:pr:convention-review` and `kramme:pr:overengineering-review` are model-invocable only as read-only gates of `kramme:pr:review-convergence`, with that parent's inline, requirements, and report-lifecycle arguments. They never edit source or choose dispositions.
- `kramme:discovery:interview` is model-invocable, including its SIW mode (`--siw`, a bare `siw`, or `siw/` paths), which writes only a new, existence-checked `siw/DISCOVERY_BRIEF.md` or `siw/SPEC_STRENGTHENING_PLAN.md` during an interactive interview. Every model caller, including `kramme:siw:init` discover mode (which passes exactly `--siw <topic>`), must never pass `--apply`. Only a direct user request may enable `--apply`, which edits existing specifications and moves the strengthening plan to Trash, and the skill still confirms the exact edits in-session before changing any file.

Each child must narrowly route model use, document its least-side-effect model contract, and retain its existing confirmation and validation gates. Focused tests must pin the parent arguments.

### Hand-off repair exceptions

Amended 2026-10-21. The exception list above gains these exact edges. Direct user invocation of each child is unchanged.

- `kramme:code:work-from-plan` is model-invocable only as the implementation delegate of `kramme:code:plan-to-pr`, after that parent has validated, archived, and claimed the plan on its deterministic plan branch. The parent passes exactly the validated archived plan path as the only argument, plus its continue-mode, prerequisite-readiness, and context-preparation facts as inert parent-owned context. The child implements only a `direct` route on the current branch inside the plan's In Scope paths and returns every other route as the blocker. Under this delegation it never invokes `kramme:linear:issue-implement`, creates SIW files, requests the source index or other plans of the set, creates or switches branches, commits, pushes, or changes the plan archive; the parent keeps the commit boundary and the archive state. A model caller never passes inline plan text or any other plan path. Focused tests pin the parent's exact hand-off sentence and the child's contract.
- `kramme:pr:resolve-review` is model-invocable only in `--implement-only` mode with a caller-scoped structured findings payload, and only from two parents. `kramme:pr:github-review-reply` invokes it only after its user enabled implementation (`--implement`, `--auto`, or an explicit request to address the feedback), passing only the items it classified `needs-code-change`, never the Pull Request URL as the source, and never `--source online`. `kramme:pr:review-convergence` invokes it only during normal-mode batch remediation, at most once per batch while the worktree is clean, passing only that batch's accepted code-changing findings, and never in validation-only mode. In this mode the child makes no GitHub write, writes no review file, drafts no reply, and creates no commit; it keeps its scope, validity, and verification checks and reports through `.context/resolve-review/implement-only-summary.json`. Each parent keeps reply, resolution, disposition, and commit ownership. A model caller never passes `--team`, `--granular`, `--source`, `--severity`, a URL, or a request without findings. Focused tests pin both parents' exact hand-offs.
- `kramme:pr:adversarial-review` is model-invocable only as Gate 5 of `kramme:pr:review-convergence`, and only when that convergence run's `--adversarial-review` came from the user, typed on the invocation or explicitly requested in the same session. That request is the repository-scoped consent the adversarial-review decision requires, and it covers only that convergence run. The internal callers `kramme:linear:issue-to-pr` and `kramme:code:plan-to-pr` never forward the flag, and convergence rejects it in internal caller mode. Convergence passes exactly the sentinel-last frozen `--requirements` block, with optional `--provider` and `--model` values before it, and never `--base`. The child stays read-only and fails closed on any provider, authentication, isolation, parse, coverage, or tree-integrity failure. A model caller never adds the review on its own initiative, infers consent from CLI presence or an earlier run, or selects the host provider. Focused tests pin Gate 5's arguments and the absence of the flag from both internal callers.

These hand-off repairs need no side-effect exception:

- `kramme:pr:product-review` with `--inline` and `kramme:linear:review-pr` are read-only: neither edits source, commits, or writes to GitHub or Linear, and product-review writes no report file with `--inline`. They become model-invocable so `kramme:pr:github-review` can delegate to them, with descriptions that route model use as narrowly as the read-only convergence gates above.
- `kramme:debug:triage-to-issue` stops invoking `kramme:debug:investigate`; both skills load one plugin-level root-cause procedure, so investigate stays model-disabled and triage stays report-only.
- `kramme:code:migrate` recommends `/kramme:deps:audit` to the user, `kramme:pr:plan-split` gives the user an explicit `/kramme:code:breakdown-findings` command, and `kramme:siw:spec-audit --apply` owns its auto-fix procedure instead of delegating to a separate skill. Those targets stay model-disabled or are removed.
- `kramme:docs:update-agents-md` becomes user-invocable and model-disabled, so the user routes in `kramme:docs:adr` and `kramme:docs:feature-spec` point at a command the user can run.

`kramme:pr:code-review --loop` is not an authorized parent of `kramme:pr:resolve-review`. Its closeout loop fixes accepted findings directly and may recommend `/kramme:pr:resolve-review` to the user.

## Consequences

- `kramme:pr:create --auto` can use the existing child skills through Claude Code's Skill tool without duplicating their workflows.
- `kramme:pr:generate-description --check` compares an open Pull Request's title and body with the branch diff and is read-only for model callers, which pass `--check --no-update`. Only a direct user invocation without `--no-update` is offered a y/N prompt after Important or Critical drift; on `y`, the skill regenerates the description in output-only form, revalidates the exact Pull Request snapshot, checkout, head, base, and local work, and publishes through its own update path. The check mode replaced the separate verifier skill on 2026-10-15 and adds no new exception.
- One skill owns the started-state transition mechanics. `kramme:linear:issue-to-pr` keeps the authorization, status resolution, and confirmation gate, and the parent's Conductor rename now runs after that gate rather than after a verified write.
- The children become visible to the model, and their routing and argument contracts are advisory rather than a platform-enforced authorization check.
- Additional side-effecting children remain model-disabled unless an accepted ADR names the exact parent-child exception.
- The 2026-10-21 repairs make five more skills visible to the model. Claude Code lists every model-invocable skill's name and description in each session within a small share of the context window and drops descriptions of the least-used skills when the list overflows, so each new child's description stays short and names its parent.
- Parents no longer depend on reading a model-disabled child's `SKILL.md` to finish a delegated step.

## Alternatives Considered

### Duplicate the child workflows inside `pr:create`

Rejected because parallel workflow text would drift and make ownership unclear.

### Keep the children model-disabled and rely on the read-the-skill fallback

Rejected because Claude Code rejects every such call first, the fallback runs the child's workflow outside the child's own model-invocation contract, and a parent that cannot locate the installed file loses the step.

### Make the children model-invocable without naming their parents

Rejected because file edits and cross-provider data transfer would then be reachable from any routing decision rather than only from parents whose arguments are pinned by tests.
