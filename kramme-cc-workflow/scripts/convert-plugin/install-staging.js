"use strict";

const { AsyncLocalStorage } = require("async_hooks");
const crypto = require("crypto");
const fs = require("fs/promises");
const path = require("path");
const { normalizeName } = require("./frontmatter");
const { confirm } = require("./confirm");
const {
  sanitizeEntryList,
  sanitizeManagedFileList,
} = require("./install-state");
const {
  copyDir,
  copyFile,
  ensureDir,
  filesystemErrorCode,
  pathExists,
  resolveManagedChild,
} = require("./filesystem");

const INSTALL_LOCK_DIR = ".kramme-install-lock";
const INSTALL_RECOVERY_CLAIMS_DIR = ".kramme-install-recovery-claims";
const INSTALL_RECOVERY_CONFLICTS_DIR = ".kramme-install-recovery-conflicts";
const INSTALL_TRANSACTIONS_DIR = ".kramme-install-transactions";
const INSTALL_BACKUPS_DIR = ".kramme-install-backups";
const LOCK_POLL_INTERVAL_MS = 20;
const MAX_LOCK_POLL_INTERVAL_MS = 250;
const DEFAULT_LOCK_TIMEOUT_MS = 30_000;
const transactionStorage = new AsyncLocalStorage();

/**
 * @typedef {Object} ConfirmOptions
 * @property {boolean} [yes]
 * @property {boolean} [nonInteractive]
 *
 * @typedef {Object} StagedDirInstallOptions
 * @property {string[]} [currentManagedFiles]
 * @property {string} [label]
 * @property {string[]} [previousManagedFiles]
 * @property {boolean} [replace]
 *
 * @typedef {Object} StagedFileInstallOptions
 * @property {string} [label]
 * @property {boolean} [replace]
 *
 * @typedef {Object} PruneStaleManagedFilesOptions
 * @property {string} [label]
 *
 * @typedef {Object} CleanupKrammeComponentsOptions
 * @property {string} [label]
 * @property {(entry: import("fs").Dirent) => boolean} [filter]
 * @property {boolean} [recursive]
 * @property {string[]} [prefixes]
 * @property {ConfirmOptions} [confirmOptions]
 *
 * @typedef {Object} CleanupInstalledEntriesOptions
 * @property {string} [label]
 * @property {boolean} [recursive]
 * @property {ConfirmOptions} [confirmOptions]
 *
 * @typedef {Object} InstallTransactionOptions
 * @property {string[]} [lockRoots]
 * @property {number} [lockTimeoutMs]
 * @property {string} [pluginName]
 */

/**
 * Serialize and journal one installation rooted at `root`.
 *
 * The lock directory is acquired before the callback reloads ownership state or
 * performs preflight. Each destructive helper below records a same-filesystem
 * backup rename before changing its target. On failure, records are replayed in
 * reverse order; a crashed owner is recovered by the next installer after the
 * recorded PID is no longer alive.
 *
 * @template T
 * @param {string} root
 * @param {InstallTransactionOptions} options
 * @param {() => Promise<T>} callback
 * @returns {Promise<T>}
 */
async function withInstallTransaction(root, options, callback) {
  await ensureDir(root);
  const lockRoots = Array.from(
    new Set(
      [root, ...(options.lockRoots ?? [])].map((entry) => path.resolve(entry)),
    ),
  ).sort();
  const transactionOwner = createLockOwner(root, options.pluginName, lockRoots);
  const locks = [];
  let releaseLocks = true;
  let primaryError = null;

  try {
    for (const lockRoot of lockRoots) {
      await ensureDir(lockRoot);
      locks.push(await acquireInstallLock(lockRoot, options, transactionOwner));
    }

    const transaction = await createInstallTransaction(transactionOwner);
    let result;
    try {
      result = await transactionStorage.run(transaction, callback);
    } catch (error) {
      const rollbackErrors = await rollbackInstallTransaction(transaction);
      if (rollbackErrors.length > 0) {
        releaseLocks = false;
        throw rollbackFailureError(error, rollbackErrors, transaction);
      }
      throw error;
    }

    try {
      await markInstallTransactionCommitted(transaction);
    } catch (error) {
      const rollbackErrors = await rollbackInstallTransaction(transaction);
      if (rollbackErrors.length > 0) {
        releaseLocks = false;
        throw rollbackFailureError(error, rollbackErrors, transaction);
      }
      throw error;
    }
    try {
      await removeTransactionArtifacts(transaction);
    } catch (error) {
      releaseLocks = false;
      throw new Error(
        `Install transaction ${transaction.token} committed, but cleanup failed. Recovery state and locks were retained.`,
        { cause: error },
      );
    }
    return result;
  } catch (error) {
    primaryError = error;
    throw error;
  } finally {
    if (releaseLocks) {
      const releaseErrors = await releaseInstallLocks(locks);
      if (releaseErrors.length > 0) {
        throw lockReleaseFailureError(primaryError, releaseErrors);
      }
    }
  }
}

