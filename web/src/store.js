// App state: habits, days and settings live in this artifact's database (one document each), with
// local changes shown immediately and written one at a time per document. Without a database the
// app still runs and keeps data in this browser only.
import { useSyncExternalStore } from "react";
import * as D from "./core/date.js";
import { activeHabits, defaultPreferences, iso, normalizeHabit, normalizePreferences, normalizeRecord, recordIsEmpty, sortedSlots } from "./core/model.js";
import * as E from "./core/engine.js";
import * as Q from "./core/quotes.js";
import { convertChain, exportBackup, readBackup } from "./core/backup.js";
import { makeHabit } from "./core/templates.js";

const HABITS = "hx_habits";
const DAYS = "hx_days";
const SETTINGS = "hx_settings/main";
const LOCAL_KEY = "hexis.local.v1";
const TIMER_KEY = "hexis.timer.v1";

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const safeStorage = {
  get(key) { try { return JSON.parse(localStorage.getItem(key) || "null"); } catch { return null; } },
  set(key, value) { try { if (value === null) localStorage.removeItem(key); else localStorage.setItem(key, JSON.stringify(value)); } catch { /* storage unavailable */ } },
};

// ---- Server state, local overlay, and the merged snapshot the UI reads ----

const srv = { habits: new Map(), days: {}, settings: null, loaded: { habits: false, days: false, settings: false } };
const overlay = new Map(); // path -> { value } (value null = delete)
const flushing = new Set();
let db = null;
let downloads = null;
let mode = null; // "db" | "local"
let canWrite = true;
let legacy = null; // Habit Chain data on this page, if any
let ui = { tab: "today", route: null, toast: null, celebration: 0, finished: null, timer: safeStorage.get(TIMER_KEY) };
let clock = { today: D.today(), nowMin: D.minutesOf(new Date()) };
let snapshot = null;
const listeners = new Set();

function normSettings(raw) {
  const r = raw && typeof raw === "object" ? raw : {};
  return {
    preferences: normalizePreferences(r.preferences),
    favoriteQuotes: Array.isArray(r.favoriteQuotes) ? r.favoriteQuotes.filter((x) => typeof x === "string") : [],
    flags: r.flags && typeof r.flags === "object" ? Object.fromEntries(Object.entries(r.flags).filter(([, v]) => typeof v === "string")) : {},
  };
}

function rebuild() {
  const habitsById = new Map(srv.habits);
  const days = { ...srv.days };
  let settings = srv.settings;
  for (const [path, { value }] of overlay) {
    const [col, id] = path.split("/");
    if (col === HABITS) { if (value) habitsById.set(id, normalizeHabit(value)); else habitsById.delete(id); }
    else if (col === DAYS) { if (value) days[id] = normalizeRecord(value); else delete days[id]; }
    else if (path === SETTINGS) settings = value ? normSettings(value) : null;
  }
  const habits = [...habitsById.values()].filter(Boolean);
  const s = settings ?? { preferences: { ...defaultPreferences(), onboarded: habits.length > 0 }, favoriteQuotes: [], flags: {} };
  const active = activeHabits(habits);
  const ready = mode === "local" || (srv.loaded.habits && srv.loaded.days && srv.loaded.settings);
  snapshot = {
    status: ready ? "ready" : "loading",
    mode, canWrite, legacy, hasDownloads: !!downloads,
    habits, active,
    archived: habits.filter((h) => h.archived).sort((a, b) => a.name.localeCompare(b.name)),
    days,
    settings: s,
    prefs: s.preferences,
    favorites: s.favoriteQuotes,
    flags: s.flags,
    today: clock.today,
    nowMin: clock.nowMin,
    engine: E.makeEngine(habits, days, clock.today),
    ...ui,
  };
}

function emit() {
  rebuild();
  for (const l of listeners) l();
}

export function useHexis() {
  return useSyncExternalStore(
    (l) => { listeners.add(l); return () => listeners.delete(l); },
    () => snapshot,
  );
}

// ---- Writing ----

let inflight = 0;
const waiting = [];
async function withSlot(fn) {
  while (inflight >= 4) await new Promise((r) => waiting.push(r));
  inflight += 1;
  try { return await fn(); } finally { inflight -= 1; waiting.shift()?.(); }
}

async function writeRemote(path, value) {
  const ref = db.doc(path);
  const run = () => (value === null ? ref.delete() : ref.set(value));
  try { await run(); }
  catch (e) {
    if (e?.code !== "unavailable") throw e;
    await sleep(300 + Math.random() * 700);
    await run();
  }
}

