import React, { useEffect, useRef } from "react";
import { AnimatePresence, MotionConfig, motion } from "framer-motion";
import { hx, useHexis } from "./store.js";
import { Icon } from "./ui/icons.jsx";
import { Celebration, ToastHost, spring } from "./ui/kit.jsx";
import { TodayScreen } from "./ui/today.jsx";
import { HabitEditor, HabitsScreen } from "./ui/habits.jsx";
import { JourneyScreen, WisdomScreen } from "./ui/journey.jsx";
import { Emblem, Onboarding, ReviewSheet, SankalpaSheet, SettingsSheet, TimerCover } from "./ui/rituals.jsx";

const TABS = [
  { id: "today", label: "Today", icon: "today" },
  { id: "habits", label: "Habits", icon: "habits" },
  { id: "journey", label: "Journey", icon: "journey" },
  { id: "wisdom", label: "Wisdom", icon: "wisdom" },
];

export function App() {
  const s = useHexis();
  return (
    <MotionConfig reducedMotion="user">
      {s.status === "loading" ? <Loading /> : <Main s={s} />}
    </MotionConfig>
  );
}

function Loading() {
  return (
    <div className="loading" role="status">
      <motion.div animate={{ rotate: 360 }} transition={{ duration: 6, repeat: Infinity, ease: "linear" }}>
        <Emblem size={72} />
      </motion.div>
      <p className="muted">Opening your habits…</p>
    </div>
  );
}

function Main({ s }) {
  const route = s.route;
  const close = () => hx.close();
  const showOnboarding = !s.prefs.onboarded && s.canWrite;
  const behind = useRef(null);
  // Content under a sheet or full-screen cover can't be reached by keyboard, screen readers or taps.
  useEffect(() => { if (behind.current) behind.current.inert = !!route || showOnboarding; }, [route, showOnboarding]);
  return (
    <>
      {s.mode === "local" && (
        <p className="banner" role="note"><Icon name="info" size={15} />Saving in this browser only. Open this page on claude.ai, signed in, to keep habits on every device.</p>
      )}
      {!s.canWrite && s.mode === "db" && (
        <p className="banner" role="note"><Icon name="eye" size={15} />You can view these habits. Only the page's owner can change them.</p>
      )}
      <div ref={behind}>
      <main className="app">
        <AnimatePresence mode="wait" initial={false}>
          <motion.div key={s.tab} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -4 }} transition={{ duration: 0.18 }}>
            {s.tab === "today" && <TodayScreen s={s} />}
            {s.tab === "habits" && <HabitsScreen s={s} />}
            {s.tab === "journey" && <JourneyScreen s={s} />}
            {s.tab === "wisdom" && <WisdomScreen s={s} />}
          </motion.div>
        </AnimatePresence>
      </main>

      <nav className="tabbar" aria-label="Sections">
        {TABS.map((t) => (
          <button key={t.id} type="button" className="tab" aria-current={s.tab === t.id ? "page" : undefined} onClick={() => { hx.setTab(t.id); window.scrollTo({ top: 0 }); }}>
            {s.tab === t.id && <motion.span layoutId="tab-pill" className="tab-pill" transition={spring} />}
            <motion.span animate={{ scale: s.tab === t.id ? 1.08 : 1 }} transition={spring} style={{ display: "grid" }}><Icon name={t.icon} size={21} strokeWidth={s.tab === t.id ? 2.4 : 2} /></motion.span>
            <span>{t.label}</span>
          </button>
        ))}
      </nav>
      </div>

      {route?.name === "editor" && <HabitEditor key={route.habitID ?? "new"} s={s} habitID={route.habitID} onClose={close} />}
      {route?.name === "sankalpa" && <SankalpaSheet s={s} onClose={close} />}
      {route?.name === "review" && <ReviewSheet s={s} onClose={close} />}
      {route?.name === "settings" && <SettingsSheet s={s} onClose={close} />}
      <AnimatePresence>
        {route?.name === "timer" && <TimerCover key="timer" s={s} habitID={route.habitID} slotID={route.slotID} onClose={close} />}
      </AnimatePresence>
      <AnimatePresence>{showOnboarding && <Onboarding key="onb" s={s} />}</AnimatePresence>

      <ToastHost toast={s.toast} showOriginal={s.prefs.showSanskrit} />
      <Celebration count={s.celebration} quote={hx.quote("dayComplete")} />
    </>
  );
}
