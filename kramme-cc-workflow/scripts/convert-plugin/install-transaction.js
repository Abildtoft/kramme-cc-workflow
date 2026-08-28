"use strict";

// Owns the atomic install transaction lifecycle and recovery state.
const { AsyncLocalStorage } = require("async_hooks");
const crypto = require("crypto");
const { constants: fsConstants } = require("fs");
const fs = require("fs/promises");
const path = require("path");
const {
  copyFilePreservingMetadata,
  ensureDir,
  expectedContentBuffer,
  fileContentEquals,
  filesystemErrorCode,
  isJsonObject,
  lstatIfExists,
  pathExists,
} = require("./filesystem");

const INSTALL_LOCK_DIR = ".kramme-install-lock";
const INSTALL_RECOVERY_CLAIMS_DIR = ".kramme-install-recovery-claims";
const INSTALL_RECOVERY_CONFLICTS_DIR = ".kramme-install-recovery-conflicts";
const INSTALL_TRANSACTIONS_DIR = ".kramme-install-transactions";
const INSTALL_BACKUPS_DIR = ".kramme-install-backups";
const LOCK_POLL_INTERVAL_MS = 20;
const MAX_LOCK_POLL_INTERVAL_MS = 250;
const DEFAULT_LOCK_TIMEOUT_MS = 30_000;
const TRANSACTION_INSPECTION_ENTRY_LIMIT = 50;
const TRANSACTION_METADATA_BYTE_LIMIT = 64 * 1024;
const TRANSACTION_TOKEN_PATTERN = /^[A-Za-z0-9-]+$/;
const MAX_OWNER_CLOCK_SKEW_MS = 60_000;
/** @type {AsyncLocalStorage<InstallTransaction>} */
const transactionStorage = new AsyncLocalStorage();

/**
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
 * @typedef {{ expectedTargetContent?: ExpectedTargetContent, expectedTargetEntries?: ExpectedTargetEntries, expectedTargetIdentity?: ExpectedTargetIdentity }} TargetExpectations
 * @typedef {TargetExpectations & { record: InstallMutationRecord, recordIndex: number, target: string, targetExists: boolean }} PreparedTransactionMutation
 * @typedef {{ error: unknown, lock: InstallLock }} InstallLockReleaseError
 * @typedef {{ error: unknown, record: InstallMutationRecord }} InstallRollbackError
 * @typedef {"active" | "committed" | "disappeared" | "malformed" | "present" | "stale" | "suspicious" | "unreadable" | "unsupported"} ArtifactEntryStatus
 * @typedef {"absent" | "active" | "malformed" | "present" | "stale" | "suspicious" | "unreadable" | "unsupported"} DiagnosticStatus
 * @typedef {{ status: "present", value: unknown } | { status: "disappeared" | "malformed" | "unreadable" | "unsupported" }} BoundedJsonResult
 * @typedef {{ entry_count: number, inspected_count: number, status: DiagnosticStatus, status_counts: Partial<Record<ArtifactEntryStatus, number>>, truncated: boolean }} ArtifactCollectionSummary
 * @typedef {{ root: string, status: DiagnosticStatus, owner?: InstallLockOwner }} DiagnosticLockInspection
 * @typedef {{ publicationTemps: Set<string>, records: InstallMutationRecord[], rollbackTargetContents: Map<string, RollbackTargetExpectation>, status: "active" | "committed" }} ParsedInstallJournal
 * @typedef {{ advisory: true, backups: ArtifactCollectionSummary, entry_limit: number, journals: ArtifactCollectionSummary, lock: { status: DiagnosticStatus }, metadata_byte_limit: number, recovery_claims: ArtifactCollectionSummary, recovery_conflicts: ArtifactCollectionSummary }} TransactionHealthSummary
 */

/**
 * Inspect private transaction artifacts without acquiring locks or changing the
 * filesystem. Counts and accepted metadata payloads are bounded, and the result
 * intentionally omits owners, tokens, paths, records, and artifact contents.
 *
 * @param {string} root
 * @param {{ lockRoots?: string[] }} [options]
 * @returns {Promise<TransactionHealthSummary>}
 */
