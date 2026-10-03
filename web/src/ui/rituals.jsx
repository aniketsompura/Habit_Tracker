// Sankalpa, the evening review, the timer, settings and the first-run welcome.
import React, { useEffect, useRef, useState } from "react";
import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import * as D from "../core/date.js";
import { quoteById } from "../core/quotes.js";
import { TEMPLATES } from "../core/templates.js";
import { hx } from "../store.js";
import { Icon, Symbol } from "./icons.jsx";
import { Card, Eyebrow, HabitMark, Press, QuoteBlock, Ring, Seg, Sheet, Toggle, hc, spring } from "./kit.jsx";
import { QUOTE_COUNT } from "./journey.jsx";

// ---- Sankalpa ----

export function SankalpaSheet({ s, onClose }) {
  const record = hx.record(s.today);
  const [intention, setIntention] = useState(record.intention ?? "");
  const [focus, setFocus] = useState(record.focusHabitID ?? null);
  const [lit, setLit] = useState(false);
  const ids = [];
  for (const item of s.engine.agenda(s.today, s.active)) if (!ids.includes(item.habitID)) ids.push(item.habitID);
  const habits = ids.map((id) => hx.habit(id)).filter(Boolean);
  const quote = hx.quote("morning");
  const commit = () => {
    setLit(true);
    hx.setSankalpa(intention, focus);
    setTimeout(onClose, 900);
  };
  return (
    <Sheet open onClose={onClose} label="Sankalpa">
      <div className="stack" style={{ gap: 22, paddingTop: 8 }}>
        <div className="ritual-head">
          <HabitMark color="var(--accent)" symbol="sparkles" state={lit ? "done" : "open"} size={84} doneSymbol="sparkles" />
          <h2 className="ritual-title">Sankalpa</h2>
          <p className="muted" style={{ margin: 0 }}>A small, clear resolve for today.</p>
        </div>
        <div className="field">
          <label htmlFor="sankalpa-intention">Today I will…</label>
          <textarea id="sankalpa-intention" className="input big" rows={2} placeholder="be patient in every conversation" value={intention} onChange={(e) => setIntention(e.target.value)} maxLength={200} />
        </div>
        {habits.length > 0 && (
          <div className="field">
            <span>The one habit that can't slip</span>
            <div className="focus-grid">
              {habits.map((h) => {
                const chosen = focus === h.id;
                return (
                  <Press key={h.id} className={`chip focus-chip ${chosen ? "on" : ""}`} style={{ "--c": hc(h.color) }} aria-pressed={chosen} onClick={() => setFocus(chosen ? null : h.id)}>
                    <AnimatePresence mode="popLayout" initial={false}>
                      <motion.span key={String(chosen)} initial={{ scale: 0.3, rotate: -40 }} animate={{ scale: 1, rotate: 0 }} transition={spring} style={{ display: "grid" }}>
                        {chosen ? <Icon name="star" size={15} fill="currentColor" /> : <Symbol name={h.symbol} size={15} />}
                      </motion.span>
                    </AnimatePresence>
                    <span className="ellipsis">{h.name}</span>
                  </Press>
                );
              })}
            </div>
            <p className="section-foot" style={{ margin: 0 }}>It gets a star on Today. Choosing one thing in advance makes it far more likely to happen.</p>
          </div>
        )}
        <Card><QuoteBlock quote={quote} showOriginal={s.prefs.showSanskrit} size={16} /></Card>
        <Press className="btn primary block" disabled={lit} onClick={commit}>{lit ? "Sankalpa set" : "Set Sankalpa"}</Press>
      </div>
    </Sheet>
  );
}

// ---- Evening review ----

