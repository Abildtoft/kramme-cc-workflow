// Local regression test for the maintained SlopRule type contract.

import { describe, expect, it } from "./test-harness.js";
import { runSlopGuard } from "./engine.js";
import type { SlopCtxLike, SlopRule } from "./types.js";

interface RequiredContext extends SlopCtxLike {
  requiredToken: string;
}

const narrowRule: SlopRule<RequiredContext> = {
  id: "required-context",
  category: "quality",
  tell: "test",
  prevention: "test",
  severity: 1,
  tier: "gate",
  detect: (_html, ctx) => [
    { ruleId: "required-context", detail: ctx.requiredToken },
  ],
};

if (false) {
  // @ts-expect-error A rule requiring extra context must not be widened.
  const widenedRule: SlopRule<SlopCtxLike> = narrowRule;
  void widenedRule;

  // @ts-expect-error The engine must require the context its rules consume.
  runSlopGuard("", {}, [narrowRule]);
}

describe("SlopRule context variance", () => {
  it("retains the narrow context at runtime", () => {
    expect(narrowRule.detect("", { requiredToken: "present" })[0]?.detail).toBe(
      "present",
    );
  });
});
