# Tally — Local-First Expense Tracker (iOS)

**Date:** 2026-06-22
**Status:** Approved (decisions auto-resolved except message-capture, chosen by user)
**Platform:** iOS 18+ (built with Xcode 26.5 / Swift 6.3, iOS 26 SDK)

## Goal

A minimalist, fast, fully on-device expense tracker. The fastest possible "I spent
X" capture, with first-class support for "I gave money to a person", per-expense
date/time, spending *themes* (categories), and App-Store-compliant capture of
bank/UPI transaction texts via Apple Shortcuts automation + a Share Sheet.

## Non-negotiable constraints

1. **100% local.** No network calls, no accounts, no analytics, no third-party SDKs.
   All data lives in a SwiftData store inside the app sandbox + a shared App Group
   container (so widgets/extensions can read it). Backups are user-initiated CSV/JSON
   export via the share sheet. No iCloud by default (a clean seam is left to enable
   private CloudKit sync later).
2. **Fast capture.** Adding an expense is ≤ 2 taps from the home screen via quick-add
   chips (frequent people + frequent themes).
3. **Native & minimal.** SwiftUI, SF Symbols, SF fonts, system materials, haptics,
   Dynamic Type, light/dark, swipe actions, large titles. One accent color.

## Decisions (auto-resolved)

| # | Topic | Decision |
|---|-------|----------|
| 1 | Quick actions | Home-screen chips for frequent payees & themes. Expense has optional `payee` + `direction` (paid / lent / owedToMe) so it doubles as informal lending tracking. |
| 2 | Date/time | Every expense auto-stamps `date = .now` (editable), stored with the device timezone identifier. Ledger groups entries by calendar day. |
| 3 | Storage | SwiftData, App Group container `group.ai.pageloop.tally`. No network. CSV + JSON export. |
| 4 | Look & native features | Minimal design system, haptics, Dynamic Type, dark mode, Home + Lock Screen widgets, Siri/App Shortcuts. |
| 5 | Message capture | **Shortcuts automation + Share Sheet** (user choice). iOS forbids silent inbox reading; this is the compliant path. |
| 6 | Themes | `Category` model with name + SF Symbol + color hex. Pre-seeded, fully editable. Insights screen shows totals per theme + per person. |
| 7 | Budgeting | Monthly income + commitment blocks (incl. a first-class Family commitment) → expendable income. Per-theme spend shown as % of expendable income. A spending **blocker** (monthly ceiling + optional per-theme caps) that requires explicit override. "Safe to spend" daily allowance + month-end pace projection. |

## Data model (SwiftData)

```
Expense
  id: UUID
  amountMinor: Int          // integer minor units (paise/cents) — never Double for money
  currencyCode: String      // ISO 4217, default "INR"
  note: String
  date: Date                // when the money moved (editable)
  createdAt: Date           // immutable audit stamp
  timeZoneId: String        // e.g. "Asia/Kolkata"
  direction: Direction      // .paid | .lent | .owedToMe
  source: EntrySource       // .manual | .quickAdd | .message | .shareSheet
  category: Category?       // theme (to-one)
  payee: Payee?             // person (to-one, optional)
  rawMessage: String?       // original text if captured from a message

Category (theme)
  id, name, symbolName (SF Symbol), colorHex, sortIndex, isArchived
  expenses: [Expense]       // inverse

Payee (person)
  id, name, note, colorHex, createdAt
  expenses: [Expense]       // inverse
  // derived: net balance across .lent / .owedToMe expenses

BudgetSettings (single row, created on first launch)
  id
  monthlyIncomeMinor: Int
  currencyCode: String
  monthlyCeilingMinor: Int?  // explicit overall cap; nil ⇒ ceiling = expendable income
  enforceBlocker: Bool       // require override when an expense breaches the ceiling
  monthStartDay: Int         // 1 = calendar month (kept simple for v1)

Commitment (fixed monthly set-aside; NOT an expense)
  id, name, amountMinor, symbolName, colorHex, createdAt, isActive
  kind: CommitmentKind       // .family | .housing | .loan | .savings | .other

Category gains:
  allocationPercent: Double? // optional envelope: % of expendable income for this theme
```

`CommitmentKind` is a `String`-backed enum; `.family` is surfaced distinctly in the UI.

### Derived budget math (`BudgetEngine`, pure & tested)

```
committedMinor   = Σ active commitments
expendableMinor  = max(0, monthlyIncome − committedMinor)
outflowThisMonth = Σ expenses in current budget month where direction ∈ {paid, lent}
ceilingMinor     = monthlyCeilingMinor ?? expendableMinor
safeToSpendMinor = ceilingMinor − outflowThisMonth
dailyAllowance   = safeToSpendMinor / daysRemainingInMonth
themeSpendPct    = themeOutflowThisMonth / expendableMinor        // the "% per theme"
themeBudgetMinor = allocationPercent/100 × expendableMinor        // optional per-theme cap
projectedSpend   = outflowThisMonth / daysElapsed × daysInMonth   // pace projection
```
`.owedToMe` is tracked as a receivable per person; it does not increase income.

`Direction` and `EntrySource` are `String`-backed `Codable` enums.
Money is stored as **integer minor units** to avoid floating-point drift; a
`Money` helper formats/parses against `currencyCode`.

