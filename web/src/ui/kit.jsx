// Shared pieces: cards, the habit ring, quotes, sheets, segmented controls, toasts and confetti.
import React, { useEffect, useId, useRef, useState } from "react";
import { AnimatePresence, motion, useDragControls, useReducedMotion } from "framer-motion";
import { Icon, Symbol } from "./icons.jsx";
import * as D from "../core/date.js";
import { COLORS, sortedSlots, unitLabel } from "../core/model.js";
import { hx } from "../store.js";

export const hc = (name) => `var(--h-${name})`;
export const spring = { type: "spring", stiffness: 420, damping: 30 };
export const softSpring = { type: "spring", stiffness: 260, damping: 26 };

export function Card({ tint, className = "", children, ...rest }) {
  return (
    <div className={`card ${tint ? "tinted" : ""} ${className}`} style={tint ? { "--tint": tint } : undefined} {...rest}>
      {children}
    </div>
  );
}

export function Eyebrow({ icon, children, style }) {
  return (
    <p className="eyebrow" style={style}>
      {icon && <Icon name={icon} size={12} strokeWidth={2.6} />}
      {children}
    </p>
  );
}

/** A button that sinks slightly when pressed. */
export const Press = React.forwardRef(function Press({ className = "", children, ...rest }, ref) {
  return (
    <motion.button ref={ref} type="button" className={className} whileTap={{ scale: 0.92 }} transition={spring} {...rest}>
      {children}
    </motion.button>
  );
});

// ---- The habit ring ----

/**
 * state: "open" (fills with `progress`), "done" (solid disc with a check), "minimum" (dashed, the chain is safe),
 * "slipped" (a quit habit that slipped).
 */
export function HabitMark({ color, symbol, state = "open", progress = 0, size = 44, doneSymbol = "checkmark", animated = true }) {
  const reduce = useReducedMotion();
  const line = Math.max(2, size * 0.085);
  const r = (size - line) / 2;
  const circ = 2 * Math.PI * r;
  const wasDone = useRef(state === "done");
  const [burst, setBurst] = useState(0);
  useEffect(() => {
    if (state === "done" && !wasDone.current && animated && !reduce) setBurst((b) => b + 1);
    wasDone.current = state === "done";
  }, [state, animated, reduce]);

  const glyph = state === "done" ? doneSymbol : state === "minimum" ? "checkmark" : state === "slipped" ? "xmark" : symbol;
  const glyphColor = state === "done" ? "#fff" : color;
  const c = size / 2;
  return (
    <motion.span
      className="mark"
      style={{ width: size, height: size }}
      animate={burst ? { scale: [1, 1.14, 1] } : { scale: 1 }}
      transition={{ duration: 0.45, ease: "easeOut" }}
      key={`m${burst}`}
    >
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} aria-hidden="true">
        {state === "open" && (
          <>
            <circle cx={c} cy={c} r={r} fill="none" stroke={color} strokeOpacity="0.2" strokeWidth={line} />
            <motion.circle
              cx={c} cy={c} r={r} fill="none" stroke={color} strokeWidth={line} strokeLinecap="round"
              strokeDasharray={circ} transform={`rotate(-90 ${c} ${c})`}
              initial={false}
              animate={{ strokeDashoffset: circ * (1 - Math.min(1, Math.max(0, progress))), opacity: progress > 0 ? 1 : 0 }}
              transition={softSpring}
            />
          </>
        )}
        {state === "done" && (
          <motion.circle cx={c} cy={c} r={size / 2} fill={color} initial={animated ? { r: r * 0.6 } : false} animate={{ r: size / 2 }} transition={spring} />
        )}
        {state === "minimum" && (
          <>
            <circle cx={c} cy={c} r={r} fill={color} fillOpacity="0.18" />
            <circle cx={c} cy={c} r={r} fill="none" stroke={color} strokeWidth={line} strokeLinecap="round" strokeDasharray={`${size * 0.12} ${size * 0.08}`} />
          </>
        )}
        {state === "slipped" && (
          <circle cx={c} cy={c} r={r} fill="none" stroke={color} strokeOpacity="0.35" strokeWidth={line} strokeDasharray={`${size * 0.06} ${size * 0.08}`} />
        )}
      </svg>
      <span className="mark-glyph" style={{ color: glyphColor }}>
        <AnimatePresence initial={false} mode="popLayout">
          <motion.span
            key={glyph + state}
            initial={{ scale: 0.3, opacity: 0, rotate: -30 }}
            animate={{ scale: 1, opacity: state === "slipped" ? 0.8 : 1, rotate: 0 }}
            exit={{ scale: 0.3, opacity: 0 }}
            transition={spring}
            style={{ display: "grid" }}
          >
            <Symbol name={glyph} size={Math.round(size * 0.42)} strokeWidth={state === "done" || state === "minimum" ? 3 : 2.2} />
          </motion.span>
        </AnimatePresence>
      </span>
      {burst > 0 && <Burst key={burst} color={color} size={size} line={line} />}
    </motion.span>
  );
}

