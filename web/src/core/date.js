// Calendar days as Julian day numbers, the same scheme the iPhone app uses, so day arithmetic
// never depends on time zones or the device's calendar system.

const pad = (n) => String(n).padStart(2, "0");

export const DAY_START = 210; // 3:30 am: late-night times count as the end of the previous day

export function jdn(y, m, d) {
  const a = Math.floor((14 - m) / 12);
  const yy = y + 4800 - a;
  const mm = m + 12 * a - 3;
  return d + Math.floor((153 * mm + 2) / 5) + 365 * yy + Math.floor(yy / 4) - Math.floor(yy / 100) + Math.floor(yy / 400) - 32045;
}

export function ymd(j) {
  const a = j + 32044;
  const b = Math.floor((4 * a + 3) / 146097);
  const c = a - Math.floor((146097 * b) / 4);
  const d = Math.floor((4 * c + 3) / 1461);
  const e = c - Math.floor((1461 * d) / 4);
  const m = Math.floor((5 * e + 2) / 153);
  return { y: 100 * b + d - 4800 + Math.floor(m / 10), m: m + 3 - 12 * Math.floor(m / 10), d: e - Math.floor((153 * m + 2) / 5) + 1 };
}

export const today = (now = new Date()) => jdn(now.getFullYear(), now.getMonth() + 1, now.getDate());
export const fromDate = (date) => jdn(date.getFullYear(), date.getMonth() + 1, date.getDate());

export function raw(j) {
  const { y, m, d } = ymd(j);
  return `${y}-${pad(m)}-${pad(d)}`;
}

export function parse(s) {
  if (typeof s !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(s)) return null;
  const [y, m, d] = s.split("-").map(Number);
  const j = jdn(y, m, d);
  const back = ymd(j);
  return back.y === y && back.m === m && back.d === d ? j : null;
}

/** 1 = Sunday … 7 = Saturday, matching the iPhone app. */
export const weekday = (j) => ((j + 1) % 7) + 1;
/** The Monday of a day's week. */
export const weekStart = (j) => j - ((weekday(j) + 5) % 7);

export function dateAt(j, minutes = 0) {
  const { y, m, d } = ymd(j);
  return new Date(y, m - 1, d, Math.floor(minutes / 60), minutes % 60);
}

export const minutesOf = (date) => date.getHours() * 60 + date.getMinutes();
export const dayOrder = (min) => (min < DAY_START ? min + 1440 : min);

export function parseTime(s) {
  if (typeof s !== "string") return null;
  const m = /^(\d{1,2}):(\d{2})$/.exec(s);
  if (!m) return null;
  return ((Number(m[1]) % 24) * 60 + Math.min(59, Number(m[2])));
}
export const formatTime = (min) => `${pad(Math.floor(min / 60) % 24)}:${pad(min % 60)}`;

export function displayTime(min) {
  return dateAt(today(), ((min % 1440) + 1440) % 1440).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
}

export function format(j, options) {
  return dateAt(j, 12 * 60).toLocaleDateString([], options);
}

export const WEEK_ORDER = [2, 3, 4, 5, 6, 7, 1];
export const WEEKDAY_SHORT = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
export const WEEKDAY_LETTER = ["S", "M", "T", "W", "T", "F", "S"];
