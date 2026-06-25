"use strict";

const readline = require("readline");

let nonInteractiveReaderInitialized = false;
let nonInteractiveInputBuffer = "";
let nonInteractiveStreamEnded = false;
let nonInteractiveAnswerWaiter = null;
let nonInteractiveFallbackAnswer;

function parseConfirmationAnswer(answer) {
  const normalized = String(answer ?? "")
    .trim()
    .toLowerCase();
  return normalized === "y" || normalized === "yes";
}

function readLineFromNonInteractiveBuffer() {
  const newlineIndex = nonInteractiveInputBuffer.indexOf("\n");
  if (newlineIndex < 0) return null;
  const rawLine = nonInteractiveInputBuffer.slice(0, newlineIndex);
  nonInteractiveInputBuffer = nonInteractiveInputBuffer.slice(newlineIndex + 1);
  return rawLine.endsWith("\r") ? rawLine.slice(0, -1) : rawLine;
}

function setupNonInteractiveReader() {
  if (nonInteractiveReaderInitialized) return;
  nonInteractiveReaderInitialized = true;
  process.stdin.setEncoding("utf8");
  process.stdin.on("data", (chunk) => {
    nonInteractiveInputBuffer += chunk;

    if (!nonInteractiveAnswerWaiter) {
      if (nonInteractiveInputBuffer.includes("\n")) {
        process.stdin.pause();
      }
      return;
    }

    const line = readLineFromNonInteractiveBuffer();
    if (line === null) return;

    const resolve = nonInteractiveAnswerWaiter;
    nonInteractiveAnswerWaiter = null;
    process.stdin.pause();
    resolve(line);
  });

  process.stdin.on("end", () => {
    nonInteractiveStreamEnded = true;
    if (!nonInteractiveAnswerWaiter) return;
    const resolve = nonInteractiveAnswerWaiter;
    nonInteractiveAnswerWaiter = null;
    const line = readLineFromNonInteractiveBuffer();
    if (line !== null) {
      resolve(line);
      return;
    }
    const trailing = nonInteractiveInputBuffer;
    nonInteractiveInputBuffer = "";
    if (trailing.length > 0) {
      resolve(trailing);
      return;
    }
    resolve(undefined);
  });

  process.stdin.pause();
}

function readNonInteractiveConfirmationAnswer() {
  setupNonInteractiveReader();
  const queued = readLineFromNonInteractiveBuffer();
  if (queued !== null) {
    return Promise.resolve(queued);
  }
  if (nonInteractiveStreamEnded) {
    const trailing = nonInteractiveInputBuffer;
    nonInteractiveInputBuffer = "";
    if (trailing.length > 0) {
      return Promise.resolve(trailing);
    }
    return Promise.resolve(undefined);
  }
  if (nonInteractiveAnswerWaiter) {
    throw new Error(
      "Concurrent non-interactive confirmations are not supported.",
    );
  }
  return new Promise((resolve) => {
    nonInteractiveAnswerWaiter = resolve;
    process.stdin.resume();
  });
}

async function confirm(message, options = {}) {
  if (options.yes) {
    return true;
  }

  if (options.nonInteractive) {
    console.log(`${message} [y/N] (non-interactive mode: defaulting to No)`);
    return false;
  }

  if (!process.stdin.isTTY) {
    process.stdout.write(`${message} [y/N] `);
    const answer = await readNonInteractiveConfirmationAnswer();
    if (answer !== undefined) {
      nonInteractiveFallbackAnswer = answer;
      return parseConfirmationAnswer(answer);
    }
    return parseConfirmationAnswer(nonInteractiveFallbackAnswer);
  }

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  return new Promise((resolve) => {
    rl.question(`${message} [y/N] `, (answer) => {
      rl.close();
      resolve(parseConfirmationAnswer(answer));
    });
  });
}

module.exports = {
  confirm,
};
