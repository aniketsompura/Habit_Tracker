// Today: the sky header, the week strip, the cards that nudge, and the day's habits by time of day.
import React, { useEffect, useMemo, useRef, useState } from "react";
import { AnimatePresence, LayoutGroup, motion } from "framer-motion";
import * as D from "../core/date.js";
import * as E from "../core/engine.js";
import { whenThen } from "../core/model.js";
import { TEMPLATES, makeHabit } from "../core/templates.js";
import { hx } from "../store.js";
import { Icon, Symbol } from "./icons.jsx";
import { Card, Describe, Eyebrow, FavoriteButton, HabitMark, Press, QuoteBlock, Ring, TraditionMark, hc, listNames, spring } from "./kit.jsx";

// ---- Sky ----

const SKY = [
  [0, 0x0a0f26, 0x1b1f4b], [270, 0x141a45, 0x3e3477], [360, 0x3a3a7a, 0xee9f5c], [450, 0x7faed3, 0xfaddaa],
  [780, 0x8dc3e6, 0xf6ead2], [1050, 0xe29a68, 0xf6d6a3], [1140, 0x4a3a6b, 0xe07a5f], [1230, 0x161c42, 0x2e2a5c], [1440, 0x0a0f26, 0x1b1f4b],
];
const mix = (a, b, t) => {
  const ch = (v, s) => (v >> s) & 0xff;
  const c = (s) => Math.round(ch(a, s) + (ch(b, s) - ch(a, s)) * t);
  return `rgb(${c(16)}, ${c(8)}, ${c(0)})`;
};
export function skyColors(minute) {
  const m = ((minute % 1440) + 1440) % 1440;
  const upper = SKY.findIndex((s) => s[0] >= m);
  if (upper <= 0) return { top: mix(SKY[0][1], SKY[0][1], 0), bottom: mix(SKY[0][2], SKY[0][2], 0) };
  const a = SKY[upper - 1], b = SKY[upper];
  const t = (m - a[0]) / Math.max(1, b[0] - a[0]);
  return { top: mix(a[1], b[1], t), bottom: mix(a[2], b[2], t) };
}
const skyIsDark = (minute) => { const m = ((minute % 1440) + 1440) % 1440; return m < 400 || m > 1110; };

const ARC_START = 240, ARC_END = 1410;

function useWidth(ref) {
  const [w, setW] = useState(360);
  useEffect(() => {
    const el = ref.current;
    if (!el) return undefined;
    const ro = new ResizeObserver(([e]) => setW(e.contentRect.width));
    ro.observe(el);
    return () => ro.disconnect();
  }, [ref]);
  return w;
}

const STARS = (() => {
  let seed = 7n;
  const out = [];
  const next = () => { seed = (seed * 6364136223846793005n + 1442695040888963407n) & 0xffffffffffffffffn; return Number(seed >> 33n) / 0xffffffff; };
  for (let i = 0; i < 40; i++) out.push({ x: next(), y: next() * 0.75, r: i % 3 === 0 ? 1.3 : 0.8 });
  return out;
})();

