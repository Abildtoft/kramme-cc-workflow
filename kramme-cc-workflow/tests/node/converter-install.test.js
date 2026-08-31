"use strict";

const assert = require("node:assert/strict");
const { constants: fsConstants } = require("fs");
const fs = require("fs/promises");
const path = require("path");
const test = require("node:test");

const installTransaction = require("../../scripts/convert-plugin/install-transaction");
const {
  inspectInstallTransactions,
  prepareTransactionMutation,
  withInstallTransaction,
} = installTransaction;

const {
  cleanupInstalledEntries,
  cleanupKrammeComponents,
  installStagedDir,
  installStagedFile,
  preflightStagedDirInstall,
  pruneStaleManagedFiles,
  withInstallTransaction: withStagingInstallTransaction,
} = require("../../scripts/convert-plugin/install-staging");

const {
  loadInstallState,
} = require("../../scripts/convert-plugin/install-state");
const {
  collectConverterDiagnostics,
} = require("../../scripts/convert-plugin/diagnostics");

const {
  createFixturePlugin,
  withTempDir,
  writeJson,
  writeFile,
  readText,
  pathExists,
  assertFilesystemError,
} = require("./converter-test-helpers");

test("install transaction exposes the narrow staging boundary", () => {
  assert.deepEqual(Object.keys(installTransaction).sort(), [
    "inspectInstallTransactions",
    "prepareTransactionMutation",
    "publishStagedFile",
    "recordInstalledTargetForRollback",
    "withInstallTransaction",
  ]);
  assert.equal(withStagingInstallTransaction, withInstallTransaction);
});

test("transaction inspector reports an absent bounded snapshot without writes", async () => {
  await withTempDir(async (root) => {
    const before = await readFilesystemSnapshot(root);

    assert.deepEqual(await inspectInstallTransactions(root), {
      advisory: true,
      backups: emptyArtifactCollection(),
      entry_limit: 50,
      journals: emptyArtifactCollection(),
      lock: { status: "absent" },
      metadata_byte_limit: 65_536,
      recovery_claims: emptyArtifactCollection(),
      recovery_conflicts: emptyArtifactCollection(),
    });
    assert.deepEqual(await readFilesystemSnapshot(root), before);
  });
});

test("transaction inspector classifies active, stale, and present artifacts without sensitive fields", async () => {
  await withTempDir(async (root) => {
    const activeToken = "active-fixture-token";
    const managedRoot = path.join(root, "skills");
    const managedTarget = path.join(managedRoot, "managed-skill");
    const activeBackup = path.join(
      managedRoot,
      ".kramme-install-backups",
      activeToken,
      "0",
    );
    const activeJournal = path.join(
      root,
      ".kramme-install-transactions",
      activeToken,
      "journal.json",
    );
    await writeJson(activeJournal, {
      version: 1,
      token: activeToken,
      status: "active",
      records: [
        {
          backup: activeBackup,
          operation: "backup-rename",
          target: managedTarget,
        },
      ],
      secret: "must-not-be-reported",
    });
    await writeJson(path.join(root, ".kramme-install-lock", "owner.json"), {
      version: 1,
      token: activeToken,
      pid: process.pid,
      pluginName: "private-plugin-name",
      createdAtMs: Date.now(),
      lockRoots: [root],
      transactionRoot: root,
      journalPath: activeJournal,
    });

    const staleToken = "stale-fixture-token";
    await writeJson(
      path.join(
        root,
        ".kramme-install-recovery-claims",
        staleToken,
        "owner.json",
      ),
      {
        version: 1,
        token: "claim-fixture-token",
        pid: 2_147_483_647,
        pluginName: "recovery",
        createdAtMs: 1,
        expectedToken: staleToken,
        transactionRoot: root,
        journalPath: activeJournal,
      },
    );
    await writeFile(
      path.join(
        managedRoot,
        ".kramme-install-recovery-conflicts",
        activeToken,
        "edited-0",
      ),
      "private conflict bytes\n",
    );
    await writeFile(activeBackup, "private backup bytes\n");
    const before = await readFilesystemSnapshot(root);

    const summary = await inspectInstallTransactions(root);

    assert.deepEqual(summary.lock, { status: "active" });
    assert.deepEqual(summary.journals, {
      entry_count: 1,
      inspected_count: 1,
      status: "present",
      status_counts: { active: 1 },
      truncated: false,
    });
    assert.deepEqual(summary.recovery_claims, {
      entry_count: 1,
      inspected_count: 1,
      status: "stale",
      status_counts: { stale: 1 },
      truncated: false,
    });
    assert.equal(summary.recovery_conflicts.status, "present");
    assert.deepEqual(summary.recovery_conflicts.status_counts, { present: 1 });
    assert.equal(summary.backups.status, "present");
    assert.deepEqual(summary.backups.status_counts, { present: 1 });
    const serialized = JSON.stringify(summary);
    assert.doesNotMatch(serialized, /private|fixture-token|2147483647/);
    assert.ok(!serialized.includes(root));
    assert.ok(!serialized.includes(activeJournal));
    assert.ok(!serialized.includes("must-not-be-reported"));
    assert.deepEqual(await readFilesystemSnapshot(root), before);
  });
});

