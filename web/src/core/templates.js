import { uuid } from "./model.js";

const ALL = [1, 2, 3, 4, 5, 6, 7];

export const TEMPLATES = [
  { name: "Meditate", symbol: "figure.mind.and.body", color: "indigo", kind: "timed", times: ["06:00"], weekdays: ALL, target: 10, cue: "I wake up and wash my face", place: "on my mat", identity: "a calm person", minimum: "three slow breaths" },
  { name: "Surya Namaskar", symbol: "sun.max.fill", color: "orange", kind: "check", times: ["06:15"], weekdays: ALL, target: 1, cue: "I finish meditating", place: "facing the sunrise", identity: "someone who moves every day", minimum: "one round" },
  { name: "Pranayama", symbol: "wind", color: "teal", kind: "timed", times: ["06:30"], weekdays: ALL, target: 5, cue: "I finish Surya Namaskar", place: "sitting by the window", identity: "a calm person", minimum: "ten breaths" },
  { name: "Drink water", symbol: "drop.fill", color: "teal", kind: "count", times: ["09:00", "12:30", "16:00", "19:00"], weekdays: ALL, target: 8, unit: "glasses", cue: "I sit down at my desk", identity: "someone who looks after their body", minimum: "four glasses" },
  { name: "Vitamins", symbol: "pills.fill", color: "yellow", kind: "check", times: ["08:00", "20:00"], weekdays: ALL, target: 1, cue: "I have breakfast", identity: "someone who looks after their body" },
  { name: "Read 20 minutes", symbol: "book.fill", color: "pink", kind: "check", times: ["21:30"], weekdays: ALL, target: 1, cue: "I put my phone on the charger", place: "in bed", identity: "a reader", minimum: "one page" },
  { name: "Evening walk", symbol: "figure.walk", color: "green", kind: "check", times: ["18:30"], weekdays: ALL, target: 1, cue: "I close my laptop", place: "around the block", identity: "someone who moves every day", minimum: "five minutes outside" },
  { name: "Work out", symbol: "dumbbell.fill", color: "red", kind: "check", times: ["07:00"], weekdays: [2, 4, 6], target: 1, cue: "I change into my gym clothes", place: "at the gym", identity: "a strong person", minimum: "ten push-ups" },
  { name: "Journal", symbol: "pencil.line", color: "graphite", kind: "check", times: ["22:00"], weekdays: ALL, target: 1, cue: "I finish the evening review", identity: "someone who reflects", minimum: "one sentence" },
  { name: "No phone in bed", symbol: "iphone.slash", color: "indigo", kind: "quit", times: ["22:30"], weekdays: ALL, target: 1, identity: "someone who sleeps well" },
  { name: "No sugar", symbol: "nosign", color: "red", kind: "quit", times: ["16:00"], weekdays: ALL, target: 1, identity: "someone in charge of their cravings" },
];

export function makeHabit(t, createdOn, order = 0) {
  return {
    id: uuid(), name: t.name, symbol: t.symbol, color: t.color, kind: t.kind, weekdays: [...t.weekdays],
    slots: t.times.map((time) => ({ id: uuid(), time, remind: true })), target: t.target, unit: t.unit || "",
    cue: t.cue || "", place: t.place || "", identity: t.identity || "", minimum: t.minimum || "", treat: "",
    createdOn, archived: false, order,
  };
}
