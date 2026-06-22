import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var expenses: [Expense]
    @Query private var settingsList: [BudgetSettings]

    @State private var csvURL: URL?
    @State private var jsonURL: URL?

    private var settings: BudgetSettings {
        if let first = settingsList.first { return first }
        let created = BudgetSettings()
        context.insert(created)
        return created
    }

    private let currencies = ["INR", "USD", "EUR", "GBP", "JPY", "AUD", "CAD", "SGD", "AED"]

    var body: some View {
        NavigationStack {
            List {
                Section("Organize") {
                    NavigationLink {
                        ThemesView()
                    } label: { Label("Themes", systemImage: "square.grid.2x2.fill") }
                    NavigationLink {
                        PeopleView()
                    } label: { Label("People", systemImage: "person.2.fill") }
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
            }
            .navigationTitle("Settings")
            .task(id: expenses.count) { regenerateExports() }
        }
    }

    private func regenerateExports() {
        let csv = Exporter.csv(expenses)
        csvURL = Exporter.writeTempFile(named: "pi-expenses.csv", contents: Data(csv.utf8))
        jsonURL = Exporter.writeTempFile(named: "pi-expenses.json", contents: Exporter.json(expenses))
    }
}