function SkyHeader({ day, isToday, items, habitsById, summary, nowMin }) {
  const ref = useRef(null);
  const width = useWidth(ref);
  const height = 252;
  const minute = isToday ? nowMin : 720;
  const colors = skyColors(minute);
  const dark = skyIsDark(minute);
  const fg = dark ? "#ffffff" : "#2a1f16";

  const point = (m) => {
    const left = 26, right = width - 26, base = height - 34, top = 104;
    let mm = m;
    if (mm < ARC_START - 30) mm += 1440;
    const t = Math.min(1, Math.max(0, (mm - ARC_START) / (ARC_END - ARC_START)));
    return { x: left + (right - left) * t, y: base - Math.sin(Math.PI * t) * (base - top) };
  };
  const arc = Array.from({ length: 61 }, (_, i) => point(ARC_START + ((ARC_END - ARC_START) * i) / 60));
  const path = arc.map((p, i) => `${i ? "L" : "M"}${p.x.toFixed(1)},${p.y.toFixed(1)}`).join(" ");
  const timed = items.filter((i) => i.time !== null);
  const sun = point(minute);

  return (
    <motion.header
      ref={ref}
      className="sky"
      animate={{ background: `linear-gradient(180deg, ${colors.top}, ${colors.bottom})` }}
      transition={{ duration: 1.2 }}
      style={{ background: `linear-gradient(180deg, ${colors.top}, ${colors.bottom})` }}
    >
      {dark && (
        <svg className="sky-layer" width={width} height={height} aria-hidden="true">
          {STARS.map((s, i) => <circle key={i} cx={s.x * width} cy={s.y * height} r={s.r} fill="#fff" opacity="0.6" />)}
        </svg>
      )}
      <svg className="sky-layer" width={width} height={height} aria-hidden="true">
        <path d={path} fill="none" stroke={dark ? "rgba(255,255,255,.35)" : "rgba(42,31,22,.22)"} strokeWidth="1.2" strokeLinecap="round" strokeDasharray="2 5" />
      </svg>
      {isToday && (
        <motion.div className="celestial" initial={false} animate={{ x: sun.x - 34, y: sun.y - 34 }} transition={{ duration: 1.2, ease: "easeInOut" }} aria-hidden="true">
          <div className="celestial-glow" style={{ background: `radial-gradient(circle, ${dark ? "rgba(255,255,255,.55)" : "rgba(255,201,79,.6)"}, transparent 70%)` }} />
          {dark ? <Icon name="moon" size={20} style={{ color: "#f4ebd0" }} fill="#f4ebd0" /> : <div className="sun" />}
        </motion.div>
      )}
      {timed.map((item, index) => {
        const h = habitsById.get(item.habitID);
        if (!h) return null;
        const p = point(item.time);
        const stack = timed.slice(0, index).filter((o) => Math.abs(o.time - item.time) < 25).length;
        return (
          <motion.div
            key={item.id}
            className="sky-mark"
            initial={false}
            animate={{ x: p.x - 14, y: p.y - 14 - 14 - stack * 18 }}
            transition={spring}
            style={{ background: dark ? "rgba(255,255,255,.12)" : "rgba(255,255,255,.55)" }}
            aria-hidden="true"
          >
            <HabitMark color={hc(h.color)} symbol={h.symbol} state={item.done ? "done" : "open"} size={24} doneSymbol={h.kind === "quit" ? h.symbol : "checkmark"} animated={false} />
          </motion.div>
        );
      })}
      <div className="sky-title" style={{ color: fg }}>
        <div>
          <h1>{isToday ? "Today" : D.format(day, { weekday: "long" })}</h1>
          <p className="sky-date">{D.format(day, { weekday: "long", day: "numeric", month: "long" })}</p>
        </div>
        <div className="sky-count" aria-label={`${summary.done} of ${summary.total} done`}>
          <AnimatePresence mode="popLayout" initial={false}>
            <motion.strong key={summary.done} className="num" initial={{ y: 12, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: -12, opacity: 0 }} transition={spring}>
              {summary.done}/{summary.total}
            </motion.strong>
          </AnimatePresence>
          <span>{summary.total === 0 ? "rest day" : "done"}</span>
        </div>
      </div>
    </motion.header>
  );
}

// ---- Week strip ----

function WeekStrip({ selected, today, engine, active, onSelect }) {
  const start = D.weekStart(selected);
  const canNext = start + 7 <= today;
  return (
    <nav className="week" aria-label="Choose a day">
      <button type="button" className="week-nav" onClick={() => onSelect(selected - 7)} aria-label="Previous week"><Icon name="left" size={18} /></button>
      {Array.from({ length: 7 }, (_, i) => {
        const j = start + i;
        const future = j > today;
        const isSel = j === selected;
        const s = future ? { done: 0, total: 0, fraction: 0 } : engine.summary(j, active);
        return (
          <button
            key={j}
            type="button"
            className={`day ${j === today ? "is-today" : ""} ${isSel ? "is-selected" : ""}`}
            disabled={future}
            onClick={() => onSelect(j)}
            aria-label={`${D.format(j, { weekday: "long", day: "numeric", month: "long" })}, ${s.done} of ${s.total} done`}
            aria-pressed={isSel}
          >
            <span className="day-letter">{D.WEEKDAY_LETTER[D.weekday(j) - 1]}</span>
            <span className="day-ring">
              {isSel && <motion.span layoutId="day-sel" className="day-sel" transition={spring} />}
              <Ring fraction={s.fraction} color="var(--accent)" width={2.5} size={38} />
              <span className="day-num num">{D.ymd(j).d}</span>
            </span>
          </button>
        );
      })}
      <button type="button" className="week-nav" disabled={!canNext} onClick={() => onSelect(Math.min(today, selected + 7))} aria-label="Next week"><Icon name="right" size={18} /></button>
    </nav>
  );
}

