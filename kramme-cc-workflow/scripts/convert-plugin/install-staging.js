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
  copyFilePreservingMetadata,
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
/** @type {AsyncLocalStorage<InstallTransaction>} */
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
 * @property {string[]} [previousManagedRoots]
 * @property {boolean} [replace]
 *
 * @typedef {Object} StagedFileInstallOptions
 * @property {ExpectedTargetContent} [expectedTargetContent]
 * @property {string} [label]
 * @property {string[]} [previousManagedFiles]
 * @property {boolean} [replace]
 *
 * @typedef {Object} InstallStagedDirOptions
 * @property {ExpectedTargetEntries} [expectedTargetEntries]
 * @property {string} [label]
 * @property {boolean} [replace]
 *
 * @typedef {Object} InstallStagedFileOptions
 * @property {ExpectedTargetContent} [expectedTargetContent]
 * @property {ExpectedTargetIdentity} [expectedTargetIdentity]
 * @property {string} [label]
 * @property {boolean} [preserveTargetChangesOnRollback]
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
 * @property {string[]} [preserveInvalidLockRoots]
 *
 * @typedef {Object} InstallLockOwner
 * @property {number} version
 * @property {string} token
 * @property {number} pid
 * @property {string} pluginName
 * @property {number} createdAtMs
 * @property {string[]} [lockRoots]
 * @property {string} [transactionRoot]
 * @property {string} journalPath
 * @property {string} [expectedToken]
 *
 * @typedef {Object} InstallLock
 * @property {string} lockDir
 * @property {InstallLockOwner} owner
 *
 * @typedef {Object} InstallMutationRecord
 * @property {string} operation
 * @property {string} target
 * @property {string | null} backup
 *
 * @typedef {Object} InstallTransaction
 * @property {string} token
 * @property {string} transactionDir
 * @property {string} journalPath
 * @property {string[]} lockRoots
 * @property {InstallMutationRecord[]} records
 * @property {{ target: string, preservedAt: string }[]} recoveryConflicts
 * @property {Set<string>} publicationTemps
 * @property {Set<string>} rollbackDeletedTargets
 * @property {Map<string, RollbackTargetExpectation>} rollbackTargetContents
 * @property {string} status
 *
 * @typedef {Buffer | string | null} ExpectedTargetContent
 * @typedef {{ ctimeMs?: number, device: number, gid?: number, inode: number, links: number, mode?: number, uid?: number }} ExpectedTargetIdentity
 * @typedef {{ ctimeMs: number, device: number, gid: number, inode: number, links: number, mode: number, uid: number }} RollbackTargetMetadata
 * @typedef {{ content: Buffer | null, metadata: RollbackTargetMetadata | null }} RollbackTargetExpectation
 * @typedef {{ kind: "directory" } | { kind: "file", content: Buffer } | { kind: "missing" }} ExpectedTargetEntry
 * @typedef {Map<string, ExpectedTargetEntry>} ExpectedTargetEntries
 * @typedef {{ expectedTargetContent?: ExpectedTargetContent, expectedTargetEntries?: ExpectedTargetEntries, expectedTargetIdentity?: ExpectedTargetIdentity, record: InstallMutationRecord, recordIndex: number, target: string, targetExists: boolean }} PreparedTransactionMutation
 * @typedef {{ error: unknown, lock: InstallLock }} InstallLockReleaseError
 * @typedef {{ error: unknown, record: InstallMutationRecord }} InstallRollbackError
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
  const transactionRoot = await canonicalizeDirectoryPath(root);
  const lockRoots = Array.from(
    new Set(
      await Promise.all(
        [transactionRoot, ...(options.lockRoots ?? [])].map((entry) =>
          canonicalizeDirectoryPath(entry),
        ),
      ),
    ),
  ).sort();
  const preserveInvalidLockRoots = new Set(
    await Promise.all(
      (options.preserveInvalidLockRoots ?? []).map((entry) =>
        canonicalizeDirectoryPath(entry),
      ),
    ),
  );
  preserveInvalidLockRoots.delete(transactionRoot);
  const transactionOptions = {
    ...options,
    preserveInvalidLockRoots: [...preserveInvalidLockRoots],
  };
  const transactionOwner = createLockOwner(
    transactionRoot,
    options.pluginName,
    lockRoots,
  );
  /** @type {InstallLock[]} */
  const locks = [];
  let releaseLocks = true;
  /** @type {unknown} */
  let primaryError = null;

  try {
    for (const lockRoot of lockRoots) {
      await ensureDir(lockRoot);
      locks.push(
        await acquireInstallLock(
          lockRoot,
          transactionOptions,
          transactionOwner,
        ),
      );
    }

    const transaction = await createInstallTransaction(transactionOwner);
    let result;
    try {
      result = await transactionStorage.run(transaction, callback);
    } catch (error) {
      const rollbackErrors = await rollbackInstallTransaction(transaction);
      reportRecoveryConflicts(transaction);
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
      reportRecoveryConflicts(transaction);
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

/**
 * @param {string} root
 * @param {InstallTransactionOptions} options
 * @param {InstallLockOwner} transactionOwner
 * @returns {Promise<InstallLock>}
 */
async function acquireInstallLock(root, options, transactionOwner) {
  const lockDir = path.join(root, INSTALL_LOCK_DIR);
  const timeoutMs = options.lockTimeoutMs ?? DEFAULT_LOCK_TIMEOUT_MS;
  const deadline = Date.now() + timeoutMs;
  const owner = { ...transactionOwner };
  const preserveInvalidLock = (options.preserveInvalidLockRoots ?? []).includes(
    path.resolve(root),
  );
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
      if (preserveInvalidLock) {
        throw new Error(
          `Refusing to reclaim invalid install lock ${lockDir} in an external AGENTS.md directory.`,
        );
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

/**
 * @param {string} root
 * @param {string | undefined} pluginName
 * @param {string[]} lockRoots
 * @returns {InstallLockOwner}
 */
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

/** @param {string} lockDir @returns {Promise<InstallLockOwner | null>} */
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
            /** @param {unknown} lockRoot */ (lockRoot) =>
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
    return /** @type {InstallLockOwner} */ (owner);
  } catch (error) {
    if (filesystemErrorCode(error) === "ENOENT" || error instanceof SyntaxError)
      return null;
    throw error;
  }
}

/** @param {number} pid */
async function isProcessAlive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    if (filesystemErrorCode(error) === "ESRCH") return false;
    if (filesystemErrorCode(error) === "EPERM") return true;
    throw error;
  }
}