async function inspectInstallTransactions(root, options = {}) {
  const resolvedRoot = await canonicalizeDiagnosticRoot(root);
  const lockInspections = await inspectAllInstallLocks(
    resolvedRoot,
    options.lockRoots ?? [],
  );
  /** @type {Map<string, ArtifactEntryStatus>} */
  const journalStatuses = new Map();
  /** @type {Set<string>} */
  const artifactRoots = new Set();
  let artifactRootsTruncated = false;
  /** @param {string} artifactRoot */
  const addArtifactRoot = (artifactRoot) => {
    if (artifactRoots.has(artifactRoot)) return;
    if (artifactRoots.size >= TRANSACTION_INSPECTION_ENTRY_LIMIT) {
      artifactRootsTruncated = true;
      return;
    }
    artifactRoots.add(artifactRoot);
  };
  for (const { root: lockRoot } of lockInspections) addArtifactRoot(lockRoot);
  const journals = await inspectArtifactCollection(
    [path.join(resolvedRoot, INSTALL_TRANSACTIONS_DIR)],
    async (entryPath, entryName) => {
      const inspected = await inspectJournalEntry(
        entryPath,
        entryName,
        diagnosticJournalLockRoots(
          lockInspections,
          resolvedRoot,
          entryName,
          path.join(entryPath, "journal.json"),
        ),
      );
      journalStatuses.set(entryName, inspected.status);
      for (const artifactRoot of inspected.artifactRoots) {
        addArtifactRoot(artifactRoot);
      }
      return inspected.status;
    },
    "journals",
  );
  const lock = summarizeInstallLocks(
    lockInspections,
    journalStatuses,
    resolvedRoot,
  );
  const recoveryClaims = await inspectArtifactCollection(
    [...artifactRoots].map((artifactRoot) =>
      path.join(artifactRoot, INSTALL_RECOVERY_CLAIMS_DIR),
    ),
    inspectRecoveryClaimEntry,
    "claims",
    artifactRootsTruncated,
  );
  const recoveryConflicts = await inspectArtifactCollection(
    [...artifactRoots].map((artifactRoot) =>
      path.join(artifactRoot, INSTALL_RECOVERY_CONFLICTS_DIR),
    ),
    inspectOpaqueArtifactEntry,
    "opaque",
    artifactRootsTruncated,
  );
  const backups = await inspectArtifactCollection(
    [...artifactRoots].map((artifactRoot) =>
      path.join(artifactRoot, INSTALL_BACKUPS_DIR),
    ),
    inspectOpaqueArtifactEntry,
    "opaque",
    artifactRootsTruncated,
  );

  return {
    advisory: true,
    backups,
    entry_limit: TRANSACTION_INSPECTION_ENTRY_LIMIT,
    journals,
    lock,
    metadata_byte_limit: TRANSACTION_METADATA_BYTE_LIMIT,
    recovery_claims: recoveryClaims,
    recovery_conflicts: recoveryConflicts,
  };
}

/** @param {string} root */
async function canonicalizeDiagnosticRoot(root) {
  try {
    return await canonicalizeDirectoryPath(root);
  } catch {
    return path.resolve(root);
  }
}

/** @param {string} transactionRoot @param {string[]} candidateRoots */
async function inspectAllInstallLocks(transactionRoot, candidateRoots) {
  const roots = [];
  const queued = new Set();
  let truncated = false;
  for (const candidate of [transactionRoot, ...candidateRoots]) {
    if (roots.length >= TRANSACTION_INSPECTION_ENTRY_LIMIT) {
      truncated = true;
      break;
    }
    const resolved = await canonicalizeDiagnosticRoot(candidate);
    if (!queued.has(resolved)) {
      queued.add(resolved);
      roots.push(resolved);
    }
  }

  /** @type {DiagnosticLockInspection[]} */
  const inspections = [];
  for (let index = 0; index < roots.length; index += 1) {
    if (index >= TRANSACTION_INSPECTION_ENTRY_LIMIT) break;
    const inspection = await inspectInstallLock(roots[index]);
    inspections.push(inspection);
    for (const ownerRoot of inspection.owner?.lockRoots ?? []) {
      if (roots.length >= TRANSACTION_INSPECTION_ENTRY_LIMIT) {
        truncated = true;
        break;
      }
      const resolved = await canonicalizeDiagnosticRoot(ownerRoot);
      if (!queued.has(resolved)) {
        queued.add(resolved);
        roots.push(resolved);
      }
    }
  }
  if (truncated || roots.length > inspections.length) {
    inspections.push({ root: transactionRoot, status: "suspicious" });
  }
  return inspections;
}

