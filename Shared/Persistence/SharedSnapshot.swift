import Foundation
import WidgetKit

/// A tiny, Codable summary the app publishes to the shared App Group so the
/// widget can render without touching SwiftData. The app rewrites it whenever
/// data changes; the widget only reads.
struct SharedSnapshot: Codable, Equatable, Sendable {
    var todayTotalMinor: Int
    var spentThisMonthMinor: Int
    var safeToSpendMinor: Int
    var dailyAllowanceMinor: Int
    var ceilingMinor: Int
    var currencyCode: String
    var updatedAt: Date

    static let placeholder = SharedSnapshot(
        todayTotalMinor: 24000,
        spentThisMonthMinor: 1840000,
        safeToSpendMinor: 660000,
        dailyAllowanceMinor: 5500,
        ceilingMinor: 2500000,
        currencyCode: "INR",
        updatedAt: .now
    )

    var todayMoney: Money { Money(minorUnits: todayTotalMinor, currencyCode: currencyCode) }
    var safeMoney: Money { Money(minorUnits: safeToSpendMinor, currencyCode: currencyCode) }
    var dailyMoney: Money { Money(minorUnits: dailyAllowanceMinor, currencyCode: currencyCode) }
    var spentMoney: Money { Money(minorUnits: spentThisMonthMinor, currencyCode: currencyCode) }

    var fractionUsed: Double {
        guard ceilingMinor > 0 else { return 0 }
        return min(1, Double(spentThisMonthMinor) / Double(ceilingMinor))
    }
}

/// Reads and writes the `SharedSnapshot` in the App Group `UserDefaults`.
enum SnapshotStore {
    private static let key = "tally.snapshot.v1"

    static func write(_ snapshot: SharedSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        AppGroup.defaults.set(data, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func read() -> SharedSnapshot? {
        guard let data = AppGroup.defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(SharedSnapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }
}
