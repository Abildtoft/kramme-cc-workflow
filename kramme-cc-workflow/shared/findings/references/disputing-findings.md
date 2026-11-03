# Disputing Findings

Use this reference when you decide whether a review or audit finding is wrong. You often wrote the work under review, so wanting a finding to be wrong is not evidence that it is. The adopting `SKILL.md` names this file and says how each outcome is recorded.

## Sort Each Finding

- **Accept:** the finding holds, or you only doubt it. Take it through the skill's normal path.
- **Contest:** the finding is wrong and you can cite evidence the reviewer could have read: a file and line, a test, a documented rule, a quote from the reviewed document, or a recorded decision. Cite it, so anyone can check your call without asking you.
- **Escalate:** the finding looks wrong only because of something no file records, such as an earlier conversation, a verbal agreement, or a team habit. Nobody can check that evidence, so do not contest the finding, and do not quietly skip it. Name the unrecorded fact and give the finding to the person who can decide.

## Rules

- "This was intentional" is not evidence. Neither is your memory of why the work looks the way it does.
- Do not contest a comprehension gap. If a fresh reader could not follow the material, it is missing something, even when you know the answer. When a reader misread code, check whether the code invited it, and make the code or its comment clearer if a careful reader could make the same mistake.
- Do not add text only to satisfy a reviewer that lacked context. Add it when a human reader needs it. When you believe only the reviewer needs it, escalate, even for a comprehension gap.
- Do not lower a severity to make a finding go away. A real problem rated too high is still a real problem: accept the finding, and record your evidence for the lower rating alongside it.
- A difference of taste is not a dispute. Use the skill's path for nits and preferences.
