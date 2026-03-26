import { add, subtract, multiply, divide } from './math';

describe('math utilities', () => {
  test('add returns sum', () => {
    expect(add(2, 3)).toBe(5);
  });

  test('subtract returns difference', () => {
    expect(subtract(5, 3)).toBe(2);
  });

  test('multiply returns product', () => {
    expect(multiply(4, 3)).toBe(12);
  });

  test('divide returns quotient', () => {
    expect(divide(10, 2)).toBe(5);
  });

  test('divide handles negative divisor', () => {
    // Bug: this throws "Division by zero" even though -3 is valid
    expect(divide(9, -3)).toBe(-3);
  });

  test('divide throws on zero', () => {
    expect(() => divide(10, 0)).toThrow('Division by zero');
  });
});
