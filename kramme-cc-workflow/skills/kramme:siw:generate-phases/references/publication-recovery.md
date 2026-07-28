# Publication and Recovery Protocol

This reference owns the destructive replacement gate, serialized publication mechanics, and interrupted-publication recovery rules for the generate-phases workflow. Read it at both mandatory points in `SKILL.md` and execute the applicable sections in order. Do not simplify a STOP condition, ownership boundary, receipt postcondition, or recovery transition.

## Replacement approval snapshot

After the user chooses Replace, verify nothing is at risk but defer deletion to Phase 6 so no mutation happens before the final serialized publication boundary.

1. Check for uncommitted changes under `siw/issues/`:

   ```bash
   git status --porcelain -- siw/issues/ 2> /dev/null
   ```

   If output is non-empty, list the dirty paths and re-prompt with AskUserQuestion options "Proceed and discard changes" / "Abort". Abort by default if the user does not pick "Proceed".

2. Verify `trash` is available for recoverability. If it is unavailable, stop instead of planning a permanent deletion. Store `REPLACE_MODE=true`; do not delete anything yet:

   ```bash
   if ! command -v trash &> /dev/null; then
     echo "MISSING REQUIREMENT: trash is required to replace existing SIW issues safely. Install with 'brew install trash' (macOS) or your distro's 'trash-cli' package, then rerun."
     exit 1
   fi
   ```

3. After the user approves Replace (including any dirty-file confirmation), capture `REPLACE_APPROVED_SNAPSHOT` as sorted `git hash-object` plus path pairs for every matching issue file. This records both the approved file set and its contents:

   ```bash
   REPLACE_APPROVED_SNAPSHOT="$(
     for path in siw/issues/ISSUE-*.md; do
       if [ ! -e "$path" ] && [ ! -L "$path" ]; then
         continue
       fi
       if [ -L "$path" ] || [ ! -f "$path" ]; then
         echo "MISSING REQUIREMENT: replacement issue path must be a non-symlink regular file: $path" >&2
         exit 1
       fi
       path_hash="$(git hash-object "$path")" || exit 1
       printf '%s  %s\n' "$path_hash" "$path"
     done
   )" || exit 1
   REPLACE_APPROVED_SNAPSHOT="$(printf '%s\n' "$REPLACE_APPROVED_SNAPSHOT" | LC_ALL=C sort)" || exit 1
   ```

## Final publication preparation

Resolve `scripts/siw-issue-reservation.sh` relative to this `SKILL.md`. Generate a collision-resistant owner token once with `sh <helper> new-owner`, retain it in this workflow's session state, and use it for the workflow's full publication and recovery lifetime. During normal contention, never copy or reuse a token observed in an existing lock or reservation.

1. Immediately before the first mutation, run `sh <helper> acquire siw <owner-token> 30`. The helper persists an owner-bound baseline manifest for the overview, log, and issue ID/file state; interrupted same-owner retries validate that manifest instead of treating the recovery-time files as a new baseline. If it reports that another writer owns publication, preserve the lock and reservations unchanged and stop for owner-guided recovery without exposing its token. For malformed state or operational failures, preserve state and surface the helper's diagnostic exactly instead of describing the failure as contention.
2. Re-read `siw/OPEN_ISSUES_OVERVIEW.md`, `siw/LOG.md`, and all matching on-disk issue files while holding publication ownership. Never publish from the Phase 1 or draft-plan snapshot.
3. In append mode, group approved provisional IDs by prefix and call `sh <helper> reserve-batch siw <prefix> <owner-token> 100 <provisional-id>...` once per prefix. Each output line maps one provisional request key to its final ID, and retrying the same batch with the retained token returns the same mappings after interrupted output. Build the complete provisional-to-final map, then update filenames, headings, dependencies, related IDs, overview rows, and log ranges before writing. Each batch scans the prefix high-water mark once, preserves gaps, and retries collisions with exclusive atomic claims. Existing append-mode IDs remain unchanged.
4. In replace mode, recompute the snapshot under the lock with the exact fail-closed path validation, hash-status checks, and separate sort defined in the `Replacement approval snapshot` section above, then compare it with `REPLACE_APPROVED_SNAPSHOT`, regardless of `git status`. If it differs, run `sh <helper> release-publication siw <owner-token>` because no replacement IDs have been reserved yet, list the current issue files, and require fresh explicit approval before deletion; auto mode must stop only after publication ownership is released. After approval, replace `REPLACE_APPROVED_SNAPSHOT` with the newly approved snapshot, reacquire with the retained token, re-read all three SIW views, and recompute the snapshot. If it changed again, release ownership and repeat approval. Compare the canonical IDs in that locked pre-deletion state with the approved replacement set and store every ID absent from the replacement set in `REMOVED_ISSUE_IDS`. Reserve every approved replacement ID first with `sh <helper> reserve-exact siw <issue-id> <owner-token>`; the helper accepts either `ISSUE-G-001` or canonical `G-001` form and same-owner retries return the canonical ID. A foreign collision stops publication without deleting anything. Set `REPLACE_DELETION_STARTED=true` immediately before running the newly approved `trash siw/issues/ISSUE-*.md`, then replace the corresponding overview rows in this same publication.

