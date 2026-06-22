import SwiftUI
import SwiftData

/// List of people with their running lending balance.
struct PeopleView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Payee.createdAt, order: .reverse) private var payees: [Payee]
    @State private var showAdd = false

    var body: some View {
        List {
            if payees.isEmpty {
                ContentUnavailableView(
                    "No people yet",
                    systemImage: "person.2",
                    description: Text("Add someone to track money you lend or receive.")
                )
            }
            ForEach(payees) { payee in
                NavigationLink {
                    PayeeDetailView(payee: payee)
                } label: {
                    PayeeRow(payee: payee)
                }
            }
            .onDelete(perform: delete)
        }
        .bottomBarClearance()
        .navigationTitle("People")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add person")
            }
        }
        .sheet(isPresented: $showAdd) {
            EditPayeeView()
        }
    }

    private func delete(_ offsets: IndexSet) {
        Haptics.warning()
        for index in offsets { context.delete(payees[index]) }
        try? context.save()
    }
}

private struct PayeeRow: View {
    let payee: Payee

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Monogram(name: payee.name, colorHex: payee.colorHex)
            VStack(alignment: .leading, spacing: 2) {
                Text(payee.name).font(.body.weight(.medium))
                Text(balanceLabel).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(Money(minorUnits: abs(payee.netBalanceMinor)).formattedCompact())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(balanceColor)
        }
    }

    private var balanceLabel: String {
        let net = payee.netBalanceMinor
        if net > 0 { return "Owes you" }
        if net < 0 { return "You owe" }
        return "Settled"
    }

    private var balanceColor: Color {
        let net = payee.netBalanceMinor
        if net > 0 { return DS.positive }
        if net < 0 { return DS.negative }
        return .secondary
    }
}

/// Create or edit a person. Calls `onSave` with the resulting payee.
struct EditPayeeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var existing: Payee?
    var onSave: ((Payee) -> Void)?

    @State private var name = ""
    @State private var note = ""
    @State private var colorHex = "30B0C7"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Note (optional)", text: $note)
                }
                Section("Color") {
                    ColorSwatchPicker(selection: $colorHex)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(existing == nil ? "New Person" : "Edit Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let existing {
                    name = existing.name
                    note = existing.note
                    colorHex = existing.colorHex
                }
            }
        }
        .presentationDetents([.medium, .large])
        .glassPopup()
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let payee: Payee
        if let existing {
            existing.name = trimmed
            existing.note = note
            existing.colorHex = colorHex
            payee = existing
        } else {
            payee = Payee(name: trimmed, note: note, colorHex: colorHex)
            context.insert(payee)
        }
        try? context.save()
        Haptics.success()
        onSave?(payee)
        dismiss()
    }
}

/// History and balance for one person.
struct PayeeDetailView: View {
    @Bindable var payee: Payee
    @State private var showEdit = false

    private var sortedExpenses: [Expense] {
        payee.expenses.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Net balance")
                    Spacer()
                    Text(Money(minorUnits: payee.netBalanceMinor).formatted())
                        .font(.headline)
                        .foregroundStyle(payee.netBalanceMinor >= 0 ? DS.positive : DS.negative)
                }
                if !payee.note.isEmpty {
                    Text(payee.note).foregroundStyle(.secondary)
                }
            }
            Section("History") {
                if sortedExpenses.isEmpty {
                    Text("No entries yet").foregroundStyle(.secondary)
                }
                ForEach(sortedExpenses) { expense in
                    ExpenseRow(expense: expense)
                }
            }
        }
        .navigationTitle(payee.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditPayeeView(existing: payee)
        }
    }
}

/// A reusable color swatch grid bound to a hex string.
struct ColorSwatchPicker: View {
    @Binding var selection: String

    private let columns = [GridItem(.adaptive(minimum: 40), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Color.piPalette, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 34, height: 34)
                    .overlay {
                        if hex == selection {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.45), radius: 1)
                        }
                    }
                    .onTapGesture {
                        Haptics.select()
                        selection = hex
                    }
            }
        }
        .padding(.vertical, 4)
    }
}