## Modules

- **App/** — `TallyApp` (entry), `ModelContainer` setup against the App Group,
  seed-on-first-launch for default categories, deep-link routing (`tally://add`).
- **DesignSystem/** — `Theme` (colors, spacing, radii, typography), `Haptics`,
  reusable `Chip`, `AmountText`, `CategoryGlyph`.
- **Models/** — the SwiftData models + enums + `Money`.
- **Features/Ledger/** — grouped-by-day list, swipe-to-delete, running totals, search.
- **Features/QuickAdd/** — bottom sheet: amount keypad, payee chips, theme chips,
  direction toggle. The 2-tap path.
- **Features/EditExpense/** — full editor (date/time picker, all fields).
- **Features/People/** — manage payees, per-person balance & history.
- **Features/Themes/** — manage categories (icon + color picker).
- **Features/Insights/** — totals by theme & person, this month / all time, plus each
  theme's spend as **% of expendable income**.
- **Features/Budget/** — income + commitments editor (Family commitment highlighted),
  expendable-income breakdown, per-theme allocations, the "Safe to spend" banner,
  ceiling/blocker settings, and the pace projection. `BudgetEngine` holds the pure math.
- **Features/Settings/** — currency, export CSV/JSON, Shortcuts setup help.
- **Parsing/** — `TransactionParser`: regex-based extraction of amount, merchant,
  direction from bank/UPI SMS text. Pure, unit-tested, no I/O.
- **Intents/** — `AddExpenseIntent` (manual Siri add) + `LogTransactionFromTextIntent`
  (used by the Shortcuts automation; takes message text → parses → inserts).
  `TallyShortcuts: AppShortcutsProvider` exposes them to Siri/Spotlight.
- **ShareExtension/** — share selected text → `TransactionParser` → pre-filled add UI.
- **Widgets/** — `TodayWidget` (today's total + accent) supporting Home Screen
  (systemSmall/Medium) and Lock Screen (accessoryRectangular/Circular), with a
  quick-add deep link.

## Shared store access

Widgets, the Share Extension, and Intents all need the data. They share the App
Group `group.ai.pageloop.tally`. `ModelContainerProvider` builds a `ModelContainer`
pointing at the App Group container URL so every target reads/writes the same store.

## Message capture flow (point 5)

1. **Share Sheet:** user selects bank/UPI text in Messages → Share → Tally →
   `TransactionParser` pre-fills amount/merchant/direction → user confirms (1 tap).
2. **Shortcuts automation:** user creates a personal automation ("When I get a
   message containing 'debited'/'UPI'/'spent' → Run Tally: Log Transaction"). The
   automation passes the message text to `LogTransactionFromTextIntent`, which parses
   and inserts silently (or asks first, per the automation's "Ask Before Running").
   Settings screen has step-by-step instructions for setting this up once.

Parser handles: `Rs`, `Rs.`, `INR`, `₹`; amounts with commas/decimals; keywords
`debited`/`spent`/`paid`/`sent` → `.paid`, `credited`/`received` → `.owedToMe`;
merchant after `at`/`to`/`VPA`. Unknown → amount only, user fills the rest.

## Budgeting & the spending blocker (point 7)

- **Income & commitments:** user enters monthly income once. Commitments are fixed
  monthly set-asides; the **Family commitment** is a first-class `kind` shown with a
  distinct badge. `expendable = income − Σ commitments`.
- **Per-theme %:** Insights and the Budget screen show each theme's spend as a
  percentage of expendable income. If a theme has an `allocationPercent`, a progress
  bar compares spend vs its envelope.
- **The blocker:** a monthly ceiling (defaults to expendable income). On save, if
  `enforceBlocker` and the new monthly outflow would exceed the ceiling, a blocking
  alert appears: *"This puts you ₹X over your limit"* → **Cancel** / **Spend anyway**
  (the override is recorded via `source`/note). Per-theme caps trigger a softer warning.
  iOS cannot prevent a real-world purchase, so the blocker is a deliberate-friction
  guardrail, not a hard lock.
- **Safe to spend:** home banner shows `ceiling − spent` and a per-day allowance for
  the rest of the month, colored green/amber/red. A pace projection estimates month-end
  spend at the current rate.

## Testing

- `TransactionParserTests` — table-driven over a corpus of real-world SMS formats
  (HDFC, SBI, UPI, generic) asserting amount/direction/merchant.
- `MoneyTests` — parse/format round-trips, comma & decimal handling, zero/negative.
- Build verification: `xcodebuild` against `iphonesimulator26.5` must compile all
  targets; app must launch in the simulator.

## Out of scope (YAGNI for v1)

Recurring *expenses* (commitments cover fixed monthly obligations; arbitrary
recurrence is out), multi-currency conversion, charts beyond simple totals/bars,
iCloud sync, attachments/receipts, custom budget periods beyond calendar month.
Seams left where cheap; not built.

## Build tooling

XcodeGen (`project.yml`) generates the multi-target `.xcodeproj` (app + widget +
share extension share an App Group & entitlements). Build/run via `xcodebuild` +
`simctl`. Optional later: SwiftLint.
