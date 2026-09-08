# Review completion requires execution evidence

- Status: ACCEPTED
- Date: 2026-09-08
- Deciders: repository maintainer (explicit implementation request)

## Context

Maintainer dogfooding found Astra shortening `kramme:pr:code-review` despite its required stages. The existing failure policy preserves useful partial findings, but successful reports do not require a positive record of each reviewer and post-processing stage. Convergence can therefore consume an unsupported claim of completion.

## Decision

Require a frozen applicability plan, per-invocation ledger, saved outputs, and a local completion validator owned by the code-review skill. Default `all` means all applicable reviewers and every required downstream stage. Explicit aspect filters remain valid. Partial results remain useful but are `INCOMPLETE`.

Bind completion to repository, HEAD, resolved base, index, working-file content, and exact report/output hashes. Convergence and the closeout loop must recheck the current evidence before accepting completion. Team Mode adopts the standard integrity → relevance → slop-meta order. Changes require a fresh full run.

This is self-attested local evidence. It cannot prove actual host execution or semantic review quality. A trusted host runner is deferred until a maintained host transcript contract exists; no unsupported Stop hook or Conductor integration is introduced. A free-form model can still bypass a script it controls.

Amend the July 6 skill-quality regime with one narrow exception: `evals/review-completion/` may hold execution-completion prompts, independent trace-observation scoring and a seven-case candidate gate for code-review. It does not grade finding quality or add a SkillOpt adapter. The explicit user request authorizes this exception. Train, validation and test cases include positive filtered-scope and cancellation controls to avoid rewarding overscoping or ignoring the user. All cases require independently inspected live traces before claiming a candidate model fixes the regression; fixture tests only test machinery.

## Alternatives and consequences

Stronger prose alone remains unobservable. A report checklist without raw outputs cannot distinguish planned reviewers from returned reviewers. A host hook would provide stronger enforcement but has no portable trusted-event adapter here.

Local evidence adds temporary files and a Node/Git dependency. Missing tooling or retired evidence blocks completion checks. No global PR creation requirement is added: workflows that require review convergence enforce this gate through that phase, while unrelated PR creation workflows retain their current contract.