async function acquireInstallLock(root, options, transactionOwner) {
  const lockDir = path.join(root, INSTALL_LOCK_DIR);
  const timeoutMs = options.lockTimeoutMs ?? DEFAULT_LOCK_TIMEOUT_MS;
  const deadline = Date.now() + timeoutMs;
  const owner = { ...transactionOwner };
  let pollIntervalMs = LOCK_POLL_INTERVAL_MS;

  while (true) {
    const existingOwner = await readLockOwner(lockDir);
    let waitingForRecovery = false;

    if (!existingOwner) {
      if (!(await pathExists(lockDir))) {
        if (await publishOwnedDirectory(lockDir, owner)) {
          return { lockDir, owner };
        }
        continue;
      }
    } else if (!(await isProcessAlive(existingOwner.pid))) {
      waitingForRecovery = await hasActiveRecoveryClaim(root, existingOwner);
      if (!waitingForRecovery) {
        const recoveryClaim = await acquireRecoveryClaim(root, existingOwner);
        if (recoveryClaim) {
          const recovered = await recoverClaimedInstall(
            root,
            lockDir,
            existingOwner,
            recoveryClaim,
          );
          if (recovered) continue;
        }
      }
    }

    if (Date.now() >= deadline) {
      if (waitingForRecovery) {
        throw new Error(
          `Timed out waiting for stale install recovery at ${lockDir}.`,
        );
      }
      if (
        !existingOwner &&
        (await quarantineInvalidLock(lockDir, "invalid-owner"))
      ) {
        continue;
      }
      const detail = existingOwner
        ? `owned by PID ${existingOwner.pid}`
        : "without valid owner metadata";
      throw new Error(
        `Timed out waiting for install lock ${lockDir} ${detail}.`,
      );
    }
    await delay(pollIntervalMs);
    pollIntervalMs = Math.min(pollIntervalMs * 2, MAX_LOCK_POLL_INTERVAL_MS);
  }
}

function createLockOwner(root, pluginName, lockRoots) {
  const resolvedRoot = path.resolve(root);
  const token = `${process.pid}-${Date.now()}-${crypto.randomBytes(8).toString("hex")}`;
  return {
    version: 1,
    token,
    pid: process.pid,
    pluginName: String(pluginName ?? "plugin"),
    createdAtMs: Date.now(),
    lockRoots,
    transactionRoot: resolvedRoot,
    journalPath: path.join(
      resolvedRoot,
      INSTALL_TRANSACTIONS_DIR,
      token,
      "journal.json",
    ),
  };
}

async function readLockOwner(lockDir) {
  try {
    const owner = JSON.parse(
      await fs.readFile(path.join(lockDir, "owner.json"), "utf8"),
    );
    if (
      owner?.version !== 1 ||
      typeof owner.token !== "string" ||
      !/^[A-Za-z0-9-]+$/.test(owner.token) ||
      !Number.isSafeInteger(owner.pid) ||
      owner.pid <= 0 ||
      (owner.lockRoots !== undefined &&
        (!Array.isArray(owner.lockRoots) ||
          !owner.lockRoots.every(
            (lockRoot) =>
              typeof lockRoot === "string" && path.isAbsolute(lockRoot),
          ))) ||
      (owner.transactionRoot !== undefined &&
        (typeof owner.transactionRoot !== "string" ||
          !path.isAbsolute(owner.transactionRoot))) ||
      typeof owner.journalPath !== "string" ||
      !path.isAbsolute(owner.journalPath)
    ) {
      return null;
    }
    return owner;
  } catch (error) {
    if (error?.code === "ENOENT" || error instanceof SyntaxError) return null;
    throw error;
  }
}

async function isProcessAlive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    if (error?.code === "ESRCH") return false;
    if (error?.code === "EPERM") return true;
    throw error;
  }
}

async function recoverStaleInstall(root, owner) {
  const { lockRoots, transactionRoot } = await validateRecoveryOwnership(
    root,
    owner,
  );
  owner.lockRoots = lockRoots;
  const expectedJournalPath = path.join(
    transactionRoot,
    INSTALL_TRANSACTIONS_DIR,
    owner.token,
    "journal.json",
  );
  if (owner.journalPath !== expectedJournalPath) {
    throw new Error(
      `Refusing to recover install lock with unowned journal ${owner.journalPath}.`,
    );
  }
  let journal;
  try {
    journal = JSON.parse(await fs.readFile(owner.journalPath, "utf8"));
  } catch (error) {
    if (error?.code === "ENOENT") return;
    throw new Error(
      `Cannot recover stale install journal ${owner.journalPath}.`,
      {
        cause: error,
      },
    );
  }
  if (!lockRoots.includes(transactionRoot)) {
    throw new Error(
      `Refusing to recover install transaction ${owner.token} without its transaction-root lock.`,
    );
  }
  if (
    journal?.version !== 1 ||
    journal?.token !== owner.token ||
    (journal.status !== undefined &&
      journal.status !== "active" &&
      journal.status !== "committed") ||
    !Array.isArray(journal.records) ||
    !journal.records.every((record, index) =>
      isOwnedMutationRecord(record, owner.token, index, lockRoots),
    )
  ) {
    throw new Error(
      `Refusing to recover invalid install journal ${owner.journalPath}.`,
    );
  }

  const transaction = {
    token: owner.token,
    transactionDir: path.dirname(owner.journalPath),
    journalPath: owner.journalPath,
    records: journal.records,
    recoveryConflicts:
      /** @type {{target: string, preservedAt: string}[]} */ ([]),
    status: journal.status === "committed" ? "committed" : "active",
  };
  if (transaction.status === "committed") {
    await removeTransactionArtifacts(transaction);
    return;
  }
  const rollbackErrors = await rollbackInstallTransaction(transaction, {
    preserveCurrentTargets: true,
  });
  if (rollbackErrors.length > 0) {
    throw rollbackFailureError(
      new Error(`Stale install ${owner.token} requires recovery.`),
      rollbackErrors,
      transaction,
    );
  }
  for (const conflict of transaction.recoveryConflicts) {
    console.warn(
      `Preserved interrupted install output ${conflict.target} at ${conflict.preservedAt}.`,
    );
  }
}