// ---- Cards ----

function UpNextCard({ item, habit, nowMin, timerRunning }) {
  const due = item.time !== null && D.dayOrder(item.time) <= D.dayOrder(nowMin) + 5;
  const timing = item.time === null ? "any time today" : Describe.relative(item.time, nowMin);
  const plan = whenThen(habit) || (habit.identity.trim() ? `Another vote for being ${habit.identity.trim()}.` : "");
  const title = habit.kind === "count" ? `Add one · ${item.amount}/${item.target}` : habit.kind === "timed" ? (timerRunning ? "Return to timer" : `Start ${habit.target}-minute timer`) : "Mark done";
  return (
    <Card tint={hc(habit.color)}>
      <div className="upnext">
        <motion.span
          className="icon-disc"
          style={{ color: hc(habit.color), "--c": hc(habit.color) }}
          animate={due ? { scale: [1, 1.08, 1] } : { scale: 1 }}
          transition={due ? { duration: 1.6, repeat: Infinity, ease: "easeInOut" } : undefined}
        >
          <Symbol name={habit.symbol} size={24} />
        </motion.span>
        <div style={{ minWidth: 0 }}>
          <Eyebrow>Up next · {timing}</Eyebrow>
          <h3 className="card-title">{habit.name}</h3>
          {plan && <p className="small muted clamp2">{plan}</p>}
        </div>
      </div>
      <Press className="btn block" style={{ background: hc(habit.color), color: "#fff", marginTop: 12 }} onClick={() => hx.tap(item, hx.get().today)}>
        {title}
      </Press>
    </Card>
  );
}

function QuoteCard({ quote, title, showOriginal, favorites }) {
  return (
    <Card>
      <div className="row-between">
        <Eyebrow icon="quote">{title}</Eyebrow>
        <div style={{ display: "flex", alignItems: "center", gap: 4 }}>
          <TraditionMark tradition={quote.tradition} />
          <FavoriteButton quote={quote} favorites={favorites} />
        </div>
      </div>
      <div style={{ marginTop: 10 }}><QuoteBlock quote={quote} showOriginal={showOriginal} /></div>
    </Card>
  );
}

function SankalpaCard({ record, focus }) {
  const has = record.intention !== undefined || record.focusHabitID !== undefined;
  if (has) {
    return (
      <Card>
        <div className="row-between" style={{ alignItems: "flex-start" }}>
          <div className="stack" style={{ gap: 6, minWidth: 0 }}>
            <Eyebrow icon="sparkles">Today's Sankalpa</Eyebrow>
            {record.intention && <p className="intention">{record.intention}</p>}
            {focus && <p className="small strong" style={{ color: "var(--accent)", display: "flex", gap: 6, alignItems: "center", margin: 0 }}><Icon name="star" size={14} fill="currentColor" />Non-negotiable: {focus.name}</p>}
          </div>
          <button type="button" className="link-btn" onClick={() => hx.open({ name: "sankalpa" })}>Edit</button>
        </div>
      </Card>
    );
  }
  return (
    <Card tint="var(--accent)">
      <button type="button" className="card-button" onClick={() => hx.open({ name: "sankalpa" })}>
        <span className="icon-disc" style={{ color: "var(--accent)", "--c": "var(--accent)" }}><Icon name="sparkles" size={22} /></span>
        <span style={{ minWidth: 0 }}>
          <span className="card-title" style={{ display: "block" }}>Set today's Sankalpa</span>
          <span className="small muted">One intention and one habit that can't slip. 20 seconds.</span>
        </span>
        <Icon name="right" size={18} style={{ color: "var(--ink2)", flex: "none" }} />
      </button>
    </Card>
  );
}

function ReviewCard({ reviewed }) {
  return (
    <Card>
      <button type="button" className="card-button" onClick={() => hx.open({ name: "review" })}>
        <span className="icon-disc" style={{ color: hc("indigo"), "--c": hc("indigo") }}><Icon name="moon" size={22} fill={reviewed ? "currentColor" : "none"} /></span>
        <span style={{ minWidth: 0 }}>
          <span className="card-title" style={{ display: "block" }}>{reviewed ? "Day reviewed" : "Evening review"}</span>
          <span className="small muted">{reviewed ? "Tap to read or change your answers." : "Seneca's three questions before sleep. Two minutes."}</span>
        </span>
        <Icon name="right" size={18} style={{ color: "var(--ink2)", flex: "none" }} />
      </button>
    </Card>
  );
}

