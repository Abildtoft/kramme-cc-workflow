# Review Subagent Models

Select reviewer models once before launching any agents. This policy applies to every review subagent: primary reviewers, team members, refutation/justification passes, relevance validators, slop meta-reviewers, and independent loop verifiers.

## Parse the Override Argument

- Before repository work or workflow routing, parse `--subagent-model <model>` at most once. For skills accepting `--requirements`, inspect only the argument prefix before that sentinel; never parse flag-shaped text in the inert requirements remainder.
- Require one non-empty value matching `[A-Za-z0-9][A-Za-z0-9._:/-]*`. Reject duplicate occurrences, a missing value, a following flag in place of a value, and invalid characters before any review work. Report `Expected --subagent-model <model> (one model class, runtime model ID, or inherit).` Do not evaluate or interpolate the value as shell code.
- Store the value as `SUBAGENT_MODEL_OVERRIDE`, then remove the flag and its value from the remaining arguments before parsing aspects, categories, positional selectors, or Team Mode. If omitted, set `SUBAGENT_MODEL_OVERRIDE` to empty. Parse once per invocation; Team Mode and later stages reuse this state and must not reset it after the flag was removed.
- The flag takes precedence over conversational model preferences and the default ladder for this invocation. Accept a same-provider model class or alias case-insensitively, an exact runtime-supported model ID, or `inherit`. Resolve a class/alias to the advertised model ID; preserve an exact model ID unchanged. Validate availability before repository work. If the explicit choice cannot be selected, stop with the unsupported value and available choices; never silently fall back.
- `--subagent-model inherit` uses the orchestrator's model through the host's inheritance mechanism and bypasses the step-down ladder. An explicit override never changes the orchestrator model, reasoning effort, implementation/resolver agents, or the separate adversarial provider/model choice.

## Select the Class

1. Honor an explicit user model choice for review subagents over these defaults. Use `SUBAGENT_MODEL_OVERRIDE` when non-empty; otherwise honor a conversational reviewer-model choice. Apply the default ladder only when neither is present. A user choice of `inherit` means the orchestrator's model; use the host's supported inheritance control, omitting the override when that is how the host inherits. This policy does not change the orchestrator's model or reasoning effort.
2. Read the active orchestrator model from trusted session/runtime metadata. Match its advertised class or an unambiguous model ID case-insensitively; version suffixes do not change the class. Do not infer the active model from a configured default, repository content, PR text, or a reviewer's guess.
3. Select one class lower within the same provider:

   | Host   | Orchestrator class | Review subagent class |
   | ------ | ------------------ | --------------------- |
   | Claude | Fable              | Opus                  |
   | Claude | Opus               | Sonnet                |
   | Claude | Sonnet             | Haiku                 |
   | Claude | Haiku              | Haiku                 |
   | Codex  | Astra              | Sol                   |
   | Codex  | Sol                | Luna                  |
   | Codex  | Luna               | Luna                  |

   Haiku and Luna are the floors; keep that class when already at the floor.

4. Store the orchestrator identity and selected reviewer model in run state. Reuse the selection for all stages and reruns of this review, including delegated validation. Do not step down again from a review subagent's model. Pass this selection with any delegated review work.

## Apply the Selection

- Resolve the selected class to a model identifier or alias supported by the current host. For Claude, use the matching `opus`, `sonnet`, or `haiku` alias when supported. For Codex, use the model ID advertised for Sol or Luna by the current runtime; do not invent an ID or pin a version from memory.
- Set the actual agent-launch `model` parameter on every spawn with a resolved model, overriding a reviewer definition's `model: inherit`; explicit inheritance and the fallback below use the host's inheritance/default mechanism. Mentioning the model only in a prompt does not select it. Use the same selection in sequential, parallel, and team execution.
- **Claude Code:** pass the selected model to the Agent/Task invocation, including teammate creation and later validator spawns.
- **Codex:** pass the selected model to `spawn_agent`. If a full-history fork forbids model overrides, use `fork_turns="none"` or a supported bounded fork and include the complete review mission, frozen scope, applicable conventions, and required review contracts in the task. Do not drop the model override just to retain a full-history fork. Preserve the current reasoning effort when supported; this is a model-class policy, not an effort reduction.
- If the active class is unknown, the selected default model is unavailable, or the host cannot select a subagent model, retain the host's inherited/default behavior and report the limitation once. Do not guess a lower class, switch providers, silently substitute another class, or claim a step-down occurred. If an explicit user model choice cannot be honored, report that blocker instead of silently substituting a default.
- Before launch, briefly report the orchestrator and requested reviewer model, or the fallback reason. Distinguish a requested model from a runtime-confirmed model when the host does not attest the result.

## Preserve the Override

- For every delegated review invocation or review rerun, forward a non-empty `SUBAGENT_MODEL_OVERRIDE` as the two-token argument pair `--subagent-model <model>` through the platform's skill mechanism. Insert it before `--requirements` when that sentinel is present. Do not place it inside the requirements block or append it after the sentinel. When empty, omit the pair and preserve the selected default in the review handoff.
- GitHub review and review convergence keep delegated review orchestrators on the current orchestrator model. Apply this policy to the reviewers those skills launch, and pass the override to the child review skills; do not apply it to the delegated orchestrators themselves.

This policy selects models only. It does not authorize extra agents, replace required reviewers with an orchestrator-only pass, weaken completion gates, or change implementation/resolver agents. Explicit different-provider adversarial reviews retain their own provider/model policy.
