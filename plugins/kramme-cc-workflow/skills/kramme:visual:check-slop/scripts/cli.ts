#!/usr/bin/env node
// Derived from Gesso Build's src/cli.ts.
// Upstream: https://github.com/Gesso-Build/skills/blob/ab68f1878dd5f19ac8dee9d55d2f4313060cac83/src/cli.ts
// Copyright (c) 2026 Gesso Build, Inc.
// Licensed under MIT; see ../references/THIRD_PARTY_NOTICES.md.
// anti-slop CLI.
//
//   anti-slop check <file.html|dir> [--json]   detect; exit 1 on gating hits
//   anti-slop fix <file.html|dir> [--write]    apply deterministic fixes
//
// The check verdict is deliberately binary (pass/slop) with the tells
// listed, so it slots into CI and slash-command workflows.
import { randomUUID } from "node:crypto";
import * as fs from "node:fs";
import * as path from "node:path";
import { applySlopFixes, runSlopGuard } from "./engine.js";
import { FLAGSHIP_RULES } from "./rules.js";

const VERSION = "0.4.2-kramme.1";
const HTML_FILE_RE = /\.html?$/i;
const MAX_HTML_FILES = 256;
const MAX_HTML_FILE_BYTES = 512 * 1024;
const MAX_HTML_TOTAL_BYTES = 8 * 1024 * 1024;
const MAX_VISITED_ENTRIES = 4096;
const MAX_VISITED_DIRECTORIES = 512;
const MAX_OUTPUT_FRAGMENT_LENGTH = 512;

interface WalkBudget {
  entries: number;
  directories: number;
}

interface FileSnapshot {
  file: string;
  html: string;
  dev: number;
  ino: number;
  size: number;
  mtimeMs: number;
  mode: number;
}

interface Replacement {
  snapshot: FileSnapshot;
  html: string;
}

interface StagedReplacement extends Replacement {
  temporary: string;
}

class PartialCommitError extends Error {
  constructor(
    message: string,
    readonly committedFiles: string[],
    cause: unknown,
  ) {
    super(message, { cause });
    this.name = "PartialCommitError";
  }
}

function renderOutputFragment(value: string, maximumLength?: number): string {
  const characters = Array.from(value);
  const bounded =
    maximumLength === undefined
      ? characters
      : characters.slice(0, maximumLength);
  const rendered = bounded
    .map((character) => {
      const codePoint = character.codePointAt(0) ?? 0;
      if (
        codePoint < 0x20 ||
        codePoint === 0x7f ||
        (codePoint >= 0x200b && codePoint <= 0x200f) ||
        (codePoint >= 0x2028 && codePoint <= 0x202e) ||
        (codePoint >= 0x2060 && codePoint <= 0x206f) ||
        codePoint === 0xfeff
      ) {
        return `\\u{${codePoint.toString(16)}}`;
      }
      if ("&<>`|[]()".includes(character)) return `&#${codePoint};`;
      return character;
    })
    .join("");
  return maximumLength !== undefined && characters.length > bounded.length
    ? `${rendered}...`
    : rendered;
}

function safeOutputFragment(value: string): string {
  return renderOutputFragment(value, MAX_OUTPUT_FRAGMENT_LENGTH);
}

function safeOutputPath(value: string): string {
  return renderOutputFragment(value);
}

function canonicalRepositoryRoot(): string {
  return fs.realpathSync(
    path.resolve(process.env.CHECK_SLOP_REPOSITORY_ROOT ?? process.cwd()),
  );
}

function requireContainedPath(candidate: string, root: string): string {
  const resolved = fs.realpathSync(candidate);
  const relative = path.relative(root, resolved);
  if (
    relative === ".." ||
    relative.startsWith(`..${path.sep}`) ||
    path.isAbsolute(relative)
  ) {
    throw new Error(`target is outside the working repository: ${candidate}`);
  }
  return resolved;
}

function printUsage(): void {
  process.stdout.write(
    [
      `anti-slop v${VERSION} (maintained by kramme; derived from Gesso)`,
      "",
      "Usage:",
      "  anti-slop check <file.html|dir> [--json]",
      "      Detect AI-slop tells. Exit 0 = no gating hits, 1 = gating hits.",
      "  anti-slop fix <file.html|dir> [--write] [--json]",
      "      Apply deterministic fixes. --write edits in place.",
      "",
    ].join("\n"),
  );
}

