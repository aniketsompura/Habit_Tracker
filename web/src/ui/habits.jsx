// Habits: the list (drag to reorder) and the editor with templates, schedule and the "make it stick" plan.
import React, { useEffect, useMemo, useRef, useState } from "react";
import { AnimatePresence, Reorder, motion, useDragControls } from "framer-motion";
import * as D from "../core/date.js";
import { COLORS, KINDS, sortedSlots, uuid, whenThen } from "../core/model.js";
import { TEMPLATES, makeHabit } from "../core/templates.js";
import { hx } from "../store.js";
import { HABIT_SYMBOLS, Icon, Symbol } from "./icons.jsx";
import { Card, Describe, Press, Seg, Sheet, hc, spring } from "./kit.jsx";

export function HabitsScreen({ s }) {
  const [order, setOrder] = useState(s.active.map((h) => h.id));
  const dragging = useRef(false);
  useEffect(() => { if (!dragging.current) setOrder(s.active.map((h) => h.id)); }, [s.active]);
  const byId = useMemo(() => new Map(s.habits.map((h) => [h.id, h])), [s.habits]);

  return (
    <>
      <div className="title-bar">
        <h1 className="page-title">Habits</h1>
        <div style={{ display: "flex", gap: 8 }}>
          <Press className="round-btn" onClick={() => hx.open({ name: "settings" })} aria-label="Settings"><Icon name="settings" size={20} /></Press>
          <Press className="round-btn accent" onClick={() => hx.open({ name: "editor" })} aria-label="New habit"><Icon name="plus" size={22} strokeWidth={2.6} /></Press>
        </div>
      </div>

      {s.active.length === 0 ? (
        <Card>
          <h3 className="card-title">No habits yet</h3>
          <p className="muted small" style={{ margin: "6px 0 0" }}>Tap + to add one, or start from a template in the editor.</p>
        </Card>
      ) : (
        <>
          <p className="section-label">Tracking</p>
          <Reorder.Group axis="y" values={order} onReorder={setOrder} className="list-group" as="ul">
            {order.map((id) => byId.get(id) && (
              <HabitListRow
                key={id}
                habit={byId.get(id)}
                stats={s.engine.stats(byId.get(id))}
                onDragStart={() => { dragging.current = true; }}
                onDragEnd={() => { dragging.current = false; hx.reorder(order); }}
              />
            ))}
          </Reorder.Group>
          <p className="section-foot">Drag the handle to reorder. Archive a habit from its editor; archived habits keep their history.</p>
        </>
      )}

      {s.archived.length > 0 && (
        <>
          <p className="section-label">Archived</p>
          <ul className="list-group">
            {s.archived.map((h) => (
              <li key={h.id} className="list-row">
                <button type="button" className="list-row-main" onClick={() => hx.open({ name: "editor", habitID: h.id })}>
                  <span style={{ color: hc(h.color), display: "grid", width: 28, placeItems: "center" }}><Symbol name={h.symbol} size={18} /></span>
                  <span className="muted">{h.name}</span>
                </button>
                <button type="button" className="link-btn" onClick={() => hx.setArchived(h, false)}>Restore</button>
              </li>
            ))}
          </ul>
        </>
      )}
    </>
  );
}