test("transaction inspector correlates multi-root locks and active journals", async () => {
  await withTempDir(async (root) => {
    const secondaryRoot = path.join(root, "agents");
    const activeToken = "correlated-token";
    const journalPath = path.join(
      root,
      ".kramme-install-transactions",
      activeToken,
      "journal.json",
    );
    await writeJson(journalPath, {
      version: 1,
      token: activeToken,
      status: "active",
      records: [],
    });
    const owner = {
      version: 1,
      token: activeToken,
      pid: process.pid,
      pluginName: "private-plugin-name",
      createdAtMs: Date.now(),
      lockRoots: [root, secondaryRoot],
      transactionRoot: root,
      journalPath,
    };
    const primaryOwnerPath = path.join(
      root,
      ".kramme-install-lock",
      "owner.json",
    );
    const secondaryOwnerPath = path.join(
      secondaryRoot,
      ".kramme-install-lock",
      "owner.json",
    );
    await writeJson(primaryOwnerPath, owner);
    await writeJson(secondaryOwnerPath, owner);

    let before = await readFilesystemSnapshot(root);
    let summary = await inspectInstallTransactions(root, {
      lockRoots: [secondaryRoot],
    });
    assert.deepEqual(summary.lock, { status: "active" });
    assert.deepEqual(await readFilesystemSnapshot(root), before);

    await writeJson(primaryOwnerPath, {
      ...owner,
      token: "mismatched-token",
      journalPath: path.join(
        root,
        ".kramme-install-transactions",
        "mismatched-token",
        "journal.json",
      ),
    });
    before = await readFilesystemSnapshot(root);
    summary = await inspectInstallTransactions(root, {
      lockRoots: [secondaryRoot],
    });
    assert.deepEqual(summary.lock, { status: "suspicious" });
    assert.deepEqual(await readFilesystemSnapshot(root), before);

    await writeJson(primaryOwnerPath, owner);
    const secondToken = "second-active-token";
    await writeJson(
      path.join(
        root,
        ".kramme-install-transactions",
        secondToken,
        "journal.json",
      ),
      { version: 1, token: secondToken, status: "active", records: [] },
    );
    before = await readFilesystemSnapshot(root);
    summary = await inspectInstallTransactions(root, {
      lockRoots: [secondaryRoot],
    });
    assert.equal(summary.journals.status, "suspicious");
    assert.deepEqual(summary.journals.status_counts, { active: 2 });
    assert.deepEqual(summary.lock, { status: "active" });
    assert.deepEqual(await readFilesystemSnapshot(root), before);

    await fs.rm(path.dirname(primaryOwnerPath), { recursive: true });
    before = await readFilesystemSnapshot(root);
    summary = await inspectInstallTransactions(root, {
      lockRoots: [secondaryRoot],
    });
    assert.deepEqual(summary.lock, { status: "suspicious" });
    assert.deepEqual(await readFilesystemSnapshot(root), before);

    await fs.rm(path.dirname(secondaryOwnerPath), { recursive: true });
    await fs.mkdir(path.dirname(primaryOwnerPath), { recursive: true });
    before = await readFilesystemSnapshot(root);
    summary = await inspectInstallTransactions(root);
    assert.deepEqual(summary.lock, { status: "suspicious" });
    assert.deepEqual(await readFilesystemSnapshot(root), before);
  });
});

test("transaction inspector bounds malformed, unsupported, unreadable, and disappearing artifacts", async () => {
  await withTempDir(async (root) => {
    const malformedToken = "malformed-token";
    const invalidShapeToken = "invalid-shape-token";
    const oversizedToken = "oversized-token";
    const raceToken = "race-token";
    await writeFile(
      path.join(root, ".kramme-install-lock", "owner.json"),
      "not-json\n",
    );
    await writeFile(
      path.join(
        root,
        ".kramme-install-transactions",
        malformedToken,
        "journal.json",
      ),
      "{not-json\n",
    );
    await writeJson(
      path.join(
        root,
        ".kramme-install-transactions",
        invalidShapeToken,
        "journal.json",
      ),
      { version: 1, token: invalidShapeToken, records: [{}] },
    );
    await writeFile(
      path.join(
        root,
        ".kramme-install-transactions",
        oversizedToken,
        "journal.json",
      ),
      JSON.stringify({ payload: "sensitive".repeat(10_000) }),
    );
    await writeJson(
      path.join(
        root,
        ".kramme-install-transactions",
        raceToken,
        "journal.json",
      ),
      { version: 1, token: raceToken, status: "active", records: [] },
    );
    await writeFile(
      path.join(
        root,
        ".kramme-install-recovery-claims",
        "broken-claim",
        "owner.json",
      ),
      "{}\n",
    );
    await writeFile(path.join(root, ".kramme-install-backups"), "not a dir\n");
    for (let index = 0; index <= 50; index += 1) {
      await fs.mkdir(
        path.join(
          root,
          ".kramme-install-recovery-conflicts",
          `conflict-${String(index).padStart(2, "0")}`,
        ),
        { recursive: true },
      );
    }
    const before = await readFilesystemSnapshot(root);
    const ownerPath = path.join(root, ".kramme-install-lock", "owner.json");
    const racedTransaction = path.join(
      root,
      ".kramme-install-transactions",
      raceToken,
    );
    const originalOpen = fs.open;
    const originalLstat = fs.lstat;
    let metadataOpenWasNonBlocking = fsConstants.O_NONBLOCK === undefined;
    fs.open = async (target, flags, mode) => {
      if (
        typeof flags === "number" &&
        fsConstants.O_NONBLOCK !== undefined &&
        (flags & fsConstants.O_NONBLOCK) === fsConstants.O_NONBLOCK
      ) {
        metadataOpenWasNonBlocking = true;
      }
      if (String(target) === ownerPath) {
        throw Object.assign(new Error("simulated unreadable metadata"), {
          code: "EACCES",
        });
      }
      return originalOpen(target, flags, mode);
    };
    fs.lstat = /** @type {typeof fs.lstat} */ (
      async (target) => {
        if (String(target) === racedTransaction) {
          throw Object.assign(new Error("simulated concurrent removal"), {
            code: "ENOENT",
          });
        }
        return originalLstat(target);
      }
    );
    let summary;
    try {
      summary = await inspectInstallTransactions(root);
    } finally {
      fs.open = originalOpen;
      fs.lstat = originalLstat;
    }

    assert.deepEqual(summary.lock, { status: "unreadable" });
    assert.equal(summary.journals.status, "malformed");
    assert.deepEqual(summary.journals.status_counts, {
      disappeared: 1,
      malformed: 2,
      unsupported: 1,
    });
    assert.equal(summary.recovery_claims.status, "malformed");
    assert.equal(summary.backups.status, "unsupported");
    assert.deepEqual(summary.recovery_conflicts, {
      entry_count: 51,
      inspected_count: 50,
      status: "suspicious",
      status_counts: { present: 50 },
      truncated: true,
    });
    assert.doesNotMatch(JSON.stringify(summary), /sensitive/);
    assert.equal(metadataOpenWasNonBlocking, true);
    assert.deepEqual(await readFilesystemSnapshot(root), before);
  });
});