export function ReviewSheet({ s, onClose }) {
  const record = hx.record(s.today);
  const [cured, setCured] = useState(record.review?.cured ?? "");
  const [resisted, setResisted] = useState(record.review?.resisted ?? "");
  const [better, setBetter] = useState(record.review?.better ?? "");
  const [note, setNote] = useState(record.note ?? "");
  const summary = s.engine.summary(s.today, s.active);
  const seneca = quoteById("seneca-anger-3-36-questions");
  const save = () => { hx.saveReview({ cured, resisted, better }, note); onClose(); };
  const prompt = (id, title, placeholder, value, set) => (
    <div className="field">
      <label htmlFor={id} className="prompt">{title}</label>
      <textarea id={id} className="input" rows={2} placeholder={placeholder} value={value} onChange={(e) => set(e.target.value)} maxLength={500} />
    </div>
  );
  return (
    <Sheet open onClose={onClose} label="Evening review">
      <div className="stack" style={{ gap: 20, paddingTop: 8 }}>
        <div className="stack" style={{ gap: 6 }}>
          <motion.span initial={{ scale: 0.6, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} transition={spring} style={{ color: hc("indigo"), display: "grid", justifyItems: "start" }}>
            <Icon name="moon" size={36} fill="currentColor" />
          </motion.span>
          <h2 className="ritual-title" style={{ textAlign: "left" }}>Evening review</h2>
          <p className="muted" style={{ margin: 0 }}>{summary.done} of {summary.total} done today. However the day went, look at it honestly and kindly.</p>
        </div>
        {seneca && <Card><QuoteBlock quote={seneca} showOriginal={false} size={16} /></Card>}
        {prompt("review-cured", "Which bad habit did I cure today?", "Didn't check my phone before breakfast", cured, setCured)}
        {prompt("review-resisted", "Which fault did I resist?", "Stayed calm in traffic", resisted, setResisted)}
        {prompt("review-better", "In what way am I better?", "Read even though I was tired", better, setBetter)}
        {prompt("review-note", "Anything else to log", "Notes for future you", note, setNote)}
        <Press className="btn block" style={{ background: hc("indigo"), color: "#fff" }} onClick={save}>Save review</Press>
      </div>
    </Sheet>
  );
}

// ---- Timer ----

function useFrame(active) {
  const [, setT] = useState(0);
  useEffect(() => {
    if (!active) return undefined;
    let id;
    const loop = () => { setT((x) => x + 1); id = requestAnimationFrame(loop); };
    id = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(id);
  }, [active]);
}

const clock = (sec) => { const t = Math.ceil(Math.max(0, sec)); return `${Math.floor(t / 60)}:${String(t % 60).padStart(2, "0")}`; };

export function TimerCover({ s, habitID, slotID, onClose }) {
  const reduce = useReducedMotion();
  const habit = hx.habit(habitID);
  const t = s.timer?.habitID === habitID ? s.timer : null;
  const finished = s.finished === habitID;
  useFrame(!!t && !t.pausedAt);
  const [readyQuote] = useState(() => hx.quote("timer"));
  const [doneQuote] = useState(() => hx.quote("timer", 5));
  const close = () => { if (t && !finished) hx.cancelTimer(); hx.acknowledgeFinish(); onClose(); };
  useEffect(() => { const k = (e) => { if (e.key === "Escape") close(); }; document.addEventListener("keydown", k); return () => document.removeEventListener("keydown", k); });
  if (!habit) return null;
  const color = hc(habit.color);

  let body;
  if (finished) {
    body = (
      <motion.div key="done" className="cover-body" initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }}>
        <div className="cover-spacer" />
        <HabitMark color={color} symbol={habit.symbol} state="done" size={130} />
        <h2 className="cover-title">Session complete</h2>
        <p className="cover-quote">“{doneQuote.text}”<br />— {doneQuote.cite}</p>
        <div className="cover-spacer" />
        <Press className="btn block" style={{ background: color, color: "#fff" }} onClick={() => { hx.acknowledgeFinish(); onClose(); }}>Done</Press>
      </motion.div>
    );
  } else if (t) {
    const now = t.pausedAt ?? Date.now();
    const total = t.minutes * 60;
    const remaining = (t.end - now) / 1000;
    const elapsed = (now - t.start) / 1000;
    const phase = (1 - Math.cos((2 * Math.PI * elapsed) / 8)) / 2;
    const breathingIn = elapsed % 8 < 4;
    body = (
      <motion.div key="run" className="cover-body" initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
        <div className="cover-spacer" />
        <div className="breath" role="timer" aria-label={`${clock(remaining)} left`}>
          <div className="breath-disc" style={{ background: color, transform: `scale(${reduce || t.pausedAt ? 0.9 : 0.72 + 0.28 * phase})` }} />
          <div className="breath-ring"><Ring fraction={1 - remaining / total} color={color} width={6} size={276} /></div>
          <div className="breath-label">
            <span className="num breath-clock">{clock(remaining)}</span>
            <AnimatePresence mode="wait" initial={false}>
              <motion.span key={t.pausedAt ? "p" : breathingIn ? "in" : "out"} className="strong" initial={{ opacity: 0 }} animate={{ opacity: 0.8 }} exit={{ opacity: 0 }} transition={{ duration: 0.5 }}>
                {t.pausedAt ? "Paused" : breathingIn ? "Breathe in" : "Breathe out"}
              </motion.span>
            </AnimatePresence>
          </div>
        </div>
        <h2 className="cover-title" style={{ fontSize: 24 }}>{habit.name}</h2>
        <div className="cover-spacer" />
        <div className="cover-actions">
          <Press className="btn glass" onClick={() => hx.togglePause()}><Icon name={t.pausedAt ? "play" : "pause"} size={18} fill="currentColor" />{t.pausedAt ? "Resume" : "Pause"}</Press>
          <Press className="btn" style={{ background: color, color: "#fff" }} onClick={() => hx.finishTimer(true)}><Icon name="check" size={18} strokeWidth={3} />Finish</Press>
        </div>
        <p className="small" style={{ opacity: 0.7, margin: 0, textAlign: "center" }}>Finishing early still counts as your minimum.</p>
      </motion.div>
    );
  } else {
    body = (
      <motion.div key="ready" className="cover-body" initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
        <div className="cover-spacer" />
        <HabitMark color={color} symbol={habit.symbol} state="open" size={110} animated={false} />
        <div style={{ textAlign: "center" }}>
          <h2 className="cover-title">{habit.name}</h2>
          <p style={{ opacity: 0.8, margin: "4px 0 0", fontSize: 18 }}>{habit.target} minutes</p>
        </div>
        <p className="cover-quote">“{readyQuote.text}”<br />— {readyQuote.cite}</p>
        <div className="cover-spacer" />
        <Press className="btn block" style={{ background: color, color: "#fff" }} onClick={() => hx.startTimer(habit, slotID)}>Begin</Press>
      </motion.div>
    );
  }

  return (
    <motion.div
      className="cover timer-cover"
      role="dialog" aria-modal="true" aria-label={`${habit.name} timer`}
      style={{ "--c": color }}
      initial={{ opacity: 0, y: 40 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: 40 }} transition={{ type: "spring", stiffness: 300, damping: 32 }}
    >
      <Press className="cover-close" onClick={close} aria-label={t && !finished ? "Cancel session" : "Close"}><Icon name="x" size={20} /></Press>
      <AnimatePresence mode="wait">{body}</AnimatePresence>
    </motion.div>
  );
}

