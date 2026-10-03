// Journey: rates, votes toward milestones, a 16-week map and timing insights per habit, and past reflections.
import React, { useMemo, useState } from "react";
import { motion } from "framer-motion";
import * as D from "../core/date.js";
import { hx } from "../store.js";
import { Icon, Symbol } from "./icons.jsx";
import { Card, Eyebrow, Press, hc, softSpring } from "./kit.jsx";
import { ReviewSummary } from "./today.jsx";
import { QUOTES, filtered } from "../core/quotes.js";
import { FavoriteButton, QuoteBlock, Seg, TraditionMark } from "./kit.jsx";

const pct = (r) => (r.scheduled === 0 ? "–" : `${Math.round((r.kept / r.scheduled) * 100)}%`);

export function JourneyScreen({ s }) {
  const { engine, active, today } = s;
  if (!active.length) {
    return (
      <>
        <h1 className="page-title">Journey</h1>
        <Card>
          <h3 className="card-title" style={{ fontSize: 22 }}>Your journey starts with one habit</h3>
          <p className="muted" style={{ margin: "8px 0 0" }}>Add a habit and check it off for a few days. Streaks, milestones and a map of every day will appear here.</p>
        </Card>
      </>
    );
  }
  const week = engine.rate(D.weekStart(today), today, active);
  const month = engine.rate(today - 29, today, active);
  const votes = active.reduce((n, h) => n + engine.stats(h).votes, 0);
  return (
    <>
      <h1 className="page-title">Journey</h1>
      <div className="tiles">
        <Tile label="This week" value={pct(week)} detail={`${week.kept} of ${week.scheduled} kept`} />
        <Tile label="30 days" value={pct(month)} detail={`${month.kept} of ${month.scheduled} kept`} />
        <Tile label="Votes" value={String(votes)} detail="for who you're becoming" />
      </div>
      <Eyebrow style={{ margin: "22px 4px 10px" }}>By habit</Eyebrow>
      <div className="stack" style={{ gap: 14 }}>
        {active.map((h) => <HabitJourneyCard key={h.id} habit={h} stats={engine.stats(h)} engine={engine} />)}
      </div>
      <Reflections s={s} />
    </>
  );
}

function Tile({ label, value, detail }) {
  return (
    <div className="tile">
      <span className="eyebrow" style={{ fontSize: 10 }}>{label}</span>
      <motion.strong key={value} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }}>{value}</motion.strong>
      <span className="tiny muted">{detail}</span>
    </div>
  );
}

function milestoneNote(votes, next) {
  if (next === 21) return `${next - votes} to go until 21: three weeks of showing up.`;
  if (next === 66) return `${next - votes} to go until 66, the average time for a habit to feel automatic.`;
  if (next === 100) return `${next - votes} to go until 100 votes.`;
  return `${next - votes} to go until ${next}.`;
}

function HabitJourneyCard({ habit, stats, engine }) {
  const color = hc(habit.color);
  return (
    <Card>
      <div className="stack" style={{ gap: 16 }}>
        <div className="row-between">
          <h3 className="card-title" style={{ display: "flex", gap: 8, alignItems: "center", minWidth: 0 }}>
            <span style={{ color, display: "grid", flex: "none" }}><Symbol name={habit.symbol} size={20} /></span>
            <span style={{ minWidth: 0, overflowWrap: "anywhere" }}>{habit.name}</span>
          </h3>
          {stats.current > 0 && <span className="streak small" style={{ flex: "none" }}><Icon name="flame" size={13} fill="currentColor" />{stats.current}-day chain</span>}
        </div>
        <div className="journey-main">
          <MilestoneRing votes={stats.votes} next={stats.nextMilestone} progress={stats.milestoneProgress} color={color} />
          <div className="stack" style={{ gap: 10 }}>
            <Metric label="Current chain" value={stats.current} />
            <Metric label="Best chain" value={stats.best} />
            <Metric label="30 days" value={stats.rate30 === null ? "–" : `${Math.round(stats.rate30 * 100)}%`} />
          </div>
        </div>
        <div className="stack" style={{ gap: 4 }}>
          {habit.identity.trim() && <p className="strong" style={{ margin: 0 }}>{stats.votes} votes for being {habit.identity.trim()}.</p>}
          <p className="small muted" style={{ margin: 0 }}>{milestoneNote(stats.votes, stats.nextMilestone)}</p>
        </div>
        {stats.atRisk && <p className="small strong" style={{ margin: 0, color: "var(--danger)", display: "flex", gap: 6, alignItems: "center" }}><Icon name="recover" size={15} />Missed last time. Never miss twice: keep today.</p>}
        <Heatmap habit={habit} engine={engine} weeks={16} color={color} />
        {stats.timing.map((t) => <TimingRow key={t.slotID} habit={habit} insight={t} color={color} />)}
      </div>
    </Card>
  );
}