function HabitListRow({ habit, stats, onDragStart, onDragEnd }) {
  const controls = useDragControls();
  return (
    <Reorder.Item
      value={habit.id}
      dragListener={false}
      dragControls={controls}
      onDragStart={onDragStart}
      onDragEnd={onDragEnd}
      className="list-row"
      whileDrag={{ scale: 1.03, boxShadow: "0 12px 30px rgba(0,0,0,.18)", zIndex: 5 }}
      transition={spring}
    >
      <button type="button" className="list-row-main" onClick={() => hx.open({ name: "editor", habitID: habit.id })}>
        <span className="icon-disc small" style={{ color: hc(habit.color), "--c": hc(habit.color) }}><Symbol name={habit.symbol} size={20} /></span>
        <span style={{ minWidth: 0, textAlign: "left" }}>
          <span className="row-name" style={{ display: "block" }}>{habit.name}</span>
          <span className="small muted" style={{ display: "block" }}>{Describe.goal(habit)} · {Describe.weekdays(habit.weekdays)}</span>
          <span className="tiny muted" style={{ display: "flex", gap: 4, alignItems: "center" }}>
            <Icon name={habit.kind === "quit" ? "shield" : "bell"} size={12} />{Describe.times(habit)}
          </span>
        </span>
      </button>
      {stats.current > 0 && <span className="streak small"><Icon name="flame" size={13} fill="currentColor" />{stats.current}</span>}
      <span className="grip" onPointerDown={(e) => { e.preventDefault(); controls.start(e); }} aria-hidden="true"><Icon name="grip" size={18} /></span>
    </Reorder.Item>
  );
}

// ---- Editor ----

const KIND_LABEL = { check: "Yes / no", count: "Count", timed: "Timed", quit: "Quit" };
const COLOR_LABEL = { orange: "Orange", red: "Red", yellow: "Yellow", teal: "Teal", green: "Green", pink: "Pink", indigo: "Indigo", graphite: "Graphite" };

function blank(today) {
  return { id: uuid(), name: "", symbol: "sparkles", color: "orange", kind: "check", weekdays: [1, 2, 3, 4, 5, 6, 7], slots: [{ id: uuid(), time: "07:00", remind: true }], target: 1, unit: "", cue: "", place: "", identity: "", minimum: "", treat: "", createdOn: D.raw(today), archived: false, order: 0 };
}

