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
            .navigationTitle("Add to π")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onClose() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled((Money.minorUnits(fromUserInput: amountText) ?? 0) == 0)
                }
            }
            .onAppear(perform: prefill)
        }
        .tint(DS.accent)
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
    private func save() {
        guard let minor = Money.minorUnits(fromUserInput: amountText), minor > 0 else { return }
        let context = ModelContainerProvider.shared.mainContext
        let expense = Expense(
            amountMinor: minor,
            currencyCode: currencyCode,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            date: .now,
            direction: direction,
            source: .shareSheet,
            rawMessage: initialText.isEmpty ? nil : initialText
        )
        LedgerService(context: context).insert(expense)
        saved = true
        onClose()
    }
}