function writeFailed(e) {
  const code = e?.code;
  if (code === "invalid_argument" || code === "not_granted" || code === "revoked") {
    canWrite = false;
    toast("This page is view-only for you, so changes can't be saved.", "eye");
  } else if (code === "quota_exceeded") {
    toast("This page's storage is full. Delete old habits you no longer need, then try again.", "alert");
  } else {
    toast("Couldn't save that change. Check your connection and try again.", "alert");
  }
}

async function flush(path) {
  flushing.add(path);
  try {
    for (;;) {
      const entry = overlay.get(path);
      if (!entry) break;
      try {
        await withSlot(() => writeRemote(path, entry.value));
      } catch (e) {
        if (overlay.get(path) === entry) overlay.delete(path);
        writeFailed(e);
        emit();
        break;
      }
      if (overlay.get(path) === entry) { overlay.delete(path); emit(); break; }
    }
  } finally {
    flushing.delete(path);
  }
}

let persistTimer = null;
function persistLocal() {
  clearTimeout(persistTimer);
  persistTimer = setTimeout(() => {
    safeStorage.set(LOCAL_KEY, { habits: [...srv.habits.values()], days: srv.days, settings: srv.settings });
  }, 250);
}

function put(path, value) {
  if (mode === "local") {
    const [col, id] = path.split("/");
    if (col === HABITS) { if (value) srv.habits.set(id, normalizeHabit(value)); else srv.habits.delete(id); }
    else if (col === DAYS) { if (value) srv.days[id] = normalizeRecord(value); else delete srv.days[id]; }
    else if (path === SETTINGS) srv.settings = value ? normSettings(value) : null;
    persistLocal();
    return;
  }
  overlay.set(path, { value });
  if (!flushing.has(path)) flush(path);
}

function guard() {
  if (snapshot.status !== "ready") return false;
  if (!canWrite) { toast("This page is view-only for you, so changes can't be saved.", "eye"); return false; }
  return true;
}

const habitBody = (h) => ({ ...h });
const dayBody = (raw, record) => ({ day: raw, ...record });

function saveRecord(j, record) {
  const raw = D.raw(j);
  put(`${DAYS}/${raw}`, recordIsEmpty(record) ? null : dayBody(raw, normalizeRecord(record)));
}

function saveSettings(change) {
  const next = structuredClone(snapshot.settings);
  change(next);
  put(SETTINGS, next);
}

/** Applies a change to one day's record and celebrates when it completes today. */
function changeDay(j, fn) {
  if (!guard()) return false;
  const before = snapshot.engine.summary(snapshot.today, snapshot.active);
  const current = snapshot.days[D.raw(j)] ?? { entries: [] };
  const next = fn(current);
  if (!next) return false;
  saveRecord(j, next);
  rebuild();
  const after = snapshot.engine.summary(snapshot.today, snapshot.active);
  if (j === snapshot.today && !before.complete && after.complete) ui = { ...ui, celebration: ui.celebration + 1 };
  emit();
  return true;
}

// ---- UI state ----

let toastSeq = 0;
function toast(message, icon = "check", quote = null) {
  ui = { ...ui, toast: { id: ++toastSeq, message, icon, quote } };
  emit();
}

function quote(moment, salt = 0) {
  return Q.pick(moment, snapshot.today, snapshot.prefs.tradition, salt);
}

// ---- Public actions ----

