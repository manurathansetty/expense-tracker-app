import SwiftUI
import SwiftData

/// Home-screen notifier: shows recurring payments due within 5 days (or overdue),
/// each with a one-tap "Pay" that logs the expense and rolls the date forward.
struct UpcomingDuesCard: View {
    let payments: [RecurringPayment]
    @Environment(\.modelContext) private var context

    private var hasOverdue: Bool {
        payments.contains { RecurringEngine.daysUntil($0.nextDueDate, now: .now) < 0 }
    }
    private var tint: Color { hasOverdue ? DS.negative : DS.warning }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(tint)
                Text("Coming up")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("^[\(payments.count) payment](inflect: true)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(payments) { payment in
                HStack(spacing: DS.Spacing.md) {
                    GlyphBadge(symbolName: payment.symbolName, colorHex: payment.colorHex, size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(payment.name).font(.subheadline.weight(.medium))
                        Text(RecurringEngine.dueLabel(payment.nextDueDate, now: .now))
                            .font(.caption2)
                            .foregroundStyle(dueColor(payment))
                    }
                    Spacer()
                    Text(payment.money.formattedCompact())
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    Button {
                        Haptics.success()
                        LedgerService(context: context).markRecurringPaid(payment)
                    } label: {
                        Text("Paid")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(DS.onAccent)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(DS.accent))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(tint.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .strokeBorder(tint.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private func dueColor(_ payment: RecurringPayment) -> Color {
        RecurringEngine.daysUntil(payment.nextDueDate, now: .now) < 0
            ? DS.negative : DS.warning
    }
}