/** @param {string} root @param {InstallLockOwner} owner */
async function recoverStaleInstall(root, owner) {
  const { journalPath, lockRoots, transactionRoot } =
    await validateRecoveryOwnership(root, owner);
  owner.journalPath = journalPath;
  owner.lockRoots = lockRoots;
  owner.transactionRoot = transactionRoot;
  let journal;
  try {
    journal = JSON.parse(await fs.readFile(journalPath, "utf8"));
  } catch (error) {
    if (filesystemErrorCode(error) === "ENOENT") return;
    throw new Error(`Cannot recover stale install journal ${journalPath}.`, {
      cause: error,
    });
  }
  if (!lockRoots.includes(transactionRoot)) {
    throw new Error(
      `Refusing to recover install transaction ${owner.token} without its transaction-root lock.`,
    );
  }
  const recordsValid =
    Array.isArray(journal?.records) &&
    (
      await Promise.all(
        journal.records.map(
          /** @param {unknown} record @param {number} index */ (
            record,
            index,
          ) => isOwnedMutationRecord(record, owner.token, index, lockRoots),
        ),
      )
    ).every(Boolean);
  const rollbackTargetContents = recordsValid
    ? await parseRollbackTargetExpectations(
        journal?.rollbackTargetExpectations,
        lockRoots,
        /** @type {InstallMutationRecord[]} */ (journal.records),
      )
    : null;
  const publicationTemps = recordsValid
    ? await parsePublicationTemps(
        journal?.publicationTemps,
        owner.token,
        /** @type {InstallMutationRecord[]} */ (journal.records),
      )
    : null;
  if (
    journal?.version !== 1 ||
    journal?.token !== owner.token ||
    (journal.status !== undefined &&
      journal.status !== "active" &&
      journal.status !== "committed") ||
    !recordsValid ||
    rollbackTargetContents === null ||
    publicationTemps === null
  ) {
    throw new Error(
      `Refusing to recover invalid install journal ${journalPath}.`,
    );
  }

  const transaction = {
    token: owner.token,
    transactionDir: path.dirname(journalPath),
    journalPath,
    lockRoots,
    records: /** @type {InstallMutationRecord[]} */ (journal.records),
    recoveryConflicts:
      /** @type {{target: string, preservedAt: string}[]} */ ([]),
    publicationTemps,
    rollbackDeletedTargets: new Set(),
    rollbackTargetContents,
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
  reportRecoveryConflicts(transaction);
}

/**
 * @param {string} root
 * @param {InstallLockOwner} owner
 * @returns {Promise<{ journalPath: string, lockRoots: string[], transactionRoot: string }>}
 */
async function validateRecoveryOwnership(root, owner) {
  const recoveredRoot = await canonicalizeDirectoryPath(root);
  const transactionRoot = await canonicalizeDirectoryPath(
    owner.transactionRoot ?? recoveredRoot,
  );
  const lockRoots = Array.from(
    new Set(
      await Promise.all(
        (owner.lockRoots ?? [transactionRoot]).map((lockRoot) =>
          canonicalizeDirectoryPath(lockRoot),
        ),
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
      ? await canonicalizeDirectoryPath(lockOwner.transactionRoot ?? lockRoot)
      : null;
    const lockJournalPath = lockOwner
      ? await canonicalizeDirectoryPath(lockOwner.journalPath)
      : null;
    const ownerJournalPath = await canonicalizeDirectoryPath(owner.journalPath);
    if (
      lockOwner?.token !== owner.token ||
      lockJournalPath !== ownerJournalPath ||
      lockTransactionRoot !== transactionRoot
    ) {
      if (lockRoot !== recoveredRoot) continue;
      throw new Error(
        `Refusing to recover install transaction ${owner.token} with an unowned lock root ${lockRoot}.`,
      );
    }
    validatedLockRoots.push(lockRoot);
  }
  const journalPath = await canonicalizeDirectoryPath(owner.journalPath);
  const expectedJournalPath = path.join(
    transactionRoot,
    INSTALL_TRANSACTIONS_DIR,
    owner.token,
    "journal.json",
  );
  if (journalPath !== expectedJournalPath) {
    throw new Error(
      `Refusing to recover install lock with unowned journal ${owner.journalPath}.`,
    );
  }
  return { journalPath, lockRoots: validatedLockRoots, transactionRoot };
}

/**
 * @param {string} root
 * @param {InstallLockOwner} staleOwner
 * @returns {Promise<InstallLock | null>}
 */
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

/** @param {string} root @param {InstallLockOwner} staleOwner */
async function hasActiveRecoveryClaim(root, staleOwner) {
  const claimDir = getRecoveryClaimDir(root, staleOwner);
  const claimOwner = await readLockOwner(claimDir);
  if (!claimOwner) return pathExists(claimDir);
  if (await isProcessAlive(claimOwner.pid)) return true;
  await quarantineOwnedLock(claimDir, claimOwner.token, "stale-claim");
  return false;
}

/** @param {string} root @param {InstallLockOwner} staleOwner */
function getRecoveryClaimDir(root, staleOwner) {
  const transactionRoot = staleOwner.transactionRoot ?? path.resolve(root);
  return path.join(
    transactionRoot,
    INSTALL_RECOVERY_CLAIMS_DIR,
    staleOwner.token,
  );
}

/**
 * @param {string} root
 * @param {InstallLockOwner} staleOwner
 * @returns {InstallLockOwner}
 */
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

/**
 * @param {string} root
 * @param {string} lockDir
 * @param {InstallLockOwner} staleOwner
 * @param {InstallLock} recoveryClaim
 */
async function recoverClaimedInstall(root, lockDir, staleOwner, recoveryClaim) {
  let recovered = false;
  /** @type {unknown} */
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
        `${errorMessage(recoveryError)} Recovery claim cleanup also failed: ${errorMessage(releaseError)}`,
        { cause: recoveryError },
      );
    }
    throw releaseError;
  }
  if (recoveryError) throw recoveryError;
  return recovered;
}

/**
 * @param {InstallLockOwner} staleOwner
 * @param {string} currentLockDir
 */
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

/** @param {InstallLock} recoveryClaim */
async function releaseRecoveryClaim(recoveryClaim) {
  await releaseInstallLock(recoveryClaim);
  try {
    await fs.rmdir(path.dirname(recoveryClaim.lockDir));
  } catch {
    // Another stale transaction may still own a sibling recovery claim.
  }
}