test("converter doctor reports resolved plugin and healthy install state without writes", async () => {
  await withTempDir(async (root) => {
    const pluginRoot = path.join(root, "doctor-plugin");
    const codexHome = path.join(root, "output");
    const codexRoot = path.join(codexHome, ".codex");
    const agentsRoot = path.join(root, "agents");
    const externalRoot = path.join(root, "external-agents");
    const externalAgentsFile = path.join(externalRoot, "AGENTS.md");
    const statePath = path.join(codexRoot, ".kramme-install-state.json");
    await createFixturePlugin(pluginRoot, "doctor-plugin");
    await writeJson(statePath, { plugins: {}, version: 1 });
    await writeFile(externalAgentsFile, "# External agents\n");
    await fs.symlink(externalAgentsFile, path.join(codexRoot, "AGENTS.md"));
    const before = await readFilesystemSnapshot(root);

    let inspectedLockRoots;
    const diagnostic = await collectConverterDiagnostics(
      {
        agentsRoot,
        codexHome,
        pluginInput: pluginRoot,
      },
      {
        inspectInstallTransactions: async (transactionRoot, options) => {
          inspectedLockRoots = options?.lockRoots;
          return inspectInstallTransactions(transactionRoot, options);
        },
      },
    );

    assert.deepEqual(diagnostic, {
      agents_root: agentsRoot,
      codex_root: codexRoot,
      install_state_from_disk: true,
      install_state_path: statePath,
      install_state_recovery_reason: null,
      install_state_status: "loaded",
      plugin_name: "doctor-plugin",
      plugin_source: pluginRoot,
      plugin_version: "1.0.0",
      schema_version: 1,
      transaction_health: {
        advisory: true,
        backups: emptyArtifactCollection(),
        entry_limit: 50,
        journals: emptyArtifactCollection(),
        lock: { status: "absent" },
        metadata_byte_limit: 65_536,
        recovery_claims: emptyArtifactCollection(),
        recovery_conflicts: emptyArtifactCollection(),
      },
    });
    assert.deepEqual(
      [...(inspectedLockRoots ?? [])].sort(),
      [agentsRoot, externalRoot].sort(),
    );
    assert.deepEqual(await readFilesystemSnapshot(root), before);
  });
});

test("converter doctor reports every install-state rebuild reason without writes", async () => {
  const fixtures = [
    { content: null, reason: "missing" },
    { content: "{not json\n", reason: "malformed-json" },
    { content: "[]\n", reason: "invalid-shape" },
  ];

  for (const fixture of fixtures) {
    await withTempDir(async (root) => {
      const pluginRoot = path.join(root, "doctor-plugin");
      const codexHome = path.join(root, "output");
      const codexRoot = path.join(codexHome, ".codex");
      const agentsRoot = path.join(root, "agents");
      const statePath = path.join(codexRoot, ".kramme-install-state.json");
      await createFixturePlugin(pluginRoot, "doctor-plugin");
      if (fixture.content !== null) {
        await writeFile(statePath, fixture.content);
      }
      const before = await readFilesystemSnapshot(root);

      const diagnostic = await collectConverterDiagnostics({
        agentsRoot,
        codexHome,
        pluginInput: pluginRoot,
      });

      assert.equal(diagnostic.install_state_from_disk, false);
      assert.equal(diagnostic.install_state_status, "reconstructed");
      assert.equal(diagnostic.install_state_recovery_reason, fixture.reason);
      assert.equal(diagnostic.install_state_path, statePath);
      assert.deepEqual(await readFilesystemSnapshot(root), before);
    });
  }
});

test("install state rebuild sanitizes legacy manifests and managed file paths", async () => {
  await withTempDir(async (root) => {
    await writeJson(
      path.join(
        root,
        ".kramme-install-manifests",
        `${encodeURIComponent("Demo Plugin")}-codex.json`,
      ),
      {
        agentSkillFiles: {
          reviewer: ["notes.md", "SKILL.md", "notes.md"],
        },
        agentSkills: [" reviewer "],
        hookMarketplaces: [" .kramme-plugin-marketplaces/demo "],
        pluginCaches: "not an array",
        prompts: [" prompt.md ", "", null],
        skillFiles: {
          " ": ["ignored.md"],
          alpha: [
            "SKILL.md",
            "docs\\guide.md",
            "docs/guide.md",
            "../escape.md",
            "/absolute.md",
            "nested//bad.md",
            "nested/../bad.md",
            null,
          ],
          beta: "not an array",
        },
        skills: [" alpha ", "beta"],
        updatedAtMs: "42",
      },
    );

    const { fromDisk, recoveryReason, state } = await loadInstallState(root);

    assert.equal(fromDisk, false);
    assert.equal(recoveryReason, "missing");
    assert.deepEqual(state.plugins["Demo Plugin"].codex, {
      agentSkillFiles: {
        reviewer: ["SKILL.md", "notes.md"],
      },
      agentSkills: ["reviewer"],
      hookMarketplaces: [".kramme-plugin-marketplaces/demo"],
      pluginCaches: [],
      prompts: ["prompt.md"],
      skillFiles: {
        alpha: ["SKILL.md", "docs/guide.md"],
        beta: [],
      },
      skills: ["alpha", "beta"],
      updatedAtMs: 42,
    });
  });
});