function Metric({ label, value }) {
  return (
    <div>
      <strong className="num" style={{ fontSize: 20, display: "block", lineHeight: 1.1 }}>{value}</strong>
      <span className="tiny muted">{label}</span>
    </div>
  );
}

function MilestoneRing({ votes, next, progress, color }) {
  const size = 128, width = 12, r = (size - width) / 2 - 2, circ = 2 * Math.PI * r, c = size / 2;
  const id = useMemo(() => `g${Math.random().toString(36).slice(2, 8)}`, []);
  return (
    <div className="milestone" role="img" aria-label={`${votes} votes. Next milestone at ${next}.`}>
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        <defs>
          <linearGradient id={id} x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stopColor={color} stopOpacity="0.55" />
            <stop offset="1" stopColor={color} />
          </linearGradient>
        </defs>
        <circle cx={c} cy={c} r={r} fill="none" stroke={color} strokeOpacity="0.15" strokeWidth={width} />
        <motion.circle
          cx={c} cy={c} r={r} fill="none" stroke={`url(#${id})`} strokeWidth={width} strokeLinecap="round" strokeDasharray={circ}
          transform={`rotate(-90 ${c} ${c})`} initial={{ strokeDashoffset: circ }} animate={{ strokeDashoffset: circ * (1 - Math.max(0.002, progress)) }}
          transition={{ duration: 0.9, ease: "easeOut" }}
        />
      </svg>
      <div className="milestone-label">
        <strong className="num">{votes}</strong>
        <span className="tiny strong muted">votes</span>
        <span className="tiny muted">next {next}</span>
      </div>
    </div>
  );
}

function Heatmap({ habit, engine, weeks, color }) {
  const start = D.weekStart(engine.today) - 7 * (weeks - 1);
  const cells = [];
  for (let w = 0; w < weeks; w++) {
    for (let d = 0; d < 7; d++) {
      const j = start + w * 7 + d;
      const p = engine.progress(habit, j);
      let style;
      switch (p.status) {
        case "done": case "clean": case "extra": case "holding": style = { background: color }; break;
        case "minimum": style = { background: color, opacity: 0.55 }; break;
        case "partial": style = { background: color, opacity: 0.35 }; break;
        case "missed": case "slipped": style = p.done > 0 ? { background: color, opacity: 0.3 } : { background: "var(--rule)" }; break;
        case "pending": style = { boxShadow: `inset 0 0 0 1.2px ${color}` }; break;
        case "rest": style = { background: "radial-gradient(circle, color-mix(in srgb, var(--ink2) 45%, transparent) 1.3px, transparent 1.6px)" }; break;
        default: style = {};
      }
      cells.push(<i key={j} style={style} title={`${D.format(j, { weekday: "short", day: "numeric", month: "short" })}: ${p.status}`} />);
    }
  }
  return (
    <div className="stack" style={{ gap: 6 }} role="img" aria-label={`Calendar of the last ${weeks} weeks for ${habit.name}`}>
      <div className="heat" style={{ gridTemplateColumns: `repeat(${weeks}, 1fr)` }}>{cells}</div>
      <div className="legend">
        <span><i style={{ background: color }} />Kept</span>
        <span><i style={{ background: color, opacity: 0.55 }} />Minimum</span>
        <span><i style={{ background: "var(--rule)" }} />Missed</span>
        <span className="muted" style={{ marginLeft: "auto" }}>{weeks} weeks</span>
      </div>
    </div>
  );
}

function TimingRow({ habit, insight, color }) {
  const typical = D.displayTime(insight.typical);
  return (
    <div className="timing" style={{ "--c": color }}>
      <Icon name="clock" size={18} style={{ color, flex: "none" }} />
      <div className="stack" style={{ gap: 8 }}>
        <p className="small" style={{ margin: 0 }}>You usually do this around {typical}, {Math.abs(insight.drift)} min {insight.drift > 0 ? "after" : "before"} your plan of {D.displayTime(insight.planned)}.</p>
        <Press className="btn small" style={{ background: `color-mix(in srgb, ${color} 16%, transparent)`, color, justifySelf: "start" }} onClick={() => hx.applyTimingSuggestion(habit.id, insight.slotID, insight.typical)}>
          Move it to {typical}
        </Press>
      </div>
    </div>
  );
}