export const hx = {
  get: () => snapshot,
  quote,
  dailyQuote: () => Q.daily(snapshot.today, snapshot.prefs.tradition),
  record: (j) => normalizeRecord(snapshot.days[D.raw(j)]),
  habit: (id) => snapshot.habits.find((h) => h.id === id),

  setTab(tab) { ui = { ...ui, tab }; emit(); },
  open(route) { ui = { ...ui, route }; emit(); },
  close() { ui = { ...ui, route: null }; emit(); },
  dismissToast(id) { if (ui.toast?.id === id) { ui = { ...ui, toast: null }; emit(); } },
  toast,

  /** The main tap on a habit's ring: complete it, add one, open the timer, or log a slip. */
  tap(item, j) {
    const habit = hx.habit(item.habitID);
    if (!habit) return;
    switch (habit.kind) {
      case "check":
        if (item.done) hx.undo(item, j); else hx.complete(habit, item.slotID, j);
        break;
      case "count":
        changeDay(j, (r) => E.complete(r, habit, null));
        break;
      case "timed":
        if (item.done) hx.undo(item, j);
        else if (j === snapshot.today) hx.open({ name: "timer", habitID: habit.id, slotID: item.slotID });
        else hx.complete(habit, item.slotID, j, { minutes: habit.target });
        break;
      case "quit":
        if (item.done) hx.slip(habit, j); else changeDay(j, (r) => E.clearSlip(r, habit.id));
        break;
    }
  },
  complete(habit, slotID, j, { minutes, at } = {}) {
    const when = at ?? (j === snapshot.today ? new Date() : D.dateAt(j, 720));
    changeDay(j, (r) => E.complete(r, habit, slotID, { at: when, amount: minutes ?? 1 }));
  },
  undo(item, j) { changeDay(j, (r) => E.undo(r, item.habitID, item.slotID)); },
  decrement(habit, j) { changeDay(j, (r) => E.undo(r, habit.id, null)); },
  logMinimum(habit, j) {
    if (changeDay(j, (r) => E.logMinimum(r, habit))) toast("The minimum counts. Your chain is safe.", "leaf", quote("minimum"));
  },
  slip(habit, j) {
    if (changeDay(j, (r) => E.logSlip(r, habit))) toast("Logged honestly. That's the practice. Begin again now.", "undo", quote("slip"));
  },

  saveHabit(habit, isNew) {
    if (!guard()) return;
    const h = normalizeHabit({ ...habit, slots: sortedSlots(habit), target: habit.kind === "check" ? 1 : habit.target });
    if (isNew) h.order = Math.max(-1, ...snapshot.active.map((x) => x.order)) + 1;
    put(`${HABITS}/${h.id}`, habitBody(h));
    emit();
    if (isNew) toast(`${h.name} added. Your first vote is waiting.`, "plus", quote("newHabit"));
  },
  setArchived(habit, archived) {
    if (!guard()) return;
    const h = { ...hx.habit(habit.id), archived };
    if (!archived) h.order = Math.max(-1, ...snapshot.active.map((x) => x.order)) + 1;
    put(`${HABITS}/${h.id}`, habitBody(h));
    emit();
    toast(archived ? `${h.name} archived. Its history is kept.` : `${h.name} is back on Today.`, archived ? "archive" : "check");
  },
  deleteHabit(habit) {
    if (!guard()) return;
    put(`${HABITS}/${habit.id}`, null);
    for (const [raw, record] of Object.entries(snapshot.days)) {
      if (!record.entries.some((e) => e.habitID === habit.id) && record.focusHabitID !== habit.id) continue;
      const next = { ...record, entries: record.entries.filter((e) => e.habitID !== habit.id) };
      if (next.focusHabitID === habit.id) delete next.focusHabitID;
      saveRecord(D.parse(raw), next);
    }
    emit();
    toast(`${habit.name} deleted.`, "trash");
  },
  reorder(ids) {
    if (!guard()) return;
    ids.forEach((id, i) => {
      const h = hx.habit(id);
      if (h && h.order !== i) put(`${HABITS}/${id}`, habitBody({ ...h, order: i }));
    });
    emit();
  },
  applyTimingSuggestion(habitID, slotID, minutes) {
    if (!guard()) return;
    const h = hx.habit(habitID);
    if (!h) return;
    put(`${HABITS}/${h.id}`, habitBody({ ...h, slots: h.slots.map((s) => (s.id === slotID ? { ...s, time: D.formatTime(minutes) } : s)) }));
    emit();
    toast(`Moved to ${D.displayTime(minutes)}. Plans that match real life stick.`, "clock");
  },

  setSankalpa(intention, focusID) {
    changeDay(snapshot.today, (r) => {
      const next = { ...r, intention: intention.trim() };
      if (focusID) next.focusHabitID = focusID; else delete next.focusHabitID;
      return next;
    });
  },
  saveReview(review, note) {
    const done = changeDay(snapshot.today, (r) => {
      const next = { ...r, review: { cured: review.cured.trim(), resisted: review.resisted.trim(), better: review.better.trim(), savedAt: iso() } };
      if (note.trim()) next.note = note.trim(); else delete next.note;
      return next;
    });
    if (done) toast("Day reviewed. Sleep well.", "moon", quote("evening", 3));
  },

  updatePreferences(patch) {
    if (!guard()) return;
    saveSettings((s) => { s.preferences = { ...s.preferences, ...patch }; for (const k of Object.keys(patch)) if (patch[k] === undefined) delete s.preferences[k]; });
    emit();
  },
  setFlag(key, value) {
    if (!guard()) return;
    saveSettings((s) => { if (value == null) delete s.flags[key]; else s.flags[key] = value; });
    emit();
  },
  toggleFavorite(id) {
    if (!guard()) return;
    saveSettings((s) => { s.favoriteQuotes = s.favoriteQuotes.includes(id) ? s.favoriteQuotes.filter((x) => x !== id) : [...s.favoriteQuotes, id]; });
    emit();
  },

  finishOnboarding(templates, importChain) {
    if (!guard()) return;
    let order = 0;
    if (importChain && legacy) order = mergeHabits(convertChain(legacy.habits, legacy.months));
    for (const t of templates) {
      const h = makeHabit(t, D.raw(snapshot.today), order++);
      put(`${HABITS}/${h.id}`, habitBody(h));
    }
    saveSettings((s) => { s.preferences.onboarded = true; if (importChain && legacy) s.flags.chainImported = D.raw(snapshot.today); });
    emit();
  },
  importChain() {
    if (!guard() || !legacy) return;
    const converted = convertChain(legacy.habits, legacy.months);
    mergeHabits(converted);
    saveSettings((s) => { s.flags.chainImported = D.raw(snapshot.today); });
    emit();
    toast(`Imported ${converted.habits.length} habits from Habit Chain.`, "download");
  },

  async exportBackup() {
    if (!downloads) return;
    const text = exportBackup({ habits: snapshot.habits, days: snapshot.days, settings: snapshot.settings });
    try {
      await downloads.save({ filename: `Hexis backup ${D.raw(snapshot.today)}.json`, data: text });
      toast("Backup saved.", "download");
    } catch (e) {
      if (e?.code === "declined") return;
      if (e?.code === "rate_limited") toast("A save is already waiting for your answer.", "alert");
      else toast("Couldn't save the backup here. Try again in a moment.", "alert");
    }
  },
  readBackup,
  restore(imported) {
    if (!guard()) return;
    if (imported.type === "hexis") {
      const keepHabits = new Set(imported.habits.map((h) => h.id));
      for (const h of snapshot.habits) if (!keepHabits.has(h.id)) put(`${HABITS}/${h.id}`, null);
      for (const raw of Object.keys(snapshot.days)) if (!imported.days[raw]) put(`${DAYS}/${raw}`, null);
      for (const h of imported.habits) put(`${HABITS}/${h.id}`, habitBody(h));
      for (const [raw, record] of Object.entries(imported.days)) if (!recordIsEmpty(record)) put(`${DAYS}/${raw}`, dayBody(raw, record));
      put(SETTINGS, imported.settings);
      emit();
      toast("Backup restored.", "download");
    } else {
      mergeHabits(imported);
      emit();
      toast(`Imported ${imported.habits.length} habits from Habit Chain.`, "download");
    }
  },

  // ---- Timer for timed habits (kept per device) ----
  startTimer(habit, slotID) {
    const now = Date.now();
    ui = { ...ui, finished: null, timer: { habitID: habit.id, slotID: slotID ?? null, day: snapshot.today, minutes: habit.target, start: now, end: now + habit.target * 60000, pausedAt: null } };
    safeStorage.set(TIMER_KEY, ui.timer);
    emit();
  },
  togglePause() {
    const t = ui.timer;
    if (!t) return;
    const now = Date.now();
    const next = t.pausedAt ? { ...t, start: t.start + (now - t.pausedAt), end: t.end + (now - t.pausedAt), pausedAt: null } : { ...t, pausedAt: now };
    ui = { ...ui, timer: next };
    safeStorage.set(TIMER_KEY, next);
    emit();
  },
  finishTimer(early = false) {
    const t = ui.timer;
    const habit = t && hx.habit(t.habitID);
    if (!t || !habit) { hx.cancelTimer(); return; }
    const now = t.pausedAt ?? Date.now();
    ui = { ...ui, timer: null, finished: t.habitID };
    safeStorage.set(TIMER_KEY, null);
    if (early && (now - (t.end - t.minutes * 60000)) / 60000 < t.minutes) hx.logMinimum(habit, t.day);
    else hx.complete(habit, t.slotID, t.day, { minutes: t.minutes, at: new Date(Math.min(now, t.end)) });
    emit();
  },
  cancelTimer() { ui = { ...ui, timer: null }; safeStorage.set(TIMER_KEY, null); emit(); },
  acknowledgeFinish() { ui = { ...ui, finished: null }; emit(); },
};