/** @param {string} dir @param {InstallLockOwner} owner */
async function publishOwnedDirectory(dir, owner) {
  const temporaryDir = `${dir}.tmp-${process.pid}-${crypto.randomBytes(6).toString("hex")}`;
  try {
    await fs.mkdir(temporaryDir);
    await writeAtomicJson(path.join(temporaryDir, "owner.json"), owner);
    try {
      await fs.rename(temporaryDir, dir);
      return true;
    } catch (error) {
      if (
        filesystemErrorCode(error) === "EEXIST" ||
        filesystemErrorCode(error) === "ENOTEMPTY"
      ) {
        return false;
      }
      throw error;
    }
  } finally {
    await fs.rm(temporaryDir, { recursive: true, force: true });
  }
}

/** @param {string} lockDir @param {string} label */
async function quarantineInvalidLock(lockDir, label) {
  const quarantineDir = `${lockDir}.${label}-${process.pid}-${crypto.randomBytes(6).toString("hex")}`;
  try {
    await fs.rename(lockDir, quarantineDir);
  } catch (error) {
    if (filesystemErrorCode(error) === "ENOENT") return false;
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

/** @param {string} lockDir @param {string} expectedToken @param {string} label */
async function quarantineOwnedLock(lockDir, expectedToken, label) {
  const quarantineDir = `${lockDir}.${label}-${process.pid}-${crypto.randomBytes(6).toString("hex")}`;
  try {
    await fs.rename(lockDir, quarantineDir);
  } catch (error) {
    if (filesystemErrorCode(error) === "ENOENT") return false;
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

/** @param {InstallLock} lock */
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

/** @param {InstallLock[]} locks @returns {Promise<InstallLockReleaseError[]>} */
async function releaseInstallLocks(locks) {
  /** @type {InstallLockReleaseError[]} */
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

/**
 * @param {unknown} primaryError
 * @param {InstallLockReleaseError[]} releaseErrors
 */
function lockReleaseFailureError(primaryError, releaseErrors) {
  const details = releaseErrors
    .map(({ error, lock }) => `${lock.lockDir}: ${errorMessage(error)}`)
    .join("; ");
  if (primaryError) {
    return new Error(
      `${errorMessage(primaryError)} Install lock cleanup also failed: ${details}`,
      { cause: primaryError },
    );
  }
  return new Error(`Install lock cleanup failed: ${details}`, {
    cause: releaseErrors[0].error,
  });
}

/** @param {InstallLockOwner} owner @returns {Promise<InstallTransaction>} */
async function createInstallTransaction(owner) {
  const transactionDir = path.dirname(owner.journalPath);
  const transactionRoot =
    owner.transactionRoot ?? path.dirname(path.dirname(transactionDir));
  const transaction = {
    token: owner.token,
    transactionDir,
    journalPath: owner.journalPath,
    lockRoots: owner.lockRoots ?? [transactionRoot],
    records: [],
    recoveryConflicts: [],
    publicationTemps: new Set(),
    rollbackDeletedTargets: new Set(),
    rollbackTargetContents: new Map(),
    status: "active",
  };
  await ensureDir(transactionDir);
  await persistInstallJournal(transaction);
  return transaction;
}

/**
 * @param {unknown} record
 * @param {string} token
 * @param {number} recordIndex
 * @param {string[]} lockRoots
 * @returns {Promise<boolean>}
 */
async function isOwnedMutationRecord(record, token, recordIndex, lockRoots) {
  const candidate = /** @type {Partial<InstallMutationRecord>} */ (record);
  const target = candidate.target;
  if (
    !record ||
    typeof record !== "object" ||
    typeof target !== "string" ||
    !path.isAbsolute(target) ||
    path.resolve(target) !== target
  ) {
    return false;
  }
  const canonicalTarget = await canonicalizeTransactionTarget(target);
  if (!isTargetCoveredByLock(canonicalTarget, lockRoots)) return false;
  if (candidate.operation === "create") return candidate.backup === null;
  if (
    candidate.operation !== "backup-rename" ||
    typeof candidate.backup !== "string" ||
    !path.isAbsolute(candidate.backup)
  ) {
    return false;
  }
  const expectedBackup = path.join(
    path.dirname(canonicalTarget),
    INSTALL_BACKUPS_DIR,
    token,
    String(recordIndex),
  );
  const canonicalBackup = await canonicalizeTransactionTarget(candidate.backup);
  return canonicalBackup === expectedBackup;
}

/** @param {InstallTransaction} transaction */
async function persistInstallJournal(transaction) {
  await writeAtomicJson(transaction.journalPath, {
    version: 1,
    token: transaction.token,
    publicationTemps: [...transaction.publicationTemps],
    records: transaction.records,
    rollbackTargetExpectations: [...transaction.rollbackTargetContents].map(
      ([target, expectation]) => ({
        target,
        contentBase64:
          expectation.content === null
            ? null
            : expectation.content.toString("base64"),
        metadata: expectation.metadata,
      }),
    ),
    status: transaction.status,
  });
}

/**
 * @param {unknown} value
 * @param {string} token
 * @param {InstallMutationRecord[]} records
 * @returns {Promise<Set<string> | null>}
 */
async function parsePublicationTemps(value, token, records) {
  if (value === undefined) return new Set();
  if (!Array.isArray(value)) return null;
  const allowed = new Set(
    records.flatMap((record, recordIndex) => [
      publicationTempPathForRecord(record, token, recordIndex, "previous"),
      publicationTempPathForRecord(record, token, recordIndex, "staged"),
    ]),
  );
  /** @type {Set<string>} */
  const publicationTemps = new Set();
  for (const entry of value) {
    if (
      typeof entry !== "string" ||
      !allowed.has(entry) ||
      publicationTemps.has(entry) ||
      (await canonicalizeTransactionTarget(entry)) !== entry
    ) {
      return null;
    }
    publicationTemps.add(entry);
  }
  return publicationTemps;
}

/**
 * @param {unknown} value
 * @param {string[]} lockRoots
 * @param {InstallMutationRecord[]} records
 * @returns {Promise<Map<string, RollbackTargetExpectation> | null>}
 */
async function parseRollbackTargetExpectations(value, lockRoots, records) {
  if (value === undefined) return new Map();
  if (!Array.isArray(value)) return null;
  /** @type {Map<string, RollbackTargetExpectation>} */
  const expectations = new Map();
  for (const entry of value) {
    if (!entry || typeof entry !== "object") return null;
    const candidate =
      /** @type {{ contentBase64?: unknown, metadata?: unknown, target?: unknown }} */ (
        entry
      );
    if (
      typeof candidate.target !== "string" ||
      !path.isAbsolute(candidate.target) ||
      path.resolve(candidate.target) !== candidate.target ||
      expectations.has(candidate.target)
    ) {
      return null;
    }
    const canonicalTarget = await canonicalizeTransactionTarget(
      candidate.target,
    );
    if (
      canonicalTarget !== candidate.target ||
      !isTargetCoveredByLock(canonicalTarget, lockRoots) ||
      !records.some(
        (record) =>
          canonicalTarget === record.target ||
          canonicalTarget.startsWith(record.target + path.sep),
      )
    ) {
      return null;
    }
    let content = null;
    if (candidate.contentBase64 !== null) {
      if (typeof candidate.contentBase64 !== "string") return null;
      content = Buffer.from(candidate.contentBase64, "base64");
      if (content.toString("base64") !== candidate.contentBase64) return null;
    }
    const metadata = parseRollbackTargetMetadata(candidate.metadata);
    if (candidate.metadata !== null && metadata === null) return null;
    expectations.set(canonicalTarget, { content, metadata });
  }
  return expectations;
}

/** @param {unknown} value @returns {RollbackTargetMetadata | null} */
function parseRollbackTargetMetadata(value) {
  if (value === null) return null;
  if (!value || typeof value !== "object") return null;
  const candidate = /** @type {Partial<RollbackTargetMetadata>} */ (value);
  for (const key of [
    "ctimeMs",
    "device",
    "gid",
    "inode",
    "links",
    "mode",
    "uid",
  ]) {
    const field = candidate[/** @type {keyof RollbackTargetMetadata} */ (key)];
    if (typeof field !== "number" || !Number.isFinite(field) || field < 0) {
      return null;
    }
  }
  return /** @type {RollbackTargetMetadata} */ (candidate);
}

/**
 * @param {string} targetPath
 * @param {{ expectedTargetContent?: ExpectedTargetContent, expectedTargetEntries?: ExpectedTargetEntries, expectedTargetIdentity?: ExpectedTargetIdentity, label?: string, preserveExisting?: boolean }} [options]
 */
async function prepareTransactionMutation(
  targetPath,
  {
    expectedTargetContent,
    expectedTargetEntries,
    expectedTargetIdentity,
    label = "install target",
    preserveExisting = false,
  } = {},
) {
  const transaction = transactionStorage.getStore();
  if (!transaction) return false;

  const resolvedTarget = await canonicalizeTransactionTarget(targetPath);
  if (!isTargetCoveredByLock(resolvedTarget, transaction.lockRoots)) {
    throw new Error(
      `Cannot mutate ${resolvedTarget} because it resolves outside the acquired install locks.`,
    );
  }
  const coveringRecord = transaction.records.find(
    (record) =>
      resolvedTarget === record.target ||
      resolvedTarget.startsWith(record.target + path.sep),
  );

  let stats = null;
  try {
    stats = await fs.lstat(resolvedTarget);
  } catch (error) {
    if (filesystemErrorCode(error) !== "ENOENT") throw error;
  }
  try {
    assertExpectedTargetType(
      resolvedTarget,
      stats,
      expectedTargetContent,
      label,
    );
    assertExpectedTargetIdentity(
      resolvedTarget,
      stats,
      expectedTargetIdentity,
      label,
    );
    if (
      expectedTargetContent !== undefined &&
      expectedTargetContent !== null &&
      !(await fileContentEquals(resolvedTarget, expectedTargetContent))
    ) {
      throw new Error(
        `Cannot install ${label} because ${resolvedTarget} changed during installation.`,
      );
    }
    await assertExpectedTargetEntries(
      resolvedTarget,
      expectedTargetEntries,
      label,
    );
  } catch (error) {
    if (coveringRecord && expectedTargetContent !== undefined) {
      transaction.rollbackTargetContents.set(resolvedTarget, {
        content:
          expectedTargetContent === null
            ? null
            : expectedContentBuffer(expectedTargetContent),
        metadata: null,
      });
    }
    if (coveringRecord && expectedTargetEntries) {
      recordExpectedTreeRollbackTargets(
        transaction,
        resolvedTarget,
        expectedTargetEntries,
      );
    }
    throw error;
  }
  if (coveringRecord) {
    return {
      expectedTargetContent,
      expectedTargetEntries,
      expectedTargetIdentity,
      record: coveringRecord,
      recordIndex: transaction.records.indexOf(coveringRecord),
      target: resolvedTarget,
      targetExists: stats !== null,
    };
  }
  if (
    transaction.records.some((record) =>
      record.target.startsWith(resolvedTarget + path.sep),
    )
  ) {
    throw new Error(
      `Install transaction cannot back up parent after child: ${resolvedTarget}`,
    );
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

  if (!stats) {
    try {
      const currentResolvedTarget =
        await canonicalizeTransactionTarget(targetPath);
      if (
        currentResolvedTarget !== resolvedTarget ||
        !isTargetCoveredByLock(currentResolvedTarget, transaction.lockRoots)
      ) {
        throw new Error(
          `Cannot install ${label} because ${resolvedTarget} changed during installation.`,
        );
      }
      const currentStats = await lstatIfExists(resolvedTarget);
      assertExpectedTargetType(
        resolvedTarget,
        currentStats,
        expectedTargetContent,
        label,
      );
      assertExpectedTargetIdentity(
        resolvedTarget,
        currentStats,
        expectedTargetIdentity,
        label,
      );
      await assertExpectedTargetEntries(
        resolvedTarget,
        expectedTargetEntries,
        label,
      );
    } catch (error) {
      if (transaction.records.at(-1) !== record) {
        throw new Error(
          `Cannot discard unapplied install mutation for ${resolvedTarget}.`,
          { cause: error },
        );
      }
      transaction.records.pop();
      await persistInstallJournal(transaction);
      throw error;
    }
    return {
      expectedTargetContent,
      expectedTargetEntries,
      expectedTargetIdentity,
      record,
      recordIndex: transaction.records.length - 1,
      target: resolvedTarget,
      targetExists: false,
    };
  }
  const backupPath = record.backup;
  if (!backupPath)
    throw new Error(`Missing transaction backup for ${resolvedTarget}.`);
  await ensureDir(path.dirname(backupPath));
  const currentStats = await lstatIfExists(resolvedTarget);
  assertExpectedTargetIdentity(
    resolvedTarget,
    currentStats,
    expectedTargetIdentity,
    label,
  );
  if (
    expectedTargetContent !== undefined &&
    expectedTargetContent !== null &&
    !(await fileContentEquals(resolvedTarget, expectedTargetContent))
  ) {
    throw new Error(
      `Cannot install ${label} because ${resolvedTarget} changed during installation.`,
    );
  }
  await assertExpectedTargetEntries(
    resolvedTarget,
    expectedTargetEntries,
    label,
  );
  await fs.rename(resolvedTarget, backupPath);
  const backupStats = await lstatIfExists(backupPath);
  assertExpectedTargetIdentity(
    backupPath,
    backupStats,
    expectedTargetIdentity,
    label,
    { ignoreCtime: true },
  );
  if (
    expectedTargetContent !== undefined &&
    expectedTargetContent !== null &&
    !(await fileContentEquals(backupPath, expectedTargetContent))
  ) {
    throw new Error(
      `Cannot install ${label} because ${resolvedTarget} changed during installation.`,
    );
  }
  await assertExpectedTargetEntries(backupPath, expectedTargetEntries, label);
  await persistInstallJournal(transaction);
  if (preserveExisting) {
    await fs.cp(backupPath, resolvedTarget, {
      recursive: stats.isDirectory(),
      preserveTimestamps: true,
      dereference: false,
    });
  }
  return {
    expectedTargetContent,
    expectedTargetEntries,
    expectedTargetIdentity,
    record,
    recordIndex: transaction.records.length - 1,
    target: resolvedTarget,
    targetExists: false,
  };
}

/**
 * @param {InstallTransaction} transaction
 * @param {{ preserveCurrentTargets?: boolean }} [options]
 * @returns {Promise<InstallRollbackError[]>}
 */
async function rollbackInstallTransaction(
  transaction,
  { preserveCurrentTargets = false } = {},
) {
  /** @type {InstallRollbackError[]} */
  const errors = [];
  const indexedRecords = transaction.records
    .map((record, index) => ({ index, record }))
    .reverse();
  for (const { index, record } of indexedRecords) {
    try {
      await preserveChangedRollbackTargets(transaction, record);
      const backupPath = record.backup;
      const backupExists =
        backupPath !== null && (await rawPathExists(backupPath));
      if (backupExists) {
        if (preserveCurrentTargets) {
          await preserveRecoveryTarget(transaction, record, index);
        } else {
          await fs.rm(record.target, { recursive: true, force: true });
        }
        await ensureDir(path.dirname(record.target));
        await fs.rename(backupPath, record.target);
      } else if (record.operation === "create") {
        if (preserveCurrentTargets) {
          await preserveRecoveryTarget(transaction, record, index);
        } else {
          await fs.rm(record.target, { recursive: true, force: true });
        }
      }
      await reapplyConcurrentRollbackDeletions(transaction, record);
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

/**
 * @param {InstallTransaction} transaction
 * @param {InstallMutationRecord} record
 */
async function preserveChangedRollbackTargets(transaction, record) {
  for (const [target, expectation] of transaction.rollbackTargetContents) {
    if (
      target !== record.target &&
      !target.startsWith(record.target + path.sep)
    ) {
      continue;
    }
    transaction.rollbackTargetContents.delete(target);

    let stats;
    try {
      stats = await fs.lstat(target);
    } catch (error) {
      if (filesystemErrorCode(error) === "ENOENT") {
        if (expectation.content !== null) {
          transaction.rollbackDeletedTargets.add(target);
        }
        continue;
      }
      throw error;
    }
    if (expectation.content !== null && stats.isFile()) {
      const currentContent = await fs.readFile(target);
      if (
        currentContent.equals(expectation.content) &&
        (!expectation.metadata ||
          targetMetadataMatches(stats, expectation.metadata))
      ) {
        continue;
      }
    }
    await preserveRecoveryTarget(
      transaction,
      {
        operation: "rollback-conflict",
        target,
        backup: null,
      },
      `edited-${transaction.recoveryConflicts.length}`,
      record.target,
    );
  }
}

/**
 * @param {InstallTransaction} transaction
 * @param {InstallMutationRecord} record
 */
async function reapplyConcurrentRollbackDeletions(transaction, record) {
  for (const target of transaction.rollbackDeletedTargets) {
    if (
      target !== record.target &&
      !target.startsWith(record.target + path.sep)
    ) {
      continue;
    }
    await fs.rm(target, { recursive: true, force: true });
    transaction.rollbackDeletedTargets.delete(target);
  }
}

/**
 * @param {InstallTransaction} transaction
 * @param {InstallMutationRecord} record
 * @param {number | string} recordIndex
 * @param {string} [rollbackBoundary]
 */
async function preserveRecoveryTarget(
  transaction,
  record,
  recordIndex,
  rollbackBoundary = record.target,
) {
  if (!(await rawPathExists(record.target))) return;
  const conflictRoot = path.join(
    path.dirname(rollbackBoundary),
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
      if (filesystemErrorCode(error) === "ENOENT") return;
      if (
        filesystemErrorCode(error) === "EEXIST" ||
        filesystemErrorCode(error) === "ENOTEMPTY"
      )
        continue;
      throw error;
    }
  }
}

/** @param {InstallTransaction} transaction */
function reportRecoveryConflicts(transaction) {
  for (const conflict of transaction.recoveryConflicts) {
    console.warn(
      `Preserved interrupted install output ${conflict.target} at ${conflict.preservedAt}.`,
    );
  }
}

/** @param {InstallTransaction} transaction */
async function markInstallTransactionCommitted(transaction) {
  transaction.status = "committed";
  await persistInstallJournal(transaction);
}

/** @param {InstallTransaction} transaction */
async function removeTransactionArtifacts(transaction) {
  const backupRoots = new Set(
    [
      ...transaction.records
        .map((record) => record.backup)
        .filter((backup) => backup !== null),
      ...transaction.publicationTemps,
    ].map((artifact) => path.dirname(artifact)),
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

/**
 * @param {unknown} originalError
 * @param {InstallRollbackError[]} rollbackErrors
 * @param {InstallTransaction} transaction
 */
function rollbackFailureError(originalError, rollbackErrors, transaction) {
  const details = rollbackErrors
    .map(
      ({ error, record }) =>
        `${record.operation} ${record.target}: ${errorMessage(error)}`,
    )
    .join("; ");
  return new Error(
    `${errorMessage(originalError)} Rollback failed for install transaction ${transaction.token}: ${details}`,
    { cause: originalError },
  );
}

/** @param {string} file @param {unknown} value */
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

/** @param {string} file */
async function rawPathExists(file) {
  try {
    await fs.lstat(file);
    return true;
  } catch (error) {
    if (filesystemErrorCode(error) === "ENOENT") return false;
    throw error;
  }
}

/** @param {string} directory */
async function canonicalizeDirectoryPath(directory) {
  let candidate = path.resolve(directory);
  const missingEntries = [];
  while (true) {
    try {
      const canonical = await fs.realpath(candidate);
      return path.join(canonical, ...missingEntries.reverse());
    } catch (error) {
      if (filesystemErrorCode(error) !== "ENOENT") throw error;
      const parent = path.dirname(candidate);
      if (parent === candidate) throw error;
      missingEntries.push(path.basename(candidate));
      candidate = parent;
    }
  }
}

/** @param {string} targetPath */
async function canonicalizeTransactionTarget(targetPath) {
  const resolvedTarget = path.resolve(targetPath);
  const canonicalParent = await canonicalizeDirectoryPath(
    path.dirname(resolvedTarget),
  );
  return path.join(canonicalParent, path.basename(resolvedTarget));
}

/** @param {string} target @param {string[]} lockRoots */
function isTargetCoveredByLock(target, lockRoots) {
  return lockRoots.some((lockRoot) =>
    target.startsWith(path.resolve(lockRoot) + path.sep),
  );
}

/**
 * @param {string} target
 * @param {import("fs").Stats | null} stats
 * @param {ExpectedTargetContent | undefined} expectedTargetContent
 * @param {string} label
 */
function assertExpectedTargetType(target, stats, expectedTargetContent, label) {
  if (expectedTargetContent === null && stats) {
    throw new Error(
      `Cannot install ${label} because ${target} was created during installation.`,
    );
  }
  if (
    expectedTargetContent !== undefined &&
    expectedTargetContent !== null &&
    (!stats || !stats.isFile())
  ) {
    throw new Error(
      `Cannot install ${label} because ${target} changed during installation.`,
    );
  }
}

/**
 * @param {string} target
 * @param {import("fs").Stats | null} stats
 * @param {ExpectedTargetIdentity | undefined} expectedIdentity
 * @param {string} label
 * @param {{ ignoreCtime?: boolean }} [options]
 */
function assertExpectedTargetIdentity(
  target,
  stats,
  expectedIdentity,
  label,
  { ignoreCtime = false } = {},
) {
  if (!expectedIdentity) return;
  if (
    !stats?.isFile() ||
    stats.dev !== expectedIdentity.device ||
    stats.ino !== expectedIdentity.inode ||
    stats.nlink !== expectedIdentity.links ||
    (expectedIdentity.mode !== undefined &&
      stats.mode !== expectedIdentity.mode) ||
    (expectedIdentity.uid !== undefined &&
      stats.uid !== expectedIdentity.uid) ||
    (expectedIdentity.gid !== undefined &&
      stats.gid !== expectedIdentity.gid) ||
    (!ignoreCtime &&
      expectedIdentity.ctimeMs !== undefined &&
      stats.ctimeMs !== expectedIdentity.ctimeMs)
  ) {
    throw new Error(
      `Cannot install ${label} because ${target} changed during installation.`,
    );
  }
}

/** @param {import("fs").Stats} stats @returns {RollbackTargetMetadata} */
function targetMetadata(stats) {
  return {
    ctimeMs: stats.ctimeMs,
    device: stats.dev,
    gid: stats.gid,
    inode: stats.ino,
    links: stats.nlink,
    mode: stats.mode,
    uid: stats.uid,
  };
}

/**
 * @param {import("fs").Stats} stats
 * @param {RollbackTargetMetadata} expected
 */
function targetMetadataMatches(stats, expected) {
  return (
    stats.ctimeMs === expected.ctimeMs &&
    stats.dev === expected.device &&
    stats.gid === expected.gid &&
    stats.ino === expected.inode &&
    stats.nlink === expected.links &&
    stats.mode === expected.mode &&
    stats.uid === expected.uid
  );
}

/**
 * @param {string} targetRoot
 * @param {ExpectedTargetEntries | undefined} expectedEntries
 * @param {string} label
 */
async function assertExpectedTargetEntries(targetRoot, expectedEntries, label) {
  if (!expectedEntries) return;
  for (const [relativePath, expected] of expectedEntries) {
    const target = relativePath
      ? path.join(targetRoot, relativePath)
      : targetRoot;
    const stats = await lstatIfExists(target);
    if (expected.kind === "missing") {
      if (!stats) continue;
    } else if (expected.kind === "directory") {
      if (stats?.isDirectory()) continue;
    } else if (
      stats?.isFile() &&
      (await fileContentEquals(target, expected.content))
    ) {
      continue;
    }
    throw new Error(
      `Cannot install ${label} because ${target} changed during installation.`,
    );
  }
}

/**
 * @param {InstallTransaction} transaction
 * @param {string} targetRoot
 * @param {ExpectedTargetEntries} expectedEntries
 */
function recordExpectedTreeRollbackTargets(
  transaction,
  targetRoot,
  expectedEntries,
) {
  for (const [relativePath, expected] of expectedEntries) {
    if (expected.kind === "directory") continue;
    const target = relativePath
      ? path.join(targetRoot, relativePath)
      : targetRoot;
    transaction.rollbackTargetContents.set(target, {
      content: expected.kind === "file" ? expected.content : null,
      metadata: null,
    });
  }
}

/** @param {number} milliseconds */
function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

/** @param {unknown} error */
function errorMessage(error) {
  return error instanceof Error ? error.message : String(error);
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
 * @returns {Promise<ExpectedTargetEntries | undefined>}
 */
async function preflightStagedDirInstall(
  stagedDir,
  targetDir,
  {
    currentManagedFiles,
    label = "directory",
    previousManagedFiles,
    previousManagedRoots = [],
    replace = false,
  } = {},
) {
  if (!(await pathExists(stagedDir)) || replace) return undefined;
  /** @type {ExpectedTargetEntries} */
  const expectedTargetEntries = new Map();
  if (!(await pathExists(targetDir))) {
    expectedTargetEntries.set("", { kind: "missing" });
    return expectedTargetEntries;
  }
  const targetStats = await fs.lstat(targetDir);
  if (!targetStats.isDirectory()) {
    throw new Error(
      `Cannot install ${label} because ${targetDir} is not a directory.`,
    );
  }
  expectedTargetEntries.set("", { kind: "directory" });

  await preflightStagedDirMerge(stagedDir, targetDir, "", {
    expectedTargetEntries,
    label,
    previousManagedFiles: new Set(
      sanitizeManagedFileList(previousManagedFiles),
    ),
    previousManagedRoots,
    staleManagedFiles: staleManagedFileSet(
      previousManagedFiles,
      currentManagedFiles,
    ),
  });
  return expectedTargetEntries;
}

/**
 * @param {string} stagedFile
 * @param {string} targetFile
 * @param {StagedFileInstallOptions} [options]
 * @returns {Promise<Buffer | null | undefined>}
 */
async function preflightStagedFileInstall(
  stagedFile,
  targetFile,
  {
    expectedTargetContent,
    label = "file",
    previousManagedFiles = [],
    replace = false,
  } = {},
) {
  if (!(await pathExists(stagedFile))) return undefined;
  if (!(await pathExists(targetFile))) return null;
  const targetStats = await fs.lstat(targetFile);
  if (targetStats.isDirectory()) {
    throw new Error(
      `Cannot install ${label} because ${targetFile} is a directory.`,
    );
  }
  if (!targetStats.isFile()) {
    throw new Error(
      `Cannot install ${label} because ${targetFile} is not a regular file.`,
    );
  }
  const targetContent = await fs.readFile(targetFile);
  if (
    replace ||
    (expectedTargetContent !== undefined &&
      expectedTargetContent !== null &&
      targetContent.equals(expectedContentBuffer(expectedTargetContent))) ||
    (await regularFilesAreIdentical(stagedFile, targetFile)) ||
    (await matchesAnyManagedFile(targetFile, previousManagedFiles))
  ) {
    return targetContent;
  }
  if (expectedTargetContent !== undefined) {
    throw new Error(
      `Cannot install ${label} because ${targetFile} changed during installation.`,
    );
  }
  throw new Error(
    `Cannot install ${label} because ${targetFile} is a non-identical unowned file.`,
  );
}

/**
 * @param {string} stagedDir
 * @param {string} targetDir
 * @param {InstallStagedDirOptions} [options]
 */
async function installStagedDir(
  stagedDir,
  targetDir,
  { expectedTargetEntries, label = "directory", replace = false } = {},
) {
  if (!(await pathExists(stagedDir))) return;
  const transactional = await prepareTransactionMutation(targetDir, {
    expectedTargetEntries,
    label,
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
 * @param {{ expectedTargetEntries: ExpectedTargetEntries, label: string, previousManagedFiles: Set<string>, previousManagedRoots: string[], staleManagedFiles: Set<string> }} options
 */
async function preflightStagedDirMerge(
  stagedDir,
  targetDir,
  prefix,
  {
    expectedTargetEntries,
    label,
    previousManagedFiles,
    previousManagedRoots,
    staleManagedFiles,
  },
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
      if (!targetStats) {
        expectedTargetEntries.set(relativePath, { kind: "missing" });
        continue;
      }
      if (!targetStats.isDirectory()) {
        throw new Error(
          `Cannot install ${label} because ${targetPath} conflicts with staged directory ${relativePath}.`,
        );
      }
      expectedTargetEntries.set(relativePath, { kind: "directory" });
      await preflightStagedDirMerge(stagedPath, targetPath, relativePath, {
        expectedTargetEntries,
        label,
        previousManagedFiles,
        previousManagedRoots,
        staleManagedFiles,
      });
      continue;
    }

    if (!entry.isFile()) continue;
    if (!targetStats) {
      expectedTargetEntries.set(relativePath, { kind: "missing" });
      continue;
    }
    if (targetStats.isDirectory()) {
      const removableDirectory = await directoryRemovedByManagedPrune(
        targetPath,
        relativePath,
        staleManagedFiles,
      );
      if (removableDirectory) {
        expectedTargetEntries.set(relativePath, { kind: "missing" });
        continue;
      }
      throw new Error(
        `Cannot install ${label} because ${targetPath} conflicts with staged file ${relativePath}.`,
      );
    }
    const targetContent = targetStats.isFile()
      ? await fs.readFile(targetPath)
      : null;
    if (
      targetContent &&
      (previousManagedFiles.has(relativePath) ||
        (await fileContentEquals(stagedPath, targetContent)) ||
        (await contentMatchesAnyManagedFile(
          targetContent,
          previousManagedRoots.map((root) => path.join(root, relativePath)),
        )))
    ) {
      expectedTargetEntries.set(relativePath, {
        content: targetContent,
        kind: "file",
      });
      continue;
    }
    throw new Error(
      `Cannot install ${label} because ${targetPath} is a non-identical unowned file.`,
    );
  }
}

/** @param {Buffer} targetContent @param {string[]} managedFiles */
async function contentMatchesAnyManagedFile(targetContent, managedFiles) {
  for (const managedFile of managedFiles) {
    const stats = await lstatIfExists(managedFile);
    if (
      stats?.isFile() &&
      (await fileContentEquals(managedFile, targetContent))
    ) {
      return true;
    }
  }
  return false;
}

/** @param {string} targetFile @param {string[]} managedFiles */
async function matchesAnyManagedFile(targetFile, managedFiles) {
  for (const managedFile of managedFiles) {
    if (await regularFilesAreIdentical(targetFile, managedFile)) return true;
  }
  return false;
}

/** @param {string} leftFile @param {string} rightFile */
async function regularFilesAreIdentical(leftFile, rightFile) {
  const [leftStats, rightStats] = await Promise.all([
    lstatIfExists(leftFile),
    lstatIfExists(rightFile),
  ]);
  if (!leftStats?.isFile() || !rightStats?.isFile()) return false;
  const [left, right] = await Promise.all([
    fs.readFile(leftFile),
    fs.readFile(rightFile),
  ]);
  return left.equals(right);
}

/** @param {string} file @param {Exclude<ExpectedTargetContent, null>} expectedContent */
async function fileContentEquals(file, expectedContent) {
  const content = await fs.readFile(file);
  return content.equals(expectedContentBuffer(expectedContent));
}

/** @param {Exclude<ExpectedTargetContent, null>} expectedContent */
function expectedContentBuffer(expectedContent) {
  return Buffer.isBuffer(expectedContent)
    ? expectedContent
    : Buffer.from(expectedContent, "utf8");
}

/** @param {string} file */
async function lstatIfExists(file) {
  try {
    return await fs.lstat(file);
  } catch (error) {
    if (filesystemErrorCode(error) === "ENOENT") return null;
    throw error;
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

/**
 * @param {InstallMutationRecord} record
 * @param {string} token
 * @param {number} recordIndex
 * @param {"previous" | "staged"} kind
 */
function publicationTempPathForRecord(record, token, recordIndex, kind) {
  return path.join(
    path.dirname(record.target),
    INSTALL_BACKUPS_DIR,
    token,
    `publication-${recordIndex}-${kind}`,
  );
}

/**
 * @param {InstallTransaction} transaction
 * @param {PreparedTransactionMutation} mutation
 */
async function markPublicationCollision(transaction, mutation) {
  if (
    mutation.record.operation === "create" &&
    mutation.record.target === mutation.target
  ) {
    if (transaction.records.at(-1) !== mutation.record) {
      throw new Error(
        `Cannot discard unapplied install mutation for ${mutation.target}.`,
      );
    }
    transaction.records.pop();
    transaction.rollbackTargetContents.delete(mutation.target);
    await persistInstallJournal(transaction);
    return;
  }
  transaction.rollbackTargetContents.set(mutation.target, {
    content: null,
    metadata: null,
  });
  await persistInstallJournal(transaction);
}

/**
 * @param {unknown} error
 * @param {string} target
 */
async function isPublicationCollision(error, target) {
  return (
    filesystemErrorCode(error) === "EEXIST" ||
    (await lstatIfExists(target)) !== null
  );
}

/**
 * @param {InstallTransaction} transaction
 * @param {string} publicationTemp
 */
async function removePublicationTemp(transaction, publicationTemp) {
  await fs.rm(publicationTemp, { force: true });
  transaction.publicationTemps.delete(publicationTemp);
  await persistInstallJournal(transaction);
}

/**
 * Move a target already covered by an ancestor mutation out of the publication
 * path, then validate the moved inode. This closes the check-to-replace window
 * without adding a second rollback record beneath the ancestor.
 *
 * @param {InstallTransaction} transaction
 * @param {PreparedTransactionMutation} mutation
 * @param {string} label
 * @returns {Promise<string | null>}
 */
async function prepareCoveredPublicationTarget(transaction, mutation, label) {
  if (!mutation.targetExists || mutation.record.target === mutation.target) {
    return null;
  }
  const publicationTemp = publicationTempPathForRecord(
    mutation.record,
    transaction.token,
    mutation.recordIndex,
    "previous",
  );
  transaction.publicationTemps.add(publicationTemp);
  await persistInstallJournal(transaction);
  await fs.rm(publicationTemp, { force: true });
  await ensureDir(path.dirname(publicationTemp));
  await fs.rename(mutation.target, publicationTemp);

  try {
    const stats = await lstatIfExists(publicationTemp);
    assertExpectedTargetIdentity(
      publicationTemp,
      stats,
      mutation.expectedTargetIdentity,
      label,
      { ignoreCtime: true },
    );
    if (
      mutation.expectedTargetContent !== undefined &&
      mutation.expectedTargetContent !== null &&
      !(await fileContentEquals(
        publicationTemp,
        mutation.expectedTargetContent,
      ))
    ) {
      throw new Error(
        `Cannot install ${label} because ${mutation.target} changed during installation.`,
      );
    }
    await assertExpectedTargetEntries(
      publicationTemp,
      mutation.expectedTargetEntries,
      label,
    );
    return publicationTemp;
  } catch (error) {
    await fs.rename(publicationTemp, mutation.target);
    transaction.publicationTemps.delete(publicationTemp);
    if (mutation.expectedTargetContent !== undefined) {
      transaction.rollbackTargetContents.set(mutation.target, {
        content:
          mutation.expectedTargetContent === null
            ? null
            : expectedContentBuffer(mutation.expectedTargetContent),
        metadata: null,
      });
    }
    await persistInstallJournal(transaction);
    throw error;
  }
}

/**
 * @param {string} stagedFile
 * @param {PreparedTransactionMutation} mutation
 * @param {string} label
 */
async function publishStagedFileAcrossDevices(stagedFile, mutation, label) {
  const transaction = transactionStorage.getStore();
  if (!transaction) {
    await copyFilePreservingMetadata(stagedFile, mutation.target);
    await fs.rm(stagedFile, { force: true });
    return;
  }

  const publicationTemp = publicationTempPathForRecord(
    mutation.record,
    transaction.token,
    mutation.recordIndex,
    "staged",
  );
  transaction.publicationTemps.add(publicationTemp);
  await persistInstallJournal(transaction);
  await fs.rm(publicationTemp, { force: true });

  let published = false;
  try {
    await copyFilePreservingMetadata(stagedFile, publicationTemp);
    await fs.link(publicationTemp, mutation.target);
    published = true;
    await fs.rm(stagedFile, { force: true });
    await removePublicationTemp(transaction, publicationTemp);
  } catch (error) {
    const collision =
      !published && (await isPublicationCollision(error, mutation.target));
    await removePublicationTemp(transaction, publicationTemp);
    if (collision) {
      await markPublicationCollision(transaction, mutation);
      throw new Error(
        `Cannot install ${label} because ${mutation.target} changed during installation.`,
        { cause: error },
      );
    }
    throw error;
  }
}

/**
 * @param {string} stagedFile
 * @param {PreparedTransactionMutation} mutation
 * @param {string} label
 */
async function publishStagedFile(stagedFile, mutation, label) {
  const transaction = transactionStorage.getStore();
  const previousTarget = transaction
    ? await prepareCoveredPublicationTarget(transaction, mutation, label)
    : null;
  let published = false;
  try {
    await fs.link(stagedFile, mutation.target);
    published = true;
    await fs.rm(stagedFile, { force: true });
    if (transaction && previousTarget) {
      await removePublicationTemp(transaction, previousTarget);
    }
  } catch (error) {
    if (!published && filesystemErrorCode(error) === "EXDEV") {
      await publishStagedFileAcrossDevices(stagedFile, mutation, label);
      if (transaction && previousTarget) {
        await removePublicationTemp(transaction, previousTarget);
      }
      return;
    }
    if (!published && (await isPublicationCollision(error, mutation.target))) {
      if (transaction) {
        await markPublicationCollision(transaction, mutation);
      }
      throw new Error(
        `Cannot install ${label} because ${mutation.target} changed during installation.`,
        { cause: error },
      );
    }
    throw error;
  }
}

/**
 * @param {string} stagedFile
 * @param {string} targetFile
 * @param {InstallStagedFileOptions} [options]
 */
async function installStagedFile(
  stagedFile,
  targetFile,
  {
    expectedTargetContent,
    expectedTargetIdentity,
    label = "file",
    preserveTargetChangesOnRollback = false,
    replace = false,
  } = {},
) {
  if (!(await pathExists(stagedFile))) return;
  const installedContent = preserveTargetChangesOnRollback
    ? await fs.readFile(stagedFile)
    : null;
  const transactional = await prepareTransactionMutation(targetFile, {
    expectedTargetContent,
    expectedTargetIdentity,
    label,
  });
  if (replace && !transactional) {
    await fs.rm(targetFile, { force: true });
  }
  await ensureDir(path.dirname(targetFile));
  const mutation =
    transactional ||
    /** @type {PreparedTransactionMutation} */ ({
      record: {
        operation: "create",
        target: path.resolve(targetFile),
        backup: null,
      },
      recordIndex: 0,
      target: path.resolve(targetFile),
      targetExists: false,
    });
  await publishStagedFile(stagedFile, mutation, label);
  if (installedContent !== null) {
    const transaction = transactionStorage.getStore();
    if (transaction) {
      transaction.rollbackTargetContents.set(mutation.target, {
        content: installedContent,
        metadata: targetMetadata(await fs.lstat(targetFile)),
      });
      await persistInstallJournal(transaction);
    }
  }
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
