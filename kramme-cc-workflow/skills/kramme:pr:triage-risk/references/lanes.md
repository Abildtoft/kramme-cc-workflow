# Review Lanes

Map the final tier and the undiscounted signals to review commands and human decisions. Recommend only the commands on this page.

## Tier Lanes

| Tier | Review commands | Human role |
| --- | --- | --- |
| low | `/kramme:pr:gut-check` | Ordinary approval by one reviewer. |
| medium | `/kramme:pr:code-review` with any emphasis from the mapping below | Ordinary approval after the review findings are resolved. |
| high | `/kramme:pr:code-review` with any emphasis from the mapping below, plus `/kramme:pr:adversarial-review` when a second model provider is configured | A person answers every "Needs a human" item before merge. |

## Code-Review Emphasis

Add `--emphasize` with every dimension that an undiscounted signal maps to, in this order: `security`, `tests`, `removal`. For example: `/kramme:pr:code-review --emphasize security tests`.

| Signals | Dimension |
| --- | --- |
| `content:secret`, `content:dangerous-sink`, `path:auth`, `path:secrets-config` | `security` |
| `shape:untested-source`, `content:disabled-test` | `tests` |
| `shape:deleted-source` | `removal` |

`/kramme:pr:code-review` stops when an emphasized dimension has no applicable reviewer. Tell the user to rerun without that dimension if it does.

## Conditional Lanes

Add each lane whose trigger the diff meets, at any tier:

| Trigger | Command |
| --- | --- |
| The diff changes user-facing UI: components, templates, styles, or routes. The command applies its own UI-relevance rules. | `/kramme:pr:ux-review` |
| The diff changes user-visible behavior, flows, copy, or product rules. | `/kramme:pr:product-review` |
| `shape:large` or `shape:very-large` is undiscounted. Run it before review so each slice gets its own triage. | `/kramme:pr:plan-split` |
| An open Pull Request exists and its branch name, title, or body references a Linear issue. | `/kramme:linear:review-pr` |

## Human Decisions

Every undiscounted signal below adds its decision to "Needs a human", tied to the evidence path or `path:line`. Phrase each item as the specific question for this diff, not the generic prompt.

| Signal | Decision a person owns |
| --- | --- |
| `content:secret` | Whether a real credential was committed. Rotating it and removing it from history are human actions; a tier change cannot resolve them. |
| `policy:changed` | Whether the review-policy change is intended and correct. |
| `policy:invalid` | Who fixes `.github/pr-risk.json` on the default branch, quoting `policy.error`; until it is fixed, every branch triages high. This branch did not cause it. |
| `policy:high-path`, `policy:medium-path` | The concern that made the repository mark this path as risky, as it applies to this change. |
| `path:auth`, `path:secrets-config` | Who gains or loses access, and whether that matches the intended access model. |
| `path:database` | Whether the change is reversible, what it costs on production-sized data, and how it deploys relative to the code that uses it. |
| `path:ci` | What now runs with repository secrets, publishing rights, or review-routing authority. |
| `path:infra` | The production blast radius and the rollback plan. |
| `path:dependencies` | Whether each new or upgraded dependency is trusted, maintained, and acceptably licensed. |
| `path:api-contract` | Whether existing consumers tolerate the contract change, and how it is versioned. |
| `shape:very-large` | Whether to split the change before review. |

The remaining signals route to code-review emphasis or conditional lanes rather than to a person; `shape:non-trivial` only sets the tier.