export function HabitEditor({ s, habitID, onClose }) {
  const existing = habitID ? s.habits.find((h) => h.id === habitID) : null;
  const [draft, setDraft] = useState(() => (existing ? structuredClone(existing) : blank(s.today)));
  const [confirmDelete, setConfirmDelete] = useState(false);
  const nameRef = useRef(null);
  const isNew = !existing;
  const set = (patch) => setDraft((d) => ({ ...d, ...patch }));
  const canSave = draft.name.trim() && draft.weekdays.length;

  useEffect(() => { if (isNew) setTimeout(() => nameRef.current?.focus({ preventScroll: true }), 350); }, [isNew]);

  const setKind = (kind) => setDraft((d) => {
    const next = { ...d, kind };
    if (kind === "count" && d.target < 2) next.target = 8;
    if (kind === "timed" && d.target < 2) next.target = 10;
    if (kind === "quit" && d.slots.length > 1) next.slots = sortedSlots(d).slice(-1);
    return next;
  });
  const apply = (t) => {
    const made = makeHabit(t, draft.createdOn);
    setDraft((d) => ({ ...made, id: d.id, createdOn: d.createdOn, order: d.order, archived: d.archived }));
  };
  const save = () => {
    const h = { ...draft, name: draft.name.trim() };
    for (const k of ["unit", "cue", "place", "identity", "minimum", "treat"]) h[k] = h[k].trim();
    hx.saveHabit(h, isNew);
    onClose();
  };
  const sentence = whenThen(draft);
  const slots = sortedSlots(draft);

  return (
    <Sheet open onClose={onClose} title={isNew ? "New habit" : "Edit habit"} action={<Press className="btn small primary" disabled={!canSave} onClick={save}>Save</Press>}>
      <div className="stack" style={{ gap: 18 }}>
        {isNew && (
          <div className="field">
            <span>Start from a template</span>
            <div className="chips-scroll">
              {TEMPLATES.map((t) => (
                <Press key={t.name} className={`chip ${draft.name === t.name ? "on" : ""}`} style={{ "--c": hc(t.color) }} onClick={() => apply(t)}>
                  <Symbol name={t.symbol} size={15} />{t.name}
                </Press>
              ))}
            </div>
          </div>
        )}

        <Card>
          <div className="stack" style={{ gap: 14 }}>
            <div className="name-line">
              <motion.span key={draft.symbol + draft.color} className="icon-disc" style={{ color: hc(draft.color), "--c": hc(draft.color) }} initial={{ scale: 0.7 }} animate={{ scale: 1 }} transition={spring}>
                <Symbol name={draft.symbol} size={24} />
              </motion.span>
              <label htmlFor="habit-name" className="visually-hidden">Name</label>
              <input id="habit-name" ref={nameRef} className="input name-input" placeholder="Name, like Read 20 minutes" value={draft.name} onChange={(e) => set({ name: e.target.value })} maxLength={60} autoComplete="off" />
            </div>
            <div className="icon-grid" role="group" aria-label="Icon">
              {HABIT_SYMBOLS.map((sym) => (
                <Press key={sym} aria-pressed={draft.symbol === sym} aria-label={sym.replace(/\./g, " ")} style={{ "--c": hc(draft.color) }} onClick={() => set({ symbol: sym })}>
                  <Symbol name={sym} size={17} />
                </Press>
              ))}
            </div>
            <div className="swatches" role="group" aria-label="Color">
              {COLORS.map((c) => (
                <Press key={c} className="swatch" aria-pressed={draft.color === c} aria-label={COLOR_LABEL[c]} style={{ "--c": hc(c) }} onClick={() => set({ color: c })} />
              ))}
            </div>
          </div>
        </Card>

        <div className="field">
          <span>Type</span>
          <Card>
            <div className="stack" style={{ gap: 12 }}>
              <Seg label="Type" options={KINDS.map((k) => ({ value: k, label: KIND_LABEL[k] }))} value={draft.kind} onChange={setKind} />
              <AnimatePresence mode="wait" initial={false}>
                <motion.div key={draft.kind} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -6 }} transition={{ duration: 0.15 }} className="stack" style={{ gap: 12 }}>
                  {draft.kind === "check" && <p className="small muted" style={{ margin: 0 }}>Mark it done once at each time you set below.</p>}
                  {draft.kind === "count" && (
                    <>
                      <Stepper label="Daily target" value={draft.target} min={1} max={99} color={hc(draft.color)} onChange={(v) => set({ target: v })} />
                      <div className="field">
                        <label htmlFor="habit-unit">Unit</label>
                        <input id="habit-unit" className="input" placeholder="glasses, pages, push-ups" value={draft.unit} onChange={(e) => set({ unit: e.target.value })} maxLength={24} />
                      </div>
                    </>
                  )}
                  {draft.kind === "timed" && (
                    <>
                      <Stepper label="Session length" value={draft.target} min={1} max={180} suffix=" min" color={hc(draft.color)} onChange={(v) => set({ target: v })} />
                      <p className="small muted" style={{ margin: 0 }}>A timer with a breathing guide marks the habit done when it ends.</p>
                    </>
                  )}
                  {draft.kind === "quit" && <p className="small muted" style={{ margin: 0 }}>Every day counts as kept unless you log a slip. Set the time cravings usually hit.</p>}
                </motion.div>
              </AnimatePresence>
            </div>
          </Card>
        </div>

        <div className="field">
          <span>{draft.kind === "quit" ? "Risky time" : "When"}</span>
          <Card>
            <div className="stack" style={{ gap: 12 }}>
              <WeekdayPicker weekdays={draft.weekdays} color={hc(draft.color)} onChange={(w) => set({ weekdays: w })} />
              <AnimatePresence initial={false}>
                {slots.map((slot, i) => (
                  <motion.div key={slot.id} className="slot" layout initial={{ opacity: 0, height: 0 }} animate={{ opacity: 1, height: "auto" }} exit={{ opacity: 0, height: 0 }}>
                    <label htmlFor={`slot-${slot.id}`} className="small strong">{draft.kind === "quit" ? "Risky time" : slots.length > 1 ? `Time ${i + 1}` : "Time"}</label>
                    <input
                      id={`slot-${slot.id}`} type="time" className="input time-input" value={slot.time}
                      onChange={(e) => e.target.value && set({ slots: draft.slots.map((x) => (x.id === slot.id ? { ...x, time: e.target.value } : x)) })}
                    />
                    <Press className="icon-btn" aria-label={slot.remind ? "Reminder on in the iPhone app" : "Reminder off in the iPhone app"} aria-pressed={slot.remind} onClick={() => set({ slots: draft.slots.map((x) => (x.id === slot.id ? { ...x, remind: !x.remind } : x)) })}>
                      <Icon name={slot.remind ? "bell" : "bellOff"} size={17} style={{ color: slot.remind ? hc(draft.color) : "var(--ink2)" }} fill={slot.remind ? "currentColor" : "none"} />
                    </Press>
                    <Press className="icon-btn" aria-label={`Remove ${D.displayTime(D.parseTime(slot.time))}`} onClick={() => set({ slots: draft.slots.filter((x) => x.id !== slot.id) })}>
                      <Icon name="x" size={16} style={{ color: "var(--ink2)" }} />
                    </Press>
                  </motion.div>
                ))}
              </AnimatePresence>
              {(draft.kind !== "quit" || draft.slots.length === 0) && (
                <button type="button" className="link-btn" style={{ justifySelf: "start", display: "flex", gap: 6, alignItems: "center" }} onClick={() => {
                  const last = slots.length ? D.parseTime(slots[slots.length - 1].time) : 420;
                  set({ slots: [...draft.slots, { id: uuid(), time: D.formatTime(slots.length ? (last + 180) % 1440 : last), remind: true }] });
                }}>
                  <Icon name="plus" size={16} />{draft.slots.length ? "Add another time" : "Add a time"}
                </button>
              )}
            </div>
          </Card>
          <p className="section-foot">{scheduleFooter(draft)}</p>
        </div>

        <div className="field">
          <span>Make it stick</span>
          <Card>
            <div className="stack" style={{ gap: 12 }}>
              <Labeled id="cue" label="After" placeholder="I make my morning coffee" value={draft.cue} onChange={(v) => set({ cue: v })} dim={draft.kind === "quit"} />
              <Labeled id="place" label="Where" placeholder="on the balcony" value={draft.place} onChange={(v) => set({ place: v })} />
              <Labeled id="identity" label="I am becoming" placeholder="a reader" value={draft.identity} onChange={(v) => set({ identity: v })} />
              {draft.kind !== "quit" && <Labeled id="minimum" label="Hard-day minimum" placeholder="read one page" value={draft.minimum} onChange={(v) => set({ minimum: v })} />}
              <Labeled id="treat" label="Pair it with" placeholder="my favourite podcast" value={draft.treat} onChange={(v) => set({ treat: v })} />
            </div>
          </Card>
          <AnimatePresence initial={false}>
            {sentence && (
              <motion.p key="sentence" className="plan-sentence" initial={{ opacity: 0, y: -4 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }}>
                {sentence}
              </motion.p>
            )}
          </AnimatePresence>
          <p className="section-foot">Plans written as “after X, I will Y” are followed far more often than plain goals. The minimum keeps your chain on hard days, and each check-in counts as a vote for who you're becoming.</p>
        </div>

        {!isNew && (
          <Card>
            <div className="stack" style={{ gap: 10 }}>
              <Press className="btn secondary block" onClick={() => { hx.setArchived(existing, !existing.archived); onClose(); }}>
                <Icon name={existing.archived ? "restore" : "archive"} size={18} />{existing.archived ? "Restore habit" : "Archive habit"}
              </Press>
              {!confirmDelete ? (
                <Press className="btn danger block" onClick={() => setConfirmDelete(true)}><Icon name="trash" size={18} />Delete habit</Press>
              ) : (
                <motion.div initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} className="confirm">
                  <p className="small" style={{ margin: 0 }}>Deleting removes every check-in and streak for {existing.name}. Archiving hides it and keeps its history.</p>
                  <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
                    <Press className="btn danger small" style={{ background: "var(--danger)", color: "#fff" }} onClick={() => { hx.deleteHabit(existing); onClose(); }}>Delete habit and history</Press>
                    <Press className="btn secondary small" onClick={() => setConfirmDelete(false)}>Keep it</Press>
                  </div>
                </motion.div>
              )}
            </div>
          </Card>
        )}
        <div style={{ height: 8 }} />
      </div>
    </Sheet>
  );
}