// ---- Settings ----

export function SettingsSheet({ s, onClose }) {
  const p = s.prefs;
  const [pending, setPending] = useState(null);
  const [error, setError] = useState("");
  const file = useRef(null);
  const update = (patch) => hx.updatePreferences(patch);
  const onFile = (e) => {
    const f = e.target.files?.[0];
    e.target.value = "";
    if (!f) return;
    const reader = new FileReader();
    reader.onload = () => {
      try { setPending(hx.readBackup(String(reader.result))); setError(""); }
      catch (err) { setError(err.message || "That file isn't a Hexis or Habit Chain backup."); }
    };
    reader.readAsText(f);
  };
  const birthday = p.birthdayMonth ? `${D.ymd(s.today).y}-${String(p.birthdayMonth).padStart(2, "0")}-${String(p.birthdayDay).padStart(2, "0")}` : "";
  return (
    <Sheet open onClose={onClose} title="Settings">
      <div className="stack" style={{ gap: 18 }}>
        <Group title="Daily rituals" foot="Marcus Aurelius prepared each morning; Seneca reviewed each night. Both take under two minutes.">
          <Toggle id="set-morning" label="Morning Sankalpa" checked={p.morningRitual} onChange={(v) => update({ morningRitual: v })} />
          {p.morningRitual && <TimeRow id="set-morning-time" label="Reminder time on iPhone" value={p.morningTime} onChange={(v) => update({ morningTime: v })} />}
          <Toggle id="set-evening" label="Evening review" checked={p.eveningReview} onChange={(v) => update({ eveningReview: v })} />
          {p.eveningReview && <TimeRow id="set-evening-time" label="Review time" value={p.eveningTime} onChange={(v) => update({ eveningTime: v })} />}
        </Group>

        <Group title="Wisdom" foot={`${QUOTE_COUNT.all} sourced quotes: ${QUOTE_COUNT.stoic} Stoic and ${QUOTE_COUNT.hindu} Hindu.`}>
          <div className="field" style={{ padding: "4px 0" }}>
            <span>Quotes from</span>
            <Seg label="Quotes from" value={p.tradition} onChange={(v) => update({ tradition: v })} options={[{ value: "both", label: "Both" }, { value: "stoic", label: "Stoic" }, { value: "hindu", label: "Hindu" }]} />
          </div>
          <Toggle id="set-sanskrit" label="Show Sanskrit and Hindi originals" checked={p.showSanskrit} onChange={(v) => update({ showSanskrit: v })} />
        </Group>

        <Group title="Fresh starts" foot="Mondays, the 1st of each month and your birthday get a fresh-start card. New beginnings make it easier to recommit.">
          <Toggle id="set-bday" label="Mark my birthday" checked={!!p.birthdayMonth} onChange={(on) => {
            const { m, d } = D.ymd(s.today);
            update(on ? { birthdayMonth: m, birthdayDay: d } : { birthdayMonth: undefined, birthdayDay: undefined });
          }} />
          {p.birthdayMonth && (
            <div className="toggle-row">
              <label htmlFor="set-bday-date">Birthday</label>
              <input id="set-bday-date" type="date" className="input compact" value={birthday} onChange={(e) => {
                const j = D.parse(e.target.value);
                if (j !== null) { const { m, d } = D.ymd(j); update({ birthdayMonth: m, birthdayDay: d }); }
              }} />
            </div>
          )}
        </Group>

        <Group title="Backup" foot="Habits and check-ins save to this page on claude.ai, so they follow you to any device where you open it signed in. A backup file also restores into the Hexis iPhone app.">
          {s.hasDownloads && (
            <button type="button" className="menu-row" onClick={() => hx.exportBackup()}><Icon name="upload" size={18} />Save a backup</button>
          )}
          <button type="button" className="menu-row" onClick={() => file.current?.click()} disabled={!s.canWrite}><Icon name="download" size={18} />Restore or import a backup</button>
          {s.legacy && s.flags.chainImported !== D.raw(s.today) && (
            <button type="button" className="menu-row" onClick={() => hx.importChain()} disabled={!s.canWrite}><Icon name="restore" size={18} />Import Habit Chain data from this page</button>
          )}
          <input ref={file} type="file" accept=".json,application/json" hidden onChange={onFile} aria-label="Backup file" />
          {error && <p className="small" style={{ color: "var(--danger)", margin: 0 }}>{error}</p>}
          <AnimatePresence>
            {pending && (
              <motion.div className="confirm" initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }}>
                <p className="strong" style={{ margin: 0 }}>{pending.type === "hexis" ? `Restore ${pending.habits.length} habits from this backup?` : `Import ${pending.habits.length} habits from Habit Chain?`}</p>
                <p className="small muted" style={{ margin: 0 }}>{pending.type === "hexis" ? "This replaces every habit, check-in and reflection here with the backup." : "These habits and their check-ins are added alongside what you already have."}</p>
                <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
                  <Press className={`btn small ${pending.type === "hexis" ? "danger" : "primary"}`} onClick={() => { hx.restore(pending); setPending(null); }}>{pending.type === "hexis" ? "Replace everything" : "Import"}</Press>
                  <Press className="btn small secondary" onClick={() => setPending(null)}>Cancel</Press>
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </Group>

        <Group title="On iPhone">
          <p className="small" style={{ margin: 0, display: "flex", gap: 10 }}>
            <Icon name="info" size={18} style={{ color: "var(--accent)", flex: "none" }} />
            <span>Reminders at each habit's time, home screen widgets and the Lock Screen timer come with the Hexis iPhone app. Its setup guide is in the project's README. Save a backup here and restore it there to bring everything across.</span>
          </p>
        </Group>
      </div>
    </Sheet>
  );
}

