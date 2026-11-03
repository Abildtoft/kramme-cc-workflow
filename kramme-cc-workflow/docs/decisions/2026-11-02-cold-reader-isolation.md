# Start Outsider Readers Without Project Instructions

- Status: ACCEPTED
- Date: 2026-11-02
- Deciders: repository maintainers

## Context

The repository already separates maker from checker, and some workflows ask for a reader who has not seen the work: the Pull Request description cold read and the in-repo raters of `kramme:code:outside-view`. Those workflows keep the conversation away from the reader. They did not keep the project's own framing away. On Claude Code, a general-purpose or custom subagent loads every `CLAUDE.md` level at startup, including the `AGENTS.md` this repository imports. Outside-view promised that "the project's self-image cannot constrain what they see" while only telling raters not to open files that were already in their context. The cold read carried the same gap as a stated caveat.

Reviewing [google/elephant-goldfish-model](https://github.com/google/elephant-goldfish-model) at commit `403d8881d62022490637d740657b33f01e321ea8` surfaced the direct fix: the `omitClaudeMd` subagent field, available from Claude Code 2.1.271. A live probe confirmed the problem and the fix. In otherwise identical sessions, a `general-purpose` subagent reported random markers planted in `CLAUDE.md` and in the `AGENTS.md` it imports, and a plugin agent with the field reported neither.

## Decision

- Add one read-only plugin agent, `kramme:cold-reader`, with `omitClaudeMd: true`, and one launch contract, `shared/agents/references/cold-reader.md`.
- Launch outsider readers through it: outside-view's in-repo raters, the Pull Request description cold read, and the comprehension read in `kramme:docs:review` and `kramme:siw:spec-audit`.
- Keep project instructions for readers who are meant to know the project: the author and teammate clarity readers in `kramme:pr:github-review`, and reviewers that check project rules, such as `kramme:code-reviewer` and `kramme:convention-drift-reviewer`.
- Skip and record a read when the host cannot start the reader without the conversation. Never simulate one in the calling context. A reader that cannot read named material replies `UNREADABLE: <path>` and the read counts as failed.
- On Codex, spawn a new agent with `fork_turns="none"`, or `fork_context: false` when the spawn tool exposes that field. Codex has no equivalent of the field and the converter drops it, so an adopting skill that reports isolation records it as reduced there.
- Check the host contract with `scripts/probe-cold-reader-isolation.js`, on demand. It runs the cold reader, a positive control with a normal agent, and a denied read.

## Consequences

- Outsider readers no longer know project vocabulary, so they flag established terms a teammate would know. Each adopting skill says how to treat those notes.
- Claude Code versions before 2.1.271 ignore the field and load the instructions without any error. Only the probe detects this, so run it after a Claude Code or Agent SDK upgrade that touches subagent startup.
- Isolation is about startup context, not the filesystem. A cold reader can still open instruction files, so prompts that allow exploring keep their rule about when it may.
- The probe spends model usage and runs on demand. It checks a host contract rather than the quality of a skill's output, so it stays in `scripts/` and does not change the committed-eval cap in [2026-07-06-skill-quality-regime.md](2026-07-06-skill-quality-regime.md).
- An isolation check needs a positive control. The first version of the probe denied the `Read` tool to stop agents reading `CLAUDE.md` from disk. That rule also stopped `CLAUDE.md` from loading, so the cold reader passed while testing nothing, and only the control variant exposed it. The probe now withholds file tools with the SDK's `tools` option, and a run without a passing control proves nothing.

## Alternatives Considered

### Keep the written rule

Rejected because a reader cannot un-see what is already in its context. A rule against opening instruction files does not remove them.

### Use the built-in Explore agent

Explore also starts without `CLAUDE.md` files, so it would need no new component. Rejected because its system prompt is tuned for locating code rather than judging material, and it cannot carry the `UNREADABLE` rule.

### Set the field on every reviewer

The upstream project does this for its document reviewers. Rejected here because this repository's reviewers check code against project rules, so `CLAUDE.md` is their input rather than their bias.

### Add the probe to the scheduled live-eval workflow

Rejected for now. That workflow's key pool and checkpoints serve skill-review predictions, and a daily run would spend credits on a contract that changes only when the host does. Revisit if a host upgrade breaks isolation unnoticed.
