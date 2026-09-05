# Capture UI Evidence During Automatic Pull Request Creation

- Status: ACCEPTED
- Date: 2026-09-05
- Deciders: repository maintainers
- First safety review: 2026-12-05

## Context

`kramme:pr:create --auto` can ask `kramme:pr:generate-description` to delegate local screenshot or video capture, validate the returned manifest, and attach successful evidence during Pull Request creation. The workflow previously left all relevance judgment under the broad category of observable behavior. That allowed an agent to skip visual evidence for a UI-facing change even when a safe runnable surface was available.

Automatic publication also means the same agent selects and semantically checks the evidence before the user-authorized publishing parent attaches it. There is no independent artifact-preview gate in auto mode. The maintainer accepts that trust model and prefers useful reviewer evidence over disabling automatic attachments.

## Decision

- Treat every UI-facing diff as presumptively relevant visual evidence. UI-facing changes include user-visible components, pages, views, routes, templates, styles, themes, design tokens, visual assets, and interaction or state behavior such as loading, validation, error, and empty states.
- When GitHub CLI attachment syntax is available, `kramme:pr:create` passes visual publishing-parent mode to `kramme:pr:generate-description`. For a UI-facing diff, the generator keeps visual mode enabled and delegates a best-effort capture attempt to `kramme:visual:demo-reel`.
- Let `kramme:visual:demo-reel` choose the safest useful screenshot or video tier. The PR workflow does not duplicate capture or environment-lifecycle mechanics.
- If no app is already running, `kramme:pr:create --auto` may pass the guarded `--start-if-easy` capability through the description generator. This lets delegated UI capture make one bounded attempt to start an environment when there is one unambiguous local development command, its command definition is unchanged from the pinned base, dependencies and local configuration are already present, and startup requires no installation, migration, container, privileged operation, credential prompt, deployment, or external-service mutation. Stop only the process started for capture.
- Keep capture non-blocking. If no safe runnable surface is available, the environment cannot be started under those constraints, authentication or private-data constraints prevent capture, or the delegated capture fails, record the skipped reason and continue creating the Pull Request without evidence.
- Keep the existing publication boundary: the capture child never uploads; `kramme:pr:create` revalidates the local manifest and remains the sole owner of `gh pr create --attach`.
- For non-UI diffs, retain the existing agent judgment about whether observable behavior warrants evidence.

## Consequences

- Reviewers should receive screenshots or video for UI changes whenever the local environment can safely produce them.
- Small, copy-only, or visually subtle UI changes still trigger an attempt rather than being dismissed as unimportant.
- Straightforward local applications need not already be running for auto mode to capture them; complicated or stateful setup remains outside the evidence workflow.
- Automatic PR creation remains fully non-interactive and continues when capture is unavailable.
- Auto mode intentionally relies on the agent's relevance judgment and semantic safety check rather than an independent human artifact preview.
- Capture and attachment remain best-effort, so the policy guarantees an attempt rather than an artifact.

## Alternatives Considered

### Omit attachments under `--auto`

Rejected because it removes useful reviewer evidence from the workflow mode most likely to benefit from automatic capture.

### Require artifact preview and approval in auto mode

Rejected because it would make `--auto` conditionally interactive and conflict with its documented contract.

### Block Pull Request creation when UI capture fails

Rejected because local runtime availability is not a correctness requirement for the code change and should not prevent publication.

### Require the user to start every environment first

Rejected because repositories with an established, dependency-ready local development command can be started and cleaned up safely enough for a bounded best-effort capture attempt.
