import SwiftUI
import SwiftData

/// Manage recurring payments (recharge, gym, subscriptions, rent).
struct RecurringView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RecurringPayment.nextDueDate) private var payments: [RecurringPayment]
    @State private var editing: RecurringPayment?
    @State private var showAdd = false

    var body: some View {
        List {
            if payments.isEmpty {
                ContentUnavailableView(
                    "No recurring payments",
                    systemImage: "calendar.badge.clock",
                    description: Text("Add bills like recharge, gym, or rent to get reminders before they're due.")
                )
            }
            ForEach(payments) { payment in
                Button { editing = payment } label: { RecurringRow(payment: payment) }
                    .swipeActions(edge: .leading) {
                        Button {
                            LedgerService(context: context).markRecurringPaid(payment)
                            Haptics.success()
                        } label: { Label("Paid", systemImage: "checkmark") }
                        .tint(DS.positive)
                    }
            }
            .onDelete(perform: delete)
        }
        .bottomBarClearance()
        .navigationTitle("Recurring")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add recurring payment")
            }
        }
        .sheet(isPresented: $showAdd) { EditRecurringView(payment: nil) }
        .sheet(item: $editing) { payment in EditRecurringView(payment: payment) }
    }

    private func delete(_ offsets: IndexSet) {
        Haptics.warning()
        for index in offsets { context.delete(payments[index]) }
        let service = LedgerService(context: context)
        service.save()
        service.rescheduleNotifications()
    }
}

struct RecurringRow: View {
    let payment: RecurringPayment

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            GlyphBadge(symbolName: payment.symbolName, colorHex: payment.colorHex)
            VStack(alignment: .leading, spacing: 2) {
                Text(payment.name).font(.body.weight(.medium))
                Text("\(payment.cadence.label) · \(RecurringEngine.dueLabel(payment.nextDueDate, now: .now))")
                    .font(.caption)
                    .foregroundStyle(dueColor)
            }
            Spacer()
            Text(payment.money.formattedCompact())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(payment.isActive ? .primary : .secondary)
        }
        .opacity(payment.isActive ? 1 : 0.5)
    }

    private var dueColor: Color {
        let days = RecurringEngine.daysUntil(payment.nextDueDate, now: .now)
        if days < 0 { return DS.negative }
        if days <= 5 { return DS.warning }
        return .secondary
    }
}

/// Create or edit a recurring payment.
struct EditRecurringView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Category> { !$0.isArchived }, sort: \Category.sortIndex)
    private var categories: [Category]
    @Query private var settingsList: [BudgetSettings]

    var payment: RecurringPayment?

    @State private var name = ""
    @State private var amountText = ""
    @State private var cadence: RecurrenceCadence = .monthly
    @State private var nextDue = Date.now
    @State private var notify = true
    @State private var isActive = true
    @State private var categoryID: UUID?

    private var currencyCode: String { settingsList.first?.currencyCode ?? Money.defaultCurrencyCode }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Phone recharge, Gym)", text: $name)
                    HStack {
                        Text(Money.symbol(for: currencyCode)).foregroundStyle(.secondary)
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                    }
                }
                Section("Repeats") {
                    Picker("Cadence", selection: $cadence) {
                        ForEach(RecurrenceCadence.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    DatePicker("Next due", selection: $nextDue, displayedComponents: .date)
                }
                Section("Theme") {
                    Picker("Theme", selection: $categoryID) {
                        Text("None").tag(UUID?.none)
                        ForEach(categories) { category in
                            Label(category.name, systemImage: category.symbolName).tag(Optional(category.id))
                        }
                    }
                }
                Section {
                    Toggle("Notify me before it's due", isOn: $notify)
                    if payment != nil {
                        Toggle("Active", isOn: $isActive)
                    }
                } footer: {
                    Text("You'll get a reminder 5 days before and on the day it's due.")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(payment == nil ? "New Recurring" : "Edit Recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty
                                  || (Money.minorUnits(fromUserInput: amountText) ?? 0) == 0)
                }
            }
            .onAppear(perform: load)
        }
        .glassPopup()
    }

    private func load() {
        guard let payment else { return }
        name = payment.name
        amountText = String(format: "%.2f", Double(payment.amountMinor) / 100)
        cadence = payment.cadence
        nextDue = payment.nextDueDate
        notify = payment.notify
        isActive = payment.isActive
        categoryID = payment.category?.id
    }

    private func save() {
        let minor = Money.minorUnits(fromUserInput: amountText) ?? 0
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let category = categories.first { $0.id == categoryID }

        if let payment {
            payment.name = trimmed
            payment.amountMinor = minor
            payment.currencyCode = currencyCode
            payment.cadence = cadence
            payment.nextDueDate = nextDue
            payment.notify = notify
            payment.isActive = isActive
            payment.category = category
        } else {
            let new = RecurringPayment(
                name: trimmed, amountMinor: minor, currencyCode: currencyCode,
                cadence: cadence, nextDueDate: nextDue, notify: notify, category: category
            )
            context.insert(new)
        }

        let service = LedgerService(context: context)
        service.save()
        service.rescheduleNotifications()
        if notify { NotificationScheduler.requestAuthorization() }
        Haptics.success()
        dismiss()
    }
}
