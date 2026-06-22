import SwiftUI
import SwiftData

/// The fast capture sheet. Uses the system keyboards only — a decimal keypad for
/// the amount (auto-focused) and the normal text keyboard for the note — so
/// there's never a second custom keypad fighting the system one.
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

    @State private var amountText = ""
    @State private var direction: Direction = .paid
    @State private var selectedCategory: Category?
    @State private var selectedPayee: Payee?
    @State private var note = ""
    @State private var source: EntrySource = .quickAdd
    @State private var rawMessage: String?

    @State private var showBlockerAlert = false
    @State private var showAddPerson = false
    @FocusState private var amountFocused: Bool

    private var settings: BudgetSettings? { settingsList.first }
    private var currencyCode: String { settings?.currencyCode ?? Money.defaultCurrencyCode }
    private var enteredMinor: Int { Money.minorUnits(fromUserInput: amountText) ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    amountField
                    // Tapping anywhere in this lower group pops the number keyboard down.
                    VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                        directionPicker
                        themeSection
                        peopleSection
                        noteField
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { amountFocused = false }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.xl)
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: attemptSave)
                        .fontWeight(.semibold)
                        .disabled(enteredMinor == 0)
                }
            }
            .onAppear {
                applyPrefill()
                if amountText.isEmpty { amountFocused = true }
            }
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
        .glassPopup()
    }

    // MARK: Sections

    private var amountField: some View {
        VStack(spacing: DS.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(Money.symbol(for: currencyCode))
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                TextField("0", text: $amountText)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity)
            if source == .message {
                Label("From message", systemImage: "text.bubble")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, DS.Spacing.sm)
    }

    private var directionPicker: some View {
        Picker("Direction", selection: $direction) {
            ForEach(Direction.allCases) { dir in
                Text(dir.label).tag(dir)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: direction) { _, _ in
            Haptics.select()
            amountFocused = false
        }
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
                            amountFocused = false
                            selectedCategory = (selectedCategory?.id == category.id) ? nil : category
                        } label: {
                            Chip(
                                title: category.name,
                                systemImage: category.symbolName,
                                colorHex: category.colorHex,
                                isSelected: selectedCategory?.id == category.id
                            )
                        }
                        .buttonStyle(PressableButtonStyle())
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
                        amountFocused = false
                        showAddPerson = true
                    } label: {
                        Chip(title: "Add", systemImage: "person.badge.plus", isSelected: false)
                    }
                    .buttonStyle(PressableButtonStyle())

                    ForEach(payees) { payee in
                        Button {
                            Haptics.select()
                            amountFocused = false
                            selectedPayee = (selectedPayee?.id == payee.id) ? nil : payee
                        } label: {
                            Chip(
                                title: payee.name,
                                systemImage: "person.fill",
                                colorHex: payee.colorHex,
                                isSelected: selectedPayee?.id == payee.id
                            )
                        }
                        .buttonStyle(PressableButtonStyle())
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
                .padding(DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
        }
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
        let enforce = settings?.enforceBlocker ?? true
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
        if let minor = parsed.amountMinor {
            amountText = String(format: "%.2f", Double(minor) / 100)
        }
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
