# π — a local-first expense tracker for iPhone

A minimalist, fast, **100% on-device** expense tracker built with SwiftUI + SwiftData.
No accounts, no network, no analytics — your data never leaves the phone unless you
export it.

## Run it

```sh
brew install xcodegen        # one-time, if not installed
xcodegen generate            # regenerates Tally.xcodeproj from project.yml
open Tally.xcodeproj          # then pick an iPhone simulator and press ⌘R
```

Requires Xcode 26+ (iOS 18+ deployment, built against the iOS 26 SDK).

### Run the tests
```sh
xcodebuild test -project Tally.xcodeproj -scheme Tally \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' CODE_SIGNING_ALLOWED=NO
```

### See it populated (dev only)
Launch with `TALLY_DEMO=1` to seed sample data. `TALLY_TAB=ledger|insights|budget|settings`
opens a specific tab; `TALLY_QUICKADD=1` opens the add sheet. These are gated by
environment variables and never run in normal use.

## Features

- **Fast capture** — floating ＋ → calculator keypad. `Spent / Lent / Received` so it
  doubles as an informal lending tracker ("I gave ₹X to Arjun").
- **Every entry stamps date & time** (editable), grouped by day.
- **Themes** — editable categories with icon, color, and an optional budget allocation.
- **Budgeting** — monthly income, **commitment blocks** (incl. a first-class *Family*
  commitment), **expendable income**, each theme as a **% of expendable income**, a
  spending **blocker** with override, and a **"safe to spend"** daily allowance + pace
  projection.
- **Message capture (compliant)** — iOS forbids silent SMS reading. Instead:
  - a **Shortcuts automation** calls the *Log Transaction* App Intent with the message text;
  - a **Share Sheet** ("Add to π") parses any message you share in.
  See Settings → *Auto-add from messages* for setup steps.
- **Widgets** — Home Screen + Lock Screen "safe to spend" / today's total, with a
  quick-add deep link.
- **Siri / App Shortcuts** — "Add an expense in π".
- **Backup** — CSV / JSON export via the share sheet.

## Architecture

| Area | Where |
|------|-------|
| Shared models (SwiftData) | `Shared/Models/` — Expense, Category, Payee, BudgetSettings, Commitment |
| Pure logic (unit-tested) | `Shared/Core/Money.swift`, `Shared/Budget/BudgetEngine.swift`, `Shared/Parsing/TransactionParser.swift` |
| Shared store + ops | `Shared/Persistence/`, `Shared/Budget/LedgerService.swift` (App Group `group.ai.pageloop.tally`) |
| App UI | `Tally/Features/*` (Ledger, QuickAdd, EditExpense, People, Themes, Insights, Budget, Settings) |
| Intents | `Tally/Intents/TallyIntents.swift` |
| Widgets | `TallyWidgets/` |
| Share extension | `TallyShareExtension/` |

Money is stored as **integer minor units** (paise) — never floating point. Only
2-decimal currencies are offered in Settings (the minor-unit scale assumes 100).

## Running on a real iPhone

For each of the 3 targets (Tally, TallyWidgets, TallyShareExtension): **Signing &
Capabilities** → set your **Team** (a free Apple ID works). Xcode provisions the App
Group `group.ai.pageloop.tally` automatically. Then select your phone and ⌘R.

## Design

The validated design spec lives in `docs/superpowers/specs/2026-06-22-tally-expense-tracker-design.md`.
