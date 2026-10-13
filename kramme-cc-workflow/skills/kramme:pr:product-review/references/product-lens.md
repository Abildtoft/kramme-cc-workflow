# Product Lens

Loaded by `/kramme:pr:product-review` unless `--categories` excludes `product`. It holds what the product reviewer needs beyond the shared UI review inputs.

## Product Conventions

In addition to the UI conventions from Step 2, extract these from the instruction files, nearby product docs, and the code:

- Product domain and target users
- Feature flags, permission models, or role-based access rules

When jobs-to-be-done, business goals, or obvious non-goals are not stated, infer the likely ones from the available docs and pass them as inferred constraints.

## Reviewer Brief

Pass this instruction to `kramme:product-reviewer` verbatim:

> You are in PR mode. Focus on changes introduced by this diff. Evaluate: user-value alignment, flow completeness, missing states (loading, error, empty, edge), copy quality and defaults, permission/role behavior, adjacent-flow regressions, whether the change makes a clear product call, and whether obvious non-goals or deprioritized cases are missing. If rationale is absent, infer the likely user job and business reason from the code and docs, state the assumption, and review against it instead of stopping.