function collectHtmlFiles(
  target: string,
  out: string[],
  budget: WalkBudget,
  root: string,
): void {
  const absolute = path.resolve(target);
  const stat = fs.lstatSync(absolute);
  if (stat.isSymbolicLink()) {
    throw new Error(`symbolic-link targets are not supported: ${target}`);
  }
  const contained = requireContainedPath(absolute, root);
  if (stat.isFile()) {
    if (HTML_FILE_RE.test(contained)) out.push(contained);
    return;
  }
  if (!stat.isDirectory()) return;
  budget.directories++;
  if (budget.directories > MAX_VISITED_DIRECTORIES) {
    throw new Error(
      `target contains more than ${MAX_VISITED_DIRECTORIES} directories`,
    );
  }
  const directory = fs.opendirSync(contained);
  try {
    let entry: fs.Dirent | null;
    while ((entry = directory.readSync()) !== null) {
      budget.entries++;
      if (budget.entries > MAX_VISITED_ENTRIES) {
        throw new Error(
          `target contains more than ${MAX_VISITED_ENTRIES} filesystem entries`,
        );
      }
      if (entry.name.startsWith(".") || entry.name === "node_modules") continue;
      const p = path.join(contained, entry.name);
      if (entry.isSymbolicLink()) {
        throw new Error(
          `symbolic links are not supported while scanning: ${p}`,
        );
      }
      if (entry.isDirectory()) collectHtmlFiles(p, out, budget, root);
      else if (HTML_FILE_RE.test(entry.name)) {
        out.push(requireContainedPath(p, root));
        if (out.length > MAX_HTML_FILES) {
          throw new Error(
            `target contains more than ${MAX_HTML_FILES} HTML files`,
          );
        }
      }
    }
  } finally {
    directory.closeSync();
  }
}

function htmlFiles(target: string): string[] {
  const out: string[] = [];
  collectHtmlFiles(
    target,
    out,
    { entries: 0, directories: 0 },
    canonicalRepositoryRoot(),
  );
  return out.sort();
}

function noFollowFlag(): number {
  return fs.constants.O_NOFOLLOW ?? 0;
}

function readSnapshot(file: string): FileSnapshot {
  const descriptor = fs.openSync(file, fs.constants.O_RDONLY | noFollowFlag());
  try {
    const stat = fs.fstatSync(descriptor);
    if (!stat.isFile())
      throw new Error(`target is not a regular file: ${file}`);
    if (stat.size > MAX_HTML_FILE_BYTES) {
      throw new Error(
        `HTML file exceeds ${MAX_HTML_FILE_BYTES} byte limit: ${file}`,
      );
    }
    return {
      file,
      html: fs.readFileSync(descriptor, "utf8"),
      dev: stat.dev,
      ino: stat.ino,
      size: stat.size,
      mtimeMs: stat.mtimeMs,
      mode: stat.mode,
    };
  } finally {
    fs.closeSync(descriptor);
  }
}

function readSnapshots(files: string[]): FileSnapshot[] {
  if (files.length > MAX_HTML_FILES) {
    throw new Error(
      `target contains ${files.length} HTML files; limit is ${MAX_HTML_FILES}`,
    );
  }
  const snapshots: FileSnapshot[] = [];
  let totalBytes = 0;
  for (const file of files) {
    const snapshot = readSnapshot(file);
    totalBytes += snapshot.size;
    if (totalBytes > MAX_HTML_TOTAL_BYTES) {
      throw new Error(
        `HTML input exceeds ${MAX_HTML_TOTAL_BYTES} byte aggregate limit`,
      );
    }
    snapshots.push(snapshot);
  }
  return snapshots;
}

function assertSnapshotUnchanged(snapshot: FileSnapshot): void {
  const current = fs.lstatSync(snapshot.file);
  if (
    !current.isFile() ||
    current.isSymbolicLink() ||
    current.dev !== snapshot.dev ||
    current.ino !== snapshot.ino ||
    current.size !== snapshot.size ||
    current.mtimeMs !== snapshot.mtimeMs
  ) {
    throw new Error(
      `target changed while fixes were prepared: ${snapshot.file}`,
    );
  }
}

