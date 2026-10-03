// Progress, streaks and the day's agenda: a straight port of the iPhone app's Engine and Agenda.
import * as D from "./date.js";
import { activeHabits, dailyRequirement, isScheduled, sortedSlots, normalizeRecord, recordIsEmpty, uuid, iso } from "./model.js";

export const KEPT = new Set(["done", "minimum", "clean"]);
export const MISS = new Set(["missed", "slipped"]);
export const isVote = (s) => KEPT.has(s) || s === "extra";
export const MILESTONES = [7, 21, 30, 66, 100, 200, 365, 500, 1000];

export const PERIODS = [
  { id: "anytime", title: "Through the day", caption: "Whenever it fits" },
  { id: "earlyMorning", title: "Early morning", caption: "Before dawn · 3:30 – 6:00" },
  { id: "morning", title: "Morning", caption: "6:00 – 12:00" },
  { id: "afternoon", title: "Afternoon", caption: "12:00 – 5:00" },
  { id: "evening", title: "Evening", caption: "5:00 – 9:00" },
  { id: "night", title: "Night", caption: "After 9:00" },
];
const PERIOD_INDEX = Object.fromEntries(PERIODS.map((p, i) => [p.id, i]));

export function periodOf(min) {
  if (min >= 210 && min < 360) return "earlyMorning";
  if (min >= 360 && min < 720) return "morning";
  if (min >= 720 && min < 1020) return "afternoon";
  if (min >= 1020 && min < 1260) return "evening";
  return "night";
}

