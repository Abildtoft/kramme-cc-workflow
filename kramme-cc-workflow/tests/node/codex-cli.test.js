"use strict";

const assert = require("node:assert/strict");
const fs = require("fs/promises");
const path = require("path");
const test = require("node:test");

const {
  defaultCodexHome,
  registerCodexPlugin,
  unregisterCodexPlugin,
} = require("../../scripts/convert-plugin/codex-cli");

const {
  fixtureCodexPluginPackage,
  pathExists,
  readText,
  withTempDir,
  writeFile,
  writeJson,
} = require("./converter-test-helpers");

const FAKE_CODEX_BIN = path.join(__dirname, "..", "test_helper", "mocks");

/**
 * @template T
 * @param {NodeJS.ProcessEnv} env
 * @param {() => Promise<T>} fn
 */
async function withEnv(env, fn) {
  const previous = { ...process.env };
  Object.assign(process.env, env);
  try {
    return await fn();
  } finally {
    for (const key of Object.keys(env)) {
      if (previous[key] === undefined) delete process.env[key];
      else process.env[key] = previous[key];
    }
  }
}

/** @param {string} root @param {import("../../scripts/convert-plugin/contracts").CodexPluginPackage} codexPlugin */
async function createMarketplace(root, codexPlugin) {
  const marketplaceRoot = path.join(root, "marketplace");
  await writeJson(
    path.join(
      marketplaceRoot,
      "plugins",
      codexPlugin.name,
      ".codex-plugin",
      "plugin.json",
    ),
    codexPlugin.manifest,
  );
  await writeFile(
    path.join(
      marketplaceRoot,
      "plugins",
      codexPlugin.name,
      "skills",
      "demo",
      "SKILL.md",
    ),
    "demo\n",
  );
  return marketplaceRoot;
}

test("register adds the marketplace, installs the plugin, and verifies the cache path", async () => {
  await withTempDir(async (root) => {
    await fs.chmod(path.join(FAKE_CODEX_BIN, "codex"), 0o755);
    const codexHome = path.join(root, "codex-home");
    const codexPlugin = fixtureCodexPluginPackage({ name: "demo-plugin" });
    const marketplaceRoot = await createMarketplace(root, codexPlugin);
    const log = path.join(root, "codex.log");

    const result = await withEnv(
      {
        FAKE_CODEX_LOG: log,
        PATH: `${FAKE_CODEX_BIN}${path.delimiter}${process.env.PATH}`,
      },
      () => registerCodexPlugin({ codexHome, codexPlugin, marketplaceRoot }),
    );

    const installedPath = path.join(codexHome, codexPlugin.cacheRelativePath);
    assert.equal(result.installedPath, installedPath);
    assert.equal(result.version, "1.0.0");
    assert.equal(
      await pathExists(path.join(installedPath, "skills", "demo", "SKILL.md")),
      true,
    );
    assert.deepEqual((await readText(log)).trim().split("\n"), [
      `plugin marketplace add ${marketplaceRoot}`,
      "plugin add demo-plugin@demo-plugin --json",
    ]);
  });
});

test("register replaces a marketplace registered from a different source", async () => {
  await withTempDir(async (root) => {
    const codexHome = path.join(root, "codex-home");
    const codexPlugin = fixtureCodexPluginPackage({ name: "demo-plugin" });
    const marketplaceRoot = await createMarketplace(root, codexPlugin);
    await writeFile(
      path.join(codexHome, ".fake-marketplace-source"),
      path.join(root, "previous-marketplace"),
    );
    const log = path.join(root, "codex.log");

    await withEnv(
      {
        FAKE_CODEX_LOG: log,
        PATH: `${FAKE_CODEX_BIN}${path.delimiter}${process.env.PATH}`,
      },
      () => registerCodexPlugin({ codexHome, codexPlugin, marketplaceRoot }),
    );

    assert.deepEqual((await readText(log)).trim().split("\n"), [
      `plugin marketplace add ${marketplaceRoot}`,
      "plugin marketplace remove demo-plugin",
      `plugin marketplace add ${marketplaceRoot}`,
      "plugin add demo-plugin@demo-plugin --json",
    ]);
  });
});

