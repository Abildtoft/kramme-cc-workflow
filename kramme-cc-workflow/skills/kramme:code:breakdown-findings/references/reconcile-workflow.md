# Reconcile Workflow

Load this only when `RECONCILE_MODE=true`.

1. Load `PR_PLAN_INDEX.md`, all `PR_PLAN_{EXECUTION_LABEL}_{SLUG}.md` files referenced by the index, and `PR_PLAN_REJECTIONS.md` if it exists.
2. Reconstruct the plan graph:
   - Execution label, filename, title, impact, leverage, status, blockers, dependents, in-scope paths, planned-at SHA, and drift-check command for every plan.
   - Rejection IDs, source references, reasons, statuses, and reconsideration triggers for every rejected/excluded item.
3. Classify each plan:
   - `READY` - plan exists, dependencies are satisfied or independent, and scoped drift check is clean.
   - `BLOCKED` - a prerequisite plan is not marked `DONE`, a required answer is missing, or a `MISSING REQUIREMENT:` remains unresolved.
   - `DRIFTED` - the scoped diff/status drift check shows in-scope changes after the plan's `Planned at` SHA.
   - `MISSING` - the index references a plan file that is absent.
   - `STALE` - the live code no longer matches the plan's **Current State** excerpts, the verification commands changed, or recon/tradeoff context has materially changed.
   - `DONE` - the index or plan is explicitly marked `DONE`, and no obvious drift contradicts that status. Do not infer `DONE` solely because source files changed.
   - `SUPERSEDED` - the index, rejection record, or user explicitly marks the plan as replaced by another plan/PR.
   Status lifecycle:
   - The index `Status` column is the source of truth. If a plan header has a conflicting status, preserve the index value and add a reconcile note describing the mismatch.
   - Valid active statuses are `TODO`, `READY`, `BLOCKED`, `DRIFTED`, and `STALE`. `MISSING` is valid only in `PR_PLAN_INDEX.md` rows because an absent plan file has no header to update. Terminal statuses are `DONE` and `SUPERSEDED`.
   - Reconcile may move `TODO` or `READY` to `BLOCKED`, `DRIFTED`, or `STALE` based on evidence. Reconcile must not mark a plan `DONE` unless the index, plan, or user already explicitly says it is done and validation does not contradict that claim.
   - Executors, not this planning skill, mark implementation completion. They may mark `DONE` only after the plan's completion criteria and verification checks have passed.
   - A terminal `DONE` or `SUPERSEDED` plan stays terminal unless the user explicitly reopens it or reconcile finds drift that contradicts the terminal state.
4. Reconcile rejection records:
   - Keep stable rejection IDs. Do not renumber.
   - Mark rejected items as `RESOLVED_OUTSIDE_PLAN` only when the source finding is clearly no longer true.
   - Mark rejected items as `RECONSIDER` when their reconsideration trigger is met, their source conflict is resolved, or new recon/tradeoff context changes the decision.
   - Keep secret-value redaction rules intact.
5. Print a `RECONCILE:` status report before writing any updates:

   ```text
   RECONCILE: Plan status
     READY: W01A, W01B
     BLOCKED: W02A (blocked by W01A not DONE)
     DRIFTED: W03A (src/api/orders.ts changed since PLANNED_AT_SHA)
     MISSING: W04A (PR_PLAN_W04A_...)
     RECONSIDERED REJECTIONS: REJECTED-002

   Proposed artifact updates:
     - Update PR_PLAN_INDEX.md statuses and drift notes
     - Refresh PR_PLAN_W03A_...md current-state excerpts
     - Update PR_PLAN_REJECTIONS.md status for REJECTED-002

   Proceed? (yes / adjust)
   ```

6. Wait for confirmation. `AUTO_MODE=true` does not bypass reconcile confirmation because reconcile may rewrite existing planning artifacts.
7. When confirmed, update only planning artifacts:
   - Update `PR_PLAN_INDEX.md` with status, drift, dependency, impact/leverage, and recommended-order changes.
   - Refresh only `DRIFTED` or `STALE` plan files whose current-state evidence can be safely re-read and whose scope remains valid.
   - Keep `DONE` and `SUPERSEDED` plan files untouched unless the user explicitly asks to annotate them.
   - Update `PR_PLAN_REJECTIONS.md` without renumbering existing rejection IDs.
8. Stop instead of updating if recon reveals a source/plan conflict that would require re-clustering or changing theme boundaries. Report the conflict and recommend either cleanup plus a fresh run, or a user-confirmed resume/recluster.
