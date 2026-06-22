import SwiftUI
import SwiftData

/// Full editor for an existing expense — amount, date/time, theme, person, note.
struct EditExpenseView: View {
    @Bindable var expense: Expense
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Category> { !$0.isArchived }, sort: \Category.sortIndex)
    private var categories: [Category]
    @Query(sort: \Payee.createdAt, order: .reverse) private var payees: [Payee]

    @State private var amountText = ""

    var body: some View {
        Form {
            Section("Amount") {
                HStack {
                    Text(Money.symbol(for: expense.currencyCode))
                        .foregroundStyle(.secondary)
                    TextField("0", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.title2.weight(.semibold))
                        .onChange(of: amountText) { _, newValue in
                            if let minor = Money.minorUnits(fromUserInput: newValue) {
                                expense.amountMinor = minor
                            } else if newValue.isEmpty {
                                expense.amountMinor = 0
                            }
                        }
                }
                Picker("Type", selection: Binding(
                    get: { expense.direction },
                    set: { expense.direction = $0 }
                )) {
                    ForEach(Direction.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("When") {
                DatePicker("Date & time", selection: $expense.date)
            }

            Section("Theme") {
                Picker("Theme", selection: Binding(
                    get: { expense.category?.id },
                    set: { id in expense.category = categories.first { $0.id == id } }
                )) {
                    Text("None").tag(UUID?.none)
                    ForEach(categories) { category in
                        Label(category.name, systemImage: category.symbolName)
                            .tag(Optional(category.id))
                    }
                }
            }

            Section("Person") {
                Picker("Person", selection: Binding(
                    get: { expense.payee?.id },
                    set: { id in expense.payee = payees.first { $0.id == id } }
                )) {
                    Text("None").tag(UUID?.none)
                    ForEach(payees) { payee in
                        Text(payee.name).tag(Optional(payee.id))
                    }
                }
            }

            Section("Note") {
                TextField("Note", text: $expense.note, axis: .vertical)
            }

            Section {
                LabeledContent("Added", value: expense.createdAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Source", value: expense.source.label)
                if let raw = expense.rawMessage, !raw.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Original message").font(.caption).foregroundStyle(.secondary)
                        Text(raw).font(.footnote)
                    }
                }
            }

            Section {
                Button(role: .destructive, action: deleteExpense) {
                    Text("Delete")
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Edit")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            amountText = expense.amountMinor == 0 ? "" : String(format: "%.2f", expense.money.majorValue)
        }
        .onDisappear { LedgerService(context: context).save() }
    }

    private func deleteExpense() {
        Haptics.warning()
        LedgerService(context: context).delete(expense)
        dismiss()
    }
}
