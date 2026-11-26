import { describe, expect, it } from 'vitest';
import ru from './ru.json';
import en from './en.json';
// Read as text through Vite's `?raw` (typed by vite/client); the web client has no Node typings.
import rejectionJava from '../../../../backend/engine/src/main/java/engine/Rejection.java?raw';

// Every refusal code the engine can return has a readable message in both locales,
// so `t(`errors.${code}`)` never shows a raw key.
const codes = rejectionJava
  .split('\n')
  .map((line) => line.trim())
  .map((line) => /^([A-Z][A-Z0-9_]*),?$/.exec(line)?.[1])
  .filter((c): c is string => typeof c === 'string');

describe('errors catalogue covers engine.Rejection', () => {
  it('finds the enum constants', () => {
    expect(codes.length).toBeGreaterThan(10);
    expect(codes).toContain('INSUFFICIENT_FUNDS');
  });

  it('every code has errors.<CODE> in ru and en', () => {
    const ruErrors: Record<string, string> = ru.errors;
    const enErrors: Record<string, string> = en.errors;
    const missing = codes.flatMap((code) => [
      ...(ruErrors[code]?.trim() ? [] : [`ru errors.${code}`]),
      ...(enErrors[code]?.trim() ? [] : [`en errors.${code}`]),
    ]);
    expect(missing).toEqual([]);
  });
});