/** Builds a read-only view over `days` (raw day → record) for one "today". */
export function makeEngine(habits, days, todayJ) {
  const index = new Map(); // habitID -> Map(jdn -> entries)
  const firstDay = new Map();
  for (const [rawDay, record] of Object.entries(days)) {
    const j = D.parse(rawDay);
    if (j === null) continue;
    for (const e of record.entries || []) {
      if (!index.has(e.habitID)) index.set(e.habitID, new Map());
      const byDay = index.get(e.habitID);
      if (!byDay.has(j)) byDay.set(j, []);
      byDay.get(j).push(e);
      firstDay.set(e.habitID, Math.min(firstDay.get(e.habitID) ?? Infinity, j));
    }
  }
  const entries = (id, j) => index.get(id)?.get(j) ?? [];
  const statsCache = new Map();

  const startDay = (h) => Math.min(D.parse(h.createdOn) ?? todayJ, firstDay.get(h.id) ?? Infinity);

  function doneSlotIDs(h, j) {
    const es = entries(h.id, j).filter((e) => e.kind === "done");
    const slots = sortedSlots(h);
    const valid = new Set(slots.map((s) => s.id));
    const done = new Set();
    let loose = 0;
    for (const e of es) {
      if (e.slotID && valid.has(e.slotID)) done.add(e.slotID);
      else loose += 1;
    }
    for (const s of slots) {
      if (loose > 0 && !done.has(s.id)) { done.add(s.id); loose -= 1; }
    }
    return done;
  }

  function progress(h, j) {
    const es = entries(h.id, j);
    const scheduled = isScheduled(h, j);
    const minimum = es.some((e) => e.kind === "minimum");
    const slipped = es.some((e) => e.kind === "slip");
    const required = dailyRequirement(h);
    let done;
    if (h.kind === "check" || h.kind === "timed") done = h.slots.length === 0 ? (es.some((e) => e.kind === "done") ? 1 : 0) : doneSlotIDs(h, j).size;
    else if (h.kind === "count") done = es.filter((e) => e.kind === "done").reduce((n, e) => n + Math.max(0, e.amount), 0);
    else done = slipped ? 0 : 1;

    let status;
    if (j > todayJ) status = "future";
    else if (j < startDay(h)) status = "notStarted";
    else if (h.kind === "quit") status = slipped ? "slipped" : !scheduled ? "rest" : j === todayJ ? "holding" : "clean";
    else if (done >= required) status = scheduled ? "done" : "extra";
    else if (minimum) status = scheduled ? "minimum" : "extra";
    else if (!scheduled) status = "rest";
    else if (j === todayJ) status = done > 0 ? "partial" : "pending";
    else status = "missed";
    return { done, required, minimum, slipped, scheduled, status, complete: done >= required, fraction: Math.min(1, done / required) };
  }

  function timing(h) {
    if (h.kind !== "check" && h.kind !== "timed") return [];
    const out = [];
    for (const slot of sortedSlots(h)) {
      const planned = D.parseTime(slot.time);
      const diffs = [];
      for (let j = todayJ - 41; j <= todayJ; j++) {
        for (const e of entries(h.id, j)) {
          if (e.kind !== "done" || e.slotID !== slot.id) continue;
          let at = new Date(e.at);
          if (h.kind === "timed") at = new Date(at.getTime() - Math.max(0, e.amount) * 60000);
          let diff = D.minutesOf(at) - planned;
          if (diff > 720) diff -= 1440; else if (diff < -720) diff += 1440;
          diffs.push(diff);
        }
      }
      if (diffs.length < 5) continue;
      const median = [...diffs].sort((a, b) => a - b)[Math.floor(diffs.length / 2)];
      if (Math.abs(median) < 20) continue;
      const rounded = Math.round(median / 5) * 5;
      out.push({ slotID: slot.id, planned, typical: (((planned + rounded) % 1440) + 1440) % 1440, drift: rounded, samples: diffs.length });
    }
    return out;
  }

  function stats(h) {
    if (statsCache.has(h.id)) return statsCache.get(h.id);
    const start = startDay(h);
    let run = 0, best = 0, misses = 0, votes = 0, kept30 = 0, scheduled30 = 0;
    for (let j = start; j <= todayJ; j++) {
      const s = progress(h, j).status;
      if (isVote(s)) votes += 1;
      if (KEPT.has(s)) { run += 1; misses = 0; }
      else if (MISS.has(s)) { misses += 1; if (misses >= 2) run = 0; }
      best = Math.max(best, run);
      if (j >= todayJ - 29) { if (KEPT.has(s)) { kept30 += 1; scheduled30 += 1; } else if (MISS.has(s)) scheduled30 += 1; }
    }
    const previous = [...MILESTONES].reverse().find((m) => m <= votes) ?? 0;
    const next = MILESTONES.find((m) => m > votes) ?? (Math.floor(votes / 500) + 1) * 500;
    const result = {
      current: run, best, atRisk: misses === 1, votes, kept30, scheduled30,
      rate30: scheduled30 ? kept30 / scheduled30 : null,
      previousMilestone: previous, nextMilestone: next,
      milestoneProgress: next - previous > 0 ? (votes - previous) / (next - previous) : 0,
      timing: timing(h),
    };
    statsCache.set(h.id, result);
    return result;
  }

  function agenda(j, active) {
    const items = [];
    for (const h of active) {
      if (!isScheduled(h, j) || startDay(h) > j) continue;
      const p = progress(h, j);
      if (h.kind === "check" || h.kind === "timed") {
        if (h.slots.length === 0) {
          items.push({ id: h.id, habitID: h.id, kind: h.kind, slotID: null, time: null, period: "anytime", done: p.complete, amount: p.done, target: 1, order: h.order });
        } else {
          const done = doneSlotIDs(h, j);
          for (const s of sortedSlots(h)) {
            const t = D.parseTime(s.time);
            items.push({ id: `${h.id}|${s.id}`, habitID: h.id, kind: h.kind, slotID: s.id, time: t, period: periodOf(t), done: done.has(s.id), amount: done.has(s.id) ? 1 : 0, target: 1, order: h.order });
          }
        }
      } else if (h.kind === "count") {
        const t = h.slots.length === 1 ? D.parseTime(h.slots[0].time) : null;
        items.push({ id: h.id, habitID: h.id, kind: "count", slotID: null, time: t, period: t === null ? "anytime" : periodOf(t), done: p.complete, amount: p.done, target: p.required, order: h.order });
      } else {
        const first = sortedSlots(h)[0];
        const t = first ? D.parseTime(first.time) : null;
        items.push({ id: h.id, habitID: h.id, kind: "quit", slotID: null, time: t, period: t === null ? "anytime" : periodOf(t), done: !p.slipped, amount: p.slipped ? 0 : 1, target: 1, order: h.order });
      }
    }
    return items.sort((a, b) =>
      PERIOD_INDEX[a.period] - PERIOD_INDEX[b.period] ||
      (a.time === null ? -1 : D.dayOrder(a.time)) - (b.time === null ? -1 : D.dayOrder(b.time)) ||
      a.order - b.order || a.id.localeCompare(b.id));
  }

  return {
    today: todayJ,
    startDay, doneSlotIDs, progress, stats, timing, agenda,
    summary(j, active) {
      const items = agenda(j, active);
      const done = items.filter((i) => i.done).length;
      return { done, total: items.length, fraction: items.length ? done / items.length : 0, complete: items.length > 0 && done === items.length };
    },
    upNext(j, active, nowMin) {
      const open = agenda(j, active).filter((i) => !i.done && i.kind !== "quit");
      const timed = open.filter((i) => i.time !== null);
      return timed.find((i) => D.dayOrder(i.time) >= D.dayOrder(nowMin) - 30) ?? timed[0] ?? open[0] ?? null;
    },
    atRisk(active) {
      return active.filter((h) => isScheduled(h, todayJ) && !KEPT.has(progress(h, todayJ).status) && stats(h).atRisk);
    },
    rate(from, to, active) {
      let kept = 0, scheduled = 0;
      for (const h of active) {
        for (let j = Math.max(from, startDay(h)); j <= to; j++) {
          const s = progress(h, j).status;
          if (KEPT.has(s)) { kept += 1; scheduled += 1; } else if (MISS.has(s)) scheduled += 1;
        }
      }
      return { kept, scheduled };
    },
  };
}