/** Adds habits and check-ins from another source without touching what's already here. Returns the next order. */
function mergeHabits({ habits, days }) {
  const existing = new Set(snapshot.habits.map((h) => h.id));
  let order = Math.max(-1, ...snapshot.active.map((x) => x.order)) + 1;
  for (const h of habits) {
    if (existing.has(h.id)) continue;
    put(`${HABITS}/${h.id}`, habitBody({ ...h, order: h.archived ? h.order : order++ }));
  }
  for (const [raw, incoming] of Object.entries(days)) {
    const current = snapshot.days[raw] ?? { entries: [] };
    const ids = new Set(current.entries.map((e) => e.id));
    const added = incoming.entries.filter((e) => !ids.has(e.id));
    const note = current.note || incoming.note;
    if (!added.length && note === current.note) continue;
    const next = { ...current, entries: [...current.entries, ...added] };
    if (note) next.note = note;
    put(`${DAYS}/${raw}`, dayBody(raw, normalizeRecord(next)));
  }
  return order;
}

// ---- Startup ----

function startLocal() {
  mode = "local";
  const saved = safeStorage.get(LOCAL_KEY);
  if (saved) {
    for (const h of saved.habits || []) { const n = normalizeHabit(h); if (n) srv.habits.set(n.id, n); }
    for (const [k, v] of Object.entries(saved.days || {})) if (D.parse(k) !== null) srv.days[k] = normalizeRecord(v);
    srv.settings = saved.settings ? normSettings(saved.settings) : null;
  }
  emit();
}

