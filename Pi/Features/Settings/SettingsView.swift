import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var expenses: [Expense]
    @Query private var settingsList: [BudgetSettings]

    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.system.rawValue

    @State private var csvURL: URL?
    @State private var jsonURL: URL?
    @State private var showResetConfirm = false

    // Non-mutating: never insert during `body`. Seeded in `.task` / at launch.
    private var settings: BudgetSettings {
        settingsList.first ?? BudgetSettings()
    }

    // Only currencies with 2 decimal minor units (Money assumes 100 minor units
    // per major). JPY (0 decimals) and similar are intentionally excluded.
    private let currencies = ["INR", "USD", "EUR", "GBP", "AUD", "CAD", "SGD", "AED"]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(alignment: .top, spacing: DS.Spacing.md) {
                        Image(systemName: "target")
                            .foregroundStyle(DS.accent)
                            .font(.title3)
                        TextField("e.g. Saving for a new MacBook", text: Binding(
                            get: { settings.monthlyGoal },
                            set: { settings.monthlyGoal = $0; LedgerService(context: context).save() }
                        ), axis: .vertical)
                        .lineLimit(1...3)
                    }
                } header: {
                    Text("This month's goal")
                } footer: {
                    Text("Shown as your home screen title — a reminder of what you're working toward.")
                }

                Section("Organize") {
                    NavigationLink {
                        ThemesView()
                    } label: { Label("Themes", systemImage: "square.grid.2x2.fill") }
                    NavigationLink {
                        PeopleView()
                    } label: { Label("People", systemImage: "person.2.fill") }
                    NavigationLink {
                        RecurringView()
                    } label: { Label("Recurring payments", systemImage: "calendar.badge.clock") }
                }

                Section("Appearance") {
                    AppearancePicker(rawValue: $appearanceRaw)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        .listRowBackground(Color.clear)
                }

                Section("Currency") {
                    Picker("Currency", selection: Binding(
                        get: { settings.currencyCode },
                        set: { settings.currencyCode = $0; LedgerService(context: context).save() }
                    )) {
                        ForEach(currencies, id: \.self) { code in
                            Text("\(code)  \(Money.symbol(for: code))").tag(code)
                        }
                    }
                }

                Section {
                    NavigationLink {
                        ShortcutsHelpView()
                    } label: {
                        Label("Auto-add from messages", systemImage: "text.bubble.fill")
                    }
                } header: {
                    Text("Capture")
                } footer: {
                    Text("Set up a Shortcuts automation so bank/UPI texts log themselves, or share any message into π.")
                }

                Section {
                    if let csvURL {
                        ShareLink(item: csvURL) {
                            Label("Export CSV", systemImage: "tablecells")
                        }
                    }
                    if let jsonURL {
                        ShareLink(item: jsonURL) {
                            Label("Export JSON", systemImage: "curlybraces")
                        }
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Your data never leaves the device unless you export it here. \(expenses.count) entries.")
                }

                Section {
                    LabeledContent("App", value: "π")
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("Storage", value: "On-device only")
                }

                Section {
                    Button(role: .destructive) { showResetConfirm = true } label: {
                        Label("Reset all data", systemImage: "trash")
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                    }
                } footer: {
                    Text("Deletes everything and starts fresh.")
                }
            }
            .listSectionSpacing(14)
            .contentMargins(.top, 8, for: .scrollContent)
            .bottomBarClearance()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                SeedData.ensureSettings(context)
                try? context.save()
            }
            .task(id: expenses.count) { regenerateExports() }
            .confirmationDialog("Reset all data?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) {
                    Haptics.warning()
                    LedgerService(context: context).resetAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes all expenses, themes, people, recurring payments, set-asides, savings, and settings. This can't be undone.")
            }
        }
    }

    private func regenerateExports() {
        let csv = Exporter.csv(expenses)
        csvURL = Exporter.writeTempFile(named: "pi-expenses.csv", contents: Data(csv.utf8))
        jsonURL = Exporter.writeTempFile(named: "pi-expenses.json", contents: Exporter.json(expenses))
    }
}