function Group({ title, foot, children }) {
  return (
    <section className="field">
      <span>{title}</span>
      <Card><div className="stack" style={{ gap: 10 }}>{children}</div></Card>
      {foot && <p className="section-foot">{foot}</p>}
    </section>
  );
}

function TimeRow({ id, label, value, onChange }) {
  return (
    <div className="toggle-row">
      <label htmlFor={id}>{label}</label>
      <input id={id} type="time" className="input compact" value={value} onChange={(e) => e.target.value && onChange(e.target.value)} />
    </div>
  );
}

// ---- First run ----

export function Emblem({ size = 150, lit = true }) {
  // Seven segments, one per day of the week, around a check.
  const c = size / 2, r = size * 0.33, w = size * 0.075;
  const segs = Array.from({ length: 7 }, (_, i) => {
    const gap = 0.16;
    const a0 = -Math.PI / 2 + (i / 7) * Math.PI * 2 + gap / 2;
    const a1 = -Math.PI / 2 + ((i + 1) / 7) * Math.PI * 2 - gap / 2;
    const p = (a) => `${(c + Math.cos(a) * r).toFixed(2)} ${(c + Math.sin(a) * r).toFixed(2)}`;
    return `M ${p(a0)} A ${r} ${r} 0 0 1 ${p(a1)}`;
  });
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} aria-hidden="true">
      <rect width={size} height={size} rx={size * 0.23} fill="#0b1220" />
      {segs.map((d, i) => (
        <motion.path key={i} d={d} fill="none" stroke={i < 6 ? "#2dd4bf" : "rgba(45,212,191,.35)"} strokeWidth={w} strokeLinecap="round"
          initial={{ pathLength: 0, opacity: 0 }} animate={lit ? { pathLength: 1, opacity: 1 } : {}} transition={{ delay: 0.25 + i * 0.09, duration: 0.35 }} />
      ))}
      <motion.path d={`M ${c - size * 0.11} ${c + size * 0.005} L ${c - size * 0.025} ${c + size * 0.09} L ${c + size * 0.12} ${c - size * 0.075}`}
        fill="none" stroke="#fff" strokeWidth={w * 1.05} strokeLinecap="round" strokeLinejoin="round"
        initial={{ pathLength: 0 }} animate={lit ? { pathLength: 1 } : {}} transition={{ delay: 1.0, duration: 0.4 }} />
    </svg>
  );
}