/** @param {string} lockRoot @returns {Promise<DiagnosticLockInspection>} */
async function inspectInstallLock(lockRoot) {
  const lockDir = path.join(lockRoot, INSTALL_LOCK_DIR);
  const directoryStatus = await inspectDirectoryType(lockDir);
  if (directoryStatus !== "present") {
    return { root: lockRoot, status: directoryStatus };
  }

  const metadata = await readBoundedJson(path.join(lockDir, "owner.json"));
  if (metadata.status === "disappeared") {
    return { root: lockRoot, status: "suspicious" };
  }
  if (metadata.status !== "present") {
    return { root: lockRoot, status: metadata.status };
  }
  if (!isDiagnosticLockOwner(metadata.value)) {
    return { root: lockRoot, status: "malformed" };
  }
  const owner = metadata.value;
  if (owner.createdAtMs > Date.now() + MAX_OWNER_CLOCK_SKEW_MS) {
    return { owner, root: lockRoot, status: "suspicious" };
  }
  try {
    return {
      owner,
      root: lockRoot,
      status: (await isProcessAlive(owner.pid)) ? "active" : "stale",
    };
  } catch {
    return { owner, root: lockRoot, status: "unreadable" };
  }
}

/** @param {unknown} value @returns {value is InstallLockOwner} */
function isDiagnosticLockOwner(value) {
  const owner = /** @type {Partial<InstallLockOwner>} */ (value);
  return (
    value !== null &&
    typeof value === "object" &&
    !Array.isArray(value) &&
    owner.version === 1 &&
    isSafeToken(owner.token) &&
    Number.isSafeInteger(owner.pid) &&
    Number(owner.pid) > 0 &&
    typeof owner.pluginName === "string" &&
    Number.isSafeInteger(owner.createdAtMs) &&
    Number(owner.createdAtMs) >= 0 &&
    typeof owner.journalPath === "string" &&
    path.isAbsolute(owner.journalPath) &&
    (owner.transactionRoot === undefined ||
      (typeof owner.transactionRoot === "string" &&
        path.isAbsolute(owner.transactionRoot))) &&
    (owner.expectedToken === undefined || isSafeToken(owner.expectedToken)) &&
    (owner.lockRoots === undefined ||
      (Array.isArray(owner.lockRoots) &&
        owner.lockRoots.every(
          (lockRoot) =>
            typeof lockRoot === "string" && path.isAbsolute(lockRoot),
        )))
  );
}

/**
 * @param {DiagnosticLockInspection[]} inspections
 * @param {Map<string, ArtifactEntryStatus>} journalStatuses
 * @param {string} transactionRoot
 * @returns {{ status: DiagnosticStatus }}
 */
function summarizeInstallLocks(inspections, journalStatuses, transactionRoot) {
  const statuses = inspections.map(({ status }) => status);
  if (statuses.includes("unreadable")) return { status: "unreadable" };
  if (statuses.includes("malformed")) return { status: "malformed" };
  if (statuses.includes("unsupported")) return { status: "unsupported" };
  if (statuses.includes("suspicious")) return { status: "suspicious" };

  const owned = inspections.filter(
    (inspection) => inspection.owner && inspection.status !== "absent",
  );
  if (
    owned.some(
      (inspection) =>
        !diagnosticLockOwnerIsCorrelated(
          /** @type {InstallLockOwner} */ (inspection.owner),
          inspection.root,
          inspections,
          journalStatuses,
          transactionRoot,
        ),
    )
  ) {
    return { status: "suspicious" };
  }
  if (statuses.includes("active") && statuses.includes("stale")) {
    return { status: "suspicious" };
  }
  if (statuses.includes("active")) return { status: "active" };
  if (statuses.includes("stale")) return { status: "stale" };
  return { status: "absent" };
}

/**
 * @param {InstallLockOwner} owner
 * @param {string} inspectedRoot
 * @param {DiagnosticLockInspection[]} inspections
 * @param {Map<string, ArtifactEntryStatus>} journalStatuses
 * @param {string} transactionRoot
 */
function diagnosticLockOwnerIsCorrelated(
  owner,
  inspectedRoot,
  inspections,
  journalStatuses,
  transactionRoot,
) {
  const expectedJournalPath = path.join(
    transactionRoot,
    INSTALL_TRANSACTIONS_DIR,
    owner.token,
    "journal.json",
  );
  if (
    !diagnosticOwnerLockSetMatches(
      owner,
      inspectedRoot,
      inspections,
      transactionRoot,
      expectedJournalPath,
    ) ||
    !["active", "committed"].includes(journalStatuses.get(owner.token) ?? "")
  ) {
    return false;
  }
  return true;
}

/**
 * @param {DiagnosticLockInspection[]} inspections
 * @param {string} transactionRoot
 * @param {string} token
 * @param {string} journalPath
 * @returns {string[] | undefined}
 */