function NeverMissTwiceCard({ habits, quote }) {
  return (
    <Card tint="var(--danger)">
      <div className="stack" style={{ gap: 10 }}>
        <Eyebrow icon="recover">Never miss twice</Eyebrow>
        <p style={{ margin: 0 }}>{listNames(habits.map((h) => h.name))} slipped last time. That's human. Keep today and the chain survives. Doing the minimum counts.</p>
        <QuoteBlock quote={quote} showOriginal={false} size={15} clamp={4} />
      </div>
    </Card>
  );
}

const FRESH_TITLE = { week: "A fresh week", month: "A fresh month", year: "A fresh year", birthday: "A new year of your life" };

function FreshStartCard({ kind, quote }) {
  const message = kind === "birthday"
    ? "Happy birthday. Whatever last year held, today starts a new one. Choose one habit to carry into it."
    : `Fresh starts are a good moment to begin again. Whatever last ${kind} held, today is a clean page.`;
  return (
    <Card tint="var(--accent)">
      <div className="stack" style={{ gap: 10 }}>
        <div className="row-between">
          <Eyebrow icon="sunrise">{FRESH_TITLE[kind]}</Eyebrow>
          <button type="button" className="icon-btn" aria-label="Dismiss" onClick={() => hx.setFlag("fresh", D.raw(hx.get().today))}><Icon name="x" size={16} /></button>
        </div>
        <p style={{ margin: 0 }}>{message}</p>
        <QuoteBlock quote={quote} showOriginal={false} size={15} clamp={4} />
      </div>
    </Card>
  );
}

function AllDoneCard({ quote, showOriginal }) {
  return (
    <Card tint="var(--accent)">
      <div className="stack" style={{ gap: 12 }}>
        <DoneMarks />
        <h3 className="card-title" style={{ fontSize: 22 }}>All done for today</h3>
        <QuoteBlock quote={quote} showOriginal={showOriginal} size={15} />
      </div>
    </Card>
  );
}

