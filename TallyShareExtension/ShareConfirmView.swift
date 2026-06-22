import SwiftUI
import SwiftData

/// Confirmation UI shown inside the share sheet. Pre-fills from the parsed
/// message and writes straight into the shared App Group store.
struct ShareConfirmView: View {
    let initialText: String
    let onClose: () -> Void

    @State private var amountText = ""
    @State private var note = ""
    @State private var direction: Direction = .paid
    @State private var currencyCode = Money.defaultCurrencyCode
    @State private var saved = false
    @State private var showBlockerAlert = false
    @State private var blockerMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    HStack {
                        Text(Money.symbol(for: currencyCode)).foregroundStyle(.secondary)
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title3.weight(.semibold))
                    }
                    Picker("Type", selection: $direction) {
                        ForEach(Direction.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Note") {
                    TextField("Note", text: $note, axis: .vertical)
                }
                if !initialText.isEmpty {
                    Section("Message") {
                        Text(initialText).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Add to π")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onClose() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: attemptSave)
                        .disabled((Money.minorUnits(fromUserInput: amountText) ?? 0) == 0)
                }
            }
            .onAppear(perform: prefill)
            .alert("Over your limit", isPresented: $showBlockerAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Spend anyway", role: .destructive) { commit(overriding: true) }
            } message: {
                Text(blockerMessage)
            }
        }
        .tint(DS.accent)
        .glassPopup()
    }

    @MainActor
    private func prefill() {
        let context = ModelContainerProvider.shared.mainContext
        let settings = LedgerService(context: context).settings()
        currencyCode = settings.currencyCode

        let parsed = TransactionParser.parse(initialText)
        if let minor = parsed.amountMinor {
            amountText = String(format: "%.2f", Double(minor) / 100)
            currencyCode = parsed.currencyCode
        }
        direction = parsed.direction
        if let merchant = parsed.merchant { note = merchant }
    }

    @MainActor
    private func attemptSave() {
        guard let minor = Money.minorUnits(fromUserInput: amountText), minor > 0 else { return }
        let service = LedgerService(context: ModelContainerProvider.shared.mainContext)
        let settings = service.settings()
        if settings.enforceBlocker, service.wouldBreachCeiling(addingMinor: minor, direction: direction) {
            let summary = service.currentSummary()
            let over = (summary.spentThisMonthMinor + minor) - summary.ceilingMinor
            let overMoney = Money(minorUnits: max(0, over), currencyCode: currencyCode)
            blockerMessage = "This puts you \(overMoney.formatted()) over your monthly limit. Record it anyway?"
            showBlockerAlert = true
        } else {
            commit(overriding: false)
        }
    }

    @MainActor
    private func commit(overriding: Bool) {
        guard let minor = Money.minorUnits(fromUserInput: amountText), minor > 0 else { return }
        let context = ModelContainerProvider.shared.mainContext
        let expense = Expense(
            amountMinor: minor,
            currencyCode: currencyCode,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            date: .now,
            direction: direction,
            source: .shareSheet,
            rawMessage: initialText.isEmpty ? nil : initialText,
            didOverrideBlocker: overriding
        )
        LedgerService(context: context).insert(expense)
        saved = true
        onClose()
    }
}