function subscribe() {
  const onError = (e) => {
    if (e?.code === "revoked") { canWrite = false; emit(); }
  };
  db.collection(HABITS).onSnapshot((snap) => {
    srv.habits = new Map();
    for (const d of snap.docs) {
      if (!d.exists) continue;
      const h = normalizeHabit({ ...d.data(), id: d.id });
      if (h) srv.habits.set(h.id, h);
    }
    srv.loaded.habits = true;
    emit();
  }, onError);
  db.collection(DAYS).onSnapshot((snap) => {
    const days = {};
    for (const d of snap.docs) if (d.exists && D.parse(d.id) !== null) days[d.id] = normalizeRecord(d.data());
    srv.days = days;
    srv.loaded.days = true;
    emit();
  }, onError);
  db.doc(SETTINGS).onSnapshot((d) => {
    srv.settings = d.exists ? normSettings(d.data()) : null;
    srv.loaded.settings = true;
    emit();
  }, onError);
}

/** Habit Chain, the tracker that lived on this page before, kept its data in `habits` and `months`. */
async function loadLegacy() {
  try {
    const [habits, months] = await Promise.all([db.collection("habits").get(), db.collection("months").get()]);
    const list = habits.docs.filter((d) => d.exists).map((d) => ({ ...d.data(), id: d.id }));
    if (!list.length) return;
    const monthMap = {};
    for (const d of months.docs) if (d.exists) monthMap[d.id] = d.data();
    legacy = { habits: list, months: monthMap };
    emit();
  } catch { /* no legacy data readable */ }
}

function tick() {
  const now = new Date();
  const today = D.today(now);
  const nowMin = D.minutesOf(now);
  if (today !== clock.today || nowMin !== clock.nowMin) {
    clock = { today, nowMin };
    emit();
  }
  const t = ui.timer;
  if (t && !t.pausedAt && Date.now() >= t.end && snapshot.status === "ready") hx.finishTimer(false);
}

export async function start() {
  rebuild();
  setInterval(tick, 15000);
  document.addEventListener("visibilitychange", () => { if (!document.hidden) tick(); });
  const claude = window.claude;
  if (!claude?.use) { startLocal(); return; }
  claude.use("downloads").then((d) => { downloads = d; emit(); }).catch(() => {});
  claude.use("user").then(async (user) => {
    if (!user) return;
    try { if ((await user.can("data.write")) === false) { canWrite = false; emit(); } } catch { /* keep inputs */ }
  }).catch(() => {});
  let found = null;
  try { found = await claude.use("db"); } catch { found = null; }
  if (!found) { startLocal(); return; }
  db = found;
  mode = "db";
  emit();
  subscribe();
  loadLegacy();
  // A timer that ran out while the page was closed is logged once data has loaded.
  const wait = setInterval(() => { if (snapshot.status === "ready") { clearInterval(wait); tick(); } }, 300);
}
