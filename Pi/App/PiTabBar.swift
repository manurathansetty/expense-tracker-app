import SwiftUI

/// Custom bottom bar: four tabs flanking a raised center ＋ that nests into the
/// bar (the "bow"). Tap ＋ to quick-add; touch-and-hold to reveal a fan and
/// slide your finger onto an action, then release to pick it.
struct PiTabBar: View {
    @Binding var selected: AppRouter.Tab
    var onAdd: () -> Void
    var onAction: (FanAction) -> Void
    var forceOpen: Bool = false

    @State private var fanOpen = false
    @State private var selection: FanAction?

    private let buttonSize: CGFloat = 74
    private var isOpen: Bool { fanOpen || forceOpen }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                tab(.ledger, "Ledger", "list.bullet.rectangle.portrait")
                tab(.insights, "Insights", "chart.pie.fill")
                Spacer().frame(width: 78)
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
        // Reserve layout height for the FAB that rises above the bar, so the
        // safe-area inset clears it and content never hides underneath.
        .padding(.top, 22)
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
            Circle().fill(.bar).frame(width: buttonSize, height: buttonSize)
            Circle()
                .fill(DS.accent)
                .frame(width: 60, height: 60)
                .shadow(color: DS.accent.opacity(0.35), radius: 10, y: 4)
            Group {
                if isOpen {
                    Image(systemName: "xmark").font(.title2.weight(.bold))
                } else {
                    Text("π").font(.system(size: 30, weight: .bold))
                }
            }
            .foregroundStyle(DS.onAccent)
        }
        .scaleEffect(isOpen ? 0.92 : 1)
        .overlay { fanOverlay }
        .contentShape(Circle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.18).onEnded { _ in open() }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    if fanOpen { updateSelection(value.location) }
                }
                .onEnded { value in
                    if fanOpen {
                        if let action = nearest(value.location) { onAction(action) }
                        close()
                    } else {
                        onAdd()
                    }
                }
        )
        .accessibilityLabel("Add")
        .accessibilityHint("Tap to add an expense. Touch and hold, then slide to a quick action.")
    }

    @ViewBuilder private var fanOverlay: some View {
        if isOpen {
            ZStack {
                ForEach(Array(FanAction.allCases.enumerated()), id: \.element) { index, action in
                    let p = position(index, FanAction.allCases.count)
                    fanItem(action, highlighted: selection == action)
                        .offset(x: p.x, y: p.y)
                }
            }
            .allowsHitTesting(false)
            .transition(.scale(scale: 0.5).combined(with: .opacity))
        }
    }

    private func fanItem(_ action: FanAction, highlighted: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(highlighted ? AnyShapeStyle(action.color) : AnyShapeStyle(.bar))
                    .frame(width: highlighted ? 60 : 52, height: highlighted ? 60 : 52)
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                Image(systemName: action.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(highlighted ? Color.white : action.color)
            }
            Text(action.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary)
                .shadow(color: Color(.systemBackground), radius: 2)
                .shadow(color: Color(.systemBackground), radius: 2)
        }
        .scaleEffect(highlighted ? 1.06 : 1)
        .animation(DS.spring, value: highlighted)
    }

    // MARK: Geometry

    private func position(_ index: Int, _ count: Int) -> CGPoint {
        let spread = 128.0
        let start = 90.0 + spread / 2
        let step = count > 1 ? spread / Double(count - 1) : 0
        let angle = (start - step * Double(index)) * .pi / 180
        let radius: CGFloat = 108
        return CGPoint(x: CGFloat(cos(angle)) * radius, y: -CGFloat(sin(angle)) * radius)
    }

    private func nearest(_ location: CGPoint) -> FanAction? {
        let center = CGPoint(x: buttonSize / 2, y: buttonSize / 2)
        let offset = CGPoint(x: location.x - center.x, y: location.y - center.y)
        guard hypot(offset.x, offset.y) > 34 else { return nil } // near center = cancel
        let actions = FanAction.allCases
        var best: FanAction?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for (index, action) in actions.enumerated() {
            let p = position(index, actions.count)
            let distance = hypot(offset.x - p.x, offset.y - p.y)
            if distance < bestDistance { bestDistance = distance; best = action }
        }
        return best
    }

    // MARK: State

    private func open() {
        guard !fanOpen else { return }
        Haptics.success()
        withAnimation(DS.spring) { fanOpen = true }
    }

    private func close() {
        withAnimation(DS.spring) { fanOpen = false }
        selection = nil
    }

    private func updateSelection(_ location: CGPoint) {
        let next = nearest(location)
        if next != selection {
            selection = next
            if next != nil { Haptics.select() }
        }
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
        case .recurring: return DS.warning
        }
    }
}
