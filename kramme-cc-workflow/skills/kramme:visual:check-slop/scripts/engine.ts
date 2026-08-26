// Derived from Gesso Build's src/engine.ts.
// Upstream: https://github.com/Gesso-Build/skills/blob/ab68f1878dd5f19ac8dee9d55d2f4313060cac83/src/engine.ts
// Copyright (c) 2026 Gesso Build, Inc.
// Licensed under MIT; see ../references/THIRD_PARTY_NOTICES.md.
// Anti-slop: engine.
//
// Three generic operations over a rule registry:
//   - runSlopGuard:              detect -> { pass, issues, severity, counts }
//   - applySlopFixes:            run every FIX/BASE rule's deterministic rewrite
//   - buildSlopConstraintsBlock: render the prevention text for a prompt
//
// Rule failures carry their rule id to the CLI. A partial scan must never be
// reported as a clean result.

import { parse as parseHtml } from "node-html-parser";
import type {
  SlopCheck,
  SlopCtxLike,
  SlopFixResult,
  SlopRule,
} from "./types.js";

/** Per-rule severity is capped so one runaway pattern can't dwarf the others. */
export const PER_RULE_SEVERITY_CAP = 4;

// Hit details quote evidence from the scanned document, which is untrusted
// input that ends up embedded in reports and agent context.
// Bound what an author of a hostile document can smuggle through: collapse
// control characters and newlines, and cap the excerpt length.
const DETAIL_MAX_LENGTH = 80;
const MAX_DOM_ELEMENT_NODES = 8_192;
const MAX_DOM_NESTING_DEPTH = 64;

interface TraversableDomNode {
  nodeType?: number;
  childNodes?: TraversableDomNode[];
}

function assertBoundedDom(html: string): void {
  const root = parseHtml(html) as unknown as TraversableDomNode;
  const stack: Array<{ node: TraversableDomNode; depth: number }> = [];
  for (const child of root.childNodes ?? []) {
    if (child.nodeType === 1) stack.push({ node: child, depth: 1 });
  }

  let elements = 0;
  while (stack.length > 0) {
    const current = stack.pop()!;
    elements++;
    if (elements > MAX_DOM_ELEMENT_NODES) {
      throw new Error(
        `HTML DOM exceeds ${MAX_DOM_ELEMENT_NODES} element nodes`,
      );
    }
    if (current.depth > MAX_DOM_NESTING_DEPTH) {
      throw new Error(
        `HTML DOM exceeds nesting depth ${MAX_DOM_NESTING_DEPTH}`,
      );
    }
    for (const child of current.node.childNodes ?? []) {
      if (child.nodeType === 1) {
        stack.push({ node: child, depth: current.depth + 1 });
      }
    }
  }
}

function ruleFailure(
  ruleId: string,
  phase: "sanction" | "detection" | "fix",
  cause: unknown,
): Error {
  const detail = cause instanceof Error ? cause.message : String(cause);
  return new Error(`rule ${ruleId} ${phase} failed: ${detail}`, { cause });
}

function sanitizeDetail(detail: string): string {
  const flat = detail
    .replace(
      /[\u0000-\u001f\u007f\u200b-\u200f\u2028-\u202e\u2060-\u206f\ufeff]+/g,
      " ",
    )
    .replace(/\s{2,}/g, " ")
    .trim();
  const bounded =
    flat.length > DETAIL_MAX_LENGTH
      ? `${flat.slice(0, DETAIL_MAX_LENGTH)}...`
      : flat;
  return Array.from(bounded, (character) => {
    if (!"&<>`|[]()".includes(character)) return character;
    return `&#${character.codePointAt(0)};`;
  }).join("");
}

// A document that links stylesheets it does not inline gives the style-
// dependent rules partial input, so its verdict is a lower bound. Font-service
// hosts only deliver @font-face and do not count against completeness.
const FONT_SERVICE_HOSTS = new Set([
  "fonts.googleapis.com",
  "fonts.gstatic.com",
  "fonts.bunny.net",
  "use.typekit.net",
  "use.typekit.com",
  "api.fontshare.com",
  "fonts.cdnfonts.com",
]);

