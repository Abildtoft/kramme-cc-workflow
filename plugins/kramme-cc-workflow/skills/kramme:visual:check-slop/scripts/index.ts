// Derived from Gesso Build's src/index.ts.
// Upstream: https://github.com/Gesso-Build/skills/blob/ab68f1878dd5f19ac8dee9d55d2f4313060cac83/src/index.ts
// Copyright (c) 2026 Gesso Build, Inc.
// Licensed under MIT; see ../references/THIRD_PARTY_NOTICES.md.
// Deterministic AI-slop detection and fixing for
// generated HTML/CSS.
//
//   import { runSlopGuard, applySlopFixes, FLAGSHIP_RULES } from "./index.js"
//
//   const check = runSlopGuard(html, {}, FLAGSHIP_RULES)   // detect
//   const fixed = applySlopFixes(html, {}, FLAGSHIP_RULES) // rewrite
//
// The engine is generic over the rule context, so hosts can register their
// own rules with richer style/token types alongside (or instead of) the
// flagship registry.

export {
  applySlopFixes,
  buildSlopConstraintsBlock,
  buildSlopCorrectionPrompt,
  PER_RULE_SEVERITY_CAP,
  runSlopGuard,
} from "./engine.js"
export { FLAGSHIP_RULES } from "./rules.js"
export type {
  SlopCategory,
  SlopCheck,
  SlopCtx,
  SlopCtxLike,
  SlopFixResult,
  SlopHit,
  SlopRule,
  SlopStyleHints,
  SlopTier,
} from "./types.js"