function DoneMarks() {
  const colors = ["orange", "green", "indigo", "teal", "pink"];
  return (
    <div style={{ display: "flex", gap: 6 }}>
      {colors.map((c, i) => (
        <motion.span key={c} initial={{ scale: 0.5, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} transition={{ ...spring, delay: i * 0.06 }}>
          <HabitMark color={hc(c)} symbol="checkmark" state="done" size={30} animated={false} />
        </motion.span>
      ))}
    </div>
  );
}

function EmptyToday() {
  const s = hx.get();
  return (
    <Card>
      <div className="stack" style={{ gap: 14 }}>
        <div style={{ display: "flex", gap: 10 }}>
          <HabitMark color={hc("teal")} symbol="drop.fill" state="done" size={44} animated={false} />
          <HabitMark color={hc("indigo")} symbol="book.fill" state="open" progress={0.6} size={44} animated={false} />
          <HabitMark color={hc("orange")} symbol="figure.walk" state="open" size={44} animated={false} />
        </div>
        <h3 className="card-title" style={{ fontSize: 24 }}>Start your first habit</h3>
        <p className="muted" style={{ margin: 0 }}>Add a habit and the time you want to do it. Each day you do it, its ring fills and it moves along the sky above.</p>
        <div className="chips-scroll">
          {TEMPLATES.slice(0, 6).map((t) => (
            <Press key={t.name} className="chip" style={{ "--c": hc(t.color) }} onClick={() => hx.saveHabit(makeHabit(t, D.raw(s.today)), true)}>
              <Symbol name={t.symbol} size={15} />{t.name}
            </Press>
          ))}
        </div>
        <Press className="btn primary block" onClick={() => hx.open({ name: "editor" })}>Create your own habit</Press>
      </div>
    </Card>
  );
}

// ---- Rows ----

function markState(habit, item, progress, timerRunning) {
  if (habit.kind === "quit") return { state: item.done ? "done" : "slipped" };
  if (item.done) return { state: "done" };
  if (progress.minimum) return { state: "minimum" };
  if (habit.kind === "count") return { state: "open", progress: item.amount / Math.max(1, item.target) };
  return { state: "open", progress: timerRunning ? 0.5 : 0 };
}

function hint(habit, item, isToday) {
  switch (habit.kind) {
    case "check": return item.done ? `Mark ${habit.name} not done` : `Mark ${habit.name} done`;
    case "count": return `Add one to ${habit.name}, ${item.amount} of ${item.target}`;
    case "timed": return item.done ? `Mark ${habit.name} not done` : isToday ? `Start the ${habit.target} minute timer for ${habit.name}` : `Mark ${habit.name} done`;
    default: return item.done ? `Log a slip for ${habit.name}` : `Remove the slip for ${habit.name}`;
  }
}

function AgendaRow({ item, habit, day, isToday, progress, stats, isFocus, timerRunning, menuOpen, onMenu }) {
  const { state, progress: fill = 0 } = markState(habit, item, progress, timerRunning);
  const struck = item.done && habit.kind !== "quit";
  const cue = !item.done && habit.cue.trim() ? `After ${habit.cue.trim()}${habit.place.trim() ? ` · ${habit.place.trim()}` : ""}` : null;
  return (
    <motion.div layout="position" className={`row ${isFocus ? "focus" : ""}`} transition={spring}>
      <Press className="mark-btn" onClick={() => hx.tap(item, day)} aria-label={hint(habit, item, isToday)}>
        <HabitMark color={hc(habit.color)} symbol={habit.symbol} state={state} progress={fill} size={48} doneSymbol={habit.kind === "quit" ? habit.symbol : "checkmark"} />
      </Press>
      <div style={{ minWidth: 0 }}>
        <div className="row-name-line">
          <span className={`row-name ${struck ? "done" : ""}`}>{habit.name}</span>
          {isFocus && <Icon name="star" size={12} fill="currentColor" style={{ color: "var(--accent)", flex: "none" }} aria-label="Non-negotiable today" />}
        </div>
        <div className="row-meta">
          {item.time !== null ? <span>{D.displayTime(item.time)}</span> : habit.kind === "count" && habit.slots.length > 1 ? <span>Through the day</span> : null}
          {stats.current > 0 && <span className="streak" aria-label={`${stats.current} day chain`}><Icon name="flame" size={13} fill="currentColor" />{stats.current}</span>}
          {isToday && stats.atRisk && !E.KEPT.has(progress.status) && <span className="badge risk">Never miss twice</span>}
          {progress.minimum && !item.done && <span className="badge ok">Minimum kept</span>}
        </div>
        {cue && <p className="row-cue">{cue}</p>}
      </div>
      <div className="row-end">
        <RowTrailing habit={habit} item={item} isToday={isToday} timerRunning={timerRunning} />
        <button type="button" className="more" aria-label={`More for ${habit.name}`} aria-expanded={menuOpen} onClick={onMenu}><Icon name="more" size={18} /></button>
      </div>
    </motion.div>
  );
}

function RowTrailing({ habit, item, isToday, timerRunning }) {
  if (habit.kind === "count") {
    return (
      <span className="count" style={{ color: item.done ? hc(habit.color) : "var(--ink)" }}>
        <AnimatePresence mode="popLayout" initial={false}>
          <motion.strong key={item.amount} className="num" initial={{ y: 10, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: -10, opacity: 0 }} transition={spring}>{item.amount}</motion.strong>
        </AnimatePresence>
        <small>of {item.target}</small>
      </span>
    );
  }
  if (habit.kind === "timed") return <span className="small strong" style={{ color: timerRunning ? hc(habit.color) : "var(--ink2)" }}>{timerRunning ? "Running" : `${habit.target} min`}</span>;
  if (habit.kind === "quit") return <span className="small strong" style={{ color: item.done ? "var(--success)" : "var(--danger)" }}>{item.done ? (isToday ? "Holding" : "Clean") : "Slipped"}</span>;
  return null;
}

function RowMenu({ item, habit, day, isToday, progress, onClose }) {
  const act = (fn) => () => { fn(); onClose(); };
  const actions = [];
  if (habit.kind === "quit") {
    actions.push({ icon: item.done ? "alert" : "undo", label: item.done ? "I slipped" : "Undo slip", run: () => hx.tap(item, day) });
  } else if (habit.kind === "count") {
    actions.push({ icon: "plus", label: "Add one", run: () => hx.tap(item, day) });
    if (item.amount > 0) actions.push({ icon: "minus", label: "Remove one", run: () => hx.decrement(habit, day) });
  } else {
    actions.push({
      icon: item.done ? "undo" : "check", label: item.done ? "Mark not done" : "Mark done",
      run: () => { if (item.done || habit.kind === "check" || !isToday) hx.tap(item, day); else hx.complete(habit, item.slotID, day, { minutes: habit.target }); },
    });
    if (habit.kind === "timed" && isToday && !item.done) actions.push({ icon: "timer", label: "Start timer", run: () => hx.open({ name: "timer", habitID: habit.id, slotID: item.slotID }) });
  }
  if (habit.kind !== "quit" && !progress.complete && !progress.minimum) {
    actions.push({ icon: "leaf", label: habit.minimum.trim() ? `Did the minimum: ${habit.minimum.trim()}` : "Did the minimum", run: () => hx.logMinimum(habit, day) });
  }
  actions.push({ icon: "edit", label: "Edit habit", run: () => hx.open({ name: "editor", habitID: habit.id }) });
  return (
    <motion.div
      className="row-menu"
      initial={{ opacity: 0, height: 0 }}
      animate={{ opacity: 1, height: "auto" }}
      exit={{ opacity: 0, height: 0 }}
      transition={{ duration: 0.2 }}
    >
      <div className="row-menu-inner">
        {actions.map((a) => (
          <Press key={a.label} className="menu-chip" onClick={act(a.run)}><Icon name={a.icon} size={15} />{a.label}</Press>
        ))}
      </div>
    </motion.div>
  );
}

// ---- Screen ----

export function TodayScreen({ s }) {
  const [selected, setSelected] = useState(null);
  const [menu, setMenu] = useState(null);
  const day = selected ?? s.today;
  const isToday = day === s.today;
  const engine = s.engine;
  const items = useMemo(() => engine.agenda(day, s.active), [engine, day, s.active]);
  const habitsById = useMemo(() => new Map(s.habits.map((h) => [h.id, h])), [s.habits]);
  const summary = { done: items.filter((i) => i.done).length, total: items.length };
  const record = hx.record(day);
  const showOriginal = s.prefs.showSanskrit;
  const timerHabit = s.timer?.day === s.today ? s.timer.habitID : null;

  useEffect(() => { setSelected(null); }, [s.today]);
  useEffect(() => { setMenu(null); }, [day]);

  const periods = E.PERIODS.filter((p) => items.some((i) => i.period === p.id));
  const select = (j) => setSelected(j === s.today ? null : Math.min(j, s.today));

  return (
    <>
      <SkyHeader day={day} isToday={isToday} items={items} habitsById={habitsById} summary={summary} nowMin={s.nowMin} />
      <WeekStrip selected={day} today={s.today} engine={engine} active={s.active} onSelect={select} />
      <LayoutGroup>
        <div className="stack" style={{ marginTop: 8 }}>
          {isToday ? <TodayCards s={s} items={items} record={record} habitsById={habitsById} showOriginal={showOriginal} timerHabit={timerHabit} /> : <PastDay record={record} />}

          {s.active.length === 0 ? <EmptyToday /> : items.length === 0 && (
            <p className="muted center" style={{ padding: "20px 0" }}>{isToday ? "Nothing scheduled today. Rest is part of the practice." : "Nothing was scheduled on this day."}</p>
          )}
        </div>

        {periods.map((p) => (
          <section key={p.id} aria-labelledby={`period-${p.id}`}>
            <div className="period">
              <Icon name={p.id} size={15} strokeWidth={2.4} style={{ color: "var(--accent)", alignSelf: "center" }} />
              <h2 id={`period-${p.id}`}>{p.title}</h2>
              <span className="small muted">{p.caption}</span>
            </div>
            <div className="stack" style={{ gap: 10 }}>
              {items.filter((i) => i.period === p.id).map((item) => {
                const habit = habitsById.get(item.habitID);
                if (!habit) return null;
                const progress = engine.progress(habit, day);
                return (
                  <div key={item.id}>
                    <AgendaRow
                      item={item} habit={habit} day={day} isToday={isToday} progress={progress} stats={engine.stats(habit)}
                      isFocus={isToday && record.focusHabitID === habit.id} timerRunning={isToday && timerHabit === habit.id}
                      menuOpen={menu === item.id} onMenu={() => setMenu(menu === item.id ? null : item.id)}
                    />
                    <AnimatePresence>
                      {menu === item.id && <RowMenu item={item} habit={habit} day={day} isToday={isToday} progress={progress} onClose={() => setMenu(null)} />}
                    </AnimatePresence>
                  </div>
                );
              })}
            </div>
          </section>
        ))}

        {isToday && showReview(s, record) && <div style={{ marginTop: 16 }}><ReviewCard reviewed={!!record.review} /></div>}
      </LayoutGroup>
    </>
  );
}

function showReview(s, record) {
  if (!s.prefs.eveningReview) return false;
  return s.nowMin >= Math.min(D.parseTime(s.prefs.eveningTime) - 60, 18 * 60) || !!record.review;
}

function TodayCards({ s, items, record, habitsById, showOriginal, timerHabit }) {
  const engine = s.engine;
  const fresh = E.freshStart(s.today, s.prefs);
  const atRisk = engine.atRisk(s.active);
  const hasSankalpa = record.intention !== undefined || record.focusHabitID !== undefined;
  const next = engine.upNext(s.today, s.active, s.nowMin);
  const nextHabit = next && habitsById.get(next.habitID);
  const summary = engine.summary(s.today, s.active);
  return (
    <>
      <AnimatePresence initial={false}>
        {fresh && s.flags.fresh !== D.raw(s.today) && (
          <motion.div key="fresh" layout initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, scale: 0.96 }}>
            <FreshStartCard kind={fresh} quote={hx.quote("fresh")} />
          </motion.div>
        )}
      </AnimatePresence>
      {s.legacy && !s.flags.chainImported && s.canWrite && <ChainImportCard count={s.legacy.habits.length} />}
      {atRisk.length > 0 && <NeverMissTwiceCard habits={atRisk} quote={hx.quote("miss")} />}
      {s.prefs.morningRitual && s.active.length > 0 && (hasSankalpa || s.nowMin < 15 * 60) && (
        <SankalpaCard record={record} focus={record.focusHabitID ? habitsById.get(record.focusHabitID) : null} />
      )}
      <AnimatePresence mode="popLayout" initial={false}>
        {nextHabit ? (
          <motion.div key={next.id} layout initial={{ opacity: 0, x: 40 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -20 }} transition={spring}>
            <UpNextCard item={next} habit={nextHabit} nowMin={s.nowMin} timerRunning={timerHabit === nextHabit.id} />
          </motion.div>
        ) : summary.complete ? (
          <motion.div key="alldone" layout initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }} transition={spring}>
            <AllDoneCard quote={hx.quote("dayComplete")} showOriginal={showOriginal} />
          </motion.div>
        ) : null}
      </AnimatePresence>
      <QuoteCard quote={hx.dailyQuote()} title="Today's wisdom" showOriginal={showOriginal} favorites={s.favorites} />
    </>
  );
}