export function Onboarding({ s }) {
  const [page, setPage] = useState(0);
  const [chosen, setChosen] = useState(() => new Set(s.legacy ? [] : ["Meditate", "Read 20 minutes"]));
  const [bring, setBring] = useState(!!s.legacy);
  const go = (n) => setPage(n);
  const count = chosen.size + (bring && s.legacy ? s.legacy.habits.length : 0);
  const finish = () => hx.finishOnboarding(TEMPLATES.filter((t) => chosen.has(t.name)), bring);
  const pages = [
    <div key="0" className="onb-page center-col">
      <div className="cover-spacer" />
      <motion.div initial={{ scale: 0.9, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} transition={{ type: "spring", stiffness: 200, damping: 18, delay: 0.15 }} className="emblem">
        <Emblem size={150} />
      </motion.div>
      <div style={{ textAlign: "center" }}>
        <h1 className="onb-title" style={{ fontSize: 44 }}>Hexis</h1>
        <p className="onb-sub">ἕξις · a habit, a settled way of being</p>
      </div>
      <p className="cover-quote">“Every habit and faculty is maintained and increased by the corresponding actions.”<br />— Epictetus, Discourses 2.18</p>
      <p className="small" style={{ opacity: 0.7, margin: 0 }}>The word Epictetus uses for habit there is hexis.</p>
      <div className="cover-spacer" />
      <Press className="btn primary block" onClick={() => go(1)}>Begin</Press>
    </div>,
    <div key="1" className="onb-page">
      <div className="cover-spacer" />
      <h1 className="onb-title">How it keeps you going</h1>
      {[
        ["time", "A time for every habit", "“After I make coffee, I will read.” Plans tied to a time and a cue are followed far more often."],
        ["recover", "Never miss twice", "One missed day never breaks your chain. Two in a row does. So a bad day is only ever one day."],
        ["leaf", "A minimum for hard days", "Every habit has a tiny version. Doing it keeps the chain alive."],
        ["journey", "Every check-in is a vote", "Each day you keep is a vote for who you're becoming. Milestones mark 21, 66 and 100 days; 66 is the average time for a habit to feel automatic."],
      ].map(([icon, title, text], i) => (
        <motion.div key={title} className="principle" initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: 0.08 * i + 0.1, ...spring }}>
          <Icon name={icon} size={22} style={{ color: "#5eead4", flex: "none" }} />
          <div><p className="strong" style={{ margin: 0 }}>{title}</p><p className="small" style={{ margin: "4px 0 0", opacity: 0.85 }}>{text}</p></div>
        </motion.div>
      ))}
      <div className="cover-spacer" />
      <Press className="btn primary block" onClick={() => go(2)}>Continue</Press>
    </div>,
    <div key="2" className="onb-page">
      <h1 className="onb-title" style={{ marginTop: 12 }}>Choose your first habits</h1>
      <p style={{ opacity: 0.85, margin: 0 }}>Start with two or three. You can change times and add more later.</p>
      {s.legacy && (
        <button type="button" className={`onb-choice ${bring ? "on" : ""}`} aria-pressed={bring} onClick={() => setBring(!bring)}>
          <Icon name="restore" size={20} />
          <span style={{ flex: 1, textAlign: "left" }}>
            <span className="strong" style={{ display: "block" }}>Bring over Habit Chain</span>
            <span className="tiny" style={{ opacity: 0.8 }}>{s.legacy.habits.length} habits and every check-in from this page</span>
          </span>
          <Icon name={bring ? "done" : "circle"} size={22} />
        </button>
      )}
      <div className="onb-list">
        {TEMPLATES.map((t) => {
          const on = chosen.has(t.name);
          return (
            <button key={t.name} type="button" className={`onb-choice ${on ? "on" : ""}`} aria-pressed={on} onClick={() => {
              const next = new Set(chosen);
              if (on) next.delete(t.name); else next.add(t.name);
              setChosen(next);
            }}>
              <Symbol name={t.symbol} size={20} />
              <span style={{ flex: 1, textAlign: "left" }}>
                <span className="strong" style={{ display: "block" }}>{t.name}</span>
                <span className="tiny" style={{ opacity: 0.75 }}>{t.times.map((x) => D.displayTime(D.parseTime(x))).join(" · ")}</span>
              </span>
              <AnimatePresence mode="popLayout" initial={false}>
                <motion.span key={String(on)} initial={{ scale: 0.4 }} animate={{ scale: 1 }} transition={spring} style={{ display: "grid" }}>
                  <Icon name={on ? "done" : "circle"} size={22} />
                </motion.span>
              </AnimatePresence>
            </button>
          );
        })}
      </div>
      <Press className="btn primary block" onClick={finish}>{count === 0 ? "Start with no habits" : `Start with ${count} ${count === 1 ? "habit" : "habits"}`}</Press>
      <p className="tiny" style={{ opacity: 0.75, margin: 0 }}>Reminders and widgets come with the Hexis iPhone app. Here, your habits save to this page and follow you to any device.</p>
    </div>,
  ];
  return (
    <motion.div className="cover onboarding" role="dialog" aria-modal="true" aria-label="Welcome to Hexis" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0, scale: 1.04 }}>
      <AnimatePresence mode="wait">
        <motion.div key={page} className="onb-wrap" initial={{ opacity: 0, x: 40 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -40 }} transition={{ type: "spring", stiffness: 300, damping: 32 }}>
          {pages[page]}
        </motion.div>
      </AnimatePresence>
      <div className="dots" aria-hidden="true">{[0, 1, 2].map((i) => <span key={i} className={i === page ? "on" : ""} />)}</div>
    </motion.div>
  );
}
