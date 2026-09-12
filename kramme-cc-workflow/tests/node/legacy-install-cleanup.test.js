"use strict";

const assert = require("node:assert/strict");
const { createHash } = require("node:crypto");
const fs = require("fs/promises");
const path = require("path");
const test = require("node:test");

const {
  cleanupLegacyInstall,
  hasLegacyInstall,
  readLegacyInstallEntries,
} = require("../../scripts/convert-plugin/legacy-install-cleanup");

const {
  pathExists,
  readText,
  withMutedConsole,
  withTempDir,
  writeFile,
  writeJson,
} = require("./converter-test-helpers");

const TOOL_MAP_BLOCK = [
  "<!-- BEGIN KRAMME CODEX TOOL MAP -->",
  "## Kramme Codex Tool Mapping (Claude Compatibility)",
  "- Read: use shell reads",
  "<!-- END KRAMME CODEX TOOL MAP -->",
].join("\n");

/** @param {string} content */
function sha256(content) {
  return createHash("sha256").update(content).digest("hex");
}

/**
 * Lay out what an earlier converter release left behind.
 * @param {string} root
 */
async function createLegacyInstall(root) {
  const codexHome = path.join(root, "codex-home");
  const agentsHome = path.join(root, "agents-home");
  const helper = "helper body\n";
  await writeJson(path.join(codexHome, ".kramme-install-state.json"), {
    plugins: {
      "legacy-plugin": {
        codex: {
          agentSkills: ["kramme:reviewer"],
          hookMarketplaces: [".kramme-plugin-marketplaces/legacy-plugin"],
          pluginCaches: ["cache/legacy-plugin/legacy-plugin/0.1.0"],
          prompts: ["legacy-prompt.md"],
          sharedHelperFiles: {
            "scripts/changed.sh": sha256("original\n"),
            "scripts/lib/helper.sh": sha256(helper),
            "../outside.sh": sha256(helper),
          },
          skills: ["kramme:demo:run", "kramme:demo:other", "../escape"],
        },
      },
    },
    version: 1,
  });
  await writeFile(
    path.join(codexHome, "skills", "kramme:demo:run", "SKILL.md"),
    "run\n",
  );
  await writeFile(
    path.join(codexHome, "skills", "kramme:demo:other", "SKILL.md"),
    "other\n",
  );
  await writeFile(
    path.join(codexHome, "skills", "user-skill", "SKILL.md"),
    "mine\n",
  );
  await writeFile(
    path.join(codexHome, "prompts", "legacy-prompt.md"),
    "prompt\n",
  );
  await writeFile(path.join(codexHome, "prompts", "user-prompt.md"), "mine\n");
  await writeFile(
    path.join(agentsHome, "skills", "kramme:reviewer", "SKILL.md"),
    "review\n",
  );
  await writeFile(
    path.join(codexHome, ".kramme-plugin-marketplaces", "legacy-plugin", "x"),
    "x\n",
  );
  await writeFile(
    path.join(
      codexHome,
      "plugins",
      "cache",
      "legacy-plugin",
      "legacy-plugin",
      "0.1.0",
      "x",
    ),
    "x\n",
  );
  await writeFile(path.join(codexHome, "scripts", "lib", "helper.sh"), helper);
  await writeFile(
    path.join(codexHome, "scripts", "changed.sh"),
    "edited by user\n",
  );
  await writeFile(path.join(root, "outside.sh"), helper);
  await writeFile(
    path.join(codexHome, "AGENTS.md"),
    `# My notes\n\n${TOOL_MAP_BLOCK}\n\n@/Users/me/RTK.md\n`,
  );
  for (const artifact of [
    ".kramme-install-lock",
    ".kramme-install-manifests",
    ".kramme-install-staging",
    ".kramme-install-transactions",
  ]) {
    await writeFile(path.join(codexHome, artifact, "entry"), "x\n");
  }
  await writeFile(
    path.join(agentsHome, ".kramme-install-staging", "entry"),
    "x\n",
  );
  return { agentsHome, codexHome };
}

