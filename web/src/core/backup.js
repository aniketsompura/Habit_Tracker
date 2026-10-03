// Backups in the iPhone app's format, plus import from the earlier Habit Chain tracker.
import * as D from "./date.js";
import { iso, normalizeHabit, normalizePreferences, normalizeRecord } from "./model.js";

export function exportBackup({ habits, days, settings }) {
  const data = {
    version: 1,
    habits,
    days,
    preferences: settings.preferences,
    favoriteQuotes: settings.favoriteQuotes || [],
    flags: settings.flags || {},
  };
  return JSON.stringify({ app: "hexis", exportedAt: iso(), data }, null, 2);
}

export function readBackup(text) {
  let raw;
  try { raw = JSON.parse(text); } catch { throw new Error("That file isn't a Hexis or Habit Chain backup."); }
  if (raw?.app === "hexis" && raw.data) {
    const d = raw.data;
    const days = {};
    for (const [k, v] of Object.entries(d.days || {})) if (D.parse(k) !== null) days[k] = normalizeRecord(v);
    return {
      type: "hexis",
      habits: (d.habits || []).map(normalizeHabit).filter(Boolean),
      days,
      settings: { preferences: { ...normalizePreferences(d.preferences), onboarded: true }, favoriteQuotes: d.favoriteQuotes || [], flags: d.flags || {} },
    };
  }
  if (raw?.app === "habit-chain" && Array.isArray(raw.habits)) return { type: "chain", ...convertChain(raw.habits, raw.months || {}) };
  throw new Error("That file isn't a Hexis or Habit Chain backup.");
}

// Stable ids for Habit Chain items, so importing twice doesn't duplicate anything.
function stableUUID(text) {
  let h1 = 0x811c9dc5, h2 = 0x9e3779b9;
  for (let i = 0; i < text.length; i++) {
    h1 = Math.imul(h1 ^ text.charCodeAt(i), 16777619);
    h2 = Math.imul(h2 ^ text.charCodeAt(i), 2246822507);
  }
  const hex = [h1, h2, Math.imul(h1, 31) ^ h2, Math.imul(h2, 17) ^ h1].map((n) => (n >>> 0).toString(16).padStart(8, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-4${hex.slice(13, 16)}-a${hex.slice(17, 20)}-${hex.slice(20, 32)}`.toUpperCase();
}

const CHAIN_COLORS = { cobalt: "indigo", teal: "teal", plum: "pink", rust: "red", olive: "green", rose: "pink", amber: "yellow", slate: "graphite" };

/** Converts Habit Chain habits and month documents (`{ "2026-10": { days: { "03": { id: n } }, notes } }`). */
export function convertChain(chainHabits, months) {
  const habits = [];
  const kinds = new Map();
  chainHabits.forEach((h, i) => {
    if (!h || typeof h.id !== "string") return;
    const target = Math.max(1, Math.round(h.target || 1));
    const kind = target > 1 ? "count" : "check";
    const id = stableUUID("habit-chain:" + h.id);
    const weekdays = (Array.isArray(h.days) ? h.days : [0, 1, 2, 3, 4, 5, 6]).filter((d) => d >= 0 && d <= 6).map((d) => d + 1);
    const habit = normalizeHabit({
      id, name: h.name || "Habit", symbol: kind === "count" ? "drop.fill" : "checkmark.seal", color: CHAIN_COLORS[h.color] || "orange",
      kind, weekdays: weekdays.length ? weekdays : [1, 2, 3, 4, 5, 6, 7], slots: [], target, unit: h.unit || "",
      createdOn: D.parse(h.createdAt) !== null ? h.createdAt : D.raw(D.today()), archived: !!h.archived, order: i,
    });
    habits.push(habit);
    kinds.set(h.id, { id, kind });
  });
  const days = {};
  for (const [month, content] of Object.entries(months || {})) {
    for (const [dd, counts] of Object.entries(content?.days || {})) {
      const j = D.parse(`${month}-${dd}`);
      if (j === null) continue;
      const key = D.raw(j);
      const record = days[key] || { entries: [] };
      for (const [chainID, value] of Object.entries(counts || {})) {
        const info = kinds.get(chainID);
        if (!info || !(value > 0)) continue;
        record.entries.push({ id: stableUUID(`${chainID}|${key}`), habitID: info.id, kind: "done", amount: info.kind === "count" ? Math.round(value) : 1, at: iso(D.dateAt(j, 720)) });
      }
      days[key] = record;
    }
    for (const [dd, text] of Object.entries(content?.notes || {})) {
      const j = D.parse(`${month}-${dd}`);
      if (j === null || !String(text).trim()) continue;
      const key = D.raw(j);
      days[key] = { ...(days[key] || { entries: [] }), note: String(text) };
    }
  }
  return { habits, days };
}