test("install state records corrupt-data recovery provenance", async () => {
  await withTempDir(async (root) => {
    const statePath = path.join(root, ".kramme-install-state.json");
    await writeFile(statePath, "{not json\n");

    let loaded = await loadInstallState(root);
    assert.equal(loaded.fromDisk, false);
    assert.equal(loaded.recoveryReason, "malformed-json");
    assert.deepEqual(loaded.state.plugins, {});

    await writeJson(statePath, []);
    loaded = await loadInstallState(root);
    assert.equal(loaded.fromDisk, false);
    assert.equal(loaded.recoveryReason, "invalid-shape");
    assert.deepEqual(loaded.state.plugins, {});

    await writeJson(statePath, { plugins: {}, version: "1" });
    loaded = await loadInstallState(root);
    assert.equal(loaded.fromDisk, false);
    assert.equal(loaded.recoveryReason, "invalid-shape");

    await writeJson(statePath, {
      plugins: { demo: { codex: [] } },
      version: 1,
    });
    loaded = await loadInstallState(root);
    assert.equal(loaded.fromDisk, false);
    assert.equal(loaded.recoveryReason, "invalid-shape");
  });
});

test("install state normalizes valid persisted entries before returning them", async () => {
  await withTempDir(async (root) => {
    const statePath = path.join(root, ".kramme-install-state.json");
    await writeJson(statePath, {
      plugins: {
        demo: {
          codex: {
            agentSkillFiles: null,
            agentSkills: [" reviewer ", 42],
            hookMarketplaces: [],
            pluginCaches: [],
            prompts: [" prompt.md "],
            skillFiles: {},
            skills: [" skill "],
            updatedAtMs: "42",
          },
        },
      },
      version: 1,
    });

    const loaded = await loadInstallState(root);

    assert.equal(loaded.fromDisk, true);
    assert.equal(loaded.recoveryReason, null);
    assert.deepEqual(loaded.state.plugins.demo.codex, {
      agentSkillFiles: {},
      agentSkills: ["reviewer", "42"],
      hookMarketplaces: [],
      pluginCaches: [],
      prompts: ["prompt.md"],
      skillFiles: {},
      skills: ["skill"],
      updatedAtMs: 42,
    });
  });
});

test("install state preserves special plugin and target keys", async () => {
  await withTempDir(async (root) => {
    const statePath = path.join(root, ".kramme-install-state.json");
    await writeJson(
      statePath,
      JSON.parse('{"version":1,"plugins":{"__proto__":{"__proto__":{}}}}'),
    );

    const loaded = await loadInstallState(root);

    assert.equal(loaded.fromDisk, true);
    assert.equal(Object.hasOwn(loaded.state.plugins, "__proto__"), true);
    const targets = loaded.state.plugins.__proto__;
    assert.equal(Object.hasOwn(targets, "__proto__"), true);
    assert.deepEqual(targets.__proto__, {
      agentSkillFiles: {},
      agentSkills: [],
      hookMarketplaces: [],
      pluginCaches: [],
      prompts: [],
      skillFiles: {},
      skills: [],
      updatedAtMs: undefined,
    });
  });
});

test("install state rebuild skips malformed and invalid-shape manifests", async () => {
  await withTempDir(async (root) => {
    const manifestsDir = path.join(root, ".kramme-install-manifests");
    await writeFile(path.join(manifestsDir, "malformed-codex.json"), "{bad\n");
    await writeJson(path.join(manifestsDir, "invalid-codex.json"), []);

    const loaded = await loadInstallState(root);

    assert.equal(loaded.fromDisk, false);
    assert.equal(loaded.recoveryReason, "missing");
    assert.deepEqual(loaded.state.plugins, {});
  });
});

test("install state rethrows operational read failures without mutation", async () => {
  await withTempDir(async (root) => {
    const statePath = path.join(root, ".kramme-install-state.json");
    await writeJson(statePath, { plugins: {}, version: 1 });

    const originalReadFile = fs.readFile;
    const readError = Object.assign(new Error("input/output error"), {
      code: "EIO",
    });
    fs.readFile = /** @type {typeof fs.readFile} */ (
      async (file, ...args) => {
        if (file === statePath) throw readError;
        return originalReadFile(file, ...args);
      }
    );
    try {
      await assert.rejects(
        () => loadInstallState(root),
        (error) => {
          assertFilesystemError(error, {
            cause: readError,
            code: "EIO",
            message: /Failed to read install state/,
            path: statePath,
          });
          return true;
        },
      );
    } finally {
      fs.readFile = originalReadFile;
    }

    assert.deepEqual(await fs.readdir(root), [".kramme-install-state.json"]);
  });
});

test("install manifest rethrows operational read failures", async () => {
  await withTempDir(async (root) => {
    const manifestPath = path.join(
      root,
      ".kramme-install-manifests",
      "demo-codex.json",
    );
    await writeJson(manifestPath, { skills: ["demo"] });

    const originalReadFile = fs.readFile;
    const readError = Object.assign(new Error("input/output error"), {
      code: "EIO",
    });
    fs.readFile = /** @type {typeof fs.readFile} */ (
      async (file, ...args) => {
        if (file === manifestPath) throw readError;
        return originalReadFile(file, ...args);
      }
    );
    try {
      await assert.rejects(
        () => loadInstallState(root),
        (error) => {
          assertFilesystemError(error, {
            cause: readError,
            code: "EIO",
            message: /Failed to read install manifest/,
            path: manifestPath,
          });
          return true;
        },
      );
    } finally {
      fs.readFile = originalReadFile;
    }
  });
});

test("install staging treats stale managed files as removable without overwriting local files", async () => {
  await withTempDir(async (root) => {
    const stagedDir = path.join(root, "staged");
    const targetDir = path.join(root, "target");
    const previousManagedFiles = ["notes/old.md"];
    const currentManagedFiles = ["notes"];

    await writeFile(path.join(stagedDir, "notes"), "new notes");
    await writeFile(path.join(targetDir, "notes", "local.md"), "local notes");

    await assert.rejects(
      () =>
        preflightStagedDirInstall(stagedDir, targetDir, {
          currentManagedFiles,
          label: "skill demo",
          previousManagedFiles,
        }),
      /conflicts with staged file notes/,
    );

    await fs.rm(targetDir, { force: true, recursive: true });
    await writeFile(path.join(targetDir, "notes", "old.md"), "old notes");

    await preflightStagedDirInstall(stagedDir, targetDir, {
      currentManagedFiles,
      label: "skill demo",
      previousManagedFiles,
    });
    await pruneStaleManagedFiles(
      targetDir,
      previousManagedFiles,
      currentManagedFiles,
      { label: "skill demo" },
    );
    await installStagedDir(stagedDir, targetDir);

    assert.equal(await readText(path.join(targetDir, "notes")), "new notes");
  });
});