async function validateRecoveryOwnership(root, owner) {
  const recoveredRoot = path.resolve(root);
  const transactionRoot = path.resolve(owner.transactionRoot ?? recoveredRoot);
  const lockRoots = Array.from(
    new Set(
      (owner.lockRoots ?? [transactionRoot]).map((lockRoot) =>
        path.resolve(lockRoot),
      ),
    ),
  );
  if (
    !lockRoots.includes(recoveredRoot) ||
    !lockRoots.includes(transactionRoot)
  ) {
    throw new Error(
      `Refusing to recover install transaction ${owner.token} from an unowned lock root.`,
    );
  }

  const validatedLockRoots = [];
  for (const lockRoot of lockRoots) {
    let lockOwner;
    try {
      lockOwner = await readLockOwner(path.join(lockRoot, INSTALL_LOCK_DIR));
    } catch (error) {
      if (lockRoot === recoveredRoot) throw error;
      continue;
    }
    const lockTransactionRoot = lockOwner
      ? path.resolve(lockOwner.transactionRoot ?? lockRoot)
      : null;
    if (
      lockOwner?.token !== owner.token ||
      lockOwner.journalPath !== owner.journalPath ||
      lockTransactionRoot !== transactionRoot
    ) {
      if (lockRoot !== recoveredRoot) continue;
      throw new Error(
        `Refusing to recover install transaction ${owner.token} with an unowned lock root ${lockRoot}.`,
      );
    }
    validatedLockRoots.push(lockRoot);
  }
  return { lockRoots: validatedLockRoots, transactionRoot };
}

async function acquireRecoveryClaim(root, staleOwner) {
  const claimDir = getRecoveryClaimDir(root, staleOwner);
  await ensureDir(path.dirname(claimDir));
  while (true) {
    const claimOwner = createRecoveryClaimOwner(root, staleOwner);
    if (await publishOwnedDirectory(claimDir, claimOwner)) {
      return { lockDir: claimDir, owner: claimOwner };
    }

    const existingClaim = await readLockOwner(claimDir);
    if (
      existingClaim?.expectedToken === staleOwner.token &&
      !(await isProcessAlive(existingClaim.pid))
    ) {
      if (
        await quarantineOwnedLock(claimDir, existingClaim.token, "stale-claim")
      ) {
        continue;
      }
    }
    return null;
  }
}

async function hasActiveRecoveryClaim(root, staleOwner) {
  const claimDir = getRecoveryClaimDir(root, staleOwner);
  const claimOwner = await readLockOwner(claimDir);
  if (!claimOwner) return pathExists(claimDir);
  if (await isProcessAlive(claimOwner.pid)) return true;
  await quarantineOwnedLock(claimDir, claimOwner.token, "stale-claim");
  return false;
}

function getRecoveryClaimDir(root, staleOwner) {
  const transactionRoot = staleOwner.transactionRoot ?? path.resolve(root);
  return path.join(
    transactionRoot,
    INSTALL_RECOVERY_CLAIMS_DIR,
    staleOwner.token,
  );
}

function createRecoveryClaimOwner(root, staleOwner) {
  const transactionRoot = staleOwner.transactionRoot ?? path.resolve(root);
  return {
    version: 1,
    token: `${process.pid}-${Date.now()}-${crypto.randomBytes(8).toString("hex")}`,
    pid: process.pid,
    pluginName: "recovery",
    createdAtMs: Date.now(),
    expectedToken: staleOwner.token,
    transactionRoot,
    journalPath: staleOwner.journalPath,
  };
}

async function recoverClaimedInstall(root, lockDir, staleOwner, recoveryClaim) {
  let recovered = false;
  let recoveryError = null;
  try {
    const claimedOwner = await readLockOwner(lockDir);
    if (claimedOwner?.token === staleOwner.token) {
      await recoverStaleInstall(root, staleOwner);
      recovered = await reclaimStaleTransactionLocks(staleOwner, lockDir);
    }
  } catch (error) {
    recoveryError = error;
  }

  try {
    await releaseRecoveryClaim(recoveryClaim);
  } catch (releaseError) {
    if (recoveryError) {
      throw new Error(
        `${recoveryError.message} Recovery claim cleanup also failed: ${releaseError.message}`,
        { cause: recoveryError },
      );
    }
    throw releaseError;
  }
  if (recoveryError) throw recoveryError;
  return recovered;
}

