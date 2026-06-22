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
Launch with `TALLY_DEMO=1` to seed sample data. `TALLY_TAB=ledger|insights|budget|settings`
opens a specific tab; `TALLY_QUICKADD=1` opens the add sheet; `TALLY_SCREEN=recurring`
opens the recurring screen. All gated by environment variables — never run in normal use.

## Features

- **Fast capture** — floating ＋ → calculator keypad. `Spent / Lent / Received` so it
  doubles as an informal lending tracker ("I gave ₹X to Arjun").
- **Every entry stamps date & time** (editable), grouped by day.
- **Themes** — editable categories with icon, color, and an optional budget allocation.
- **Budgeting** — monthly income, **set-asides** (incl. a first-class *Family* set-aside),
  **expendable income**, each theme as a **% of expendable income**, a spending
  **blocker** with override, and a **"safe to spend"** daily allowance + pace projection.
- **Recurring payments** — recharge, gym, rent, subscriptions; a **"Coming up" home card**
  for anything due within 5 days, one-tap **Pay**, and **local notifications** (5 days
  before + on the day).
- **Message capture (compliant)** — iOS forbids silent SMS reading. Instead a **Shortcuts
  automation** calls the *Log Transaction* App Intent, and a **Share Sheet** parses any
  message you share in. See Settings → *Auto-add from messages*.
- **Widgets** — Home + Lock Screen "safe to spend" / today's total, with a quick-add link.
- **Appearance** — System / Light / **Dark** mode toggle in Settings; adaptive graphite accent.
- **Backup** — CSV / JSON export via the share sheet.

## Architecture

| Area | Where |
|------|-------|
| Shared models (SwiftData) | `Shared/Models/` — Expense, Category, Payee, BudgetSettings, Commitment, RecurringPayment |
| Pure logic (unit-tested) | `Shared/Core/Money.swift`, `Shared/Budget/{BudgetEngine,RecurringEngine}.swift`, `Shared/Parsing/TransactionParser.swift` |
| Shared store + ops | `Shared/Persistence/`, `Shared/Budget/LedgerService.swift` |
| App UI | `Pi/Features/*` (Ledger, QuickAdd, EditExpense, People, Themes, Insights, Budget, Recurring, Settings) |
| Intents | `Pi/Intents/PiIntents.swift` |
| Widgets | `PiWidgets/` |
| Share extension | `PiShareExtension/` |
| Tests | `PiTests/` (`@testable import Pi`) |

Money is stored as **integer minor units** (paise) — never floating point. Only
2-decimal currencies are offered (the minor-unit scale assumes 100). 26 unit tests cover
Money, BudgetEngine, RecurringEngine, and TransactionParser.

## Installing on a real iPhone

**Free Apple ID (default):** the project ships **without** the App Group capability so it
signs with a free personal team. Set your **Team** on the Pi / PiWidgets / PiShareExtension
targets (Signing & Capabilities), select your phone, ⌘R, then trust the developer cert in
Settings → General → VPN & Device Management. The main app works fully (local storage);
the widget + Share-sheet can't share data without App Groups, and the build expires in ~7
days (just re-run).

**Paid Apple Developer account:** add the **App Group** capability `group.ai.pageloop.pi`
back to all three targets to enable widget + Share-sheet data sharing; the build then lasts
a year and can ship via TestFlight / the App Store.

## Design

The validated design spec lives in
`docs/superpowers/specs/2026-06-22-tally-expense-tracker-design.md`.