test("install staging does not prune stale files through symlinked ancestors", async () => {
  await withTempDir(async (root) => {
    const skillDir = path.join(root, "skill");
    const outsideDir = path.join(root, "outside");
    await fs.mkdir(skillDir, { recursive: true });
    await fs.mkdir(outsideDir, { recursive: true });

    const outsideFile = path.join(outsideDir, "OLD.md");
    await writeFile(outsideFile, "outside\n");
    await fs.symlink(outsideDir, path.join(skillDir, "references"), "dir");

    await pruneStaleManagedFiles(skillDir, ["references/OLD.md"], ["SKILL.md"]);

    assert.equal(await readText(outsideFile), "outside\n");
    assert.equal(
      (await fs.lstat(path.join(skillDir, "references"))).isSymbolicLink(),
      true,
    );
  });
});

test("cleanup helpers remove files and directories without recursive options", async () => {
  await withTempDir(async (root) => {
    const managedRoot = path.join(root, "managed");
    const managedDir = path.join(managedRoot, "nested");
    const managedFile = path.join(managedRoot, "prompt.md");
    const legacyRoot = path.join(root, "legacy");
    const legacyDir = path.join(legacyRoot, "kramme:old-skill");

    await writeFile(path.join(managedDir, "child.md"), "managed\n");
    await writeFile(managedFile, "prompt\n");
    await writeFile(path.join(legacyDir, "SKILL.md"), "legacy\n");

    assert.equal(
      await cleanupInstalledEntries(managedRoot, ["nested", "prompt.md"], {
        label: "managed entry",
        confirmOptions: { yes: true },
      }),
      true,
    );
    await cleanupKrammeComponents(legacyRoot, {
      label: "skill",
      filter: (entry) => entry.isDirectory(),
      confirmOptions: { yes: true },
    });

    assert.equal(await pathExists(managedDir), false);
    assert.equal(await pathExists(managedFile), false);
    assert.equal(await pathExists(legacyDir), false);
  });
});

test("transaction revalidates absent targets after journaling create records", async () => {
  for (const scenario of ["file", "parent-symlink"]) {
    await withTempDir(async (root) => {
      const transactionRoot = path.join(root, "transaction-root");
      const stagedFile = path.join(transactionRoot, "staged.md");
      const targetParent = path.join(transactionRoot, "managed");
      const targetFile = path.join(targetParent, "target.md");
      const userContent = `# Concurrent ${scenario}\n`;
      await writeFile(stagedFile, "# Installed\n");
      if (scenario === "file") {
        await fs.mkdir(targetParent, { recursive: true });
      } else {
        const externalRoot = path.join(root, "external");
        await writeFile(path.join(externalRoot, "target.md"), userContent);
      }

      const originalRename = fs.rename;
      let armed = false;
      let injected = false;
      fs.rename = async (source, target) => {
        const result = await originalRename(source, target);
        if (
          armed &&
          !injected &&
          String(target).endsWith(`${path.sep}journal.json`)
        ) {
          injected = true;
          if (scenario === "file") {
            await writeFile(targetFile, userContent);
          } else {
            await fs.symlink(path.join(root, "external"), targetParent);
          }
        }
        return result;
      };
      try {
        await assert.rejects(
          () =>
            withInstallTransaction(
              transactionRoot,
              { pluginName: `late-${scenario}-plugin` },
              async () => {
                armed = true;
                await installStagedFile(stagedFile, targetFile, {
                  expectedTargetContent: null,
                  label: `late ${scenario}`,
                });
              },
            ),
          /created during installation|changed during installation/,
        );
      } finally {
        fs.rename = originalRename;
      }

      assert.equal(injected, true);
      assert.equal(await readText(targetFile), userContent);
      assert.equal(
        await pathExists(path.join(transactionRoot, ".kramme-install-lock")),
        false,
      );
    });
  }
});

test("transaction refuses targets created at no-clobber publication", async () => {
  await withTempDir(async (root) => {
    const stagedFile = path.join(root, "staged.md");
    const targetFile = path.join(root, "target.md");
    const userContent = "# Created at publication\n";
    await writeFile(stagedFile, "# Installed\n");

    const originalLink = fs.link;
    let injected = false;
    fs.link = async (source, target) => {
      if (!injected && source === stagedFile && target === targetFile) {
        injected = true;
        await writeFile(targetFile, userContent);
      }
      return originalLink(source, target);
    };
    try {
      await assert.rejects(
        () =>
          withInstallTransaction(
            root,
            { pluginName: "publication-create-race-plugin" },
            () =>
              installStagedFile(stagedFile, targetFile, {
                expectedTargetContent: null,
                label: "publication create race",
              }),
          ),
        /changed during installation/,
      );
    } finally {
      fs.link = originalLink;
    }

    assert.equal(injected, true);
    assert.equal(await readText(targetFile), userContent);
    assert.equal(
      await pathExists(path.join(root, ".kramme-install-lock")),
      false,
    );
  });
});