async function reclaimStaleTransactionLocks(staleOwner, currentLockDir) {
  const resolvedCurrentLockDir = path.resolve(currentLockDir);
  const lockDirs = new Set([resolvedCurrentLockDir]);
  for (const lockRoot of staleOwner.lockRoots ?? []) {
    lockDirs.add(path.join(path.resolve(lockRoot), INSTALL_LOCK_DIR));
  }

  let reclaimedCurrent = false;
  for (const lockDir of [...lockDirs].sort()) {
    const reclaimed = await quarantineOwnedLock(
      lockDir,
      staleOwner.token,
      "stale",
    );
    if (lockDir === resolvedCurrentLockDir) {
      reclaimedCurrent = reclaimed;
    }
  }
  return reclaimedCurrent;
}

async function releaseRecoveryClaim(recoveryClaim) {
  await releaseInstallLock(recoveryClaim);
  try {
    await fs.rmdir(path.dirname(recoveryClaim.lockDir));
  } catch {
    // Another stale transaction may still own a sibling recovery claim.
  }
}

async function publishOwnedDirectory(dir, owner) {
  const temporaryDir = `${dir}.tmp-${process.pid}-${crypto.randomBytes(6).toString("hex")}`;
  try {
    await fs.mkdir(temporaryDir);
    await writeAtomicJson(path.join(temporaryDir, "owner.json"), owner);
    try {
      await fs.rename(temporaryDir, dir);
      return true;
    } catch (error) {
      if (error?.code === "EEXIST" || error?.code === "ENOTEMPTY") {
        return false;
      }
      throw error;
    }
  } finally {
    await fs.rm(temporaryDir, { recursive: true, force: true });
  }
}

async function quarantineInvalidLock(lockDir, label) {
  const quarantineDir = `${lockDir}.${label}-${process.pid}-${crypto.randomBytes(6).toString("hex")}`;
  try {
    await fs.rename(lockDir, quarantineDir);
  } catch (error) {
    if (error?.code === "ENOENT") return false;
    throw error;
  }

  const movedOwner = await readLockOwner(quarantineDir);
  if (movedOwner) {
    try {
      await fs.rename(quarantineDir, lockDir);
    } catch (restoreError) {
      throw new Error(
        `Install lock became owned while reclaiming ${lockDir}.`,
        {
          cause: restoreError,
        },
      );
    }
    return false;
  }
  await fs.rm(quarantineDir, { recursive: true, force: true });
  return true;
}

async function quarantineOwnedLock(lockDir, expectedToken, label) {
  const quarantineDir = `${lockDir}.${label}-${process.pid}-${crypto.randomBytes(6).toString("hex")}`;
  try {
    await fs.rename(lockDir, quarantineDir);
  } catch (error) {
    if (error?.code === "ENOENT") return false;
    throw error;
  }

  const movedOwner = await readLockOwner(quarantineDir);
  if (movedOwner?.token !== expectedToken) {
    try {
      await fs.rename(quarantineDir, lockDir);
    } catch (restoreError) {
      throw new Error(
        `Install lock ownership changed while recovering ${lockDir}.`,
        {
          cause: restoreError,
        },
      );
    }
    return false;
  }
  await fs.rm(quarantineDir, { recursive: true, force: true });
  return true;
}

async function releaseInstallLock(lock) {
  const released = await quarantineOwnedLock(
    lock.lockDir,
    lock.owner.token,
    "release",
  );
  if (!released && (await pathExists(lock.lockDir))) {
    throw new Error(
      `Refusing to release unowned install lock ${lock.lockDir}.`,
    );
  }
}

async function releaseInstallLocks(locks) {
  const errors = [];
  for (const lock of [...locks].reverse()) {
    try {
      await releaseInstallLock(lock);
    } catch (error) {
      errors.push({ error, lock });
    }
  }
  return errors;
}

function lockReleaseFailureError(primaryError, releaseErrors) {
  const details = releaseErrors
    .map(({ error, lock }) => `${lock.lockDir}: ${error.message}`)
    .join("; ");
  if (primaryError) {
    return new Error(
      `${primaryError.message} Install lock cleanup also failed: ${details}`,
      { cause: primaryError },
    );
  }
  return new Error(`Install lock cleanup failed: ${details}`, {
    cause: releaseErrors[0].error,
  });
}

async function createInstallTransaction(owner) {
  const transactionDir = path.dirname(owner.journalPath);
  const transaction = {
    token: owner.token,
    transactionDir,
    journalPath: owner.journalPath,
    records: [],
    status: "active",
  };
  await ensureDir(transactionDir);
  await persistInstallJournal(transaction);
  return transaction;
}

