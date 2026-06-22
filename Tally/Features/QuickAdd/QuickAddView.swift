import SwiftUI
import SwiftData

/// The fast capture sheet. Calculator-style keypad (each digit shifts minor
/// units, so "1 2 5 0" = 12.50), direction toggle, theme chips, and optional
/// person — designed so a normal expense is two taps from open.
struct QuickAddView: View {
    var prefillMessage: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Category> { !$0.isArchived },
           sort: \Category.sortIndex)
    private var categories: [Category]

    @Query(sort: \Payee.createdAt, order: .reverse)
    private var payees: [Payee]

    @Query private var settingsList: [BudgetSettings]

    @State private var enteredMinor = 0
    @State private var direction: Direction = .paid
    @State private var selectedCategory: Category?
    @State private var selectedPayee: Payee?
    @State private var note = ""
    @State private var source: EntrySource = .quickAdd
    @State private var rawMessage: String?

    @State private var showBlockerAlert = false
    @State private var showAddPerson = false
    @FocusState private var noteFocused: Bool

    private var settings: BudgetSettings? { settingsList.first }
    private var currencyCode: String { settings?.currencyCode ?? Money.defaultCurrencyCode }
    private var money: Money { Money(minorUnits: enteredMinor, currencyCode: currencyCode) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                amountDisplay
                directionPicker
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                        themeSection
                        if direction != .paid || selectedPayee != nil {
                            peopleSection
                        } else {
                            peopleSection // still available for normal expenses
                        }
                        noteField
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.lg)
                }
                NumberPad(
                    onDigit: appendDigit,
                    onDelete: deleteDigit
                )
                saveButton
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear(perform: applyPrefill)
            .sheet(isPresented: $showAddPerson) {
                EditPayeeView { newPayee in selectedPayee = newPayee }
            }
            .alert("Over your limit", isPresented: $showBlockerAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Spend anyway", role: .destructive) { commit(overriding: true) }
            } message: {
                Text(blockerMessage)
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: Sections

    private var amountDisplay: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(money.formatted())
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy, value: enteredMinor)
                .foregroundStyle(enteredMinor == 0 ? .secondary : .primary)
            if source == .message {
                Label("From message", systemImage: "text.bubble")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, DS.Spacing.lg)
        .frame(maxWidth: .infinity)
    }

    private var directionPicker: some View {
        Picker("Direction", selection: $direction) {
            ForEach(Direction.allCases) { dir in
                Text(dir.label).tag(dir)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.md)
        .onChange(of: direction) { _, _ in Haptics.select() }
    }

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Theme")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(categories) { category in
                        Button {
                            Haptics.select()
                            selectedCategory = (selectedCategory?.id == category.id) ? nil : category
                        } label: {
                            Chip(
                                title: category.name,
                                systemImage: category.symbolName,
                                colorHex: category.colorHex,
                                isSelected: selectedCategory?.id == category.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(direction == .paid ? "Person (optional)" : "Person")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    Button {
                        Haptics.tap()
                        showAddPerson = true
                    } label: {
                        Chip(title: "Add", systemImage: "person.badge.plus", isSelected: false)
                    }
                    .buttonStyle(.plain)

                    ForEach(payees) { payee in
                        Button {
                            Haptics.select()
                            selectedPayee = (selectedPayee?.id == payee.id) ? nil : payee
                        } label: {
                            Chip(
                                title: payee.name,
                                systemImage: "person.fill",
                                colorHex: payee.colorHex,
                                isSelected: selectedPayee?.id == payee.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Note")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField("What was it for?", text: $note, axis: .vertical)
                .focused($noteFocused)
                .padding(DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
        }
        .padding(.bottom, DS.Spacing.lg)
    }

    private var saveButton: some View {
        Button(action: attemptSave) {
            Text("Save")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
        }
        .buttonStyle(.borderedProminent)
        .tint(DS.accent)
        .disabled(enteredMinor == 0)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(.bar)
    }

    // MARK: Keypad actions

    private func appendDigit(_ digit: Int) {
        guard enteredMinor < 1_000_000_000 else { return } // sane cap
        enteredMinor = enteredMinor * 10 + digit
        Haptics.tap()
    }

    private func deleteDigit() {
        enteredMinor /= 10
        Haptics.tap()
    }

    // MARK: Save

    private var blockerMessage: String {
        let service = LedgerService(context: context)
        let summary = service.currentSummary()
        let over = (summary.spentThisMonthMinor + enteredMinor) - summary.ceilingMinor
        let overMoney = Money(minorUnits: max(0, over), currencyCode: currencyCode)
        return "This puts you \(overMoney.formatted()) over your monthly limit. Record it anyway?"
    }

    private func attemptSave() {
        let service = LedgerService(context: context)
        let enforce = settings?.enforceBlocker ?? false
        if enforce, service.wouldBreachCeiling(addingMinor: enteredMinor, direction: direction) {
            Haptics.warning()
            showBlockerAlert = true
        } else {
            commit(overriding: false)
        }
    }

    private func commit(overriding: Bool) {
        let expense = Expense(
            amountMinor: enteredMinor,
            currencyCode: currencyCode,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            date: .now,
            direction: direction,
            source: source,
            category: selectedCategory,
            payee: selectedPayee,
            rawMessage: rawMessage,
            didOverrideBlocker: overriding
        )
        LedgerService(context: context).insert(expense)
        Haptics.success()
        dismiss()
    }

    // MARK: Prefill from a shared / parsed message

    private func applyPrefill() {
        guard let text = prefillMessage, !text.isEmpty else { return }
        let parsed = TransactionParser.parse(text)
        if let minor = parsed.amountMinor { enteredMinor = minor }
        direction = parsed.direction
        rawMessage = text
        source = .message
        if let merchant = parsed.merchant {
            note = merchant
        }
        if let match = categories.first(where: { merchantMatchesCategory(parsed.merchant, $0) }) {
            selectedCategory = match
        }
    }

    private func merchantMatchesCategory(_ merchant: String?, _ category: Category) -> Bool {
        guard let merchant = merchant?.lowercased() else { return false }
        return merchant.contains(category.name.lowercased())
    }
}

/// A compact numeric keypad. Digits shift the running minor-unit amount.
private struct NumberPad: View {
    let onDigit: (Int) -> Void
    let onDelete: () -> Void

    private let rows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["", "0", "⌫"],
    ]

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.sm)
    }

    @ViewBuilder
    private func keyButton(_ key: String) -> some View {
        if key.isEmpty {
            Color.clear.frame(maxWidth: .infinity).frame(height: 52)
        } else {
            Button {
                if key == "⌫" { onDelete() }
                else if let digit = Int(key) { onDigit(digit) }
            } label: {
                Text(key)
                    .font(.title2.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
        }
    }
}