function ChainImportCard({ count }) {
  return (
    <Card tint="var(--accent)">
      <div className="stack" style={{ gap: 10 }}>
        <Eyebrow icon="download">Your Habit Chain history</Eyebrow>
        <p style={{ margin: 0 }}>This page used to run Habit Chain. Bring its {count} {count === 1 ? "habit" : "habits"} and every check-in into Hexis. Your chains carry over.</p>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
          <Press className="btn primary small" onClick={() => hx.importChain()}>Bring them over</Press>
          <Press className="btn secondary small" onClick={() => hx.setFlag("chainImported", "skipped")}>Not now</Press>
        </div>
      </div>
    </Card>
  );
}

function PastDay({ record }) {
  const has = record.intention || record.review || record.note;
  return (
    <>
      {has && (
        <Card>
          <div className="stack" style={{ gap: 10 }}>
            {record.intention && (<><Eyebrow icon="sparkles">Sankalpa</Eyebrow><p className="intention">{record.intention}</p></>)}
            {record.review && (<><Eyebrow icon="moon">Evening review</Eyebrow><ReviewSummary review={record.review} /></>)}
            {record.note && (<><Eyebrow icon="edit">Log</Eyebrow><p style={{ margin: 0 }}>{record.note}</p></>)}
          </div>
        </Card>
      )}
      <p className="small muted" style={{ margin: "0 4px" }}>You can still fill in this day. Tap a ring to complete it.</p>
    </>
  );
}

export function ReviewSummary({ review }) {
  const line = (label, text) => text.trim() && <p className="small" style={{ margin: 0 }}><span className="muted strong">{label}: </span>{text}</p>;
  return (
    <div className="stack" style={{ gap: 6 }}>
      {line("Cured", review.cured)}
      {line("Resisted", review.resisted)}
      {line("Better", review.better)}
    </div>
  );
}
