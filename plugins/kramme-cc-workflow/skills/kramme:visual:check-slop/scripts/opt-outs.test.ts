// Local regression suite (maintained by kramme; not derived from Gesso).
// Every opt-out the catalog documents must reach an opt-out helper in the
// rules, the opt-outs this suite exercises must suppress their rule in
// detection and fixing, pill controls are never reported as over-rounded
// cards, and fixers that rewrite a <style> body keep the author's comments.

import * as fs from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";
import { applySlopFixes, runSlopGuard } from "./engine.js";
import { FLAGSHIP_RULES } from "./rules.js";
import { describe, expect, it } from "./test-harness.js";

const SCRIPTS_DIR = path.dirname(fileURLToPath(import.meta.url));
const rulesSource = fs.readFileSync(path.join(SCRIPTS_DIR, "rules.ts"), "utf8");
const catalog = fs.readFileSync(
  path.join(SCRIPTS_DIR, "..", "references", "rules.md"),
  "utf8",
);

const guard = (html: string) => runSlopGuard(html, {}, FLAGSHIP_RULES);
const fix = (html: string) => applySlopFixes(html, {}, FLAGSHIP_RULES);
// Other rules may legitimately rewrite the same declarations, so opt-out
// fixing is checked against the one rule under test.
const fixOnly = (html: string, ruleId: string) =>
  applySlopFixes(
    html,
    {},
    FLAGSHIP_RULES.filter((rule) => rule.id === ruleId),
  );
const hits = (html: string, ruleId: string) =>
  guard(html).counts.byRule[ruleId];

const page = (body: string, head = "") =>
  `<!doctype html><html lang="en"><head><title>t</title>${head}</head><body>${body}</body></html>`;
const styled = (css: string) =>
  page(
    `<main><p class="x card">Hello there</p></main>`,
    `<style>${css}</style>`,
  );

/** Literal rule ids passed to any of `helpers` in rules.ts. */
function idsPassedTo(helpers: string[]): Set<string> {
  const ids = new Set<string>();
  const call = new RegExp(`\\b(?:${helpers.join("|")})\\(`, "g");
  for (const match of rulesSource.matchAll(call)) {
    const start = (match.index ?? 0) + match[0].length;
    const args = rulesSource.slice(start, start + 160).split(")")[0] ?? "";
    for (const id of args.matchAll(/"([a-z-]+)"/g)) ids.add(id[1]);
  }
  return ids;
}

describe("documented opt-outs", () => {
  it("every catalog opt-out reaches an opt-out check in the rules", () => {
    const cssIds = new Set(
      [...catalog.matchAll(/--slop-allow: ([a-z-]+)/g)].map((m) => m[1]),
    );
    const elementIds = new Set(
      [...catalog.matchAll(/data-slop-allow="([a-z-]+)"/g)].map((m) => m[1]),
    );
    cssIds.delete("rule-id");
    elementIds.delete("rule-id");
    const cssHonored = idsPassedTo([
      "declsAllow",
      "unlessAllowed",
      "bodyAllows",
    ]);
    const elementHonored = idsPassedTo([
      "tagAllows",
      "elAllows",
      "allowsUpTo",
      "bodyAllows",
    ]);
    expect([...cssIds].filter((id) => !cssHonored.has(id))).toEqual([]);
    expect([...elementIds].filter((id) => !elementHonored.has(id))).toEqual([]);
  });

  const cssCases: Array<[string, string]> = [
    ["indigo-accent", ".x{color:#6366f1}"],
    ["purple-violet-wash", ".x{background:#9333ea}"],
    ["safe-green-default", ".x{color:#10b981}"],
    ["crushed-tracking", ".x{letter-spacing:-0.06em}"],
    ["wide-body-tracking", ".x{font-size:16px;letter-spacing:0.1em}"],
    ["tight-line-height", ".x{font-size:16px;line-height:1.1}"],
    ["tiny-body-text", ".x{font-size:10px}"],
    ["over-rounded-card", ".card{background:#ffffff;border-radius:48px}"],
    [
      "ghost-card",
      ".x{border:1px solid #e5e7eb;box-shadow:0 8px 30px rgba(0,0,0,0.08)}",
    ],
    ["dark-glow", ".x{box-shadow:0 0 40px rgba(168,85,247,0.6)}"],
    [
      "bounce-easing",
      ".x{transition:transform .3s cubic-bezier(0.68,-0.55,0.265,1.55)}",
    ],
    ["hover-scale-image", ".card:hover img{transform:scale(1.1)}"],
  ];

  for (const [ruleId, css] of cssCases) {
    it(`--slop-allow suppresses ${ruleId} in detection and fixing`, () => {
      expect(hits(styled(css), ruleId)).toBeGreaterThan(0);
      const optedOut = `${css.slice(0, -1)};--slop-allow: ${ruleId}}`;
      expect(hits(styled(optedOut), ruleId)).toBeUndefined();
      expect(fixOnly(styled(optedOut), ruleId).html).toContain(optedOut);
      if (FLAGSHIP_RULES.find((rule) => rule.id === ruleId)?.fix) {
        // Control: without the opt-out the same rule does rewrite the group.
        expect(fixOnly(styled(css), ruleId).html).not.toContain(css);
      }
    });
  }

  it("cream-default-wash honors both documented page opt-outs", () => {
    const cream = (bodyCss: string, bodyAttrs = "") =>
      `<!doctype html><html lang="en"><head><title>t</title><style>body{${bodyCss}} h1{font-family:Georgia, serif}</style></head><body${bodyAttrs}><main><h1>Hi</h1><p>Hello</p></main></body></html>`;
    expect(hits(cream("background:#f7f2e8"), "cream-default-wash")).toBe(1);
    expect(
      hits(
        cream("background:#f7f2e8;--slop-allow: cream-default-wash"),
        "cream-default-wash",
      ),
    ).toBeUndefined();
    expect(
      hits(
        cream("background:#f7f2e8", ' data-slop-allow="cream-default-wash"'),
        "cream-default-wash",
      ),
    ).toBeUndefined();
  });

  it("row-as-card honors a per-row element opt-out", () => {
    const rows = (attrs: string) =>
      Array.from(
        { length: 3 },
        () =>
          `<div class="feedrow"${attrs}><img src="a.jpg" alt=""><div>Coffee with Sam</div><div>Yesterday, 4pm</div></div>`,
      ).join("");
    const css = `<style>.feedrow{border-radius:12px;background:#fff}</style>`;
    expect(hits(page(`<div>${rows("")}</div>`, css), "row-as-card")).toBe(1);
    expect(
      hits(
        page(`<div>${rows(' data-slop-allow="row-as-card"')}</div>`, css),
        "row-as-card",
      ),
    ).toBeUndefined();
  });

  it("publication-masthead-block honors its element opt-out", () => {
    const block = (attrs: string) =>
      page(
        `<div class="hero-meta"${attrs}><span>VOL. 04 / 2024</span><span>Catalogue HV-IDX-029</span></div><h2>Real content</h2>`,
      );
    expect(hits(block(""), "publication-masthead-block")).toBe(1);
    const optedOut = block(' data-slop-allow="publication-masthead-block"');
    expect(hits(optedOut, "publication-masthead-block")).toBeUndefined();
    expect(fix(optedOut).html).toContain("Catalogue HV-IDX-029");
  });
});