function diagnosticJournalLockRoots(
  inspections,
  transactionRoot,
  token,
  journalPath,
) {
  const candidates = inspections.filter(
    (inspection) => inspection.owner?.token === token,
  );
  if (candidates.length === 0) return undefined;
  for (const candidate of candidates) {
    if (
      !diagnosticOwnerLockSetMatches(
        /** @type {InstallLockOwner} */ (candidate.owner),
        candidate.root,
        inspections,
        transactionRoot,
        journalPath,
      )
    ) {
      return undefined;
    }
  }
  const owner = /** @type {InstallLockOwner} */ (candidates[0].owner);
  return owner.lockRoots ?? [transactionRoot];
}

/**
 * @param {InstallLockOwner} owner
 * @param {string} inspectedRoot
 * @param {DiagnosticLockInspection[]} inspections
 * @param {string} transactionRoot
 * @param {string} journalPath
 */
function diagnosticOwnerLockSetMatches(
  owner,
  inspectedRoot,
  inspections,
  transactionRoot,
  journalPath,
) {
  const ownerTransactionRoot = path.resolve(
    owner.transactionRoot ?? inspectedRoot,
  );
  const expectedLockRoots = new Set(
    (owner.lockRoots ?? [ownerTransactionRoot]).map((root) =>
      path.resolve(root),
    ),
  );
  if (
    ownerTransactionRoot !== transactionRoot ||
    path.resolve(owner.journalPath) !== journalPath ||
    !expectedLockRoots.has(transactionRoot) ||
    !expectedLockRoots.has(inspectedRoot)
  ) {
    return false;
  }
  return [...expectedLockRoots].every((lockRoot) =>
    inspections.some(
      (inspection) =>
        inspection.root === lockRoot &&
        inspection.owner !== undefined &&
        installLockOwnersMatch(owner, inspection.owner),
    ),
  );
}

/** @param {InstallLockOwner} left @param {InstallLockOwner} right */
function installLockOwnersMatch(left, right) {
  return (
    left.token === right.token &&
    path.resolve(left.transactionRoot ?? "") ===
      path.resolve(right.transactionRoot ?? "") &&
    path.resolve(left.journalPath) === path.resolve(right.journalPath) &&
    JSON.stringify(
      [...(left.lockRoots ?? [])].map((root) => path.resolve(root)).sort(),
    ) ===
      JSON.stringify(
        [...(right.lockRoots ?? [])].map((root) => path.resolve(root)).sort(),
      )
  );
}

/**
 * @param {string[]} collectionRoots
 * @param {(entryPath: string, entryName: string) => Promise<ArtifactEntryStatus>} inspectEntry
 * @param {"claims" | "journals" | "opaque"} kind
 * @param {boolean} [rootTruncated]
 * @returns {Promise<ArtifactCollectionSummary>}
 */
async function inspectArtifactCollection(
  collectionRoots,
  inspectEntry,
  kind,
  rootTruncated = false,
) {
  /** @type {ArtifactEntryStatus[]} */
  const entryStatuses = [];
  let entryCount = 0;
  let inspectedCount = 0;
  let entryTruncated = false;
  for (const collectionRoot of new Set(collectionRoots)) {
    if (entryTruncated) break;
    const directoryStatus = await inspectDirectoryType(collectionRoot);
    if (directoryStatus === "absent") continue;
    if (directoryStatus !== "present") {
      entryStatuses.push(directoryStatus);
      continue;
    }

    /** @type {import("fs").Dir | null} */
    let directory = null;
    try {
      directory = await fs.opendir(collectionRoot);
      while (entryCount <= TRANSACTION_INSPECTION_ENTRY_LIMIT) {
        const entry = await directory.read();
        if (!entry) break;
        entryCount += 1;
        if (entryCount > TRANSACTION_INSPECTION_ENTRY_LIMIT) {
          entryTruncated = true;
          break;
        }
        inspectedCount += 1;
        entryStatuses.push(
          await inspectEntry(path.join(collectionRoot, entry.name), entry.name),
        );
      }
    } catch (error) {
      entryStatuses.push(
        filesystemErrorCode(error) === "ENOENT" ? "disappeared" : "unreadable",
      );
    } finally {
      if (directory) {
        try {
          await directory.close();
        } catch (error) {
          if (filesystemErrorCode(error) !== "ERR_DIR_CLOSED") {
            entryStatuses.push("unreadable");
          }
        }
      }
    }
  }

  return summarizeArtifactCollection(
    entryStatuses,
    entryCount,
    inspectedCount,
    rootTruncated || entryTruncated,
    kind,
  );
}

/**
 * @param {string} entryPath
 * @param {string} entryName
 * @param {string[] | undefined} lockRoots
 * @returns {Promise<{ artifactRoots: string[], status: ArtifactEntryStatus }>}
 */
