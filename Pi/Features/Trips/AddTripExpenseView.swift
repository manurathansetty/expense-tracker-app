import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// Add a shared trip expense: amount, who paid, who shares it (split equally),
/// and an optional bill photo.
struct AddTripExpenseView: View {
    @Bindable var trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title = ""
    @State private var amountText = ""
    @State private var date = Date.now
    @State private var payerID: UUID?
    @State private var participantIDs: Set<UUID> = []
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showCamera = false

    private var members: [TripMember] { trip.sortedMembers }
    private var currencyCode: String { trip.currencyCode }
    private var minor: Int { Money.minorUnits(fromUserInput: amountText) ?? 0 }
    private var canSave: Bool { minor > 0 && payerID != nil && !participantIDs.isEmpty }
    private var perShareMinor: Int {
        participantIDs.isEmpty ? 0 : minor / participantIDs.count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Expense") {
                    TextField("What was it for?", text: $title)
                    HStack {
                        Text(Money.symbol(for: currencyCode)).foregroundStyle(.secondary)
                        TextField("Amount", text: $amountText).keyboardType(.decimalPad)
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Paid by") {
                    Picker("Paid by", selection: $payerID) {
                        ForEach(members) { Text($0.name).tag(Optional($0.id)) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                Section {
                    ForEach(members) { member in
                        Button {
                            Haptics.select()
                            toggle(member.id)
                        } label: {
                            HStack(spacing: DS.Spacing.md) {
                                Monogram(name: member.name, colorHex: member.colorHex, size: 28)
                                Text(member.name).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: participantIDs.contains(member.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(participantIDs.contains(member.id) ? DS.accent : Color.secondary)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Split between")
                        Spacer()
                        Button(participantIDs.count == members.count ? "Clear" : "All") { toggleAll() }
                            .font(.caption.weight(.semibold))
                    }
                } footer: {
                    if minor > 0 && !participantIDs.isEmpty {
                        Text("\(Money(minorUnits: perShareMinor, currencyCode: currencyCode).formatted()) each")
                    } else {
                        Text("Pick who shared this expense.")
                    }
                }

                Section("Bill photo") {
                    if let photoData, let image = UIImage(data: photoData) {
                        Image(uiImage: image)
                            .resizable().scaledToFill()
                            .frame(maxWidth: .infinity).frame(height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                        Button("Remove photo", role: .destructive) {
                            self.photoData = nil
                            photoItem = nil
                        }
                    } else {
                        if CameraPicker.isAvailable {
                            Button {
                                Haptics.tap()
                                showCamera = true
                            } label: {
                                Label("Take a photo", systemImage: "camera.fill")
                            }
                        }
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("Choose from library", systemImage: "photo.on.rectangle")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(!canSave) }
            }
            .onAppear {
                if payerID == nil { payerID = members.first?.id }
                if participantIDs.isEmpty { participantIDs = Set(members.map(\.id)) }
            }
            .onChange(of: photoItem) { _, item in
                Task { await loadPhoto(item) }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { data in photoData = data }
                    .ignoresSafeArea()
            }
        }
        .glassPopup()
    }

    private func toggle(_ id: UUID) {
        if participantIDs.contains(id) { participantIDs.remove(id) } else { participantIDs.insert(id) }
    }

    private func toggleAll() {
        Haptics.tap()
        participantIDs = participantIDs.count == members.count ? [] : Set(members.map(\.id))
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        // Re-encode to a reasonable size to keep the store small.
        let compressed = UIImage(data: data)?.jpegData(compressionQuality: 0.6) ?? data
        await MainActor.run { photoData = compressed }
    }

    private func save() {
        guard let payerID else { return }
        let expense = TripExpense(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            amountMinor: minor,
            date: date,
            payerID: payerID,
            participantIDs: Array(participantIDs),
            photo: photoData
        )
        expense.trip = trip
        context.insert(expense)
        try? context.save()
        Haptics.success()
        dismiss()
    }
}