function isOwnedMutationRecord(record, token, recordIndex, lockRoots) {
  if (
    !record ||
    typeof record !== "object" ||
    typeof record.target !== "string" ||
    !path.isAbsolute(record.target) ||
    path.resolve(record.target) !== record.target ||
    !lockRoots.some((lockRoot) =>
      record.target.startsWith(path.resolve(lockRoot) + path.sep),
    )
  ) {
    return false;
  }
  if (record.operation === "create") return record.backup === null;
  if (
    record.operation !== "backup-rename" ||
    typeof record.backup !== "string" ||
    !path.isAbsolute(record.backup)
  ) {
    return false;
  }
  const expectedBackup = path.join(
    path.dirname(record.target),
    INSTALL_BACKUPS_DIR,
    token,
    String(recordIndex),
  );
  return record.backup === expectedBackup;
}

async function persistInstallJournal(transaction) {
  await writeAtomicJson(transaction.journalPath, {
    version: 1,
    token: transaction.token,
    records: transaction.records,
    status: transaction.status,
  });
}

async function prepareTransactionMutation(
  targetPath,
  { preserveExisting = false } = {},
) {
  const transaction = transactionStorage.getStore();
  if (!transaction) return false;

  const resolvedTarget = path.resolve(targetPath);
  const coveringRecord = transaction.records.find(
    (record) =>
      resolvedTarget === record.target ||
      resolvedTarget.startsWith(record.target + path.sep),
  );
  if (coveringRecord) return true;
  if (
    transaction.records.some((record) =>
      record.target.startsWith(resolvedTarget + path.sep),
    )
  ) {
    throw new Error(
      `Install transaction cannot back up parent after child: ${resolvedTarget}`,
    );
  }

  let stats = null;
  try {
    stats = await fs.lstat(resolvedTarget);
  } catch (error) {
    if (error?.code !== "ENOENT") throw error;
  }

  const record =
    /** @type {{operation: string, target: string, backup: string | null}} */ ({
      operation: stats ? "backup-rename" : "create",
      target: resolvedTarget,
      backup: null,
    });
  if (stats) {
    const backupRoot = path.join(
      path.dirname(resolvedTarget),
      INSTALL_BACKUPS_DIR,
      transaction.token,
    );
    record.backup = path.join(backupRoot, String(transaction.records.length));
  }
  transaction.records.push(record);
  await persistInstallJournal(transaction);

  if (!stats) return true;
  const backupPath = record.backup;
  if (!backupPath)
    throw new Error(`Missing transaction backup for ${resolvedTarget}.`);
  await ensureDir(path.dirname(backupPath));
  await fs.rename(resolvedTarget, backupPath);
  await persistInstallJournal(transaction);
  if (preserveExisting) {
    await fs.cp(backupPath, resolvedTarget, {
      recursive: stats.isDirectory(),
      preserveTimestamps: true,
      dereference: false,
    });
  }
  return true;
}

async function rollbackInstallTransaction(
  transaction,
  { preserveCurrentTargets = false } = {},
) {
  const errors = [];
  const indexedRecords = transaction.records
    .map((record, index) => ({ index, record }))
    .reverse();
  for (const { index, record } of indexedRecords) {
    try {
      const backupExists =
        record.backup && (await rawPathExists(record.backup));
      if (backupExists) {
        if (preserveCurrentTargets) {
          await preserveRecoveryTarget(transaction, record, index);
        } else {
          await fs.rm(record.target, { recursive: true, force: true });
        }
        await ensureDir(path.dirname(record.target));
        await fs.rename(record.backup, record.target);
      } else if (record.operation === "create") {
        if (preserveCurrentTargets) {
          await preserveRecoveryTarget(transaction, record, index);
        } else {
          await fs.rm(record.target, { recursive: true, force: true });
        }
      }
    } catch (error) {
      errors.push({ error, record });
    }
  }
  if (errors.length === 0) {
    try {
      await removeTransactionArtifacts(transaction);
    } catch (error) {
      errors.push({
        error,
        record: {
          operation: "cleanup",
          target: transaction.transactionDir,
          backup: null,
        },
      });
    }
  }
  return errors;
}

async function preserveRecoveryTarget(transaction, record, recordIndex) {
  if (!(await rawPathExists(record.target))) return;
  const conflictRoot = path.join(
    path.dirname(record.target),
    INSTALL_RECOVERY_CONFLICTS_DIR,
    transaction.token,
  );
  await ensureDir(conflictRoot);

  for (let suffix = 0; ; suffix += 1) {
    const name =
      suffix === 0 ? String(recordIndex) : `${recordIndex}-${suffix}`;
    const preservedAt = path.join(conflictRoot, name);
    try {
      await fs.rename(record.target, preservedAt);
      transaction.recoveryConflicts.push({
        target: record.target,
        preservedAt,
      });
      return;
    } catch (error) {
      if (error?.code === "ENOENT") return;
      if (error?.code === "EEXIST" || error?.code === "ENOTEMPTY") continue;
      throw error;
    }
  }
}

async function markInstallTransactionCommitted(transaction) {
  transaction.status = "committed";
  await persistInstallJournal(transaction);
}