function Reflections({ s }) {
  const days = [];
  for (let k = 0; k < 30; k++) {
    const j = s.today - k;
    const r = hx.record(j);
    if (r.intention || r.review || r.note) days.push([j, r]);
  }
  if (!days.length) return null;
  return (
    <>
      <Eyebrow style={{ margin: "24px 4px 10px" }}>Reflections</Eyebrow>
      <div className="stack">
        {days.map(([j, r]) => (
          <Card key={j}>
            <div className="stack" style={{ gap: 8 }}>
              <p className="small strong" style={{ margin: 0, color: "var(--accent)" }}>{j === s.today ? "Today" : D.format(j, { weekday: "long", day: "numeric", month: "short" })}</p>
              {r.intention && <p className="intention" style={{ fontSize: 16 }}>Sankalpa: {r.intention}</p>}
              {r.review && <ReviewSummary review={r.review} />}
              {r.note && <p className="small" style={{ margin: 0 }}>{r.note}</p>}
            </div>
          </Card>
        ))}
      </div>
    </>
  );
}

// ---- Wisdom ----

export function WisdomScreen({ s }) {
  const [filter, setFilter] = useState("all");
  const [search, setSearch] = useState("");
  const query = search.trim().toLowerCase();
  const list = useMemo(() => {
    let l = QUOTES;
    if (filter === "stoic" || filter === "hindu") l = l.filter((q) => q.tradition === filter);
    if (filter === "saved") l = l.filter((q) => s.favorites.includes(q.id));
    if (query) l = l.filter((q) => q.text.toLowerCase().includes(query) || q.cite.toLowerCase().includes(query) || (q.transliteration || "").toLowerCase().includes(query));
    return l;
  }, [filter, query, s.favorites]);
  const daily = hx.dailyQuote();
  return (
    <>
      <h1 className="page-title">Wisdom</h1>
      <div className="search">
        <Icon name="search" size={17} style={{ color: "var(--ink2)" }} />
        <label htmlFor="wisdom-search" className="visually-hidden">Search quotes</label>
        <input id="wisdom-search" type="search" placeholder="Search words or sources" value={search} onChange={(e) => setSearch(e.target.value)} />
      </div>
      <div className="stack" style={{ marginTop: 12 }}>
        {!query && (
          <Card>
            <div className="row-between">
              <Eyebrow icon="quote">Today's wisdom</Eyebrow>
              <div style={{ display: "flex", alignItems: "center", gap: 4 }}>
                <TraditionMark tradition={daily.tradition} />
                <FavoriteButton quote={daily} favorites={s.favorites} />
              </div>
            </div>
            <div style={{ marginTop: 10 }}><QuoteBlock quote={daily} showOriginal={s.prefs.showSanskrit} /></div>
          </Card>
        )}
        <Seg label="Show" value={filter} onChange={setFilter} options={[{ value: "all", label: "All" }, { value: "stoic", label: "Stoic" }, { value: "hindu", label: "Hindu" }, { value: "saved", label: "Saved" }]} />
        {list.length === 0 && <p className="muted center" style={{ padding: "26px 0" }}>{filter === "saved" && !query ? "Tap the heart on any quote to save it here." : "No quotes match that search."}</p>}
        {list.map((q) => (
          <motion.div key={q.id} layout="position" initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={softSpring}>
            <Card>
              <div className="row-between">
                <TraditionMark tradition={q.tradition} />
                <FavoriteButton quote={q} favorites={s.favorites} />
              </div>
              <div style={{ marginTop: 8 }}><QuoteBlock quote={q} showOriginal={s.prefs.showSanskrit} size={16} /></div>
            </Card>
          </motion.div>
        ))}
        <p className="tiny muted" style={{ margin: "8px 4px 0" }}>Stoic passages follow public-domain translations, lightly modernised. Sanskrit verses are translated from the original. Every quote names its source.</p>
      </div>
    </>
  );
}

export const QUOTE_COUNT = { all: QUOTES.length, stoic: filtered("stoic").length, hindu: filtered("hindu").length };
