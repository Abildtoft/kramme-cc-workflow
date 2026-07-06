# 0001. Audience model for kramme-cc-workflow

**Status**: ACCEPTED
**Date**: 2026-07-06
**Deciders**: Maintainer

## Context

The repository describes itself as "my personal workflow, built primarily for myself" while also carrying public-product machinery: marketplace installation, SemVer and changelog automation, GitHub release workflows, a security response policy, installer CI, SkillSpector release evidence, and first-class Codex conversion. Current public adoption does not yet validate those taxes: GitHub shows 2 stars, 1 fork, and no open issue from an external reporter as of 2026-07-06.

UNVERIFIED: monthly savings below are planning estimates, not time-tracked maintenance data.

SIMPLICITY CHECK: minimum ADR = context, proposed decision, and rejected alternatives. This memo expands alternatives because the maintainer asked for the three audience options, commitments, stops, and cheapest tests before committing.

## Decision

Choose **Option C, practice arena / showcase**. The machinery is part of the product: release process, installer validation, security scanning, Codex conversion, and review workflows are deliberate exercises and portfolio artifacts. External adoption is welcome, but it is not the justification for keeping those systems.

## Options

| Option | Commits the maintainer to | Stops | Cheapest test before committing |
| --- | --- | --- | --- |
| **A. Personal tool: cut product taxes** | Rewrite the README lead to say the repo is personal-first and support is best effort. Demote `SECURITY.md` from a 7-day acknowledgement expectation to "private reports welcome, no SLA." Remove Codex installer CI from required branch protection and run it manually or nightly. Release only when a real user-facing milestone needs it, not as routine ceremony. Treat Codex as generated best-effort output, not a first-class host contract. | Stops optimizing for marketplace trust, external compatibility guarantees, release polish on every batch, and keeping Codex parity as a merge blocker. | For one month, make installer CI non-required, batch release notes weekly at most, and move Codex docs below Claude install docs. If nothing important breaks, accept A. Estimated freed time: 4-8 hours/month from release/changelog ceremony, installer-CI failures, Codex compatibility fixes, and security/process review overhead. |
| **B. Public product: keep taxes and test demand** | Keep security SLA wording, required installer checks, release automation, changelog discipline, SemVer, marketplace readiness, and Codex first-class support. Shift effort from engineering polish to demand generation. | Stops adding more infrastructure before proving that users want the existing plugin. Stops treating low adoption as an engineering problem. | Run a one-week demand test: publish one announcement post, replace the quickstart with a one-screen "install -> try three commands -> update" path, and submit to relevant Claude/Codex plugin directories or community lists. Continue the public-product taxes only if the repo reaches at least 25 new installs or stars within 90 days, or gets 5 external issues/PRs from people who are not the maintainer. |
| **C. Practice arena / showcase: machinery is the product** | Say explicitly in the README that this is a personal workflow lab and showcase. Keep the taxes because they are the practice surface: release engineering, cross-host portability, security scanning, CI design, and agent-workflow documentation are maintained to learn, demonstrate taste, and reuse in other work. | Stops justifying the machinery with adoption metrics. Stops confusing readers by implying this is primarily a supported public product. Stops demand work unless the maintainer separately chooses Option B. | Change only the README positioning paragraph and this ADR status. For the next 30 days, label maintenance PRs by exercise area, such as release, portability, security, or docs. If those labels feel honest and useful, accept C. |

## Consequences

- Positive: Option C reconciles the existing behavior with the stated personal-workflow identity without deleting useful engineering practice.
- Negative: Option C does not create an adoption plan; public usage may stay near zero.
- Neutral / follow-on: If the maintainer later wants external users, run Option B as a time-boxed demand test before expanding product commitments.

## Alternatives considered

- Option A, personal tool only - rejected for now because it would remove systems that appear to be useful as reusable practice and showcase material.
- Option B, public product - rejected for now because current adoption indicates that engineering quality is not the constraint; demand needs proof before carrying public-product taxes for users.