function scheduleFooter(d) {
  switch (d.kind) {
    case "check":
    case "timed":
      return d.slots.length > 1 ? "Each time is its own check-in. On iPhone, each gets its own reminder." : d.slots.length === 0 ? "With no time set, the habit sits under Through the day." : "The habit sits at this time on your sky. On iPhone, you also get a reminder.";
    case "count":
      return d.slots.length > 1 ? "On iPhone, reminders spread through the day nudge you toward the target." : "Add a few times to get nudges through the day on iPhone.";
    default:
      return "On iPhone, you get one nudge at your risky time.";
  }
}

function Stepper({ label, value, min, max, suffix = "", color, onChange }) {
  return (
    <div className="stepper-row">
      <span className="strong">{label}</span>
      <div className="stepper">
        <Press aria-label={`Less ${label.toLowerCase()}`} disabled={value <= min} onClick={() => onChange(Math.max(min, value - 1))}><Icon name="minus" size={18} /></Press>
        <output className="num" style={{ color }} aria-live="polite">
          <AnimatePresence mode="popLayout" initial={false}>
            <motion.span key={value} initial={{ y: 8, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: -8, opacity: 0 }} transition={spring} style={{ display: "inline-block" }}>{value}{suffix}</motion.span>
          </AnimatePresence>
        </output>
        <Press aria-label={`More ${label.toLowerCase()}`} disabled={value >= max} onClick={() => onChange(Math.min(max, value + 1))}><Icon name="plus" size={18} /></Press>
      </div>
    </div>
  );
}

