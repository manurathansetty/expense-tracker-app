import SwiftUI
import SwiftData

/// List of group trips. Each opens a detail with shared expenses + settle-up.
struct TripsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @State private var showAdd = false

    var body: some View {
        List {
            if trips.isEmpty {
                ContentUnavailableView(
                    "No trips yet",
                    systemImage: "airplane",
                    description: Text("Create a trip to split shared expenses with friends and settle up.")
                )
            }
            ForEach(trips) { trip in
                NavigationLink {
                    TripDetailView(trip: trip)
                } label: {
                    TripRow(trip: trip)
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Trips")
        .bottomBarClearance()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add trip")
            }
        }
        .sheet(isPresented: $showAdd) { EditTripView() }
    }

    private func delete(_ offsets: IndexSet) {
        Haptics.warning()
        for index in offsets { context.delete(trips[index]) }
        try? context.save()
    }
}

private struct TripRow: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            GlyphBadge(symbolName: "airplane", colorHex: "30B0C7")
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.name).font(.body.weight(.medium))
                Text("^[\(trip.members.count) person](inflect: true) · ^[\(trip.expenses.count) expense](inflect: true)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(Money(minorUnits: trip.totalMinor, currencyCode: trip.currencyCode).formattedCompact())
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
    }
}

/// Create a trip: a name plus the people on it.
struct EditTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var settingsList: [BudgetSettings]

    @State private var name = ""
    @State private var memberNames: [String] = ["", ""]

    private var currencyCode: String { settingsList.first?.currencyCode ?? Money.defaultCurrencyCode }
    private var validMembers: [String] {
        memberNames.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && validMembers.count >= 2
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip") {
                    TextField("Trip name (e.g. Goa 2026)", text: $name)
                }
                Section {
                    ForEach(memberNames.indices, id: \.self) { index in
                        TextField("Person \(index + 1)", text: $memberNames[index])
                    }
                    .onDelete { memberNames.remove(atOffsets: $0) }
                    Button {
                        memberNames.append("")
                    } label: {
                        Label("Add person", systemImage: "person.badge.plus")
                    }
                } header: {
                    Text("People")
                } footer: {
                    Text("Add at least two people to split expenses between.")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: save).disabled(!canSave)
                }
            }
        }
        .glassPopup()
    }

    private func save() {
        let trip = Trip(name: name.trimmingCharacters(in: .whitespaces), currencyCode: currencyCode)
        context.insert(trip)
        let palette = Color.piPalette
        for (index, memberName) in validMembers.enumerated() {
            let member = TripMember(name: memberName, colorHex: palette[index % palette.count])
            member.trip = trip
            context.insert(member)
        }
        try? context.save()
        Haptics.success()
        dismiss()
    }
}
