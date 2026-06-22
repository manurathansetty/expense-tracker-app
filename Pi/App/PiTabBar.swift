import SwiftUI

/// Custom bottom bar: four tabs flanking a raised center ＋ that nests into the
/// bar (the "bow"). Tap ＋ to quick-add; touch-and-hold to fan out more actions.
struct PiTabBar: View {
    @Binding var selected: AppRouter.Tab
    var onAdd: () -> Void
    var onLongPress: () -> Void

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                tab(.ledger, "Ledger", "list.bullet.rectangle.portrait")
                tab(.insights, "Insights", "chart.pie.fill")
                Spacer().frame(width: 78) // room for the center FAB
                tab(.budget, "Budget", "target")
                tab(.settings, "Settings", "gearshape.fill")
            }
            .padding(.horizontal, 8)
            .frame(height: 62)
            .background(
                Capsule(style: .continuous)
                    .fill(.bar)
                    .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            )

            addButton.offset(y: -20)
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private func tab(_ tab: AppRouter.Tab, _ title: String, _ icon: String) -> some View {
        Button {
            Haptics.select()
            selected = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                Text(title).font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selected == tab ? DS.accent : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var addButton: some View {
        ZStack {
            Circle().fill(.bar).frame(width: 74, height: 74) // halo nests the FAB into the bar
            Circle()
                .fill(DS.accent)
                .frame(width: 60, height: 60)
                .shadow(color: DS.accent.opacity(0.35), radius: 10, y: 4)
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .foregroundStyle(DS.onAccent)
        }
        .contentShape(Circle())
        .onTapGesture { onAdd() }
        .onLongPressGesture(minimumDuration: 0.3) { onLongPress() }
        .accessibilityLabel("Add")
        .accessibilityHint("Adds an expense. Touch and hold for more actions.")
    }
}

/// Actions offered by the long-press fan.
enum FanAction: CaseIterable, Identifiable {
    case expense, theme, person, recurring
    var id: Self { self }

    var title: String {
        switch self {
        case .expense: return "Expense"
        case .theme: return "Theme"
        case .person: return "Person"
        case .recurring: return "Recurring"
        }
    }
    var icon: String {
        switch self {
        case .expense: return "indianrupeesign"
        case .theme: return "square.grid.2x2.fill"
        case .person: return "person.fill"
        case .recurring: return "calendar.badge.clock"
        }
    }
    var color: Color {
        switch self {
        case .expense: return Color(hex: "5E5CE6")
        case .theme: return Color(hex: "BF5AF2")
        case .person: return Color(hex: "30B0C7")
        case .recurring: return Color(hex: "FF9F0A")
        }
    }
}

/// The "rainbow" fan revealed by holding the ＋ button. Dim background, items
/// arc out above the button; tap one to act, tap the backdrop to dismiss.
struct QuickActionFan: View {
    let onSelect: (FanAction) -> Void
    let onDismiss: () -> Void

    @State private var shown = false
    private let actions = FanAction.allCases

    var body: some View {
        ZStack {
            Color.black.opacity(shown ? 0.32 : 0)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            ZStack {
                ForEach(Array(actions.enumerated()), id: \.element) { index, action in
                    fanButton(action, index: index, count: actions.count)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 92)
        }
        .onAppear { withAnimation(DS.spring) { shown = true } }
    }

    private func fanButton(_ action: FanAction, index: Int, count: Int) -> some View {
        let spread = 120.0
        let startAngle = 90.0 + spread / 2          // sweep from upper-left to upper-right
        let step = count > 1 ? spread / Double(count - 1) : 0
        let angle = (startAngle - step * Double(index)) * .pi / 180
        let radius: CGFloat = 118
        let dx = CGFloat(cos(angle)) * radius
        let dy = -CGFloat(sin(angle)) * radius

        return VStack(spacing: 5) {
            ZStack {
                Circle().fill(.bar).frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                Image(systemName: action.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(action.color)
            }
            Text(action.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(.bar))
        }
        .scaleEffect(shown ? 1 : 0.4)
        .opacity(shown ? 1 : 0)
        .offset(x: shown ? dx : 0, y: shown ? dy : 0)
        .animation(DS.spring.delay(Double(index) * 0.04), value: shown)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap()
            onSelect(action)
        }
    }
}