function Burst({ color, size, line }) {
  return (
    <span className="burst" aria-hidden="true">
      <motion.span
        className="burst-ring"
        style={{ borderColor: color, borderWidth: line }}
        initial={{ scale: 1, opacity: 0.7 }}
        animate={{ scale: 1.8, opacity: 0 }}
        transition={{ duration: 0.55, ease: "easeOut" }}
      />
      {Array.from({ length: 8 }, (_, i) => {
        const a = (i / 8) * Math.PI * 2;
        return (
          <motion.span
            key={i}
            className="burst-spark"
            style={{ background: color, width: size * 0.09, height: size * 0.09 }}
            initial={{ x: Math.cos(a) * size * 0.45, y: Math.sin(a) * size * 0.45, opacity: 0.9 }}
            animate={{ x: Math.cos(a) * size * 0.95, y: Math.sin(a) * size * 0.95, opacity: 0 }}
            transition={{ duration: 0.6, ease: "easeOut" }}
          />
        );
      })}
    </span>
  );
}

export function DoneRow({ count = 5, size = 34 }) {
  return (
    <div style={{ display: "flex", gap: size * 0.18 }}>
      {Array.from({ length: count }, (_, i) => (
        <motion.span key={i} initial={{ scale: 0.4, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} transition={{ ...spring, delay: 0.08 * i }}>
          <HabitMark color={hc(COLORS[(i * 3) % COLORS.length])} symbol="checkmark" state="done" size={size} animated={false} />
        </motion.span>
      ))}
    </div>
  );
}

export function Ring({ fraction, color, width = 3, size = 36 }) {
  const r = (size - width) / 2;
  const circ = 2 * Math.PI * r;
  const c = size / 2;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} aria-hidden="true">
      <circle cx={c} cy={c} r={r} fill="none" stroke={color} strokeOpacity="0.18" strokeWidth={width} />
      <motion.circle
        cx={c} cy={c} r={r} fill="none" stroke={color} strokeWidth={width} strokeLinecap="round" strokeDasharray={circ}
        transform={`rotate(-90 ${c} ${c})`} initial={false}
        animate={{ strokeDashoffset: circ * (1 - Math.min(1, Math.max(0, fraction))), opacity: fraction > 0 ? 1 : 0 }}
        transition={softSpring}
      />
    </svg>
  );
}

// ---- Quotes ----

export function QuoteBlock({ quote, showOriginal, size = 18, clamp }) {
  if (!quote) return null;
  return (
    <div className="stack" style={{ gap: 10 }}>
      {showOriginal && quote.original && (
        <>
          <p className="quote-original" lang="sa" style={{ fontSize: size - 1 }}>{quote.original}</p>
          {quote.transliteration && <p className="quote-translit" style={{ fontSize: size - 4 }}>{quote.transliteration}</p>}
        </>
      )}
      <p className={`quote-text ${clamp ? "clamp" : ""}`} style={{ fontSize: size, WebkitLineClamp: clamp }}>{quote.text}</p>
      <p className="quote-cite">— {quote.cite}</p>
    </div>
  );
}

export function TraditionMark({ tradition }) {
  const stoic = tradition === "stoic";
  return (
    <span className="tradition" style={{ color: stoic ? hc("graphite") : "var(--accent)" }}>
      <Icon name={stoic ? "stoic" : "hindu"} size={12} strokeWidth={2.4} />
      {stoic ? "Stoic" : "Hindu"}
    </span>
  );
}

