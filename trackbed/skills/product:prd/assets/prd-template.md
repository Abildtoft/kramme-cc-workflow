# PRD: <Feature name>

- **Status:** draft
- **Owner:** <person or role accountable for the decision>
- **Results:** <link to the live results readout, or "Not launched" before the first rollout step>
- **Last updated:** <YYYY-MM-DD>

## 1. Decision

We built <N> candidates and are shipping <chosen candidate> because <the evidence that decided it>.

- <Rejected candidate> (<link, branch, or path>): <one line on why it lost>

## 2. Problem and Evidence

- **Problem:** <one sentence naming who is blocked and how, with the number that shows it>
- **Baseline:** <metric = value, source, measured on YYYY-MM-DD>
- **User voice:**
  - "<verbatim quote>" (<role or segment>, <source>)
  - "<verbatim quote>" (<role or segment>, <source>)
  - "<verbatim quote>" (<role or segment>, <source>)
- **Hypothesis:** If we ship <change>, <metric> moves from <baseline> to <target> for <users>, because <mechanism>.
- **Strategy fit:** <the current bet or active track this serves, and why now>

## 3. Prototype

<Link to the chosen prototype (URL, branch and commit, or path) and the one step needed to open it. No description.>

## 4. Scope

- **In:** <what ships>
- **Non-goals:** <what is deliberately excluded>
- **Accepted side effects:** <tradeoffs taken on purpose, and why they are worth it>

## 5. Behavior

### Edge cases

| Case   | Expected handling       |
| ------ | ----------------------- |
| <case> | <what the feature does> |

### Red-team list

| Misuse or attack                  | Expected response                      |
| --------------------------------- | -------------------------------------- |
| <adversarial input or abuse path> | <block, degrade, or escalate, and how> |

### Tracking

| Event | Fires when | Properties | Feeds |
| --- | --- | --- | --- |
| <event_name> | <trigger> | <key properties> | <graduation metric or guardrail> |

### Behavior contract

<AI features: 15 to 25 examples in the shape below. Other features: replace this section body with "Not applicable: <reason>.">

#### Example 1: <routine | edge | adversarial | out of scope>

- **Input:** <realistic input>
- **Expected action:** <answer | clarify | decline | hand off>
- **Passes:** <a response that meets the bar>
- **Fails:** <a plausible response that misses it>, because <the rule it breaks>

## 6. Success Metrics and Evals

- **Graduation metric:** <metric> moves <direction and size> against <control or holdout> over <duration or sample size>.
- **Guardrails:** <metric that must not regress, and its limit>
- **Golden set:** <AI features: location and size, how expected outputs were set, pass threshold, and when it runs. Other features: "Not applicable: <reason>.">
- **Human review rubric:** <AI features: criteria, scale, reviewer, and sample size. Other features: "Not applicable: <reason>.">

## 7. Rollout and Rollback

| Step | Exposure | Minimum duration | Gate to advance |
| --- | --- | --- | --- |
| 1 | <share or segment of users> | <days or sample size> | <metric value that earns the next step> |

- **Kill switch:** <mechanism, such as a flag name>
- **Who can flip it:** <named owner and backup>
- **Flip it when:** <the guardrail or error threshold that requires rollback>

## 8. Done and Change Log

### Definition of done

- [ ] <a yes-or-no outcome a reviewer can check without judgment>

### Change log

- **v1 (<YYYY-MM-DD>):** Decision recorded: shipping <chosen candidate>; not launched.