test("transaction revalidates existing targets after the backup rename", async () => {
  await withTempDir(async (root) => {
    const stagedFile = path.join(root, "staged.md");
    const targetFile = path.join(root, "target.md");
    const userContent = "# Edited at backup rename\n";
    await writeFile(stagedFile, "# Installed\n");
    await writeFile(targetFile, "# Original\n");

    const originalRename = fs.rename;
    let injected = false;
    fs.rename = async (source, target) => {
      if (
        !injected &&
        source === targetFile &&
        String(target).includes(".kramme-install-backups")
      ) {
        injected = true;
        await writeFile(targetFile, userContent);
      }
      return originalRename(source, target);
    };
    try {
      await assert.rejects(
        () =>
          withInstallTransaction(
            root,
            { pluginName: "backup-rename-race-plugin" },
            () =>
              installStagedFile(stagedFile, targetFile, {
                expectedTargetContent: "# Original\n",
                label: "backup rename race",
              }),
          ),
        /changed during installation/,
      );
    } finally {
      fs.rename = originalRename;
    }

    assert.equal(injected, true);
    assert.equal(await readText(targetFile), userContent);
    assert.equal(
      await pathExists(path.join(root, ".kramme-install-lock")),
      false,
    );
  });
});

test("transaction preserves rollback conflicts beside external targets", async () => {
  await withTempDir(async (root) => {
    const transactionRoot = path.join(root, "transaction-root");
    const externalRoot = path.join(root, "external-root");
    const stagedFile = path.join(transactionRoot, "staged-agents.md");
    const targetFile = path.join(externalRoot, "AGENTS.md");
    const injectedError = new Error("failure after external target edit");
    await writeFile(stagedFile, "# Installed\n");
    await writeFile(targetFile, "# Original\n");

    const originalRename = fs.rename;
    fs.rename = async (source, target) => {
      if (
        String(source).startsWith(externalRoot + path.sep) &&
        !String(target).startsWith(externalRoot + path.sep)
      ) {
        throw Object.assign(new Error("simulated cross-device rename"), {
          code: "EXDEV",
        });
      }
      return originalRename(source, target);
    };
    try {
      await assert.rejects(
        () =>
          withInstallTransaction(
            transactionRoot,
            {
              lockRoots: [externalRoot],
              pluginName: "external-conflict-plugin",
            },
            async () => {
              await installStagedFile(stagedFile, targetFile, {
                expectedTargetContent: "# Original\n",
                preserveTargetChangesOnRollback: true,
              });
              await fs.writeFile(targetFile, "# User edit\n", "utf8");
              throw injectedError;
            },
          ),
        (error) => error === injectedError,
      );
    } finally {
      fs.rename = originalRename;
    }

    assert.equal(await readText(targetFile), "# Original\n");
    const conflictsRoot = path.join(
      externalRoot,
      ".kramme-install-recovery-conflicts",
    );
    const conflictTokens = await fs.readdir(conflictsRoot);
    assert.equal(conflictTokens.length, 1);
    assert.equal(
      await readText(path.join(conflictsRoot, conflictTokens[0], "edited-0")),
      "# User edit\n",
    );
    assert.equal(
      await pathExists(path.join(transactionRoot, ".kramme-install-lock")),
      false,
    );
    assert.equal(
      await pathExists(path.join(externalRoot, ".kramme-install-lock")),
      false,
    );
  });
});

test("transaction enforces file CAS beneath an existing parent mutation", async () => {
  await withTempDir(async (root) => {
    const targetDir = path.join(root, "managed");
    const targetFile = path.join(targetDir, "AGENTS.md");
    const stagedDir = path.join(root, "staged-directory");
    const stagedFile = path.join(root, "staged-agents.md");
    await writeFile(targetFile, "# Original\n");
    await writeFile(path.join(stagedDir, "shared.js"), "shared\n");
    await writeFile(stagedFile, "# Original\n\nTOOL MAP\n");

    await assert.rejects(
      () =>
        withInstallTransaction(
          root,
          { pluginName: "nested-cas-plugin" },
          async () => {
            await installStagedDir(stagedDir, targetDir, { replace: false });
            await writeFile(targetFile, "# Late user edit\n");
            await installStagedFile(stagedFile, targetFile, {
              expectedTargetContent: "# Original\n",
              label: "Codex AGENTS.md tool map",
              preserveTargetChangesOnRollback: true,
            });
          },
        ),
      /changed during installation/,
    );

    assert.equal(await readText(targetFile), "# Original\n");
    const conflictsRoot = path.join(root, ".kramme-install-recovery-conflicts");
    const conflictTokens = await fs.readdir(conflictsRoot);
    assert.equal(conflictTokens.length, 1);
    assert.equal(
      await readText(path.join(conflictsRoot, conflictTokens[0], "edited-0")),
      "# Late user edit\n",
    );
  });
});

test("transaction preserves nested file edits outside an ancestor rollback target", async () => {
  await withTempDir(async (root) => {
    const targetDir = path.join(root, "managed");
    const targetFile = path.join(targetDir, "AGENTS.md");
    const stagedDir = path.join(root, "staged-directory");
    const stagedFile = path.join(root, "staged-agents.md");
    const injectedError = new Error("fail after nested user edit");
    await writeFile(targetFile, "# Original\n");
    await writeFile(path.join(stagedDir, "shared.js"), "shared\n");
    await writeFile(stagedFile, "# Original\n\nTOOL MAP\n");

    await assert.rejects(
      () =>
        withInstallTransaction(
          root,
          { pluginName: "nested-rollback-conflict-plugin" },
          async () => {
            await installStagedDir(stagedDir, targetDir, { replace: false });
            await installStagedFile(stagedFile, targetFile, {
              expectedTargetContent: "# Original\n",
              label: "Codex AGENTS.md tool map",
              preserveTargetChangesOnRollback: true,
            });
            await writeFile(targetFile, "# User edit after publication\n");
            throw injectedError;
          },
        ),
      (error) => error === injectedError,
    );

    assert.equal(await readText(targetFile), "# Original\n");
    const conflictsRoot = path.join(root, ".kramme-install-recovery-conflicts");
    const conflictTokens = await fs.readdir(conflictsRoot);
    assert.equal(conflictTokens.length, 1);
    assert.equal(
      await readText(path.join(conflictsRoot, conflictTokens[0], "edited-0")),
      "# User edit after publication\n",
    );
  });
});