async function inspectJournalEntry(entryPath, entryName, lockRoots) {
  if (!isSafeToken(entryName)) {
    return { artifactRoots: [], status: "malformed" };
  }
  const directoryStatus = await inspectCollectionEntryDirectory(entryPath);
  if (directoryStatus !== "present") {
    return { artifactRoots: [], status: directoryStatus };
  }
  const journal = await readBoundedJson(path.join(entryPath, "journal.json"));
  if (journal.status !== "present") {
    return { artifactRoots: [], status: journal.status };
  }
  try {
    const parsed = await parseInstallJournal(
      journal.value,
      entryName,
      lockRoots,
    );
    if (!parsed) return { artifactRoots: [], status: "malformed" };
    return {
      artifactRoots: lockRoots
        ? [
            ...new Set(
              parsed.records.map((record) => path.dirname(record.target)),
            ),
          ]
        : [],
      status: parsed.status,
    };
  } catch {
    return { artifactRoots: [], status: "unreadable" };
  }
}

/** @param {string} entryPath @param {string} entryName */
async function inspectRecoveryClaimEntry(entryPath, entryName) {
  if (!isSafeToken(entryName)) return "malformed";
  const directoryStatus = await inspectCollectionEntryDirectory(entryPath);
  if (directoryStatus !== "present") return directoryStatus;
  const metadata = await readBoundedJson(path.join(entryPath, "owner.json"));
  if (metadata.status !== "present") return metadata.status;
  if (
    !isDiagnosticLockOwner(metadata.value) ||
    metadata.value.expectedToken !== entryName
  ) {
    return "malformed";
  }
  const owner = metadata.value;
  if (owner.createdAtMs > Date.now() + MAX_OWNER_CLOCK_SKEW_MS) {
    return "suspicious";
  }
  try {
    return (await isProcessAlive(owner.pid)) ? "active" : "stale";
  } catch {
    return "unreadable";
  }
}

/** @param {string} entryPath @param {string} entryName */
async function inspectOpaqueArtifactEntry(entryPath, entryName) {
  if (!isSafeToken(entryName)) return "malformed";
  return inspectCollectionEntryDirectory(entryPath);
}

/** @param {string} directory */
async function inspectCollectionEntryDirectory(directory) {
  const status = await inspectDirectoryType(directory);
  return status === "absent" ? "disappeared" : status;
}

/** @param {string} directory */
async function inspectDirectoryType(directory) {
  try {
    const stats = await fs.lstat(directory);
    return stats.isDirectory() ? "present" : "unsupported";
  } catch (error) {
    if (filesystemErrorCode(error) === "ENOENT") return "absent";
    return "unreadable";
  }
}

/** @param {string} file @returns {Promise<BoundedJsonResult>} */
async function readBoundedJson(file) {
  /** @type {import("fs/promises").FileHandle | null} */
  let handle = null;
  /** @type {BoundedJsonResult} */
  let result = { status: "unreadable" };
  try {
    const noFollow = fsConstants.O_NOFOLLOW ?? 0;
    const nonBlock = fsConstants.O_NONBLOCK ?? 0;
    handle = await fs.open(file, fsConstants.O_RDONLY | noFollow | nonBlock);
    const stats = await handle.stat();
    if (!stats.isFile() || stats.size > TRANSACTION_METADATA_BYTE_LIMIT) {
      result = { status: "unsupported" };
    } else {
      const content = Buffer.alloc(TRANSACTION_METADATA_BYTE_LIMIT + 1);
      let offset = 0;
      while (offset < content.length) {
        const { bytesRead } = await handle.read(
          content,
          offset,
          content.length - offset,
          offset,
        );
        if (bytesRead === 0) break;
        offset += bytesRead;
      }
      if (offset > TRANSACTION_METADATA_BYTE_LIMIT) {
        result = { status: "unsupported" };
      } else {
        try {
          result = {
            status: "present",
            value: JSON.parse(content.subarray(0, offset).toString("utf8")),
          };
        } catch {
          result = { status: "malformed" };
        }
      }
    }
  } catch (error) {
    const code = filesystemErrorCode(error);
    if (code === "ENOENT") result = { status: "disappeared" };
    else if (code === "ELOOP" || code === "EISDIR" || code === "ENOTDIR") {
      result = { status: "unsupported" };
    } else result = { status: "unreadable" };
  } finally {
    if (handle) {
      try {
        await handle.close();
      } catch {
        result = { status: "unreadable" };
      }
    }
  }
  return result;
}

