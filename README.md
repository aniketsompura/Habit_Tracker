# Hexis

A habit tracker in two forms that share one data format:

| | What it is | Start here |
| --- | --- | --- |
| **iPhone app** | Native SwiftUI app with reminders at each habit's time, home screen and Lock Screen widgets, and a Lock Screen timer. Needs a Mac with Xcode to install. | [`ios/README.md`](ios/README.md) |
| **Web app** | The same design and features, running as a claude.ai artifact. Opens anywhere you're signed in; no reminders or widgets. | Below |

A backup saved from either one restores into the other.

## Web app

Source is in `web/`. React draws the screens, Framer Motion animates the rings, sheets and transitions, and the habit logic in `web/src/core/` is a straight port of the iPhone app's `Core`, so streaks, milestones and quotes work the same way. The 124 quotes come from `ios/Core/Resources/quotes.json`.

### What's in it

- **Today**: a sky that follows the time of day, with each habit placed at its preferred time. Tap a ring to complete it, add one, start a timer or log a slip. The **⋯** button holds "Did the minimum", undo, −1 and Edit. The week strip lets you fill in past days.
- **Habits**: four kinds (yes/no, count, timed, quit), several times a day, days of the week, and the "make it stick" plan (cue, place, identity, hard-day minimum). Drag to reorder.
- **Psychology**: never miss twice, a minimum for hard days, votes and milestones, fresh-start cards, morning Sankalpa, Seneca's evening review and timing insights ("Move it to 9:40 pm").
- **Wisdom**: Stoic and Hindu quotes matched to the moment, with Sanskrit originals, search and saved quotes.
- **Settings**: rituals, quote tradition, birthday, backup and restore.

### Build and publish

```sh
cd web
npm install
npm run build        # writes dist/hexis.html
```

`dist/hexis.html` is the page published to the artifact. React and Framer Motion load from cdnjs and jsDelivr; everything else is inline.

### How data is stored

The page uses the artifact's `db` capability, so your data follows you to any device where you're signed in to claude.ai. Each document matches the iPhone app's JSON.

| Path | Contents |
| --- | --- |
| `hx_habits/<habit id>` | One habit: name, symbol, color, kind, weekdays (1 = Sunday … 7 = Saturday), slots (times), target, unit, cue, place, identity, minimum, created date, order, archived |
| `hx_days/<YYYY-MM-DD>` | One day: check-in entries, Sankalpa intention and focus habit, evening review, log note |
| `hx_settings/main` | Preferences, saved quotes, flags |

The page used to run Habit Chain, an earlier and simpler tracker. Its `habits` and `months` collections are left untouched. On first open, Hexis offers to bring those habits and check-ins across, and Settings → Backup can import them later.

### On your iPhone

Open the artifact link in Safari, signed in to claude.ai, then tap **Share → Add to Home Screen**. For reminders and widgets, install the native app from `ios/`, then restore a backup saved from the web app.