describe("over-rounded-card controls", () => {
  it("spares rounded links, buttons, and control classes", () => {
    const html = page(
      `<a class="cta" href="#" style="border-radius:99px;background:#111;color:#fff">Start</a>` +
        `<button style="border-radius:44px;background:#2563eb;color:#fff">Go</button>` +
        `<span class="btn">Buy</span><span class="chip chip--active">New</span>` +
        `<div role="button" style="border-radius:40px;background:#111">Menu</div>` +
        `<input type="submit" value="Send" style="border-radius:40px;background:#111">`,
      `<style>.btn{border-radius:100px;background:#111}.chip--active{border-radius:48px;background:#eee}</style>`,
    );
    expect(hits(html, "over-rounded-card")).toBeUndefined();
    const fixed = fix(html).html;
    expect(fixed).toContain("border-radius:99px");
    expect(fixed).toContain("border-radius:44px");
    expect(fixed).toContain(".btn{border-radius:100px");
  });

  it("still flags content surfaces, including look-alike names", () => {
    const flagged = [
      styled(".panel{border-radius:56px;background:#fff}"),
      styled(".tag-list .card{border-radius:48px;background:#fff}"),
      styled(".cta-banner{border-radius:48px;background:#fff}"),
      styled(".btn-group .panel{border-radius:48px;background:#fff}"),
      // A list mixing a control with a surface still rounds the surface.
      styled(".btn, .card{border-radius:48px;background:#fff}"),
      page(
        `<div aria-label="make a card" style="border-radius:48px;background:#fff">x</div>`,
      ),
      page(
        `<a class="card" href="#" style="border-radius:48px;background:#fff">Clickable card</a>`,
      ),
    ];
    for (const html of flagged) {
      expect(hits(html, "over-rounded-card")).toBe(1);
    }
    expect(fix(flagged[0]).html).toContain("border-radius:24px");
  });
});

describe("fixers keep authored CSS comments", () => {
  it("redundant-border", () => {
    const html = page(
      `<div class="c">card</div>`,
      `<style>/* palette */ .c{background:#f6f1ea; border:1px solid #d8cfc2; border-radius:12px} /* end */</style>`,
    );
    expect(hits(html, "redundant-border")).toBe(1);
    const fixed = fix(html).html;
    expect(fixed).not.toContain("border:1px solid #d8cfc2");
    expect(fixed).toContain("/* palette */");
    expect(fixed).toContain("/* end */");
  });

  it("grid-spacer-void", () => {
    const html = page(
      `<div class="grid"><div class="cell">A</div><div class="sep"></div><div class="cell">B</div></div>`,
      `<style>/* layout */ .grid{display:grid;/* rows */grid-auto-rows:168px}.sep{grid-column:1/-1;height:1px;background:#eee}</style>`,
    );
    expect(hits(html, "grid-spacer-void")).toBe(1);
    const fixed = fix(html).html;
    expect(fixed).toContain("grid-auto-rows: auto");
    expect(fixed).toContain("/* layout */");
    expect(fixed).toContain("/* rows */");
  });

  it("wrap-padding-collision", () => {
    const html = page(
      `<section class="wrap band">content</section>`,
      `<style>/* shell */ .wrap{max-width:1100px;margin-inline:auto;padding-inline:24px}.band{/* rhythm */padding:64px 0}</style>`,
    );
    expect(hits(html, "wrap-padding-collision")).toBe(1);
    const fixed = fix(html).html;
    expect(fixed).toContain("padding-block: 64px");
    expect(fixed).toContain("/* shell */");
    expect(fixed).toContain("/* rhythm */");
  });
});