/** @param {unknown} value */
function isSafeToken(value) {
  return typeof value === "string" && TRANSACTION_TOKEN_PATTERN.test(value);
}

/** @returns {ArtifactCollectionSummary} */
function emptyArtifactCollectionSummary() {
  return {
    entry_count: 0,
    inspected_count: 0,
    status: "absent",
    status_counts: {},
    truncated: false,
  };
}

/**
 * @param {ArtifactEntryStatus[]} entryStatuses
 * @param {number} entryCount
 * @param {number} inspectedCount
 * @param {boolean} truncated
 * @param {"claims" | "journals" | "opaque"} kind
 * @returns {ArtifactCollectionSummary}
 */
function summarizeArtifactCollection(
  entryStatuses,
  entryCount,
  inspectedCount,
  truncated,
  kind,
) {
  /** @type {ArtifactEntryStatus[]} */
  const orderedStatuses = [
    "active",
    "stale",
    "present",
    "committed",
    "suspicious",
    "malformed",
    "unreadable",
    "unsupported",
    "disappeared",
  ];
  /** @type {Partial<Record<ArtifactEntryStatus, number>>} */
  const statusCounts = {};
  for (const status of orderedStatuses) {
    const count = entryStatuses.filter(
      (entryStatus) => entryStatus === status,
    ).length;
    if (count > 0) statusCounts[status] = count;
  }

  /** @type {DiagnosticStatus} */
  let status = "absent";
  if (statusCounts.unreadable) status = "unreadable";
  else if (statusCounts.malformed) status = "malformed";
  else if (statusCounts.unsupported) status = "unsupported";
  else if (
    truncated ||
    statusCounts.disappeared ||
    statusCounts.committed ||
    statusCounts.suspicious ||
    (kind === "journals" && Number(statusCounts.active) > 1) ||
    Object.keys(statusCounts).length > 1
  ) {
    status = "suspicious";
  } else if (statusCounts.active) {
    status = kind === "claims" ? "active" : "present";
  } else if (statusCounts.stale) status = "stale";
  else if (statusCounts.present) status = "present";

  return {
    entry_count: entryCount,
    inspected_count: inspectedCount,
    status,
    status_counts: statusCounts,
    truncated,
  };
}

/**
 * Serialize and journal one installation rooted at `root`.
 *
 * The lock directory is acquired before the callback reloads ownership state or
 * performs preflight. Staging prepares and journals each target mutation before
 * publication or cleanup. On failure, records are replayed in reverse order; a
 * crashed owner is recovered by the next installer after the recorded PID is no
 * longer alive.
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
      !isSafeToken(owner.token) ||
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
  const parsedJournal = await parseInstallJournal(
    journal,
    owner.token,
    lockRoots,
  );
  if (!parsedJournal) {
    throw new Error(
      `Refusing to recover invalid install journal ${journalPath}.`,
    );
  }

  const transaction = {
    token: owner.token,
    transactionDir: path.dirname(journalPath),
    journalPath,
    lockRoots,
    records: parsedJournal.records,
    recoveryConflicts:
      /** @type {{target: string, preservedAt: string}[]} */ ([]),
    publicationTemps: parsedJournal.publicationTemps,
    rollbackDeletedTargets: new Set(),
    rollbackTargetContents: parsedJournal.rollbackTargetContents,
    status: parsedJournal.status,
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
 * @param {string[]} [lockRoots]
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
  if (
    canonicalTarget !== target ||
    (lockRoots && !isTargetCoveredByLock(canonicalTarget, lockRoots))
  ) {
    return false;
  }
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

/**
 * Parse the journal shape shared by diagnostics and stale recovery. Diagnostics
 * validates intrinsic ownership paths; recovery additionally supplies lock roots
 * so every target must be covered by the acquired lock set.
 *
 * @param {unknown} journal
 * @param {string} token
 * @param {string[]} [lockRoots]
 * @returns {Promise<ParsedInstallJournal | null>}
 */
