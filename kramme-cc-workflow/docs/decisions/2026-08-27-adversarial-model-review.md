# Add Explicit Cross-Provider Adversarial Review

- Status: ACCEPTED
- Date: 2026-08-27
- Deciders: repository maintainers
- First adoption review: 2026-11-27

## Context

The review skills can obtain fresh contexts and specialized lenses, but a Claude Code implementation is still normally reviewed by Claude-family models and a Codex implementation by OpenAI-family models. That creates correlated blind spots: a second pass may challenge the code while retaining the same provider's training, tool-use, and instruction-following tendencies.

Model metadata on an agent or skill does not establish a cross-provider boundary. The Codex conversion also intentionally drops Claude-specific model metadata. Conductor can run Claude and Codex agents in the same workspace, while both provider CLIs can run locally, but those execution paths have different isolation and audit properties.

The capability must remain optional because it sends repository content to another configured provider, requires separate authentication, and can fail for reasons unrelated to code quality. It must also fit the existing bounded review-convergence policy without replacing its established code, convention, overengineering, or refactor gates.

## Decision

Create user-invocable `kramme:pr:adversarial-review` as the canonical cross-provider primitive. Invocation is explicit repository-scoped consent to send the tracked `HEAD` snapshot, committed diff, and supplied requirements to the selected provider. The selected provider must differ from the active Claude Code or Codex host; provider failure never degrades to a same-provider pass.

Use a skill-local runner and structured result schema:

- In a local workspace, archive tracked `HEAD` into a temporary snapshot. Run Claude with safe mode, no persistence, no MCP, and read-only file tools, or run Codex ephemerally with a read-only sandbox and ignored user configuration.
- In a Conductor cloud workspace, create a different-provider session in the current workspace, poll it to completion, and retrieve the structured result. Compare the branch, `HEAD`, tree identity, and clean status before and after so any reviewer mutation fails closed.
- Require normalized findings, positive observations, and coverage. Revalidate every external finding against the real prepared repository and preserve concrete disagreement evidence.
- Return results inline. Temporary local inputs and outputs are deleted; a Conductor cloud session remains in workspace history as execution evidence.

Add `--adversarial-review` to `kramme:pr:review-convergence`. When requested, Gate 5 runs only after all ordinary active gates reach a no-change candidate. Accepted code-changing findings consume the existing remediation budget and restart the next round at Gate 1; the alternative provider then reviews the later candidate again. Final completion requires an adversarial result for the final verified tree.

The skill is platform-neutral at the instruction level and its directory is copied by the existing Codex converter. A conversion contract test requires the runner to retain executable permissions in the generated install.

## Consequences

- Users can request a genuinely different provider without changing the normal review path or relying on ambiguous model labels.
- Review convergence gains an optional fifth gate while retaining one remediation budget and established gate ordering.
- Local reviews cannot inspect untracked or unstaged work because the capability intentionally requires a clean committed branch and reviews tracked `HEAD`.
- Conductor cloud execution is detect-and-fail read-only rather than preemptively sandboxed; any observed mutation blocks the workflow and requires inspection.
- Provider availability, authentication, timeout, malformed output, degraded coverage, and tree-integrity failures are workflow blockers rather than clean reviews.
- The adoption review should inspect direct and convergence usage, provider failure rates, rejected-finding rates, review-caused mutations, and whether the additional gate finds materially distinct issues.

## Alternatives Considered

### Select another model with skill or agent frontmatter

Rejected because model metadata selects within a host's supported runtime and does not prove that the reviewer belongs to another provider. The generated Codex surface does not preserve Claude model metadata.

### Replace one existing convergence gate

Rejected because provider diversity is an execution boundary, not a review lens. It complements code, convention, overengineering, and refactor review rather than subsuming them.

### Invoke an unrestricted alternative-provider CLI in the current tree

Rejected because provider defaults, user configuration, MCP servers, and broad tools could mutate the worktree or execute instructions embedded in untrusted repository content.

### Require Conductor for every adversarial review

Rejected because canonical behavior should work in ordinary local Claude Code and Codex workspaces. Conductor remains the supported cloud-session adapter where its workspace runtime is present.
