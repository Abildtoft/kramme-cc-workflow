// Derived from Gesso Build's src/__tests__/report-context.test.ts.
// Upstream: https://github.com/Gesso-Build/skills/blob/ab68f1878dd5f19ac8dee9d55d2f4313060cac83/src/__tests__/report-context.test.ts
// Copyright (c) 2026 Gesso Build, Inc.
// Licensed under MIT; see ../references/THIRD_PARTY_NOTICES.md.
// Comparative readings of checked documents need more than the gating
// severity: advisory (flag-tier) hits and style-input completeness are
// context the check must carry, and advisory hits must never gate the
// verdict. These tests pin that report-context contract.
import assert from "node:assert/strict";
import { applySlopFixes, runSlopGuard } from "./engine.js";
import { describe, expect, it } from "./test-harness.js";
import type { SlopCtx, SlopRule } from "./types.js";

function rule(
  id: string,
  tier: "fix" | "gate" | "flag",
  hits: number,
): SlopRule<SlopCtx> {
  const definition = {
    id,
    category: "copy" as const,
    tell: `${id} (test rule)`,
    prevention: "n/a (test rule)",
    severity: 1,
    detect: () =>
      Array.from({ length: hits }, (_, i) => ({
        ruleId: id,
        detail: `hit ${i}`,
      })),
  };
  return tier === "fix"
    ? { ...definition, tier, fix: (html: string) => html }
    : { ...definition, tier };
}

describe("gating vs advisory counts", () => {
  it("splits the totals and keeps advisory out of pass and severity", () => {
    const check = runSlopGuard("<html></html>", {}, [
      rule("gate-a", "gate", 2),
      rule("flag-b", "flag", 5),
    ]);
    expect(check.counts.gating).toBe(2);
    expect(check.counts.advisory).toBe(5);
    expect(check.counts.total).toBe(7);
    expect(check.pass).toBe(false);
    expect(check.severity).toBe(2);
  });

  it("passes with zero severity on advisory-only hits", () => {
    const check = runSlopGuard("<html></html>", {}, [
      rule("flag-only", "flag", 3),
    ]);
    expect(check.pass).toBe(true);
    expect(check.severity).toBe(0);
    expect(check.counts.gating).toBe(0);
    expect(check.counts.advisory).toBe(3);
    expect(check.counts.total).toBe(3);
  });
});

describe("external stylesheet completeness signal", () => {
  const NO_RULES: SlopRule<SlopCtx>[] = [];

  it("counts linked stylesheets the document does not inline", () => {
    const check = runSlopGuard(
      '<link rel="stylesheet" href="https://cdn.example.com/site.css">' +
        '<link href="/styles/app.css" rel="stylesheet">',
      {},
      NO_RULES,
    );
    expect(check.externalStylesheets).toBe(2);
  });

  it("recognizes stylesheet anywhere in a multi-token rel value", () => {
    const check = runSlopGuard(
      '<link rel="alternate stylesheet" href="/alternate.css">' +
        '<link rel="preload stylesheet" href="/preloaded.css">',
      {},
      NO_RULES,
    );
    expect(check.externalStylesheets).toBe(2);
  });

  it("ignores font-service links, which only deliver @font-face", () => {
    const check = runSlopGuard(
      '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Fraunces">' +
        '<link rel="stylesheet" href="https://fonts.bunny.net/css?family=x">',
      {},
      NO_RULES,
    );
    expect(check.externalStylesheets).toBe(0);
  });

  it("does not trust font-service names in an attacker URL", () => {
    const check = runSlopGuard(
      '<link rel="stylesheet" href="https://attacker.example/theme.css?fonts.googleapis.com">' +
        '<link rel="stylesheet" href="https://attacker.example/fonts.gstatic.com/theme.css">',
      {},
      NO_RULES,
    );
    expect(check.externalStylesheets).toBe(2);
  });

  it("parses quoted angle brackets without losing stylesheet links", () => {
    const check = runSlopGuard(
      '<link data-note=">" rel="stylesheet" href="https://attacker.example/theme.css">',
      {},
      NO_RULES,
    );
    expect(check.externalStylesheets).toBe(1);
  });

  it("counts @import targets inside style blocks", () => {
    const check = runSlopGuard(
      "<style>@import url('https://cdn.example.com/theme.css'); body { color: red }</style>",
      {},
      NO_RULES,
    );
    expect(check.externalStylesheets).toBe(1);
  });

  it("counts compact and comment-separated @import targets", () => {
    const check = runSlopGuard(
      '<style>@import"/compact.css"; @import/**/url("https://cdn.example.com/commented.css");</style>',
      {},
      NO_RULES,
    );
    expect(check.externalStylesheets).toBe(2);
  });

  it("counts escaped CSS @import identifiers", () => {
    const check = runSlopGuard(
      '<style>@\\69mport "/escaped.css"; @\\000069 mport url("/padded.css");</style>',
      {},
      NO_RULES,
    );
    expect(check.externalStylesheets).toBe(2);
  });

  it("reports zero for a self-contained document", () => {
    const check = runSlopGuard(
      '<style>body { margin: 0 }</style><link rel="icon" href="/favicon.ico">',
      {},
      NO_RULES,
    );
    expect(check.externalStylesheets).toBe(0);
  });
});

