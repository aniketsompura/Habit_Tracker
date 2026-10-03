# Sadhana

A native iPhone habit tracker built with SwiftUI. Each habit is a diya (clay lamp) that lights when you do it, placed on a sky that follows the time of day. Reminders arrive at each habit's preferred time, and Stoic and Hindu wisdom shows up at the moments it helps most.

## What's inside

**Habits**
- Four kinds: **yes / no**, **count** (8 glasses of water), **timed** (meditate 10 minutes, with a breathing guide and a Lock Screen countdown) and **quit** (no sugar; each day counts unless you log a slip).
- **Several times a day.** "Vitamins at 8 am and 8 pm" is two lamps, each with its own reminder.
- **Days of the week** for each habit. Days a habit isn't scheduled never break its streak.

**Reminders**
- A notification at each preferred time, with **Done**, **+1**, **Start timer** or **Snooze 15 min** buttons.
- One gentle follow-up if a habit is still open. It offers **Did the minimum**.
- Reminders for things you've already done are cancelled. Quit habits get one nudge at your "risky time".

**The psychology built in**
- **When-then plans.** "After I make coffee, I will read on the balcony." The editor builds the sentence, and reminders use it.
- **Never miss twice.** One missed day is forgiven; two in a row break the chain. After a miss, the app says so kindly and shows a recovery quote.
- **A minimum for hard days.** Every habit can have a tiny version that still keeps the chain.
- **Votes and the mala.** Each kept day is a vote for who you're becoming ("212 votes for being a reader"). Votes fill a 108-bead mala.
- **Fresh starts.** Mondays, the 1st of the month and your birthday get a fresh-start card.
- **Morning Sankalpa:** one intention, plus one habit that can't slip.
- **Evening review:** Seneca's three questions (On Anger 3.36).
- **Timing insights.** If you always read at 9:40 pm instead of 9:00, Journey offers to move the reminder.

**Wisdom**
- 124 sourced quotes: Marcus Aurelius, Epictetus, Seneca, Musonius Rufus, Zeno, the Bhagavad Gita, the Upanishads, the Vedas, the Yoga Sutras, Vivekananda, Kabir, Bhartṛhari and more.
- Sanskrit and Hindi originals with transliteration.
- Quotes are matched to moments: morning, after a miss, a long streak, an urge, the timer, a completed day.

**Widgets**
- Home screen **Up next** (small) and **Today's lamps** (medium). Both have buttons that light a lamp without opening the app.
- Lock Screen widgets.
- A Live Activity for timed habits.

**Your data**
- Everything stays on your iPhone in one file.
- Settings → Backup saves it to Files or iCloud Drive, and restores it later.
- You can also import a backup from the Habit Chain web tracker.

## Put it on your iPhone

You need a Mac, a USB cable for your iPhone, and an Apple ID.

1. **Install Xcode** from the Mac App Store. It's free.
2. **Get the code.** Either:
   - On GitHub, switch to the branch `claude/iphone-habit-tracker-vx0avy`, then choose **Code → Download ZIP**, or
   - Run `git clone -b claude/iphone-habit-tracker-vx0avy https://github.com/aniketsompura/Habit_Tracker.git`
3. **Open the project.** Double-click `ios/Sadhana.xcodeproj`.
4. **Add your Apple ID.** Xcode → Settings → Accounts → **+** → Apple ID.
5. **Set signing.** Click **Sadhana** at the top of the left sidebar. For each target, **Sadhana** and **SadhanaWidgets**:
   - Open **Signing & Capabilities**.
   - Set **Team** to your name (Personal Team).
6. **Prepare your iPhone.**
   - Connect it with the cable and tap **Trust** on the phone.
   - Turn on Settings → Privacy & Security → **Developer Mode** (the phone restarts).
7. **Run it.** Choose your iPhone at the top of the Xcode window and press **Run** (⌘R).
8. **Trust yourself as a developer.** The first time, iPhone may say "Untrusted Developer". Go to Settings → General → VPN & Device Management, tap your Apple ID, then **Trust**.
9. **Allow reminders** when Sadhana asks.
10. **Add widgets.**
    - Home screen: long-press the home screen → **Edit → Add Widget → Sadhana**.
    - Lock Screen: long-press the Lock Screen → **Customize**.

### With a free Apple ID

- **Apps expire after 7 days.** Plug in your iPhone and press Run again. Your habits and history are kept as long as you don't delete the app.
- **The paid Apple Developer Program** ($99 a year) makes the app last a year between installs.

### If something goes wrong

- **"Failed to register bundle identifier" or "No profiles for…"**
  - The app's ID is already taken.
  - Click the **Sadhana** project, open **Build Settings**, search for `SADHANA_ID_PREFIX`, and change `com.aniketsompura` to something unique, like `com.yourname.habits`.
- **"Personal development teams do not support App Groups"**
  - Remove **App Groups** from both targets under Signing & Capabilities.
  - The app works normally. The widgets show "turn on widgets" until you use a paid account and add the App Group back.
- **No reminders.** Check Settings → Notifications → Sadhana. In the app, Habits → gear → Reminders shows the status.
- **No Lock Screen timer.** Turn on Settings → Sadhana → Live Activities.

## Code layout

| Folder | What it holds |
| --- | --- |
| `Core/` | Plain Swift logic shared by the app and widgets: models, streaks, agenda, reminder planning, quotes (`Resources/quotes.json`), backup, templates. |
| `CoreTests/` | Unit tests for `Core`. Run with `swift test --package-path ios`. |
| `Shared/` | SwiftUI and system code used by both the app and widgets: theme, sky, the diya drawing, data file, notifications, App Intents, the timer Live Activity. |
| `Sadhana/` | The app: Today, Habits, Journey, Wisdom, Settings, rituals, timer, onboarding. |
| `SadhanaWidgets/` | Home screen and Lock Screen widgets and the Live Activity. |
| `Config/` | Info.plists and entitlements. |

The Xcode project uses synchronized folders, so new Swift files in these folders are picked up automatically. Every push builds the app and runs the tests on GitHub's macOS runners (`.github/workflows/ios.yml`).

Minimum iOS version: 17.
