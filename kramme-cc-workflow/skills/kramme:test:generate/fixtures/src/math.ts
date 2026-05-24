/**
 * Adds two numbers together.
 */
export function add(a: number, b: number): number {
  return a + b;
}

/**
 * Subtracts the second number from the first.
 */
export function subtract(a: number, b: number): number {
  return a - b;
}

/**
 * Multiplies two numbers together.
 */
export function multiply(a: number, b: number): number {
  return a * b;
}

/**
 * Divides the first number by the second.
 * Throws an error if the divisor is zero.
 */
export function divide(a: number, b: number): number {
  if (b === 0) {
    throw new Error("Cannot divide by zero");
  }
  return a / b;
}

/**
 * Calculates the remainder of dividing a by b.
 */
export function modulo(a: number, b: number): number {
  if (b === 0) {
    throw new Error("Cannot modulo by zero");
  }
  return a % b;
}

/**
 * Raises base to the given exponent.
 */
export function power(base: number, exponent: number): number {
  return Math.pow(base, exponent);
}

/**
 * Clamps a value between a minimum and maximum.
 */
export function clamp(value: number, min: number, max: number): number {
  if (min > max) {
    throw new Error("min must be less than or equal to max");
  }
  return Math.min(Math.max(value, min), max);
}
