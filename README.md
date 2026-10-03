# Habit Chain

A personal habit tracker for iPhone. It runs as a claude.ai artifact, and your habits, daily check-ins and notes are saved in the artifact's own database.

`habit-chain.html` is the full source of the published page.

## What it does

- **Today**: tap a habit to check it off. Habits you do more than once a day (like 8 glasses of water) count up with each tap, and **−1** undoes one tap. Use the week strip to go back and fill in days you missed. Each row shows the last 7 days as a chain.
- **Schedules**: pick the days a habit applies to (every day, weekdays, Mon/Wed/Fri…). Days that aren't scheduled never break a chain.
- **Daily log**: write a note for any day. All your notes appear on the Progress tab.
- **Progress**: completion for this week and the last 30 days, your current and best chain for each habit, and an 18-week map of every check-in.
- **Habits**: add, edit, reorder, archive (keeps the history) or delete habits.
- **Backup**: save everything as a `.json` file, and restore from one later.

## Using it on your iPhone

1. Open the artifact link in **Safari** and sign in to claude.ai.
2. Tap **Share → Add to Home Screen**.
3. Open Habit Chain from that icon each day.

You can also pin it in the claude.ai sidebar so it's easy to find in the Claude app.

### About widgets

Only native apps built with Xcode can add home screen widgets on iOS. A web page, including this artifact, can't. Here are the closest options:

- **Home screen icon** (above). It opens the tracker with one tap.
- **Shortcuts widget**: make a shortcut with an *Open URLs* action that points at the artifact link, then add the Shortcuts widget to your home screen. It's a button that opens the tracker. It can't show your progress.
- **Native app later**: if you get access to a Mac, the next step would be a SwiftUI app with an interactive WidgetKit widget. You'd use the backup file to move your data into it.

## How data is stored

The page uses the artifact `db` capability. Nothing is saved in your browser, so your data follows you to any device where you're signed in.

| Collection | Document | Contents |
| --- | --- | --- |
| `habits` | one per habit | `name`, `color`, `days` (0 = Sunday … 6 = Saturday), `target` per day, `unit`, `createdAt` (`YYYY-MM-DD`), `order`, `archived` |
| `months` | one per month, id `YYYY-MM` | `days: { "DD": { <habitId>: count } }`, `notes: { "DD": "text" }` |

The artifact is private by default. Anyone you share it with can see your habits. Only you, and people you give Contributor access, can log check-ins.
