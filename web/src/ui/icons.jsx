// SF Symbol names (as stored in habits, shared with the iPhone app) mapped to Lucide icons.
import React from "react";
import {
  Activity, Archive, ArchiveRestore, BadgeCheck, Ban, BedDouble, Bell, BellOff, Bike, BookMarked, BookOpen, Brain, Carrot, Check,
  ChevronLeft, ChevronRight, Circle, CircleCheck, CircleDashed, Clock, Coffee, CornerLeftUp, Download, Droplet, Dumbbell, Ellipsis,
  Eye, Flame, Flower2, Footprints, GraduationCap, GripVertical, HandHeart, Heart, HeartPulse, Hexagon, History, Hourglass, Info,
  Landmark, Leaf, Library, ListChecks, Minus, Moon, MoonStar, Music, Paintbrush, Pause, PenLine, Pencil, PersonStanding, PhoneOff, Pill,
  Play, Plus, Quote, Search, Settings, ShieldAlert, Sparkles, Star, Sun, Sunrise, Sunset, Timer, Trash2, TriangleAlert, Undo2, Upload,
  Utensils, Wind, X,
} from "lucide-react";

const SYMBOLS = {
  sparkles: Sparkles, "sun.max.fill": Sun, "sunrise.fill": Sunrise, "moon.stars.fill": MoonStar, "figure.mind.and.body": Flower2,
  "figure.yoga": PersonStanding, "figure.walk": Footprints, "figure.run": Activity, "dumbbell.fill": Dumbbell, bicycle: Bike, wind: Wind,
  "lungs.fill": HeartPulse, "drop.fill": Droplet, "cup.and.saucer.fill": Coffee, "leaf.fill": Leaf, "carrot.fill": Carrot,
  "fork.knife": Utensils, "pills.fill": Pill, "bed.double.fill": BedDouble, "book.fill": BookOpen, "books.vertical.fill": Library,
  "pencil.line": PenLine, "brain.head.profile": Brain, "graduationcap.fill": GraduationCap, "music.note": Music,
  "paintbrush.fill": Paintbrush, "hands.sparkles.fill": HandHeart, "heart.fill": Heart, "flame.fill": Flame, hourglass: Hourglass,
  "iphone.slash": PhoneOff, nosign: Ban, "checkmark.seal": BadgeCheck, checkmark: Check, xmark: X,
};

/** The habit symbols offered in the editor, in the iPhone app's order. */
export const HABIT_SYMBOLS = [
  "sparkles", "sun.max.fill", "sunrise.fill", "moon.stars.fill", "figure.mind.and.body", "figure.yoga", "figure.walk", "figure.run",
  "dumbbell.fill", "bicycle", "wind", "lungs.fill", "drop.fill", "cup.and.saucer.fill", "leaf.fill", "carrot.fill",
  "fork.knife", "pills.fill", "bed.double.fill", "book.fill", "books.vertical.fill", "pencil.line", "brain.head.profile", "graduationcap.fill",
  "music.note", "paintbrush.fill", "hands.sparkles.fill", "heart.fill", "flame.fill", "hourglass", "iphone.slash", "nosign",
];

const UI = {
  plus: Plus, minus: Minus, left: ChevronLeft, right: ChevronRight, more: Ellipsis, settings: Settings, star: Star, undo: Undo2,
  leaf: Leaf, edit: Pencil, timer: Timer, archive: Archive, restore: ArchiveRestore, trash: Trash2, bell: Bell, bellOff: BellOff,
  shield: ShieldAlert, heart: Heart, quote: Quote, search: Search, download: Download, upload: Upload, clock: History, sunrise: Sunrise,
  recover: CornerLeftUp, eye: Eye, alert: TriangleAlert, stoic: Landmark, hindu: Sunset, play: Play, pause: Pause, check: Check, x: X,
  flame: Flame, today: Sun, habits: ListChecks, journey: Hexagon, wisdom: BookMarked, grip: GripVertical, done: CircleCheck,
  circle: Circle, info: Info, moon: MoonStar, sparkles: Sparkles, time: Clock,
  anytime: CircleDashed, earlyMorning: MoonStar, morning: Sunrise, afternoon: Sun, evening: Sunset, night: Moon,
};

export function Icon({ name, size = 20, strokeWidth = 2, ...rest }) {
  const C = UI[name] ?? SYMBOLS[name] ?? Sparkles;
  return <C size={size} strokeWidth={strokeWidth} aria-hidden="true" {...rest} />;
}

export function Symbol({ name, size = 20, strokeWidth = 2, ...rest }) {
  const C = SYMBOLS[name] ?? Sparkles;
  return <C size={size} strokeWidth={strokeWidth} aria-hidden="true" {...rest} />;
}
