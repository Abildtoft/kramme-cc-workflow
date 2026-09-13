// Derived from Gesso Build's src/types.ts.
// Upstream: https://github.com/Gesso-Build/skills/blob/ab68f1878dd5f19ac8dee9d55d2f4313060cac83/src/types.ts
// Copyright (c) 2026 Gesso Build, Inc.
// Licensed under MIT; see ../references/THIRD_PARTY_NOTICES.md.
// Anti-slop: shared types.
//
// A "slop rule" is one source of truth for three artifacts:
//   - `prevention`: a negative constraint to inject into a generation prompt,
//   - `detect`: a post-generation detector over the HTML string,
//   - `fix` (optional): a deterministic, idempotent, design-preserving rewrite.
//
// The engine (./engine) is generic over the rule context, so a host can
// thread its own richer context (style-system objects, design tokens)
// through detect/fix/sanctionedBy without this package knowing about them.

/**
 * How a rule is enforced.
 * - "fix":  deterministic rewrite of a DEFECT, available only through an
 *           explicit applySlopFixes()/--fix call. Must be design-preserving
 *           and idempotent. Hits count toward pass/severity.
 * - "base": deterministic ADDITIVE injection of a base-style default. Its
 *           absence is NOT a defect, so runSlopGuard excludes it from
 *           pass/severity/issues; only applySlopFixes consumes its detect().
 * - "gate": contributes `severity` and blocks the verdict. A reviewer must
 *           choose the resolution because a regex cannot safely rewrite it.
 * - "flag": advisory output and counting only; never blocks the verdict.
 */
export type SlopTier = "fix" | "base" | "gate" | "flag";

export type SlopCategory =
  | "visual"
  | "type"
  | "color"
  | "layout"
  | "motion"
  | "copy"
  | "imagery"
  | "quality";

/** One detected occurrence of a slop rule. */
export interface SlopHit {
  ruleId: string;
  /** Human-readable specifics (a value, selector, or excerpt) for logs. */
  detail: string;
}

/**
 * The minimal context shape the engine needs. Hosts extend this with their
 * own style/token types; the engine only threads it through.
 */
export interface SlopCtxLike {
  /** The active style reference, consulted by sanctionedBy(). */
  styleRef?: unknown;
  /** Design tokens, for picking safe replacement values in fixes. */
  tokens?: unknown;
  /**
   * Replication mode: when faithfully reproducing a reference whose hero
   * legitimately uses an expressive treatment (gradient headline), rules
   * that would strip it are sanctioned.
   */
  replicate?: boolean;
}

/** The context shape this package's own flagship rules consume. */
export interface SlopCtx extends SlopCtxLike {
  styleRef?: SlopStyleHints;
  tokens?: Record<string, unknown>;
}

/** Structural hints a flagship rule may read off a host's style reference. */
export interface SlopStyleHints {
  /** Stable style id (e.g. "swiss", "brutalist-bold"). */
  id?: string;
}

interface SlopRuleDefinition<Ctx extends SlopCtxLike> {
  /** Stable kebab-case id, e.g. "gradient-text". */
  id: string;
  category: SlopCategory;
  /** The tell: why this pattern reads as generated-UI slop. */
  tell: string;
  /** Negative constraint injected into the system prompt (prevention side). */
  prevention: string;
  /** Per-occurrence severity weight (capped per-rule in runSlopGuard). */
  severity: number;
  /** Detect occurrences. Pure; failures surface with this rule's identity. */
  detect: (html: string, ctx: Ctx) => SlopHit[];
  /**
   * Style-awareness. Return true when the active style legitimately mandates
   * this pattern, so the guard skips it instead of fighting the design system.
   */
  sanctionedBy?: (styleRef: Ctx["styleRef"], ctx?: Ctx) => boolean;
}

export type SlopRule<Ctx extends SlopCtxLike = SlopCtx> =
  | (SlopRuleDefinition<Ctx> & {
      tier: Extract<SlopTier, "fix" | "base">;
      /** Deterministic, idempotent rewrite required for rewrite tiers. */
      fix: (html: string, ctx: Ctx) => string;
    })
  | (SlopRuleDefinition<Ctx> & {
      tier: Exclude<SlopTier, "fix" | "base">;
      fix?: never;
    });

export interface SlopCheck {
  pass: boolean;
  issues: string[];
  /** Numeric severity for a unified retry comparator. */
  severity: number;
  counts: {
    /** Hit count per rule id (non-zero entries only). */
    byRule: Record<string, number>;
    total: number;
    /** Hits from the verdict-gating tiers (fix/gate). */
    gating: number;
    /**
     * Hits from the advisory flag tier. Advisory hits never gate pass or
     * severity, so a comparative reading of two documents must consider
     * this number alongside severity, never severity alone.
     */
    advisory: number;
  };
  /**
   * External non-font-service stylesheets the document references but does
   * not inline. Style-dependent rules only see the markup they are given,
   * so when this is nonzero the verdict is a lower bound, not a clean
   * bill.
   */
  externalStylesheets: number;
}

export interface SlopFixResult {
  html: string;
  /** Occurrences fixed per rule id (non-zero entries only). */
  fixes: Record<string, number>;
  total: number;
}