test("register fails clearly when Codex is missing, refuses the install, or installs elsewhere", async () => {
  await withTempDir(async (root) => {
    const codexHome = path.join(root, "codex-home");
    const codexPlugin = fixtureCodexPluginPackage({ name: "demo-plugin" });
    const marketplaceRoot = await createMarketplace(root, codexPlugin);
    const emptyBin = path.join(root, "empty-bin");
    await fs.mkdir(emptyBin);

    await assert.rejects(
      withEnv({ PATH: emptyBin }, () =>
        registerCodexPlugin({ codexHome, codexPlugin, marketplaceRoot }),
      ),
      /codex CLI was not found on PATH/,
    );

    const fakePath = `${FAKE_CODEX_BIN}${path.delimiter}${process.env.PATH}`;
    await assert.rejects(
      withEnv({ FAKE_CODEX_FAIL_ADD: "1", PATH: fakePath }, () =>
        registerCodexPlugin({ codexHome, codexPlugin, marketplaceRoot }),
      ),
      /codex plugin add failed \(exit 1\): Error: plugin install refused by fixture/,
    );

    const elsewhere = path.join(root, "elsewhere");
    await assert.rejects(
      withEnv({ FAKE_CODEX_INSTALL_PATH: elsewhere, PATH: fakePath }, () =>
        registerCodexPlugin({ codexHome, codexPlugin, marketplaceRoot }),
      ),
      /installed demo-plugin to .*elsewhere, but the converted skills reference/,
    );
  });
});

test("unregister removes the plugin and marketplace and only warns on failures", async () => {
  await withTempDir(async (root) => {
    const codexHome = path.join(root, "codex-home");
    const codexPlugin = fixtureCodexPluginPackage({ name: "demo-plugin" });
    const cached = path.join(codexHome, codexPlugin.cacheRelativePath, "x");
    await writeFile(cached, "x\n");
    await writeFile(path.join(codexHome, ".fake-marketplace-source"), "/src");
    const fakePath = `${FAKE_CODEX_BIN}${path.delimiter}${process.env.PATH}`;
    const warnings = /** @type {string[]} */ ([]);

    await withEnv({ PATH: fakePath }, () =>
      unregisterCodexPlugin({
        codexHome,
        codexPlugin,
        warn: (message) => warnings.push(message),
      }),
    );
    assert.equal(warnings.length, 0);
    assert.equal(await pathExists(cached), false);
    assert.equal(
      await pathExists(path.join(codexHome, ".fake-marketplace-source")),
      false,
    );

    await withEnv(
      {
        FAKE_CODEX_FAIL_MARKETPLACE_REMOVE: "1",
        FAKE_CODEX_FAIL_REMOVE: "1",
        PATH: fakePath,
      },
      () =>
        unregisterCodexPlugin({
          codexHome,
          codexPlugin,
          warn: (message) => warnings.push(message),
        }),
    );
    assert.deepEqual(warnings, [
      "codex plugin remove failed (exit 1): Error: plugin removal refused by fixture",
      "codex plugin marketplace remove failed (exit 1): Error: marketplace removal refused by fixture",
    ]);
  });
});

test("default Codex home honours CODEX_HOME", async () => {
  await withTempDir(async (root) => {
    const custom = path.join(root, "custom home");
    assert.equal(
      await withEnv({ CODEX_HOME: custom }, async () => defaultCodexHome()),
      custom,
    );
    const previous = process.env.CODEX_HOME;
    delete process.env.CODEX_HOME;
    try {
      assert.match(defaultCodexHome(), /[\\/]\.codex$/);
    } finally {
      if (previous !== undefined) process.env.CODEX_HOME = previous;
    }
  });
});
