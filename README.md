# π — a local-first expense tracker for iPhone

A minimalist, **100% on-device** expense tracker built with SwiftUI + SwiftData.
No accounts, no network, no analytics — your data never leaves the phone unless you
export it. The app is named **π** (the home-screen name); the Xcode project/targets
are named **Pi**.

## Run it

```sh
brew install xcodegen        # one-time, if not installed
xcodegen generate            # regenerates Pi.xcodeproj from project.yml
open Pi.xcodeproj             # then pick an iPhone simulator and press ⌘R
```

Requires Xcode 26+ (iOS 18+ deployment, built against the iOS 26 SDK).

### Run the tests
```sh
xcodebuild test -project Pi.xcodeproj -scheme Pi \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' CODE_SIGNING_ALLOWED=NO
```

### See it populated (dev only)
Launch with `TALLY_DEMO=1` to seed sample data (add `TALLY_OVER=1` to preview the
over-budget state). Other `TALLY_*` flags — `TALLY_TAB`, `TALLY_QUICKADD`, `TALLY_INSIGHTS`,
`TALLY_SCREEN` — jump straight to a tab or screen during development. All gated by
environment variables — never active in normal use.

## Features

- **Fast capture** — a floating **π** opens the add sheet on the native number pad; confirm
  with **Add** in the top bar. `Spent / Lent / Received` so it doubles as an informal lending
  tracker ("I gave ₹X to Arjun"). Touch-and-hold π for a radial fan (expense / theme / person
  / recurring).
- **Every entry stamps date & time** (editable), grouped by day.
- **Themes** — editable categories with icon, color, and an optional budget allocation.
- **Budgeting** — monthly income, **set-asides** (incl. a first-class *Family* set-aside),
  **expendable income**, each theme as a **% of expendable income**, a spending
  **blocker** with override, and a **"safe to spend"** daily allowance + pace projection.
- **Savings & carry-over** — a **Savings** tab tracks money kept each month over time; an
  optional **lag** rolls last month's overspend into this month's ceiling.
- **Recurring payments** — recharge, gym, rent, subscriptions; a **"Coming up" home card**
  for anything due within 5 days, one-tap **Paid**, calendar-style date tiles, and **local
  notifications** (5 days before + on the day).
- **Trips** — split shared costs Splitwise-style (in the **More** tab): add members, log who
  paid and who shares (split equally), see per-person balances and the minimal **settle-up**
  transfers, and attach a **bill photo** from the library or the **camera**. Kept entirely
  separate from your personal budget.
- **Message capture (compliant)** — iOS forbids silent SMS reading. Instead a **Shortcuts
  automation** calls the *Log Transaction* App Intent, and a **Share Sheet** parses any
  message you share in. See More → *Auto-add from messages*.
- **Widgets** — Home + Lock Screen "safe to spend" / today's total, with a quick-add link.
- **Goal banner** — an optional monthly goal/quote shown as a stylish banner on the home screen.
- **Appearance** — System / Light / **Dark** mode toggle; adaptive graphite accent.
- **Backup & reset** — CSV / JSON export via the share sheet; a guarded **reset all data**.

## Architecture

| Area | Where |
|------|-------|
| Shared models (SwiftData) | `Shared/Models/` — Expense, Category, Payee, BudgetSettings, Commitment, RecurringPayment, SavingsRecord, Trip / TripMember / TripExpense |
| Pure logic (unit-tested) | `Shared/Core/Money.swift`, `Shared/Budget/{BudgetEngine,RecurringEngine,TripEngine}.swift`, `Shared/Parsing/TransactionParser.swift` |
| Shared store + ops | `Shared/Persistence/`, `Shared/Budget/LedgerService.swift` |
| App UI | `Pi/Features/*` (Ledger, QuickAdd, EditExpense, People, Themes, Insights, Savings, Budget, Recurring, Trips, Settings/More) |
| Intents | `Pi/Intents/PiIntents.swift` |
| Widgets | `PiWidgets/` |
| Share extension | `PiShareExtension/` |
| Tests | `PiTests/` (`@testable import Pi`) |

Money is stored as **integer minor units** (paise) — never floating point. Only
2-decimal currencies are offered (the minor-unit scale assumes 100). 31 unit tests cover
Money, BudgetEngine, RecurringEngine, TransactionParser, and TripEngine (the trip split +
settle-up math).

## Installing on a real iPhone

**Free Apple ID (default):** the project ships **without** the App Group capability so it
signs with a free personal team. Set your **Team** on the Pi / PiWidgets / PiShareExtension
targets (Signing & Capabilities) — or set `DEVELOPMENT_TEAM` in `project.yml` and re-run
`xcodegen generate` — select your phone, ⌘R, then trust the developer cert in
Settings → General → VPN & Device Management. The main app works fully (local storage);
the widget + Share-sheet can't share data without App Groups, and the build **expires in ~7
days** with a free account (just re-build; see below).

**Paid Apple Developer account:** add the **App Group** capability `group.ai.pageloop.pi`
back to all three targets to enable widget + Share-sheet data sharing; the build then lasts
a year and can ship via TestFlight / the App Store.

## Design

The validated design spec lives in
`docs/superpowers/specs/2026-06-22-tally-expense-tracker-design.md`.