async function removeTransactionArtifacts(transaction) {
  const backupRoots = new Set(
    transaction.records
      .map((record) => record.backup)
      .filter(Boolean)
      .map((backup) => path.dirname(backup)),
  );
  for (const backupRoot of backupRoots) {
    await fs.rm(backupRoot, { recursive: true, force: true });
    try {
      await fs.rmdir(path.dirname(backupRoot));
    } catch {
      // Other installs may own sibling backup directories.
    }
  }
  await fs.rm(transaction.transactionDir, { recursive: true, force: true });
  try {
    await fs.rmdir(path.dirname(transaction.transactionDir));
  } catch {
    // Other installs may own sibling transaction directories.
  }
}

function rollbackFailureError(originalError, rollbackErrors, transaction) {
  const details = rollbackErrors
    .map(
      ({ error, record }) =>
        `${record.operation} ${record.target}: ${error.message}`,
    )
    .join("; ");
  return new Error(
    `${originalError.message} Rollback failed for install transaction ${transaction.token}: ${details}`,
    { cause: originalError },
  );
}

async function writeAtomicJson(file, value) {
  await ensureDir(path.dirname(file));
  const temporary = `${file}.tmp-${process.pid}-${crypto.randomBytes(6).toString("hex")}`;
  try {
    await fs.writeFile(
      temporary,
      JSON.stringify(value, null, 2) + "\n",
      "utf8",
    );
    await fs.rename(temporary, file);
  } finally {
    await fs.rm(temporary, { force: true });
  }
}

async function rawPathExists(file) {
  try {
    await fs.lstat(file);
    return true;
  } catch (error) {
    if (error?.code === "ENOENT") return false;
    throw error;
  }
}

function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

/**
 * @typedef {{ removed: boolean, hasStaleManagedFile?: boolean }} ManagedPruneInspection
 */

/** @param {string} baseRoot @param {string} pluginName @param {string} label */
async function createInstallStagingRoot(baseRoot, pluginName, label) {
  await ensureDir(baseRoot);
  const nonce = Math.random().toString(16).slice(2);
  const stagingRoot = path.join(
    baseRoot,
    ".kramme-install-staging",
    `${normalizeName(pluginName)}-${label}-${Date.now()}-${process.pid}-${nonce}`,
  );
  await ensureDir(stagingRoot);
  return stagingRoot;
}

/** @param {string | null | undefined} stagingRoot */
async function removeInstallStagingRoot(stagingRoot) {
  if (!stagingRoot) return;
  await fs.rm(stagingRoot, { recursive: true, force: true });
  try {
    await fs.rmdir(path.dirname(stagingRoot));
  } catch {
    // Another concurrent install may still have a sibling staging directory.
  }
}

/**
 * @param {string} stagedDir
 * @param {string} targetDir
 * @param {StagedDirInstallOptions} [options]
 */
async function preflightStagedDirInstall(
  stagedDir,
  targetDir,
  {
    currentManagedFiles,
    label = "directory",
    previousManagedFiles,
    replace = false,
  } = {},
) {
  if (
    !(await pathExists(stagedDir)) ||
    replace ||
    !(await pathExists(targetDir))
  ) {
    return;
  }
  const targetStats = await fs.lstat(targetDir);
  if (!targetStats.isDirectory()) {
    throw new Error(
      `Cannot install ${label} because ${targetDir} is not a directory.`,
    );
  }

  await preflightStagedDirMerge(stagedDir, targetDir, "", {
    label,
    staleManagedFiles: staleManagedFileSet(
      previousManagedFiles,
      currentManagedFiles,
    ),
  });
}

/**
 * @param {string} stagedFile
 * @param {string} targetFile
 * @param {StagedFileInstallOptions} [options]
 */
async function preflightStagedFileInstall(
  stagedFile,
  targetFile,
  { label = "file", replace = false } = {},
) {
  if (
    !(await pathExists(stagedFile)) ||
    replace ||
    !(await pathExists(targetFile))
  ) {
    return;
  }
  const targetStats = await fs.lstat(targetFile);
  if (targetStats.isDirectory()) {
    throw new Error(
      `Cannot install ${label} because ${targetFile} is a directory.`,
    );
  }
}

/** @param {string} stagedDir @param {string} targetDir @param {{ replace?: boolean }} [options] */
async function installStagedDir(
  stagedDir,
  targetDir,
  { replace = false } = {},
) {
  if (!(await pathExists(stagedDir))) return;
  const transactional = await prepareTransactionMutation(targetDir, {
    preserveExisting: !replace,
  });
  if (replace && !transactional) {
    await fs.rm(targetDir, { recursive: true, force: true });
  }
  await ensureDir(path.dirname(targetDir));
  if (replace || !(await pathExists(targetDir))) {
    try {
      await fs.rename(stagedDir, targetDir);
      return;
    } catch (error) {
      if (filesystemErrorCode(error) !== "EXDEV") throw error;
    }
  }
  await copyDir(stagedDir, targetDir);
  await fs.rm(stagedDir, { recursive: true, force: true });
}