function Labeled({ id, label, placeholder, value, onChange, dim }) {
  return (
    <div className="field" style={{ opacity: dim ? 0.55 : 1 }}>
      <label htmlFor={`habit-${id}`}>{label}</label>
      <input id={`habit-${id}`} className="input" placeholder={placeholder} value={value} onChange={(e) => onChange(e.target.value)} maxLength={80} autoComplete="off" />
    </div>
  );
}

const WEEKDAY_NAMES = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

export function WeekdayPicker({ weekdays, color, onChange }) {
  const same = (a, b) => a.length === b.length && a.every((x) => b.includes(x));
  const quick = [["Every day", [1, 2, 3, 4, 5, 6, 7]], ["Weekdays", [2, 3, 4, 5, 6]], ["Weekends", [1, 7]]];
  return (
    <div className="stack" style={{ gap: 10 }}>
      <div className="daychips" role="group" aria-label="Days">
        {D.WEEK_ORDER.map((d) => {
          const on = weekdays.includes(d);
          return (
            <Press key={d} aria-pressed={on} aria-label={WEEKDAY_NAMES[d - 1]} style={{ "--c": color }}
              onClick={() => onChange(on ? (weekdays.length > 1 ? weekdays.filter((x) => x !== d) : weekdays) : [...weekdays, d].sort())}>
              {D.WEEKDAY_LETTER[d - 1]}
            </Press>
          );
        })}
      </div>
      <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
        {quick.map(([label, days]) => (
          <button key={label} type="button" className={`chip ${same(weekdays, days) ? "on" : ""}`} style={{ "--c": same(weekdays, days) ? color : "var(--ink2)", padding: "6px 12px", fontSize: 13 }} onClick={() => onChange(days)}>{label}</button>
        ))}
      </div>
    </div>
  );
}