export function freshStart(j, prefs) {
  const { m, d } = D.ymd(j);
  if (prefs.birthdayMonth === m && prefs.birthdayDay === d) return "birthday";
  if (m === 1 && d === 1) return "year";
  if (d === 1) return "month";
  if (D.weekday(j) === 2) return "week";
  return null;
}

// ---- Changes to a day's record. Each returns a new record, or null when nothing changed. ----

const withEntry = (record, entry) => ({ ...record, entries: [...(record.entries || []), entry] });

export function complete(record, habit, slotID, { at = new Date(), amount = 1 } = {}) {
  record = normalizeRecord(record);
  const doneEntries = record.entries.filter((e) => e.habitID === habit.id && e.kind === "done");
  if (habit.kind === "quit") return null;
  if (habit.kind === "count") return withEntry(record, { id: uuid(), habitID: habit.id, kind: "done", amount: Math.max(1, amount), at: iso(at) });
  if (habit.slots.length === 0) {
    if (doneEntries.length) return null;
    return withEntry(record, { id: uuid(), habitID: habit.id, kind: "done", amount: Math.max(1, amount), at: iso(at) });
  }
  // Work out which preferred times are done, with loose entries filling the earliest.
  const slots = sortedSlots(habit);
  const valid = new Set(slots.map((s) => s.id));
  const done = new Set();
  let loose = 0;
  for (const e of doneEntries) { if (e.slotID && valid.has(e.slotID)) done.add(e.slotID); else loose += 1; }
  for (const s of slots) if (loose > 0 && !done.has(s.id)) { done.add(s.id); loose -= 1; }
  const target = slotID && valid.has(slotID) ? slotID : slots.find((s) => !done.has(s.id))?.id;
  if (!target || done.has(target)) return null;
  return withEntry(record, { id: uuid(), habitID: habit.id, kind: "done", slotID: target, amount: Math.max(1, amount), at: iso(at) });
}

export function undo(record, habitID, slotID) {
  record = normalizeRecord(record);
  const entries = [...record.entries];
  let idx = -1;
  for (let i = entries.length - 1; i >= 0; i--) {
    const e = entries[i];
    if (e.habitID === habitID && e.kind === "done" && (!slotID || e.slotID === slotID || !e.slotID)) { idx = i; break; }
  }
  if (idx < 0) {
    for (let i = entries.length - 1; i >= 0; i--) if (entries[i].habitID === habitID && entries[i].kind === "minimum") { idx = i; break; }
  }
  if (idx < 0) return null;
  entries.splice(idx, 1);
  return { ...record, entries };
}

export function logMinimum(record, habit, at = new Date()) {
  record = normalizeRecord(record);
  if (habit.kind === "quit" || record.entries.some((e) => e.habitID === habit.id && e.kind === "minimum")) return null;
  return withEntry(record, { id: uuid(), habitID: habit.id, kind: "minimum", amount: 0, at: iso(at) });
}

export function logSlip(record, habit, at = new Date()) {
  record = normalizeRecord(record);
  if (habit.kind !== "quit" || record.entries.some((e) => e.habitID === habit.id && e.kind === "slip")) return null;
  return withEntry(record, { id: uuid(), habitID: habit.id, kind: "slip", amount: 0, at: iso(at) });
}

export function clearSlip(record, habitID) {
  record = normalizeRecord(record);
  const entries = record.entries.filter((e) => !(e.habitID === habitID && e.kind === "slip"));
  return entries.length === record.entries.length ? null : { ...record, entries };
}

export { recordIsEmpty };

export function activeOnly(habits) {
  return activeHabits(habits);
}
