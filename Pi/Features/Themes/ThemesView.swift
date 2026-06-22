import SwiftUI
import SwiftData

/// Manage spending themes (categories): icon, color, and optional budget
/// allocation as a percentage of expendable income.
struct ThemesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.sortIndex) private var categories: [Category]
    @State private var editing: Category?
    @State private var showAdd = false

    var body: some View {
        List {
            ForEach(categories) { category in
                Button {
                    editing = category
                } label: {
                    HStack(spacing: DS.Spacing.md) {
                        GlyphBadge(symbolName: category.symbolName, colorHex: category.colorHex)
                        Text(category.name).foregroundStyle(.primary)
                        Spacer()
                        if let pct = category.allocationPercent {
                            Text("\(Int(pct))%")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete(perform: delete)
            .onMove(perform: move)
        }
        .bottomBarClearance()
        .navigationTitle("Themes")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { EditButton() }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add theme")
            }
        }
        .sheet(item: $editing) { category in
            CategoryEditView(category: category)
        }
        .sheet(isPresented: $showAdd) {
            CategoryEditView(category: nil, nextSortIndex: categories.count)
        }
    }

    private func delete(_ offsets: IndexSet) {
        Haptics.warning()
        for index in offsets { context.delete(categories[index]) }
        try? context.save()
    }

    private func move(_ offsets: IndexSet, _ destination: Int) {
        var ordered = categories
        ordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, category) in ordered.enumerated() { category.sortIndex = index }
        try? context.save()
    }
}

/// Create or edit a category.
struct CategoryEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var category: Category?
    var nextSortIndex: Int = 0

    @State private var name = ""
    @State private var symbolName = "tag.fill"
    @State private var colorHex = "5E5CE6"
    @State private var hasAllocation = false
    @State private var allocationPercent: Double = 10

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        GlyphBadge(symbolName: symbolName, colorHex: colorHex, size: 44)
                        TextField("Theme name", text: $name)
                            .font(.headline)
                    }
                }
                Section("Icon") {
                    SymbolPicker(selection: $symbolName)
                }
                Section("Color") {
                    ColorSwatchPicker(selection: $colorHex)
                }
                Section("Budget") {
                    Toggle("Set a monthly allocation", isOn: $hasAllocation)
                    if hasAllocation {
                        VStack(alignment: .leading) {
                            Text("\(Int(allocationPercent))% of expendable income")
                                .font(.subheadline)
                            Slider(value: $allocationPercent, in: 1...100, step: 1)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(category == nil ? "New Theme" : "Edit Theme")
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

    private func load() {
        guard let category else { return }
        name = category.name
        symbolName = category.symbolName
        colorHex = category.colorHex
        if let pct = category.allocationPercent {
            hasAllocation = true
            allocationPercent = pct
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let target: Category
        if let category {
            target = category
        } else {
            target = Category(name: trimmed, sortIndex: nextSortIndex)
            context.insert(target)
        }
        target.name = trimmed
        target.symbolName = symbolName
        target.colorHex = colorHex
        target.allocationPercent = hasAllocation ? allocationPercent : nil
        try? context.save()
        Haptics.success()
        dismiss()
    }
}

/// A grid of SF Symbols to pick a theme icon from.
struct SymbolPicker: View {
    @Binding var selection: String

    private let symbols = [
        "fork.knife", "cart.fill", "car.fill", "house.fill", "bolt.fill",
        "bag.fill", "cross.case.fill", "film.fill", "gift.fill", "airplane",
        "book.fill", "cup.and.saucer.fill", "fuelpump.fill", "tram.fill",
        "pawprint.fill", "gamecontroller.fill", "tshirt.fill", "wrench.and.screwdriver.fill",
        "phone.fill", "wifi", "drop.fill", "heart.fill", "graduationcap.fill",
        "creditcard.fill", "dumbbell.fill", "scissors", "leaf.fill", "ellipsis.circle.fill",
    ]
    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(symbols, id: \.self) { symbol in
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(symbol == selection ? DS.onAccent : .primary)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(symbol == selection ? DS.accent : Color(.secondarySystemFill))
                    )
                    .onTapGesture {
                        Haptics.select()
                        selection = symbol
                    }
            }
        }
        .padding(.vertical, 4)
    }
}