function errorDetail(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function cleanupTemporaryFiles(files: string[]): string[] {
  const failures: string[] = [];
  for (const file of files) {
    try {
      fs.rmSync(file, { force: true });
    } catch (error) {
      failures.push(`${file}: ${errorDetail(error)}`);
    }
  }
  return failures;
}

function cleanupContext(failures: string[]): string {
  return failures.length === 0
    ? ""
    : `; temporary cleanup also failed (${failures.join("; ")})`;
}

function stageReplacement(replacement: Replacement): StagedReplacement {
  assertSnapshotUnchanged(replacement.snapshot);
  const temporary = path.join(
    path.dirname(replacement.snapshot.file),
    `.${path.basename(replacement.snapshot.file)}.anti-slop-${process.pid}-${randomUUID()}.tmp`,
  );
  let descriptor: number | undefined;
  try {
    descriptor = fs.openSync(
      temporary,
      fs.constants.O_WRONLY |
        fs.constants.O_CREAT |
        fs.constants.O_EXCL |
        noFollowFlag(),
      replacement.snapshot.mode & 0o777,
    );
    fs.writeFileSync(descriptor, replacement.html, "utf8");
    fs.fsyncSync(descriptor);
  } catch (error) {
    const cleanupFailures = cleanupTemporaryFiles([temporary]);
    if (cleanupFailures.length === 0) throw error;
    throw new Error(
      `fix staging failed: ${errorDetail(error)}${cleanupContext(cleanupFailures)}`,
      { cause: error },
    );
  } finally {
    if (descriptor !== undefined) fs.closeSync(descriptor);
  }
  return { ...replacement, temporary };
}

function commitReplacements(replacements: Replacement[]): void {
  const staged: StagedReplacement[] = [];
  try {
    for (const replacement of replacements) {
      staged.push(stageReplacement(replacement));
    }
  } catch (error) {
    const cleanupFailures = cleanupTemporaryFiles(
      staged.map((item) => item.temporary),
    );
    if (cleanupFailures.length === 0) throw error;
    throw new Error(
      `fix staging failed: ${errorDetail(error)}${cleanupContext(cleanupFailures)}`,
      { cause: error },
    );
  }

  const committed: string[] = [];
  try {
    for (const item of staged) {
      assertSnapshotUnchanged(item.snapshot);
      fs.renameSync(item.temporary, item.snapshot.file);
      committed.push(item.snapshot.file);
    }
  } catch (error) {
    const cleanupFailures = cleanupTemporaryFiles(
      staged.map((item) => item.temporary),
    );
    const detail = errorDetail(error);
    throw new PartialCommitError(
      `fix commit failed after changing ${committed.length} file(s): ${detail}${cleanupContext(cleanupFailures)}`,
      committed,
      error,
    );
  }
}

function runCheck(target: string, json: boolean): number {
  const files = htmlFiles(target);
  if (files.length === 0) {
    process.stderr.write(
      `no .html files found under ${safeOutputFragment(target)}\n`,
    );
    return 2;
  }
  let gatingTotal = 0;
  let advisoryTotal = 0;
  const results = readSnapshots(files).map((snapshot) => {
    const check = runSlopGuard(snapshot.html, {}, FLAGSHIP_RULES);
    gatingTotal += check.counts.gating;
    advisoryTotal += check.counts.advisory;
    return {
      file: snapshot.file,
      displayFile: safeOutputFragment(snapshot.file),
      ...check,
    };
  });

  if (json) {
    process.stdout.write(JSON.stringify({ results }, null, 2) + "\n");
  } else {
    for (const r of results) {
      const advisory = r.counts.advisory;
      const verdict = r.pass
        ? advisory > 0
          ? `PASS (${advisory} advisory)`
          : "PASS"
        : `SLOP (severity ${r.severity}${advisory > 0 ? `, ${advisory} advisory` : ""})`;
      process.stdout.write(`${r.displayFile}: ${verdict}\n`);
      if (r.externalStylesheets > 0) {
        process.stdout.write(
          `  note: ${r.externalStylesheets} external stylesheet(s) not inlined; ` +
            "style-dependent results are a lower bound\n",
        );
      }
      for (const issue of r.issues) process.stdout.write(`  ${issue}\n`);
    }
    process.stdout.write(
      `\n${files.length} file(s), ${gatingTotal} slop occurrence(s), ` +
        `${advisoryTotal} advisory.\n`,
    );
  }
  // The exit code is the verdict: advisory (flag-tier) hits report context but
  // never fail a check, matching the documented pass contract.
  return gatingTotal > 0 ? 1 : 0;
}

function runFix(target: string, write: boolean, json: boolean): number {
  const files = htmlFiles(target);
  if (files.length === 0) {
    process.stderr.write(
      `no .html files found under ${safeOutputFragment(target)}\n`,
    );
    return 2;
  }
  if (!write && !json && files.length !== 1) {
    process.stderr.write(
      "error: fix without --write accepts exactly one file\n",
    );
    return 2;
  }

  const snapshots = readSnapshots(files);
  const replacements: Replacement[] = [];
  let outputBytes = 0;
  const results = snapshots.map((snapshot) => {
    const result = applySlopFixes(snapshot.html, {}, FLAGSHIP_RULES);
    const changed = result.html !== snapshot.html;
    const resultBytes = changed
      ? Buffer.byteLength(result.html, "utf8")
      : snapshot.size;
    if (resultBytes > MAX_HTML_FILE_BYTES) {
      throw new Error(
        `fixed HTML exceeds ${MAX_HTML_FILE_BYTES} byte limit: ${snapshot.file}`,
      );
    }
    outputBytes += resultBytes;
    if (outputBytes > MAX_HTML_TOTAL_BYTES) {
      throw new Error(
        `fixed HTML exceeds ${MAX_HTML_TOTAL_BYTES} byte aggregate limit`,
      );
    }
    if (write && changed) replacements.push({ snapshot, html: result.html });
    return {
      file: snapshot.file,
      displayFile: safeOutputFragment(snapshot.file),
      changed,
      fixes: result.fixes,
      total: result.total,
      html: write || json ? undefined : result.html,
    };
  });
  if (write) commitReplacements(replacements);

  if (json) {
    process.stdout.write(JSON.stringify({ results }, null, 2) + "\n");
  } else if (write) {
    for (const result of results) {
      const summary = Object.entries(result.fixes)
        .map(([id, n]) => `${id} x${n}`)
        .join(", ");
      process.stdout.write(
        result.total > 0
          ? `${result.displayFile}: fixed ${result.total} occurrence(s): ${summary}\n`
          : `${result.displayFile}: already clean\n`,
      );
    }
  } else {
    process.stdout.write(results[0]?.html ?? "");
  }
  return 0;
}

function main(): number {
  const [, , cmd, ...rest] = process.argv;
  if (cmd === "-h" || cmd === "--help" || cmd === "help" || cmd === undefined) {
    printUsage();
    return cmd === undefined ? 2 : 0;
  }
  if (cmd === "-v" || cmd === "--version") {
    process.stdout.write(`${VERSION}\n`);
    return 0;
  }
  if (cmd === "check") {
    const unknown = rest.filter(
      (argument) => argument.startsWith("--") && argument !== "--json",
    );
    const targets = rest.filter((argument) => !argument.startsWith("--"));
    if (unknown.length > 0 || targets.length !== 1) {
      process.stderr.write(
        unknown.length > 0
          ? `error: unknown option '${safeOutputFragment(unknown[0])}'\n`
          : "error: check needs exactly one file or directory\n",
      );
      return 2;
    }
    return runCheck(targets[0], rest.includes("--json"));
  }
  if (cmd === "fix") {
    const unknown = rest.filter(
      (argument) =>
        argument.startsWith("--") &&
        argument !== "--json" &&
        argument !== "--write",
    );
    const targets = rest.filter((argument) => !argument.startsWith("--"));
    if (unknown.length > 0 || targets.length !== 1) {
      process.stderr.write(
        unknown.length > 0
          ? `error: unknown option '${safeOutputFragment(unknown[0])}'\n`
          : "error: fix needs exactly one file or directory\n",
      );
      return 2;
    }
    return runFix(
      targets[0],
      rest.includes("--write"),
      rest.includes("--json"),
    );
  }
  process.stderr.write(
    `error: unknown command '${safeOutputFragment(cmd)}'\n\n`,
  );
  printUsage();
  return 2;
}

try {
  process.exitCode = main();
} catch (err) {
  process.stderr.write(
    `[anti-slop] fatal: ${safeOutputFragment(err instanceof Error ? err.message : String(err))}\n`,
  );
  if (err instanceof PartialCommitError) {
    for (const file of err.committedFiles) {
      process.stderr.write(`[anti-slop] changed: ${safeOutputPath(file)}\n`);
    }
  }
  process.exitCode = 2;
}
