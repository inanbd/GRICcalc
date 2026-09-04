// Number formatting and lenient parsing, matching lib/logic/formatting.dart.

/** Fixed decimals, for headline figures where steady digits read better. */
export function fixed(value, decimals = 1) {
  if (!Number.isFinite(value)) return '--';
  return value.toFixed(decimals);
}

/** Fixed decimals with trailing zeros dropped: 12.50 -> "12.5", 10.0 -> "10". */
export function trimmed(value, decimals = 1) {
  if (!Number.isFinite(value)) return '--';
  const text = value.toFixed(decimals);
  if (!text.includes('.')) return text;
  return text.replace(/\.?0+$/, '');
}

/** Parses user input, tolerating a comma decimal separator and stray spaces. */
export function parseNumber(text) {
  if (text === null || text === undefined) return null;
  const cleaned = String(text).trim().replace(',', '.');
  if (cleaned === '') return null;
  const value = Number(cleaned);
  return Number.isFinite(value) ? value : null;
}
