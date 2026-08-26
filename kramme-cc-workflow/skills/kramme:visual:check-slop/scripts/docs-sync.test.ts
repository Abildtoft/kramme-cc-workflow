// Derived from Gesso Build's src/__tests__/docs-sync.test.ts.
// Upstream: https://github.com/Gesso-Build/skills/blob/ab68f1878dd5f19ac8dee9d55d2f4313060cac83/src/__tests__/docs-sync.test.ts
// Copyright (c) 2026 Gesso Build, Inc.
// Licensed under MIT; see ../references/THIRD_PARTY_NOTICES.md.
// The member-facing docs promise users they know what the detector
// ACTUALLY entails. This suite is the ratchet: every rule in the registry
// must be documented in references/rules.md with the right severity and tier,
// and no orchestration doc may claim a guard that does not exist. Add a rule,
// update the catalog; the numbers in "The N guards" headings update with it.

import * as fs from "node:fs"
import * as path from "node:path"
import { fileURLToPath } from "node:url"
import { describe, expect, it } from "./test-harness.js"
import { FLAGSHIP_RULES } from "./rules.js"

const SKILL_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")

const skillMd = fs.readFileSync(path.join(SKILL_ROOT, "SKILL.md"), "utf8")
const rulesMd = fs.readFileSync(
  path.join(SKILL_ROOT, "references/rules.md"),
  "utf8",
)

const registryIds = FLAGSHIP_RULES.map((r) => r.id).sort()

const TIER_LABEL: Record<string, string> = {
  fix: "FIX",
  gate: "GATE",
  base: "BASE",
  flag: "FLAG",
}

describe("docs stay in sync with the registry", () => {
  it("references/rules.md documents every guard with its severity and tier", () => {
    const heads = [
      ...rulesMd.matchAll(/^### ([a-z-]+) \(severity (\d+), (FIX|GATE|BASE|FLAG)\)$/gm),
    ]
    expect(heads.map((m) => m[1]).sort()).toEqual(registryIds)
    for (const [, id, severity, tier] of heads) {
      const rule = FLAGSHIP_RULES.find((r) => r.id === id)!
      expect(Number(severity), `${id} severity`).toBe(rule.severity)
      expect(tier, `${id} tier`).toBe(TIER_LABEL[rule.tier])
    }
    // Every entry carries the sections users rely on. BASE rules are
    // additive polish, not slop, so their rationale heading differs.
    for (const id of registryIds) {
      const rule = FLAGSHIP_RULES.find((r) => r.id === id)!
      const start = rulesMd.indexOf(`### ${id} `)
      const end = rulesMd.indexOf("### ", start + 1)
      const section = rulesMd.slice(start, end === -1 ? undefined : end)
      expect(section, `${id} detection spec`).toContain("**Detects:**")
      expect(section, `${id} rationale`).toContain(
        rule.tier === "base" ? "**Why it matters:**" : "**Why it reads as slop:**",
      )
    }
  })

  it("the claimed guard count matches the registry everywhere", () => {
    const n = FLAGSHIP_RULES.length
    for (const [name, text] of [
      ["SKILL.md", skillMd],
      ["references/rules.md", rulesMd],
    ] as const) {
      const claims = [...text.matchAll(/[Tt]he (\d+) guards|(\d+) slop guards/g)]
        .map((m) => Number(m[1] ?? m[2]))
      expect(claims.length, `${name} claims a count`).toBeGreaterThan(0)
      for (const c of claims) expect(c, `${name} count`).toBe(n)
    }
  })

  it("every rule id referenced in SKILL.md exists", () => {
    for (const [, id] of skillMd.matchAll(/`([a-z]+(?:-[a-z]+)+)`/g)) {
      if (id.startsWith("data-slop") || id.startsWith("slop-allow")) continue
      if (
        [
          "check-slop",
          "argument-hint",
          "anti-slop",
          "scroll-padding-inline",
          "third-party-notices",
        ].includes(id)
      )
        continue
      expect(registryIds, `SKILL.md references unknown guard ${id}`).toContain(id)
    }
  })
})
