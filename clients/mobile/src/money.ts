// Money is integer minor units underneath; only formatting and parsing touch decimals, and never with floats.

/** 1234567 with scale 2 → "12 345,67" (ru) or "12,345.67" (en). */
export function formatMinor(minor: number, scale: number, locale: string): string {
  const negative = minor < 0;
  const digits = Math.abs(Math.trunc(minor)).toString().padStart(scale + 1, '0');
  const whole = digits.slice(0, digits.length - scale);
  const frac = scale > 0 ? digits.slice(digits.length - scale) : '';
  const fmt = new Intl.NumberFormat(locale, { useGrouping: true });
  const parts = fmt.formatToParts(12345.6);
  const group = parts.find((p) => p.type === 'group')?.value ?? ' ';
  const decimal = parts.find((p) => p.type === 'decimal')?.value ?? '.';
  const grouped = whole.replace(/\B(?=(\d{3})+(?!\d))/g, group);
  return (negative ? '−' : '') + grouped + (frac ? decimal + frac : '');
}

/** "100.5" or "100,50" with scale 2 → 10050. Returns null for anything that is not a positive amount. */
export function parseToMinor(text: string, scale: number): number | null {
  const t = text.trim().replace(/\s/g, '').replace(',', '.');
  const m = /^(\d+)(?:\.(\d*))?$/.exec(t);
  if (!m) return null;
  const frac = m[2] ?? '';
  if (frac.length > scale) return null;
  const minor = Number(m[1] + frac.padEnd(scale, '0'));
  return Number.isSafeInteger(minor) && minor > 0 ? minor : null;
}