test("writer rejects stale journals targeting paths outside owned roots", async () => {
  await withTempDir(async (root) => {
    const installRoot = path.join(root, "install-root");
    const victimPath = path.join(root, "outside-victim.txt");
    const token = "unowned-target-transaction";
    const journalPath = path.join(
      installRoot,
      ".kramme-install-transactions",
      token,
      "journal.json",
    );
    const owner = {
      version: 1,
      token,
      pid: 2_147_483_647,
      pluginName: "unowned-target-plugin",
      createdAtMs: 1,
      lockRoots: [installRoot],
      transactionRoot: installRoot,
      journalPath,
    };

    await writeFile(victimPath, "must survive\n");
    await writeJson(journalPath, {
      version: 1,
      token,
      status: "active",
      records: [
        {
          operation: "create",
          target: victimPath,
          backup: null,
        },
      ],
    });
    await writeJson(
      path.join(installRoot, ".kramme-install-lock", "owner.json"),
      owner,
    );

    await assert.rejects(
      () =>
        withInstallTransaction(
          installRoot,
          { pluginName: "next-plugin" },
          async () => {},
        ),
      /Refusing to recover invalid install journal/,
    );
    assert.equal(await readText(victimPath), "must survive\n");
  });
});

test("transaction recovers an interrupted partial multi-root lock acquisition", async () => {
  await withTempDir(async (root) => {
    const firstRoot = path.join(root, "a-shared-root");
    const transactionRoot = path.join(root, "z-transaction-root");
    const token = "partial-lock-acquisition";
    const journalPath = path.join(
      transactionRoot,
      ".kramme-install-transactions",
      token,
      "journal.json",
    );
    const owner = {
      version: 1,
      token,
      pid: 2_147_483_647,
      pluginName: "partial-lock-plugin",
      createdAtMs: 1,
      lockRoots: [firstRoot, transactionRoot],
      transactionRoot,
      journalPath,
    };

    await writeJson(
      path.join(firstRoot, ".kramme-install-lock", "owner.json"),
      owner,
    );

    let callbackRan = false;
    await withInstallTransaction(
      transactionRoot,
      {
        lockRoots: [firstRoot],
        pluginName: "next-plugin",
      },
      async () => {
        callbackRan = true;
      },
    );

    assert.equal(callbackRan, true);
    assert.equal(
      await pathExists(path.join(firstRoot, ".kramme-install-lock")),
      false,
    );
    assert.equal(
      await pathExists(path.join(transactionRoot, ".kramme-install-lock")),
      false,
    );
  });
});

test("transaction preserves the primary error when rollback cleanup fails", async () => {
  await withTempDir(async (root) => {
    const targetPath = path.join(root, "target.txt");
    const stagedPath = path.join(root, "staged.txt");
    const primaryError = new Error("primary install failure");
    const cleanupError = Object.assign(new Error("rollback cleanup failure"), {
      code: "EIO",
    });
    const originalRm = fs.rm;

    await writeFile(targetPath, "stable\n");
    await writeFile(stagedPath, "replacement\n");
    fs.rm = async (target, rmOptions) => {
      if (String(target).includes(".kramme-install-backups")) {
        throw cleanupError;
      }
      return originalRm(target, rmOptions);
    };
    try {
      await assert.rejects(
        () =>
          withInstallTransaction(
            root,
            { pluginName: "rollback-cleanup-plugin" },
            async () => {
              await installStagedFile(stagedPath, targetPath, {
                replace: true,
              });
              throw primaryError;
            },
          ),
        (error) => {
          assert.ok(error instanceof Error);
          assert.equal(error.cause, primaryError);
          assert.match(error.message, /primary install failure/);
          assert.match(error.message, /rollback cleanup failure/);
          return true;
        },
      );
    } finally {
      fs.rm = originalRm;
    }

    assert.equal(await readText(targetPath), "stable\n");
    assert.equal(
      await pathExists(path.join(root, ".kramme-install-lock")),
      true,
    );
  });
});

test("transaction attempts every lock release and preserves the primary error", async () => {
  await withTempDir(async (root) => {
    const sharedRoot = path.join(root, "shared-root");
    const sharedLock = path.join(sharedRoot, ".kramme-install-lock");
    const primaryError = new Error("primary transaction failure");
    const releaseError = Object.assign(new Error("lock release failure"), {
      code: "EIO",
    });
    const originalRename = fs.rename;

    fs.rename = async (source, target) => {
      if (
        source === sharedLock &&
        String(target).includes(".kramme-install-lock.release-")
      ) {
        throw releaseError;
      }
      return originalRename(source, target);
    };
    try {
      await assert.rejects(
        () =>
          withInstallTransaction(
            root,
            {
              lockRoots: [sharedRoot],
              pluginName: "release-cleanup-plugin",
            },
            async () => {
              throw primaryError;
            },
          ),
        (error) => {
          assert.ok(error instanceof Error);
          assert.equal(error.cause, primaryError);
          assert.match(error.message, /primary transaction failure/);
          assert.match(error.message, /lock release failure/);
          return true;
        },
      );
    } finally {
      fs.rename = originalRename;
    }

    assert.equal(
      await pathExists(path.join(root, ".kramme-install-lock")),
      false,
    );
    assert.equal(await pathExists(sharedLock), true);
  });
});

const PREPARED_MUTATION_KEYS = [
  "expectedTargetContent",
  "expectedTargetEntries",
  "expectedTargetIdentity",
  "record",
  "recordIndex",
  "target",
  "targetExists",
];

function emptyArtifactCollection() {
  return {
    entry_count: 0,
    inspected_count: 0,
    status: "absent",
    status_counts: {},
    truncated: false,
  };
}

