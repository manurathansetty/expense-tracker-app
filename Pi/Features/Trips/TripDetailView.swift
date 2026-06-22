import SwiftUI
import SwiftData
import UIKit

/// One trip: total spent, each person's balance, the minimal settle-up transfers,
/// and the list of shared expenses (with optional bill photos).
struct TripDetailView: View {
    @Bindable var trip: Trip
    @Environment(\.modelContext) private var context

    @State private var showAddExpense = false
    @State private var photoExpense: TripExpense?

    private var currencyCode: String { trip.currencyCode }
    private var members: [TripMember] { trip.sortedMembers }
    private var expenses: [TripExpense] { trip.expenses.sorted { $0.date > $1.date } }

    private var net: [UUID: Int] {
        TripEngine.netBalances(
            memberIDs: members.map(\.id),
            charges: trip.expenses.map {
                TripEngine.Charge(amountMinor: $0.amountMinor, payerID: $0.payerID, participantIDs: $0.participantIDs)
            }
        )
    }
    private var settlements: [TripEngine.Settlement] { TripEngine.settlements(net: net) }

    private func member(_ id: UUID) -> TripMember? { trip.members.first { $0.id == id } }
    private func name(_ id: UUID) -> String { member(id)?.name ?? "?" }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total spent").font(.subheadline).foregroundStyle(.secondary)
                    Text(Money(minorUnits: trip.totalMinor, currencyCode: currencyCode).formatted())
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }

            Section("Balances") {
                ForEach(members) { m in
                    let balance = net[m.id] ?? 0
                    HStack {
                        Monogram(name: m.name, colorHex: m.colorHex, size: 30)
                        Text(m.name)
                        Spacer()
                        Text(balanceLabel(balance))
                            .font(.subheadline.weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(balance == 0 ? .secondary : (balance > 0 ? DS.positive : DS.negative))
                    }
                }
            }

            Section("Settle up") {
                if settlements.isEmpty {
                    Label("All settled up", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(DS.positive)
                }
                ForEach(Array(settlements.enumerated()), id: \.offset) { _, s in
                    HStack(spacing: DS.Spacing.sm) {
                        Text(name(s.fromID)).fontWeight(.medium)
                        Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
                        Text(name(s.toID)).fontWeight(.medium)
                        Spacer()
                        Text(Money(minorUnits: s.amountMinor, currencyCode: currencyCode).formattedCompact())
                            .monospacedDigit().fontWeight(.semibold)
                    }
                }
            }

            Section("Expenses") {
                if expenses.isEmpty {
                    Text("No expenses yet — tap ＋ to add one.").foregroundStyle(.secondary)
                }
                ForEach(expenses) { expense in
                    TripExpenseRow(
                        expense: expense,
                        payerName: name(expense.payerID),
                        currencyCode: currencyCode
                    ) { photoExpense = expense }
                }
                .onDelete(perform: deleteExpense)
            }
        }
        .listSectionSpacing(14)
        .bottomBarClearance()
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddExpense = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add trip expense")
            }
        }
        .sheet(isPresented: $showAddExpense) {
            AddTripExpenseView(trip: trip)
        }
        .sheet(item: $photoExpense) { expense in
            BillPhotoView(expense: expense)
        }
    }

    private func balanceLabel(_ balance: Int) -> String {
        if balance == 0 { return "settled" }
        let money = Money(minorUnits: abs(balance), currencyCode: currencyCode).formattedCompact()
        return balance > 0 ? "gets \(money)" : "owes \(money)"
    }

    private func deleteExpense(_ offsets: IndexSet) {
        Haptics.warning()
        for index in offsets { context.delete(expenses[index]) }
        try? context.save()
    }
}

private struct TripExpenseRow: View {
    let expense: TripExpense
    let payerName: String
    let currencyCode: String
    let onTapPhoto: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            if let data = expense.photo, let image = UIImage(data: data) {
                Button(action: onTapPhoto) {
                    Image(uiImage: image)
                        .resizable().scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 44, height: 44)
                    .overlay(Image(systemName: "receipt").foregroundStyle(.secondary))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.title.isEmpty ? "Expense" : expense.title).font(.body.weight(.medium))
                Text("Paid by \(payerName) · split \(expense.participantIDs.count) ways")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(Money(minorUnits: expense.amountMinor, currencyCode: currencyCode).formattedCompact())
                .font(.subheadline.weight(.semibold)).monospacedDigit()
        }
    }
}

/// Full-screen view of a bill photo.
private struct BillPhotoView: View {
    let expense: TripExpense
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let data = expense.photo, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFit()
                } else {
                    ContentUnavailableView("No photo", systemImage: "photo")
                }
            }
            .navigationTitle(expense.title.isEmpty ? "Bill" : expense.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