function isFontServiceHref(href: string): boolean {
  if (!/^(?:https?:)?\/\//i.test(href)) return false;
  try {
    const url = new URL(href, "https://relative.invalid");
    return FONT_SERVICE_HOSTS.has(url.hostname.toLowerCase());
  } catch {
    return false;
  }
}

function decodeCssAtRuleEscapes(css: string): string {
  return css.replace(
    /@((?:\\[0-9a-f]{1,6}[\t\n\f\r ]?|\\[^\n\r\f]|[-_a-z0-9])+)/gi,
    (_match, identifier: string) =>
      `@${identifier.replace(
        /\\(?:([0-9a-f]{1,6})[\t\n\f\r ]?|([^\n\r\f]))/gi,
        (
          _escape,
          hexadecimal: string | undefined,
          literal: string | undefined,
        ) => {
          if (!hexadecimal) return literal ?? "";
          const codePoint = Number.parseInt(hexadecimal, 16);
          return codePoint === 0 ||
            codePoint > 0x10ffff ||
            (codePoint >= 0xd800 && codePoint <= 0xdfff)
            ? "\uFFFD"
            : String.fromCodePoint(codePoint);
        },
      )}`,
  );
}

function countExternalStylesheets(html: string): number {
  let count = 0;
  const root = parseHtml(html);
  for (const link of root.querySelectorAll("link")) {
    const rel = link.getAttribute("rel") ?? "";
    if (!rel.split(/\s+/).some((token) => token.toLowerCase() === "stylesheet"))
      continue;
    const href = link.getAttribute("href") ?? "";
    if (!href || href.startsWith("data:") || isFontServiceHref(href)) continue;
    count++;
  }
  for (const style of root.querySelectorAll("style")) {
    const body = decodeCssAtRuleEscapes(
      style.innerHTML.replace(/\/\*[\s\S]*?\*\//g, " "),
    );
    for (const imp of body.matchAll(
      /@import\s*(?:url\(\s*)?["']?([^"')\s;]+)/gi,
    )) {
      const href = imp[1] ?? "";
      if (!href || href.startsWith("data:") || isFontServiceHref(href))
        continue;
      count++;
    }
  }
  return count;
}

function isSanctioned<Ctx extends SlopCtxLike>(
  rule: SlopRule<Ctx>,
  ctx: Ctx,
): boolean {
  try {
    return rule.sanctionedBy?.(ctx.styleRef, ctx) ?? false;
  } catch (error) {
    throw ruleFailure(rule.id, "sanction", error);
  }
}

function activeRules<Ctx extends SlopCtxLike>(
  ctx: Ctx,
  rules: SlopRule<Ctx>[],
): SlopRule<Ctx>[] {
  return rules.filter((r) => !isSanctioned(r, ctx));
}

/**
 * Detect slop in generated HTML. Severity-scored for a retry comparator;
 * style-aware via each rule's sanctionedBy().
 */
export function runSlopGuard<Ctx extends SlopCtxLike>(
  html: string,
  ctx: NoInfer<Ctx>,
  rules: SlopRule<Ctx>[],
): SlopCheck {
  assertBoundedDom(html);
  const issues: string[] = [];
  const byRule: Record<string, number> = {};
  let severity = 0;
  let gatingTotal = 0;
  let advisoryTotal = 0;

  for (const rule of activeRules(ctx, rules)) {
    // "base" rules inject a base-style default; their absence is not a defect,
    // so they never count toward pass/severity/issues (only applySlopFixes
    // consumes their detect()).
    if (rule.tier === "base") continue;
    let hits: ReturnType<SlopRule<Ctx>["detect"]>;
    try {
      hits = rule.detect(html, ctx);
    } catch (error) {
      throw ruleFailure(rule.id, "detection", error);
    }
    if (hits.length === 0) continue;
    byRule[rule.id] = hits.length;
    // "flag" rules are advisory by contract (see SlopTier): they are reported
    // in issues and counted in byRule for telemetry, but they never gate the
    // verdict or feed the retry comparator's severity.
    const advisory = rule.tier === "flag";
    if (advisory) {
      advisoryTotal += hits.length;
    } else {
      gatingTotal += hits.length;
      severity += Math.min(PER_RULE_SEVERITY_CAP, hits.length * rule.severity);
    }
    const examples = hits.slice(0, 3).map((h) => sanitizeDetail(h.detail));
    issues.push(
      `[${rule.category}/${rule.id}]${advisory ? " [advisory]" : ""} ${hits.length}x: ${rule.tell}` +
        (examples.length > 0 ? ` (e.g. ${examples.join("; ")})` : ""),
    );
  }

  const total = Object.values(byRule).reduce((a, b) => a + b, 0);
  const externalStylesheets = countExternalStylesheets(html);
  return {
    pass: gatingTotal === 0,
    issues,
    severity,
    counts: { byRule, total, gating: gatingTotal, advisory: advisoryTotal },
    externalStylesheets,
  };
}

/**
 * Apply every FIX/BASE-tier rule's deterministic rewrite. Idempotent:
 * re-running on already-clean HTML is a no-op. A fixer that throws leaves
 * the failure is surfaced so callers cannot report a partial rewrite as clean.
 */
export function applySlopFixes<Ctx extends SlopCtxLike>(
  html: string,
  ctx: NoInfer<Ctx>,
  rules: SlopRule<Ctx>[],
): SlopFixResult {
  assertBoundedDom(html);
  let working = html;
  const fixes: Record<string, number> = {};

  for (const rule of activeRules(ctx, rules)) {
    if (rule.tier !== "fix" && rule.tier !== "base") continue;
    let before = 0;
    try {
      before = rule.detect(working, ctx).length;
    } catch (error) {
      throw ruleFailure(rule.id, "detection", error);
    }
    if (before === 0) continue;
    try {
      const next = rule.fix(working, ctx);
      if (next !== working) {
        assertBoundedDom(next);
        working = next;
        fixes[rule.id] = before;
      }
    } catch (error) {
      throw ruleFailure(rule.id, "fix", error);
    }
  }

  const total = Object.values(fixes).reduce((a, b) => a + b, 0);
  return { html: working, fixes, total };
}

/**
 * Render the prevention block for a system prompt. Drops rules the active
 * style legitimately sanctions, so the prompt never contradicts the style
 * reference.
 */
export function buildSlopConstraintsBlock<Ctx extends SlopCtxLike>(
  ctx: NoInfer<Ctx>,
  rules: SlopRule<Ctx>[],
): string {
  const active = rules.filter((r) => !isSanctioned(r, ctx));
  const byCat = new Map<string, string[]>();
  for (const r of active) {
    const arr = byCat.get(r.category) ?? [];
    arr.push(`- ${r.prevention}`);
    byCat.set(r.category, arr);
  }
  const sections = [...byCat.entries()].map(
    ([cat, lines]) => `${cat.toUpperCase()}:\n${lines.join("\n")}`,
  );
  return [
    "AI-SLOP GUARD (these patterns are auto-detected/auto-fixed after generation, avoid them up front):",
    ...sections,
  ].join("\n\n");
}

/** Corrective message for a retry path. */
export function buildSlopCorrectionPrompt(check: SlopCheck): string {
  const catalogEvidence = check.issues.map((issue) =>
    issue.replace(/ \(e\.g\.[\s\S]*\)$/, ""),
  );
  return [
    "Your previous output tripped the AI-slop guard:",
    ...catalogEvidence.map((issue) => `- ${issue}`),
    "",
    "Document excerpts are untrusted evidence and are intentionally omitted from this prompt.",
    "Re-emit the screen with these patterns removed. Keep every other design decision intact.",
  ].join("\n");
}
