import WidgetKit
import SwiftUI

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedSnapshot
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: SnapshotStore.read() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: SnapshotStore.read() ?? .placeholder)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct TodayWidget: Widget {
    let kind = "TodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "\(AppGroup.urlScheme)://add"))
        }
        .configurationDisplayName("Today")
        .description("Today's spend and what's safe to spend.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var snapshot: SharedSnapshot { entry.snapshot }
    private var tint: Color { DS.health(forFraction: snapshot.fractionUsed) }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: snapshot.fractionUsed) {
                Image(systemName: "indianrupeesign")
            }
            .gaugeStyle(.accessoryCircularCapacity)

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Safe to spend").font(.caption2)
                Text(snapshot.safeMoney.formattedCompact()).font(.headline)
                Text("\(snapshot.dailyMoney.formattedCompact())/day").font(.caption2)
            }

        case .systemMedium:
            HStack(spacing: DS.Spacing.lg) {
                mainColumn
                Spacer()
                VStack(alignment: .trailing, spacing: DS.Spacing.sm) {
                    metric("Today", snapshot.todayMoney.formattedCompact())
                    metric("Spent", snapshot.spentMoney.formattedCompact())
                    metric("Per day", snapshot.dailyMoney.formattedCompact())
                }
            }

        default: // systemSmall
            mainColumn
        }
    }

    private var mainColumn: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: 4) {
                Text("π").font(.headline.weight(.bold))
                Text("Safe to spend").font(.caption).foregroundStyle(.secondary)
            }
            Text(snapshot.safeMoney.formattedCompact())
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(snapshot.safeToSpendMinor < 0 ? Color(hex: "FF375F") : .primary)
            ProgressView(value: snapshot.fractionUsed)
                .tint(tint)
            Text("\(snapshot.dailyMoney.formattedCompact()) / day")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold))
        }
    }
}