async function parseInstallJournal(journal, token, lockRoots) {
  if (
    !isJsonObject(journal) ||
    journal.version !== 1 ||
    journal.token !== token ||
    !Array.isArray(journal.records) ||
    (journal.status !== undefined &&
      journal.status !== "active" &&
      journal.status !== "committed")
  ) {
    return null;
  }
  const recordsValid = (
    await Promise.all(
      journal.records.map(
        /** @param {unknown} record @param {number} index */ (record, index) =>
          isOwnedMutationRecord(record, token, index, lockRoots),
      ),
    )
  ).every(Boolean);
  if (!recordsValid) return null;
  const records = /** @type {InstallMutationRecord[]} */ (journal.records);
  const rollbackTargetContents = await parseRollbackTargetExpectations(
    journal.rollbackTargetExpectations,
    lockRoots,
    records,
  );
  const publicationTemps = await parsePublicationTemps(
    journal.publicationTemps,
    token,
    records,
  );
  if (rollbackTargetContents === null || publicationTemps === null) return null;
  return {
    publicationTemps,
    records,
    rollbackTargetContents,
    status: journal.status === "committed" ? "committed" : "active",
  };
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
 * @param {string[] | undefined} lockRoots
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
      (lockRoots && !isTargetCoveredByLock(canonicalTarget, lockRoots)) ||
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
 * Journal one target mutation and hand the caller a prepared mutation.
 *
 * The target is verified before anything is journaled, so a concurrent edit is
 * rejected while the installation can still be abandoned cleanly. An existing
 * target is renamed into the transaction backup and reverified afterwards; an
 * absent one is revalidated after journaling and its record discarded when the
 * path appeared in the meantime.
 *
 * @param {string} targetPath
 * @param {TargetExpectations & { label?: string, preserveExisting?: boolean }} [options]
 * @returns {Promise<PreparedTransactionMutation | false>}
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

  /** @type {TargetExpectations} */
  const expectations = {
    expectedTargetContent,
    expectedTargetEntries,
    expectedTargetIdentity,
  };
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
    await assertTargetMatchesExpectations(
      resolvedTarget,
      stats,
      expectations,
      label,
      { assertType: true, checkContent: true },
    );
  } catch (error) {
    if (coveringRecord) {
      recordPreparationRollbackTargets(
        transaction,
        resolvedTarget,
        expectations,
      );
    }
    throw error;
  }
  if (coveringRecord) {
    return preparedMutation(expectations, {
      record: coveringRecord,
      recordIndex: transaction.records.indexOf(coveringRecord),
      target: resolvedTarget,
      targetExists: stats !== null,
    });
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

  const record = appendTargetMutationRecord(transaction, resolvedTarget, stats);
  await persistInstallJournal(transaction);

  return stats
    ? backUpExistingTarget(transaction, record, expectations, label, {
        isDirectory: stats.isDirectory(),
        preserveExisting,
      })
    : revalidateAbsentTarget(
        transaction,
        record,
        expectations,
        label,
        targetPath,
      );
}

/**
 * Verify one target against the caller's expectations, always in the order
 * type, identity, content, then tree entries.
 *
 * `contentTarget` names the path reported by a content mismatch, which differs
 * from the inspected path once the original has been renamed into the backup.
 *
 * @param {string} target
 * @param {import("fs").Stats | null} stats
 * @param {TargetExpectations} expectations
 * @param {string} label
 * @param {{ assertType?: boolean, checkContent?: boolean, contentTarget?: string, ignoreCtime?: boolean }} [options]
 */
async function assertTargetMatchesExpectations(
  target,
  stats,
  { expectedTargetContent, expectedTargetEntries, expectedTargetIdentity },
  label,
  {
    assertType = false,
    checkContent = false,
    contentTarget = target,
    ignoreCtime = false,
  } = {},
) {
  if (assertType) {
    assertExpectedTargetType(target, stats, expectedTargetContent, label);
  }
  assertExpectedTargetIdentity(target, stats, expectedTargetIdentity, label, {
    ignoreCtime,
  });
  if (
    checkContent &&
    expectedTargetContent !== undefined &&
    expectedTargetContent !== null &&
    !(await fileContentEquals(target, expectedTargetContent))
  ) {
    throw new Error(
      `Cannot install ${label} because ${contentTarget} changed during installation.`,
    );
  }
  await assertExpectedTargetEntries(target, expectedTargetEntries, label);
}

/**
 * @param {TargetExpectations} expectations
 * @param {{ record: InstallMutationRecord, recordIndex: number, target: string, targetExists: boolean }} placement
 * @returns {PreparedTransactionMutation}
 */
function preparedMutation(
  { expectedTargetContent, expectedTargetEntries, expectedTargetIdentity },
  { record, recordIndex, target, targetExists },
) {
  return {
    expectedTargetContent,
    expectedTargetEntries,
    expectedTargetIdentity,
    record,
    recordIndex,
    target,
    targetExists,
  };
}

/**
 * Remember what an already-backed-up target held so rollback can restore it
 * after preparation rejected a concurrent change.
 *
 * @param {InstallTransaction} transaction
 * @param {string} resolvedTarget
 * @param {TargetExpectations} expectations
 */