test("legacy cleanup removes exactly the recorded converter output", async () => {
  await withTempDir(async (root) => {
    const { agentsHome, codexHome } = await createLegacyInstall(root);
    assert.equal(await hasLegacyInstall(codexHome), true);

    const result = await withMutedConsole(() =>
      cleanupLegacyInstall({
        agentsHome,
        codexHome,
        confirmOptions: { yes: true },
        pluginName: "legacy-plugin",
      }),
    );
    assert.equal(result.status, "removed");

    const removed = [
      "skills/kramme:demo:run",
      "skills/kramme:demo:other",
      "prompts/legacy-prompt.md",
      ".kramme-plugin-marketplaces/legacy-plugin",
      "plugins/cache/legacy-plugin/legacy-plugin/0.1.0",
      "scripts/lib/helper.sh",
      "scripts/lib",
      ".kramme-install-state.json",
    ];
    for (const relativePath of removed) {
      assert.equal(
        await pathExists(path.join(codexHome, relativePath)),
        false,
        `${relativePath} should be removed`,
      );
    }
    assert.equal(
      await pathExists(path.join(agentsHome, "skills", "kramme:reviewer")),
      false,
    );
    assert.equal(
      await pathExists(path.join(agentsHome, ".kramme-install-staging")),
      true,
    );

    const kept = [
      "skills/user-skill/SKILL.md",
      "prompts/user-prompt.md",
      "scripts/changed.sh",
      "scripts",
      ".kramme-install-lock/entry",
      ".kramme-install-staging/entry",
      ".kramme-install-transactions/entry",
    ];
    for (const relativePath of kept) {
      assert.equal(
        await pathExists(path.join(codexHome, relativePath)),
        true,
        `${relativePath} should survive`,
      );
    }
    assert.equal(await pathExists(path.join(root, "outside.sh")), true);
    assert.equal(
      await readText(path.join(codexHome, "AGENTS.md")),
      "# My notes\n\n@/Users/me/RTK.md\n",
    );
    assert.equal(await hasLegacyInstall(codexHome), false);
  });
});

test("legacy cleanup deletes an AGENTS.md that only held the tool map", async () => {
  await withTempDir(async (root) => {
    const codexHome = path.join(root, "codex-home");
    await writeJson(path.join(codexHome, ".kramme-install-state.json"), {
      plugins: { "legacy-plugin": { codex: {} } },
      version: 1,
    });
    await writeFile(path.join(codexHome, "AGENTS.md"), `${TOOL_MAP_BLOCK}\n`);

    await withMutedConsole(() =>
      cleanupLegacyInstall({
        agentsHome: path.join(root, "agents-home"),
        codexHome,
        confirmOptions: { yes: true },
        pluginName: "legacy-plugin",
      }),
    );
    assert.equal(await pathExists(path.join(codexHome, "AGENTS.md")), false);
  });
});

test("legacy cleanup preserves paths used by the new native install", async () => {
  await withTempDir(async (root) => {
    const { agentsHome, codexHome } = await createLegacyInstall(root);
    const marketplace = path.join(codexHome, ".kramme-plugin-marketplaces", "legacy-plugin");
    const cache = path.join(codexHome, "plugins", "cache", "legacy-plugin", "legacy-plugin", "0.1.0");
    await withMutedConsole(() => cleanupLegacyInstall({
      agentsHome,
      codexHome,
      confirmOptions: { yes: true },
      pluginName: "legacy-plugin",
      preservePaths: [marketplace, cache],
    }));
    assert.equal(await pathExists(path.join(marketplace, "x")), true);
    assert.equal(await pathExists(path.join(cache, "x")), true);
    assert.equal(await pathExists(path.join(codexHome, "skills", "kramme:demo:run")), false);
  });
});

test("legacy cleanup is a no-op without state and when the user declines", async () => {
  await withTempDir(async (root) => {
    const fresh = path.join(root, "fresh-home");
    await writeFile(
      path.join(fresh, "skills", "user-skill", "SKILL.md"),
      "mine\n",
    );
    assert.deepEqual(
      await cleanupLegacyInstall({
        agentsHome: path.join(root, "agents-home"),
        codexHome: fresh,
        confirmOptions: { yes: true },
        pluginName: "legacy-plugin",
      }),
      { status: "absent" },
    );

    const { agentsHome, codexHome } = await createLegacyInstall(root);
    const declined = await withMutedConsole(() =>
      cleanupLegacyInstall({
        agentsHome,
        codexHome,
        confirmOptions: { nonInteractive: true },
        pluginName: "legacy-plugin",
      }),
    );
    assert.deepEqual(declined, { status: "declined" });
    assert.equal(
      await pathExists(path.join(codexHome, "skills", "kramme:demo:run")),
      true,
    );
    assert.equal(await hasLegacyInstall(codexHome), true);
  });
});

