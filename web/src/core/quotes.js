// The same 124 sourced quotes the iPhone app bundles.
import QUOTES from "../../../ios/Core/Resources/quotes.json";

export { QUOTES };

const byId = (a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
const gcd = (a, b) => (b === 0 ? a : gcd(b, a % b));

/** Steps through a list with a stride that shares no factor with its length, so each quote comes up once per cycle. */
function walk(pool, position) {
  const sorted = [...pool].sort(byId);
  const n = sorted.length;
  const stride = [7, 11, 13, 17, 19, 23, 29, 31, 37].find((p) => gcd(p, n) === 1) ?? 1;
  const index = ((((position % n) * stride) % n) + n) % n;
  return sorted[index];
}

export function filtered(tradition) {
  return tradition === "both" ? QUOTES : QUOTES.filter((q) => q.tradition === tradition);
}

export function daily(j, tradition) {
  if (tradition === "both") {
    const pool = QUOTES.filter((q) => q.tradition === (j % 2 === 0 ? "stoic" : "hindu"));
    return walk(pool.length ? pool : QUOTES, Math.floor(j / 2));
  }
  const pool = filtered(tradition);
  return walk(pool.length ? pool : QUOTES, j);
}

const MOMENTS = ["morning", "evening", "miss", "slip", "urge", "streak", "newHabit", "fresh", "dayComplete", "minimum", "timer", "general"];

export function pick(moment, j, tradition, salt = 0) {
  let pool = filtered(tradition).filter((q) => q.moments.includes(moment));
  if (!pool.length) pool = QUOTES.filter((q) => q.moments.includes(moment));
  if (!pool.length) return daily(j, tradition);
  return walk(pool, j + MOMENTS.indexOf(moment) * 7 + salt);
}

export const quoteById = (id) => QUOTES.find((q) => q.id === id);