/**
 * @param {string} targetDir
 * @param {string[] | undefined} previousFiles
 * @param {string[] | undefined} currentFiles
 * @param {PruneStaleManagedFilesOptions} [options]
 */
async function pruneStaleManagedFiles(
  targetDir,
  previousFiles,
  currentFiles,
  { label = "directory" } = {},
) {
  await prepareTransactionMutation(targetDir, { preserveExisting: true });
  for (const relativeFile of staleManagedFileSet(previousFiles, currentFiles)) {
    const targetPath = resolveManagedChild(
      targetDir,
      relativeFile,
      `${label} managed file`,
    );
    if (!(await hasSafeManagedAncestorDirs(targetDir, targetPath))) continue;

    let stats;
    try {
      stats = await fs.lstat(targetPath);
    } catch (error) {
      if (filesystemErrorCode(error) === "ENOENT") continue;
      throw error;
    }

    if (!stats.isFile() && !stats.isSymbolicLink()) continue;
    await fs.rm(targetPath, { force: true });
    await removeEmptyAncestorDirs(path.dirname(targetPath), targetDir);
  }
}

/** @param {unknown} previousFiles @param {unknown} currentFiles @returns {Set<string>} */
function staleManagedFileSet(previousFiles, currentFiles) {
  const currentFileSet = new Set(sanitizeManagedFileList(currentFiles));
  return new Set(
    sanitizeManagedFileList(previousFiles).filter(
      (relativeFile) => !currentFileSet.has(relativeFile),
    ),
  );
}

/**
 * @param {string} stagedDir
 * @param {string} targetDir
 * @param {string} prefix
 * @param {{ label: string, staleManagedFiles: Set<string> }} options
 */
async function preflightStagedDirMerge(
  stagedDir,
  targetDir,
  prefix,
  { label, staleManagedFiles },
) {
  const entries = await fs.readdir(stagedDir, { withFileTypes: true });
  for (const entry of entries) {
    const relativePath = prefix ? `${prefix}/${entry.name}` : entry.name;
    const stagedPath = path.join(stagedDir, entry.name);
    const targetPath = path.join(targetDir, entry.name);
    const targetStats = await lstatAfterManagedPrune(
      targetPath,
      relativePath,
      staleManagedFiles,
    );

    if (entry.isDirectory()) {
      if (!targetStats) continue;
      if (!targetStats.isDirectory()) {
        throw new Error(
          `Cannot install ${label} because ${targetPath} conflicts with staged directory ${relativePath}.`,
        );
      }
      await preflightStagedDirMerge(stagedPath, targetPath, relativePath, {
        label,
        staleManagedFiles,
      });
      continue;
    }

    if (!entry.isFile() || !targetStats?.isDirectory()) continue;

    const removableDirectory = await directoryRemovedByManagedPrune(
      targetPath,
      relativePath,
      staleManagedFiles,
    );
    if (!removableDirectory) {
      throw new Error(
        `Cannot install ${label} because ${targetPath} conflicts with staged file ${relativePath}.`,
      );
    }
  }
}

/** @param {string} targetPath @param {string} relativePath @param {Set<string>} staleManagedFiles */
async function lstatAfterManagedPrune(
  targetPath,
  relativePath,
  staleManagedFiles,
) {
  let stats;
  try {
    stats = await fs.lstat(targetPath);
  } catch (error) {
    if (filesystemErrorCode(error) === "ENOENT") return null;
    throw error;
  }
  if (
    staleManagedFiles.has(relativePath) &&
    (stats.isFile() || stats.isSymbolicLink())
  ) {
    return null;
  }
  return stats;
}

/** @param {string} dirPath @param {string} relativeDir @param {Set<string>} staleManagedFiles */
async function directoryRemovedByManagedPrune(
  dirPath,
  relativeDir,
  staleManagedFiles,
) {
  const result = await inspectDirectoryForManagedPrune(
    dirPath,
    relativeDir,
    staleManagedFiles,
  );
  return result.removed;
}

/**
 * @param {string} dirPath
 * @param {string} relativeDir
 * @param {Set<string>} staleManagedFiles
 * @returns {Promise<ManagedPruneInspection>}
 */
async function inspectDirectoryForManagedPrune(
  dirPath,
  relativeDir,
  staleManagedFiles,
) {
  const entries = await fs.readdir(dirPath, { withFileTypes: true });
  let hasStaleManagedFile = false;
  for (const entry of entries) {
    const relativePath = `${relativeDir}/${entry.name}`;
    const fullPath = path.join(dirPath, entry.name);
    if (entry.isDirectory()) {
      const child = await inspectDirectoryForManagedPrune(
        fullPath,
        relativePath,
        staleManagedFiles,
      );
      if (!child.removed) return { removed: false };
      hasStaleManagedFile =
        hasStaleManagedFile || Boolean(child.hasStaleManagedFile);
      continue;
    }

    if (
      (entry.isFile() || entry.isSymbolicLink()) &&
      staleManagedFiles.has(relativePath)
    ) {
      hasStaleManagedFile = true;
      continue;
    }

    return { removed: false };
  }

  return {
    hasStaleManagedFile,
    removed: hasStaleManagedFile,
  };
}