test("prepared transaction mutations share one shape across target states", async () => {
  await withTempDir(async (root) => {
    const createdTarget = path.join(root, "created.md");
    const replacedTarget = path.join(root, "replaced.md");
    const managedDir = path.join(root, "managed");
    const coveredTarget = path.join(managedDir, "covered.md");
    await writeFile(replacedTarget, "# Replaced\n");
    await writeFile(coveredTarget, "# Covered\n");

    assert.equal(await prepareTransactionMutation(createdTarget), false);

    await withInstallTransaction(
      root,
      { pluginName: "prepared-shape-plugin" },
      async () => {
        const created = await prepareTransactionMutation(createdTarget, {
          label: "created target",
        });
        assert.ok(created !== false);
        assert.deepEqual(Object.keys(created).sort(), PREPARED_MUTATION_KEYS);
        assert.deepEqual(created.record, {
          operation: "create",
          target: createdTarget,
          backup: null,
        });
        assert.equal(created.recordIndex, 0);
        assert.equal(created.target, createdTarget);
        assert.equal(created.targetExists, false);
        assert.equal(created.expectedTargetContent, undefined);

        const replaced = await prepareTransactionMutation(replacedTarget, {
          expectedTargetContent: "# Replaced\n",
          label: "replaced target",
        });
        assert.ok(replaced !== false);
        assert.deepEqual(Object.keys(replaced).sort(), PREPARED_MUTATION_KEYS);
        assert.equal(replaced.record.operation, "backup-rename");
        assert.equal(replaced.record.target, replacedTarget);
        assert.equal(typeof replaced.record.backup, "string");
        assert.equal(replaced.recordIndex, 1);
        assert.equal(replaced.target, replacedTarget);
        // The backup rename already moved the original aside.
        assert.equal(replaced.targetExists, false);
        assert.equal(replaced.expectedTargetContent, "# Replaced\n");

        const ancestor = await prepareTransactionMutation(managedDir, {
          label: "managed ancestor",
          preserveExisting: true,
        });
        assert.ok(ancestor !== false);
        assert.equal(ancestor.recordIndex, 2);

        const covered = await prepareTransactionMutation(coveredTarget, {
          label: "covered child",
        });
        assert.ok(covered !== false);
        assert.deepEqual(Object.keys(covered).sort(), PREPARED_MUTATION_KEYS);
        // A covering ancestor record is reused instead of journaling a child.
        assert.equal(covered.record, ancestor.record);
        assert.equal(covered.recordIndex, 2);
        assert.equal(covered.target, coveredTarget);
        assert.equal(covered.targetExists, true);
      },
    );
  });
});

test("prepared transaction mutations keep their filesystem call order", async () => {
  await withTempDir(async (root) => {
    const createdTarget = path.join(root, "created.md");
    const replacedTarget = path.join(root, "replaced.md");
    await writeFile(replacedTarget, "# Replaced\n");

    /** @type {string[]} */
    const calls = [];
    /** @param {unknown} target */
    const describe = (target) => {
      const value = String(target);
      if (value.endsWith(`${path.sep}journal.json`)) return "journal";
      if (value.includes(".kramme-install-backups")) return "backup";
      if (value === createdTarget) return "created.md";
      if (value === replacedTarget) return "replaced.md";
      return null;
    };
    const originalLstat = fs.lstat;
    const originalRename = fs.rename;
    const originalCp = fs.cp;
    fs.lstat = /** @type {typeof fs.lstat} */ (
      /** @param {import("fs").PathLike} target */
      async (target) => {
        const label = describe(target);
        if (label) calls.push(`lstat:${label}`);
        return originalLstat(target);
      }
    );
    fs.rename = async (source, target) => {
      const to = describe(target);
      if (to === "journal") {
        calls.push("journal");
      } else if (to) {
        calls.push(`rename:${describe(source)}->${to}`);
      }
      return originalRename(source, target);
    };
    fs.cp = async (source, target, options) => {
      calls.push(`cp:${describe(source)}->${describe(target)}`);
      return originalCp(source, target, options);
    };
    try {
      await withInstallTransaction(
        root,
        { pluginName: "prepared-order-plugin" },
        async () => {
          await prepareTransactionMutation(createdTarget, {
            label: "created target",
          });
          calls.push("--");
          await prepareTransactionMutation(replacedTarget, {
            expectedTargetContent: "# Replaced\n",
            label: "replaced target",
            preserveExisting: true,
          });
        },
      );
    } finally {
      fs.lstat = originalLstat;
      fs.rename = originalRename;
      fs.cp = originalCp;
    }

    assert.deepEqual(calls, [
      // Transaction start journals its empty record list.
      "journal",
      // Create path: journal the record, then revalidate the absent target.
      "lstat:created.md",
      "journal",
      "lstat:created.md",
      "--",
      // Backup-rename path: journal, revalidate, rename aside, verify the
      // backup, journal again, then restore the preserved copy.
      "lstat:replaced.md",
      "journal",
      "lstat:replaced.md",
      "rename:replaced.md->backup",
      "lstat:backup",
      "journal",
      "cp:backup->replaced.md",
      // Commit journals the final status.
      "journal",
    ]);
  });
});

/**
 * @param {string} root
 * @param {string} [prefix]
 * @returns {Promise<Record<string, { content?: string, mode?: number, target?: string, type: string }>>}
 */
async function readFilesystemSnapshot(root, prefix = "") {
  const snapshot =
    /** @type {Record<string, { content?: string, mode?: number, target?: string, type: string }>} */ ({});
  const entries = await fs.readdir(root, { withFileTypes: true });
  entries.sort((left, right) => left.name.localeCompare(right.name));
  for (const entry of entries) {
    const relativePath = prefix ? `${prefix}/${entry.name}` : entry.name;
    const file = path.join(root, entry.name);
    const stats = await fs.lstat(file);
    if (entry.isDirectory()) {
      snapshot[`${relativePath}/`] = {
        mode: stats.mode & 0o777,
        type: "dir",
      };
      Object.assign(snapshot, await readFilesystemSnapshot(file, relativePath));
    } else if (entry.isSymbolicLink()) {
      snapshot[relativePath] = {
        target: await fs.readlink(file),
        type: "symlink",
      };
    } else if (entry.isFile()) {
      snapshot[relativePath] = {
        content: (await fs.readFile(file)).toString("base64"),
        mode: stats.mode & 0o777,
        type: "file",
      };
    }
  }
  return snapshot;
}