export function FavoriteButton({ quote, favorites }) {
  const on = favorites.includes(quote.id);
  return (
    <Press className="icon-btn" onClick={() => hx.toggleFavorite(quote.id)} aria-label={on ? "Remove from saved quotes" : "Save quote"} aria-pressed={on}>
      <motion.span key={String(on)} initial={{ scale: on ? 0.4 : 1 }} animate={{ scale: 1 }} transition={{ type: "spring", stiffness: 500, damping: 12 }} style={{ display: "grid" }}>
        <Icon name="heart" size={18} fill={on ? "currentColor" : "none"} style={{ color: on ? "var(--danger)" : "var(--ink2)" }} />
      </motion.span>
    </Press>
  );
}

// ---- Controls ----

export function Seg({ options, value, onChange, label }) {
  const id = useId();
  return (
    <div className="seg" role="group" aria-label={label}>
      {options.map((o) => (
        <button key={o.value} type="button" aria-pressed={value === o.value} onClick={() => onChange(o.value)}>
          {value === o.value && <motion.span layoutId={`seg${id}`} className="seg-pill" transition={spring} />}
          <span>{o.label}</span>
        </button>
      ))}
    </div>
  );
}

export function Toggle({ checked, onChange, label, id }) {
  return (
    <label className="toggle-row" htmlFor={id}>
      <span>{label}</span>
      <input id={id} type="checkbox" role="switch" className="switch" checked={checked} onChange={(e) => onChange(e.target.checked)} />
    </label>
  );
}

// ---- Sheets and covers ----