describe("DOM shape limits", () => {
  const NO_RULES: SlopRule<SlopCtx>[] = [];

  it("rejects excessive nesting before running detectors or fixers", () => {
    const html = `${"<div>".repeat(65)}content${"</div>".repeat(65)}`;
    assert.throws(
      () => runSlopGuard(html, {}, NO_RULES),
      /HTML DOM exceeds nesting depth 64/,
    );
    assert.throws(
      () => applySlopFixes(html, {}, NO_RULES),
      /HTML DOM exceeds nesting depth 64/,
    );
  });

  it("rejects excessive element counts before running detectors", () => {
    const html = `<main>${"<span>x</span>".repeat(8_192)}</main>`;
    assert.throws(
      () => runSlopGuard(html, {}, NO_RULES),
      /HTML DOM exceeds 8192 element nodes/,
    );
  });

  it("rejects a fixer output that crosses the DOM limit", () => {
    const html = `<main>${"<span>x</span>".repeat(8_191)}</main>`;
    const expandingRule: SlopRule<SlopCtx> = {
      id: "expanding-rule",
      category: "quality",
      tell: "test",
      prevention: "test",
      severity: 1,
      tier: "base",
      detect: () => [{ ruleId: "expanding-rule", detail: "test" }],
      fix: (source) => source.replace("</main>", "<i></i></main>"),
    };
    assert.throws(
      () => applySlopFixes(html, {}, [expandingRule]),
      /rule expanding-rule fix failed: HTML DOM exceeds 8192 element nodes/,
    );
  });
});

describe("rule execution failures", () => {
  const throwingRule: SlopRule<SlopCtx> = {
    id: "broken-rule",
    category: "quality",
    tell: "test",
    prevention: "test",
    tier: "fix",
    severity: 1,
    detect: () => {
      throw new Error("detector exploded");
    },
    fix: (html) => html,
  };

  it("surfaces detector failures with the rule identity", () => {
    assert.throws(
      () => runSlopGuard("<html></html>", {}, [throwingRule]),
      /rule broken-rule detection failed: detector exploded/,
    );
    assert.throws(
      () => applySlopFixes("<html></html>", {}, [throwingRule]),
      /rule broken-rule detection failed: detector exploded/,
    );
  });

  it("surfaces fixer failures with the rule identity", () => {
    const fixerRule: SlopRule<SlopCtx> = {
      ...throwingRule,
      detect: () => [{ ruleId: "broken-rule", detail: "hit" }],
      fix: () => {
        throw new Error("fixer exploded");
      },
    };
    assert.throws(
      () => applySlopFixes("<html></html>", {}, [fixerRule]),
      /rule broken-rule fix failed: fixer exploded/,
    );
  });

  it("surfaces sanction failures instead of enabling a rule", () => {
    const sanctionRule: SlopRule<SlopCtx> = {
      ...throwingRule,
      sanctionedBy: () => {
        throw new Error("style lookup exploded");
      },
    };
    assert.throws(
      () => runSlopGuard("<html></html>", {}, [sanctionRule]),
      /rule broken-rule sanction failed: style lookup exploded/,
    );
    assert.throws(
      () => applySlopFixes("<html></html>", {}, [sanctionRule]),
      /rule broken-rule sanction failed: style lookup exploded/,
    );
  });
});