/** @param {string} rootDir @param {string} targetPath */
async function hasSafeManagedAncestorDirs(rootDir, targetPath) {
  const resolvedRoot = path.resolve(rootDir);
  const targetDir = path.dirname(path.resolve(targetPath));
  const dirs = [];

  try {
    const rootStats = await fs.lstat(resolvedRoot);
    if (!rootStats.isDirectory()) return false;
  } catch (error) {
    if (filesystemErrorCode(error) === "ENOENT") return false;
    throw error;
  }

  let current = targetDir;
  while (current !== resolvedRoot) {
    if (!current.startsWith(resolvedRoot + path.sep)) return false;
    dirs.push(current);
    current = path.dirname(current);
  }

  for (const dir of dirs.reverse()) {
    let stats;
    try {
      stats = await fs.lstat(dir);
    } catch (error) {
      if (filesystemErrorCode(error) === "ENOENT") return false;
      throw error;
    }
    if (!stats.isDirectory()) return false;
  }

  return true;
}

/** @param {string} startDir @param {string} rootDir */
async function removeEmptyAncestorDirs(startDir, rootDir) {
  const resolvedRoot = path.resolve(rootDir);
  let current = path.resolve(startDir);

  while (
    current !== resolvedRoot &&
    current.startsWith(resolvedRoot + path.sep)
  ) {
    try {
      await fs.rmdir(current);
    } catch {
      return;
    }
    current = path.dirname(current);
  }
}

/** @param {string} stagedFile @param {string} targetFile @param {{ replace?: boolean }} [options] */
async function installStagedFile(
  stagedFile,
  targetFile,
  { replace = false } = {},
) {
  if (!(await pathExists(stagedFile))) return;
  const transactional = await prepareTransactionMutation(targetFile);
  if (replace && !transactional) {
    await fs.rm(targetFile, { force: true });
  }
  await ensureDir(path.dirname(targetFile));
  try {
    await fs.rename(stagedFile, targetFile);
    return;
  } catch (error) {
    if (filesystemErrorCode(error) !== "EXDEV") throw error;
  }
  await copyFile(stagedFile, targetFile);
  await fs.rm(stagedFile, { force: true });
}

/**
 * @param {string} dir
 * @param {CleanupKrammeComponentsOptions} [options]
 */
async function cleanupKrammeComponents(
  dir,
  {
    label,
    filter,
    recursive = false,
    prefixes = ["kramme:", "kramme-"],
    confirmOptions = {},
  } = {},
) {
  if (!(await pathExists(dir))) return;
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const matched = entries
    .filter(/** @type {(entry: import("fs").Dirent) => boolean} */ (filter))
    .filter((entry) => prefixes.some((prefix) => entry.name.startsWith(prefix)))
    .map((entry) => entry.name);

  if (matched.length === 0) return;

  console.log(
    `\nFound ${matched.length} existing kramme ${label}(s) in ${dir}:`,
  );
  for (const name of matched) {
    console.log(`  - ${name}`);
  }

  const confirmed = await confirm(
    `Delete these ${label}s before installing?`,
    confirmOptions,
  );
  if (!confirmed) {
    console.log(`Skipping ${label} cleanup.`);
    return;
  }

  for (const name of matched) {
    const targetPath = path.join(dir, name);
    if (!(await prepareTransactionMutation(targetPath))) {
      await fs.rm(targetPath, { recursive: true, force: true });
    }
  }
  console.log(`Deleted ${matched.length} ${label}(s).`);
}

/**
 * @param {string} dir
 * @param {string[] | undefined} entries
 * @param {CleanupInstalledEntriesOptions} [options]
 */
async function cleanupInstalledEntries(
  dir,
  entries,
  { label, recursive = false, confirmOptions = {} } = {},
) {
  const matched = [];
  for (const entry of sanitizeEntryList(entries)) {
    const targetPath = resolveManagedChild(dir, entry, `${label} entry`);
    if (await pathExists(targetPath)) {
      matched.push({ name: entry, path: targetPath });
    }
  }

  if (matched.length === 0) return true;

  console.log(
    `\nFound ${matched.length} existing ${label}(s) from this plugin in ${dir}:`,
  );
  for (const { name } of matched) {
    console.log(`  - ${name}`);
  }

  const confirmed = await confirm(
    `Delete these ${label}s before installing?`,
    confirmOptions,
  );
  if (!confirmed) {
    console.log(`Skipping ${label} cleanup.`);
    return false;
  }

  for (const { path: targetPath } of matched) {
    if (!(await prepareTransactionMutation(targetPath))) {
      await fs.rm(targetPath, { recursive: true, force: true });
    }
  }
  console.log(`Deleted ${matched.length} ${label}(s).`);
  return true;
}

module.exports = {
  cleanupInstalledEntries,
  cleanupKrammeComponents,
  createInstallStagingRoot,
  installStagedDir,
  installStagedFile,
  preflightStagedDirInstall,
  preflightStagedFileInstall,
  pruneStaleManagedFiles,
  removeInstallStagingRoot,
  withInstallTransaction,
};
