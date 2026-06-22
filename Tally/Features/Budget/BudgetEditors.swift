import SwiftUI
import SwiftData

/// A small sheet for entering a single money amount.
struct MoneyInputSheet: View {
    let title: String
    let currencyCode: String
    let minor: Int
    let onSave: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(Money.symbol(for: currencyCode))
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        TextField("0", text: $text)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(Money.minorUnits(fromUserInput: text) ?? 0)
                        Haptics.success()
                        dismiss()
                    }
                }
            }
            .onAppear {
                text = minor == 0 ? "" : String(format: "%.2f", Double(minor) / 100)
            }
        }
        .presentationDetents([.height(220), .medium])
        .glassPopup()
    }
}

/// Create or edit a fixed monthly commitment.
struct EditCommitmentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var commitment: Commitment?
    let currencyCode: String

    @State private var name = ""
    @State private var amountText = ""
    @State private var kind: CommitmentKind = .family
    @State private var colorHex = "FF375F"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Family support, Rent)", text: $name)
                    HStack {
                        Text(Money.symbol(for: currencyCode)).foregroundStyle(.secondary)
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                    }
                }
                Section("Type") {
                    Picker("Type", selection: $kind) {
                        ForEach(CommitmentKind.allCases) { kind in
                            Label(kind.label, systemImage: kind.symbolName).tag(kind)
                        }
                    }
                    .pickerStyle(.inline)
                    .onChange(of: kind) { _, newValue in colorHex = Self.defaultColor(for: newValue) }
                }
                Section("Color") {
                    ColorSwatchPicker(selection: $colorHex)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(commitment == nil ? "New Commitment" : "Edit Commitment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
        .glassPopup()
    }

    private static func defaultColor(for kind: CommitmentKind) -> String {
        switch kind {
        case .family: return "FF375F"
        case .housing: return "BF5AF2"
        case .loan: return "FF9F0A"
        case .savings: return "34C759"
        case .other: return "8E8E93"
        }
    }

    private func load() {
        guard let commitment else { return }
        name = commitment.name
        amountText = String(format: "%.2f", Double(commitment.amountMinor) / 100)
        kind = commitment.kind
        colorHex = commitment.colorHex
    }

    private func save() {
        let minor = Money.minorUnits(fromUserInput: amountText) ?? 0
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let commitment {
            commitment.name = trimmed
            commitment.amountMinor = minor
            commitment.kind = kind
            commitment.colorHex = colorHex
        } else {
            let new = Commitment(name: trimmed, amountMinor: minor, kind: kind, colorHex: colorHex)
            context.insert(new)
        }
        LedgerService(context: context).save()
        Haptics.success()
        dismiss()
    }
}