export function Sheet({ open, onClose, title, action, children, label }) {
  const reduce = useReducedMotion();
  const panel = useRef(null);
  const drag = useDragControls();
  useEffect(() => {
    if (!open) return undefined;
    const prev = document.activeElement;
    const onKey = (e) => { if (e.key === "Escape") onClose(); };
    document.addEventListener("keydown", onKey);
    document.body.style.overflow = "hidden";
    const t = setTimeout(() => panel.current?.focus({ preventScroll: true }), 50);
    return () => {
      clearTimeout(t);
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = "";
      prev?.focus?.({ preventScroll: true });
    };
  }, [open, onClose]);
  return (
    <AnimatePresence>
      {open && (
        <>
          <motion.div className="scrim" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={onClose} />
          <motion.div
            ref={panel}
            className="sheet"
            role="dialog"
            aria-modal="true"
            aria-label={label || title}
            tabIndex={-1}
            initial={reduce ? { opacity: 0 } : { y: "100%" }}
            animate={reduce ? { opacity: 1 } : { y: 0 }}
            exit={reduce ? { opacity: 0 } : { y: "100%" }}
            transition={{ type: "spring", stiffness: 380, damping: 38 }}
            drag={reduce ? false : "y"}
            dragConstraints={{ top: 0, bottom: 0 }}
            dragElastic={{ top: 0, bottom: 0.6 }}
            dragListener={false}
            dragControls={drag}
            onDragEnd={(_, info) => { if (info.offset.y > 120 || info.velocity.y > 600) onClose(); }}
          >
            <div className="grabber-zone" onPointerDown={(e) => drag.start(e)} aria-hidden="true"><div className="grabber" /></div>
            {(title || action) && (
              <div className="sheet-head">
                <Press className="btn small secondary" onClick={onClose}>Close</Press>
                {title && <h2>{title}</h2>}
                {action ?? <span style={{ width: 64 }} />}
              </div>
            )}
            {children}
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}

// ---- Toasts and celebration ----

export function ToastHost({ toast, showOriginal }) {
  useEffect(() => {
    if (!toast) return undefined;
    const t = setTimeout(() => hx.dismissToast(toast.id), toast.quote ? 5500 : 2800);
    return () => clearTimeout(t);
  }, [toast]);
  return (
    <div aria-live="polite" className="toast-host">
      <AnimatePresence>
        {toast && (
          <motion.div
            key={toast.id}
            className="toast"
            initial={{ y: -40, opacity: 0, scale: 0.96 }}
            animate={{ y: 0, opacity: 1, scale: 1 }}
            exit={{ y: -30, opacity: 0 }}
            transition={{ type: "spring", stiffness: 380, damping: 30 }}
            onClick={() => hx.dismissToast(toast.id)}
          >
            <p className="toast-msg"><Icon name={toast.icon} size={16} strokeWidth={2.4} style={{ color: "var(--accent)", flex: "none" }} />{toast.message}</p>
            {toast.quote && (
              <>
                <p className="toast-quote">“{toast.quote.text}”</p>
                <p className="quote-cite small">{toast.quote.cite}</p>
              </>
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

export function Celebration({ count, quote }) {
  const reduce = useReducedMotion();
  const [visible, setVisible] = useState(false);
  const first = useRef(count);
  useEffect(() => {
    if (count === first.current) return undefined;
    setVisible(true);
    const t = setTimeout(() => setVisible(false), 4200);
    return () => clearTimeout(t);
  }, [count]);
  return (
    <AnimatePresence>
      {visible && (
        <motion.div className="celebrate" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setVisible(false)}>
          {!reduce && <Confetti />}
          <motion.div
            className="celebrate-card"
            initial={{ scale: 0.85, opacity: 0, y: 20 }}
            animate={{ scale: 1, opacity: 1, y: 0 }}
            exit={{ scale: 0.9, opacity: 0 }}
            transition={{ type: "spring", stiffness: 300, damping: 22 }}
          >
            <DoneRow count={5} size={38} />
            <h2 className="celebrate-title">All done for today</h2>
            <QuoteBlock quote={quote} showOriginal={false} size={15} />
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

function Confetti() {
  const canvas = useRef(null);
  useEffect(() => {
    const el = canvas.current;
    const ctx = el.getContext("2d");
    const dpr = window.devicePixelRatio || 1;
    const resize = () => { el.width = el.clientWidth * dpr; el.height = el.clientHeight * dpr; };
    resize();
    const styles = getComputedStyle(document.documentElement);
    const colors = COLORS.map((c) => styles.getPropertyValue(`--h-${c}`).trim() || "#0d9488");
    const start = performance.now();
    let frame;
    const draw = (now) => {
      const t = (now - start) / 1000;
      const w = el.width / dpr, h = el.height / dpr;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, w, h);
      for (let i = 0; i < 90; i++) {
        const seed = i * 12.9898;
        const rx = Math.abs((Math.sin(seed) * 43758.5453) % 1);
        const life = t - Math.abs(Math.sin(seed * 2.3)) * 0.6;
        if (life <= 0) continue;
        const speed = 260 + Math.abs(Math.sin(seed * 1.7)) * 320;
        const x = w * rx + Math.sin(life * 3 + seed) * 26;
        const y = -30 + life * speed;
        if (y > h + 30) continue;
        const size = 6 + Math.abs(Math.sin(seed * 3.1)) * 6;
        ctx.save();
        ctx.globalAlpha = Math.max(0, 1 - life / 3.4);
        ctx.translate(x, y);
        ctx.rotate(life * (2 + Math.abs(Math.sin(seed)) * 4) + seed);
        ctx.fillStyle = colors[i % colors.length];
        ctx.fillRect(-size / 2, -size * 0.3, size, size * 0.6);
        ctx.restore();
      }
      if (t < 4) frame = requestAnimationFrame(draw);
    };
    frame = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(frame);
  }, []);
  return <canvas ref={canvas} className="confetti" aria-hidden="true" />;
}

// ---- Text helpers ----

export const Describe = {
  weekdays(days) {
    const set = new Set(days);
    if (set.size === 7) return "Every day";
    if (set.size === 5 && [2, 3, 4, 5, 6].every((d) => set.has(d))) return "Weekdays";
    if (set.size === 2 && set.has(1) && set.has(7)) return "Weekends";
    return D.WEEK_ORDER.filter((d) => set.has(d)).map((d) => D.WEEKDAY_SHORT[d - 1]).join(", ");
  },
  goal(h) {
    switch (h.kind) {
      case "check": return h.slots.length > 1 ? `${h.slots.length} times a day` : "Once a day";
      case "count": return `${h.target} ${unitLabel(h)} a day`;
      case "timed": return `${h.target} min${h.slots.length > 1 ? ` × ${h.slots.length}` : ""}`;
      default: return "Avoid";
    }
  },
  times(h) {
    const times = sortedSlots(h).map((s) => D.displayTime(D.parseTime(s.time)));
    if (!times.length) return h.kind === "quit" ? "No risky time set" : "Any time";
    return times.join(" · ");
  },
  relative(time, now) {
    const diff = D.dayOrder(time) - D.dayOrder(now);
    if (Math.abs(diff) <= 5) return "now";
    if (diff > 0) return diff < 60 ? `in ${diff} min` : `at ${D.displayTime(time)}`;
    return -diff < 60 ? `${-diff} min ago` : `since ${D.displayTime(time)}`;
  },
};

export function listNames(names) {
  if (names.length <= 2) return names.join(" and ");
  return `${names.slice(0, -1).join(", ")} and ${names[names.length - 1]}`;
}