test("legacy entries union the per-plugin manifest with a damaged state file", async () => {
  await withTempDir(async (root) => {
    const codexHome = path.join(root, "codex-home");
    await writeFile(
      path.join(codexHome, ".kramme-install-state.json"),
      "{not json",
    );
    await writeJson(
      path.join(
        codexHome,
        ".kramme-install-manifests",
        "legacy%3Aplugin-codex.json",
      ),
      {
        skills: ["kramme:from-manifest", "", 7],
        sharedHelperFiles: { "scripts/ok.sh": "a".repeat(64), "bad path": "b" },
      },
    );

    const entries = await withMutedConsole(() =>
      readLegacyInstallEntries(codexHome, "legacy:plugin"),
    );
    assert.deepEqual(entries, {
      agentSkills: [],
      hookMarketplaces: [],
      pluginCaches: [],
      prompts: [],
      sharedHelperFiles: { "scripts/ok.sh": "a".repeat(64) },
      skills: ["kramme:from-manifest", "7"],
    });
  });
});

test("legacy cleanup recovers a manifest-only install", async () => {
  await withTempDir(async (root) => {
    const codexHome = path.join(root, "codex-home");
    const agentsHome = path.join(root, "agents-home");
    await writeJson(
      path.join(codexHome, ".kramme-install-manifests", "legacy-plugin-codex.json"),
      { skills: ["kramme:legacy:skill"] },
    );
    await writeFile(
      path.join(codexHome, "skills", "kramme:legacy:skill", "SKILL.md"),
      "legacy\n",
    );
    const result = await withMutedConsole(() =>
      cleanupLegacyInstall({
        agentsHome,
        codexHome,
        confirmOptions: { yes: true },
        pluginName: "legacy-plugin",
      }),
    );
    assert.equal(result.status, "removed");
    assert.equal(await pathExists(path.join(codexHome, "skills", "kramme:legacy:skill")), false);
    assert.equal(await pathExists(path.join(codexHome, ".kramme-install-manifests")), false);
  });
});

test("legacy cleanup preserves other plugin records", async () => {
  await withTempDir(async (root) => {
    const codexHome = path.join(root, "codex-home");
    const agentsHome = path.join(root, "agents-home");
    await writeJson(path.join(codexHome, ".kramme-install-state.json"), {
      plugins: {
        first: { codex: { skills: ["kramme:first"] } },
        second: { codex: { skills: ["kramme:second"] } },
      },
    });
    await writeFile(path.join(codexHome, "skills", "kramme:first", "SKILL.md"), "1\n");
    await writeFile(path.join(codexHome, "skills", "kramme:second", "SKILL.md"), "2\n");
    await withMutedConsole(() =>
      cleanupLegacyInstall({
        agentsHome,
        codexHome,
        confirmOptions: { yes: true },
        pluginName: "first",
      }),
    );
    assert.equal(await pathExists(path.join(codexHome, "skills", "kramme:first")), false);
    assert.equal(await pathExists(path.join(codexHome, "skills", "kramme:second")), true);
    const state = JSON.parse(await readText(path.join(codexHome, ".kramme-install-state.json")));
    assert.deepEqual(Object.keys(state.plugins), ["second"]);
  });
});

test("legacy cleanup fails closed on unreadable ownership metadata", async () => {
  await withTempDir(async (root) => {
    const codexHome = path.join(root, "codex-home");
    await writeFile(path.join(codexHome, ".kramme-install-state.json"), "{not json");
    await assert.rejects(
      cleanupLegacyInstall({
        agentsHome: path.join(root, "agents-home"),
        codexHome,
        confirmOptions: { yes: true },
        pluginName: "legacy-plugin",
      }),
      /Cannot safely clean legacy Codex output/,
    );
    assert.equal(await pathExists(path.join(codexHome, ".kramme-install-state.json")), true);
  });
});
