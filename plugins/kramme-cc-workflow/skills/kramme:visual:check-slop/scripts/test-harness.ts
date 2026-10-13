import assert from "node:assert/strict"
import { describe, test } from "node:test"

export { describe }
export const it = test

type Matcher = {
  toBe(expected: unknown): void
  toBeGreaterThan(expected: number): void
  toBeGreaterThanOrEqual(expected: number): void
  toBeLessThan(expected: number): void
  toBeUndefined(): void
  toContain(expected: unknown): void
  toEqual(expected: unknown): void
  toHaveLength(expected: number): void
  toMatch(expected: RegExp | string): void
}

function matcher(actual: unknown, message: string | undefined, negate: boolean): Matcher {
  const check = (condition: boolean, fallback: string): void => {
    assert.ok(negate ? !condition : condition, message ?? fallback)
  }

  return {
    toBe: (expected) =>
      negate
        ? assert.notStrictEqual(actual, expected, message)
        : assert.strictEqual(actual, expected, message),
    toBeGreaterThan: (expected) =>
      check(typeof actual === "number" && actual > expected, `${actual} is not greater than ${expected}`),
    toBeGreaterThanOrEqual: (expected) =>
      check(
        typeof actual === "number" && actual >= expected,
        `${actual} is not greater than or equal to ${expected}`,
      ),
    toBeLessThan: (expected) =>
      check(typeof actual === "number" && actual < expected, `${actual} is not less than ${expected}`),
    toBeUndefined: () => check(actual === undefined, "value is not undefined"),
    toContain: (expected) => {
      const condition =
        typeof actual === "string"
          ? actual.includes(String(expected))
          : Array.isArray(actual) && actual.includes(expected)
      check(condition, `value does not contain ${String(expected)}`)
    },
    toEqual: (expected) =>
      negate
        ? assert.notDeepStrictEqual(actual, expected, message)
        : assert.deepStrictEqual(actual, expected, message),
    toHaveLength: (expected) =>
      check(
        actual !== null &&
          actual !== undefined &&
          "length" in Object(actual) &&
          Number((actual as { length: unknown }).length) === expected,
        `value does not have length ${expected}`,
      ),
    toMatch: (expected) => {
      const value = String(actual)
      const condition =
        typeof expected === "string" ? value.includes(expected) : expected.test(value)
      check(condition, `value does not match ${String(expected)}`)
    },
  }
}

export function expect(actual: unknown, message?: string): Matcher & { not: Matcher } {
  return Object.assign(matcher(actual, message, false), {
    not: matcher(actual, message, true),
  })
}