Hold publication ownership only through Phase 6.1-6.3 and the verification/release steps below; never hold it during analysis, review, or user approval.

## Verification, release, and recovery

Re-read every created issue file, `siw/OPEN_ISSUES_OVERVIEW.md`, and `siw/LOG.md`. Verify each final ID appears once in a canonical issue heading and overview issue row, the log names every final ID in a Current Progress publication entry, every dependency uses the final mapping, and accurate entries from other writers remain intact. In append mode, run `sh <helper> publish-receipt siw <owner-token> <final-issue-id>...` as the final publication write, listing every final ID. In replace mode, append every `REMOVED_ISSUE_IDS` value after the final IDs so the receipt covers the complete transition; the helper accepts a removed ID only when the acquisition baseline proves that it had a canonical issue file, overview row, and log entry and the current issue file and overview row are both absent. The command validates and writes one idempotent receipt from the same immutable operation snapshot. The receipt binds the owner, complete issue-state hash, and every ID whose issue file, overview row, or log entry changed since acquisition; it also rejects foreign-owned IDs and omitted same-owner reservations. After it succeeds, release only the completed final-ID reservations with one `sh <helper> release-batch siw <owner-token> <final-issue-id>...` call, then run `sh <helper> release-publication siw <owner-token>`. Each release revalidates the receipt and current state, so a separate normal-path `verify-receipt` full-tree scan is unnecessary. These receipt and release commands are postcondition-idempotent, and the helper batches all issue-file digests within each immutable operation snapshot, so the retained owner may safely retry interrupted output without per-issue hashing.

Before replacement deletion starts, a failed multi-ID reservation attempt must unwind every exact reservation created by that attempt before releasing publication: run `release` for a replacement ID whose old issue file still exists and `abandon` for an ID with no issue file. The helper permits these pre-mutation releases only while the current SIW state matches the baseline captured at acquisition. Other failures before a reserved issue file exists may use `abandon` while `REPLACE_DELETION_STARTED` is not true. If cleanup fails, preserve the remaining reservation and publication lock for owner-guided recovery instead of reporting the collision as cleanly stopped. Once replacement deletion starts, never abandon any replacement reservation even when its new issue file does not exist: reacquire with the retained token, restore or repair all three views from current state, verify them, publish and verify the receipt for every final ID and every `REMOVED_ISSUE_IDS` value, and then release only the final-ID reservations. A later recovery session may use the retained token only after the user explicitly confirms it is resuming that interrupted workflow. Never delete a reservation based on age or filename, and never clean up a different owner's token.

An owner-only publication lock written by an older helper has no trustworthy baseline. Reacquire it only with the retained token, repair and verify all three SIW views, then publish and verify a receipt before releasing publication. A legacy reservation cannot be abandoned because the helper cannot prove that the live views still match the pre-edit state. When that interrupted legacy workflow has no owned issue reservation or issue ID to bind, `sh <helper> publish-receipt siw <owner-token>` and the optional diagnostic `sh <helper> verify-receipt siw <owner-token>` create and verify a legacy-only zero-ID recovery receipt; a current baseline-hashed lock and a legacy lock with an owned reservation both reject that form.
