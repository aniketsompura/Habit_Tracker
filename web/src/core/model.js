// Data shapes match the iPhone app's JSON exactly, so a backup from here restores there.
import * as D from "./date.js";

export const KINDS = ["check", "count", "timed", "quit"];
export const COLORS = ["orange", "red", "yellow", "teal", "green", "pink", "indigo", "graphite"];
export const TRADITIONS = ["both", "stoic", "hindu"];

export const uuid = () =>
  (globalThis.crypto?.randomUUID?.() ?? "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    return (c === "x" ? r : (r & 0x3) | 0x8).toString(16);
  })).toUpperCase();

/** ISO 8601 without milliseconds, the format the iPhone app's decoder expects. */
export const iso = (date = new Date()) => date.toISOString().replace(/\.\d{3}Z$/, "Z");

const str = (v, fallback = "") => (typeof v === "string" ? v : fallback);
const int = (v, fallback) => (Number.isFinite(v) ? Math.round(v) : fallback);

export function normalizeHabit(raw) {
  if (!raw || typeof raw !== "object" || typeof raw.id !== "string") return null;
  const weekdays = Array.isArray(raw.weekdays) ? [...new Set(raw.weekdays.filter((d) => Number.isInteger(d) && d >= 1 && d <= 7))].sort() : [1, 2, 3, 4, 5, 6, 7];
  const slots = (Array.isArray(raw.slots) ? raw.slots : [])
    .map((s) => ({ id: str(s?.id) || uuid(), time: D.parseTime(s?.time) ?? 540, remind: s?.remind !== false }))
    .map((s) => ({ ...s, time: D.formatTime(s.time) }));
  return {
    id: raw.id,
    name: str(raw.name).trim() || "Untitled habit",
    symbol: str(raw.symbol, "sparkles"),
    color: COLORS.includes(raw.color) ? raw.color : "orange",
    kind: KINDS.includes(raw.kind) ? raw.kind : "check",
    weekdays: weekdays.length ? weekdays : [1, 2, 3, 4, 5, 6, 7],
    slots,
    target: Math.max(1, int(raw.target, 1)),
    unit: str(raw.unit),
    cue: str(raw.cue),
    place: str(raw.place),
    identity: str(raw.identity),
    minimum: str(raw.minimum),
    treat: str(raw.treat),
    createdOn: D.parse(raw.createdOn) !== null ? raw.createdOn : D.raw(D.today()),
    archived: raw.archived === true,
    order: int(raw.order, 0),
  };
}

export function normalizeRecord(raw) {
  const r = raw && typeof raw === "object" ? raw : {};
  const entries = (Array.isArray(r.entries) ? r.entries : [])
    .filter((e) => e && typeof e.habitID === "string")
    .map((e) => ({
      id: str(e.id) || uuid(),
      habitID: e.habitID,
      kind: ["done", "minimum", "slip"].includes(e.kind) ? e.kind : "done",
      ...(typeof e.slotID === "string" ? { slotID: e.slotID } : {}),
      amount: int(e.amount, 1),
      at: str(e.at, iso()),
    }));
  const out = { entries };
  if (typeof r.intention === "string") out.intention = r.intention;
  if (typeof r.focusHabitID === "string") out.focusHabitID = r.focusHabitID;
  if (r.review && typeof r.review === "object") {
    out.review = { cured: str(r.review.cured), resisted: str(r.review.resisted), better: str(r.review.better), savedAt: str(r.review.savedAt, iso()) };
  }
  if (typeof r.note === "string" && r.note) out.note = r.note;
  return out;
}

export const recordIsEmpty = (r) =>
  !r || ((!r.entries || r.entries.length === 0) && r.intention === undefined && r.focusHabitID === undefined && !r.review && !r.note);

export const defaultPreferences = () => ({
  morningRitual: true,
  morningTime: "06:30",
  eveningReview: true,
  eveningTime: "21:30",
  followUps: true,
  followUpMinutes: 30,
  tradition: "both",
  showSanskrit: true,
  onboarded: false,
});

export function normalizePreferences(raw) {
  const d = defaultPreferences();
  const r = raw && typeof raw === "object" ? raw : {};
  const out = { ...d };
  for (const key of ["morningRitual", "eveningReview", "followUps", "showSanskrit", "onboarded"]) if (typeof r[key] === "boolean") out[key] = r[key];
  for (const key of ["morningTime", "eveningTime"]) if (D.parseTime(r[key]) !== null) out[key] = r[key];
  if (Number.isFinite(r.followUpMinutes)) out.followUpMinutes = r.followUpMinutes;
  if (TRADITIONS.includes(r.tradition)) out.tradition = r.tradition;
  if (Number.isInteger(r.birthdayMonth) && Number.isInteger(r.birthdayDay)) {
    out.birthdayMonth = r.birthdayMonth;
    out.birthdayDay = r.birthdayDay;
  }
  return out;
}

export const unitLabel = (h) => (h.unit.trim() ? h.unit : "times");

export function dailyRequirement(h) {
  if (h.kind === "check" || h.kind === "timed") return Math.max(1, h.slots.length);
  if (h.kind === "count") return Math.max(1, h.target);
  return 1;
}

export const sortedSlots = (h) => [...h.slots].sort((a, b) => D.dayOrder(D.parseTime(a.time)) - D.dayOrder(D.parseTime(b.time)));
export const isScheduled = (h, j) => h.weekdays.includes(D.weekday(j));

export const activeHabits = (habits) => habits.filter((h) => !h.archived).sort((a, b) => a.order - b.order || a.createdOn.localeCompare(b.createdOn));

/** "After I make coffee, read 20 minutes on the balcony." */
export function whenThen(h) {
  const cue = h.cue.trim();
  const place = h.place.trim();
  if (!cue && !place) return "";
  const name = /[A-Z]/.test(h.name.slice(1)) ? h.name : h.name.charAt(0).toLowerCase() + h.name.slice(1);
  let s = cue ? `After ${cue}, ${name}` : h.name;
  if (place) s += ` ${place}`;
  return s + ".";
}