function recordPreparationRollbackTargets(
  transaction,
  resolvedTarget,
  { expectedTargetContent, expectedTargetEntries },
) {
  if (expectedTargetContent !== undefined) {
    transaction.rollbackTargetContents.set(resolvedTarget, {
      content:
        expectedTargetContent === null
          ? null
          : expectedContentBuffer(expectedTargetContent),
      metadata: null,
    });
  }
  if (expectedTargetEntries) {
    recordExpectedTreeRollbackTargets(
      transaction,
      resolvedTarget,
      expectedTargetEntries,
    );
  }
}

/**
 * Append the record describing this mutation. An existing target also reserves
 * a backup slot keyed by its position, so the caller persists the journal
 * before touching the target.
 *
 * @param {InstallTransaction} transaction
 * @param {string} resolvedTarget
 * @param {import("fs").Stats | null} stats
 * @returns {InstallMutationRecord}
 */
function appendTargetMutationRecord(transaction, resolvedTarget, stats) {
  /** @type {InstallMutationRecord} */
  const record = {
    operation: stats ? "backup-rename" : "create",
    target: resolvedTarget,
    backup: null,
  };
  if (stats) {
    const backupRoot = path.join(
      path.dirname(resolvedTarget),
      INSTALL_BACKUPS_DIR,
      transaction.token,
    );
    record.backup = path.join(backupRoot, String(transaction.records.length));
  }
  transaction.records.push(record);
  return record;
}

/**
 * Confirm a journaled create target is still absent, discarding the record when
 * the path appeared between journaling and this check.
 *
 * @param {InstallTransaction} transaction
 * @param {InstallMutationRecord} record
 * @param {TargetExpectations} expectations
 * @param {string} label
 * @param {string} targetPath
 * @returns {Promise<PreparedTransactionMutation>}
 */
async function revalidateAbsentTarget(
  transaction,
  record,
  expectations,
  label,
  targetPath,
) {
  const resolvedTarget = record.target;
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
    await assertTargetMatchesExpectations(
      resolvedTarget,
      await lstatIfExists(resolvedTarget),
      expectations,
      label,
      { assertType: true },
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
  return preparedMutation(expectations, {
    record,
    recordIndex: transaction.records.length - 1,
    target: resolvedTarget,
    targetExists: false,
  });
}

/**
 * Move an existing target into the transaction backup, verifying it both before
 * and after the rename so a concurrent edit cannot be captured silently.
 *
 * @param {InstallTransaction} transaction
 * @param {InstallMutationRecord} record
 * @param {TargetExpectations} expectations
 * @param {string} label
 * @param {{ isDirectory: boolean, preserveExisting: boolean }} options
 * @returns {Promise<PreparedTransactionMutation>}
 */
async function backUpExistingTarget(
  transaction,
  record,
  expectations,
  label,
  { isDirectory, preserveExisting },
) {
  const resolvedTarget = record.target;
  const backupPath = record.backup;
  if (!backupPath)
    throw new Error(`Missing transaction backup for ${resolvedTarget}.`);
  await ensureDir(path.dirname(backupPath));
  await assertTargetMatchesExpectations(
    resolvedTarget,
    await lstatIfExists(resolvedTarget),
    expectations,
    label,
    { checkContent: true },
  );
  await fs.rename(resolvedTarget, backupPath);
  await assertTargetMatchesExpectations(
    backupPath,
    await lstatIfExists(backupPath),
    expectations,
    label,
    { checkContent: true, contentTarget: resolvedTarget, ignoreCtime: true },
  );
  await persistInstallJournal(transaction);
  if (preserveExisting) {
    await fs.cp(backupPath, resolvedTarget, {
      recursive: isDirectory,
      preserveTimestamps: true,
      dereference: false,
    });
  }
  return preparedMutation(expectations, {
    record,
    recordIndex: transaction.records.length - 1,
    target: resolvedTarget,
    targetExists: false,
  });
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
 * @param {string} targetFile
 * @param {Buffer} installedContent
 * @param {PreparedTransactionMutation} mutation
 */
async function recordInstalledTargetForRollback(
  targetFile,
  installedContent,
  mutation,
) {
  const transaction = transactionStorage.getStore();
  if (!transaction) return;
  transaction.rollbackTargetContents.set(mutation.target, {
    content: installedContent,
    metadata: targetMetadata(await fs.lstat(targetFile)),
  });
  await persistInstallJournal(transaction);
}

module.exports = {
  inspectInstallTransactions,
  prepareTransactionMutation,
  publishStagedFile,
  recordInstalledTargetForRollback,
  withInstallTransaction,
};
