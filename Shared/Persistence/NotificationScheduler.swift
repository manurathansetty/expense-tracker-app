import Foundation
import UserNotifications

/// Schedules local notifications for recurring payments — a heads-up 5 days
/// before the due date and a reminder on the day itself. Local notifications
/// need no special entitlement, only the user's permission.
enum NotificationScheduler {
    static func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Replace all pending reminders with a fresh set for the active, notifying
    /// payments. (This app is the only scheduler, so clearing all is safe.)
    static func reschedule(_ payments: [RecurringPayment], now: Date = .now) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        for payment in payments where payment.isActive && payment.notify {
            schedule(payment, center: center, now: now)
        }
    }

    private static func schedule(_ payment: RecurringPayment, center: UNUserNotificationCenter, now: Date) {
        let calendar = Calendar.current
        let amount = payment.money.formatted()
        let due = payment.nextDueDate
        let dueAt9 = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: due) ?? due
        let preDate = calendar.date(byAdding: .day, value: -5, to: dueAt9) ?? dueAt9

        add(id: "\(payment.id.uuidString)-pre", title: payment.name,
            body: "\(amount) due in 5 days", date: preDate, center: center, now: now)
        add(id: "\(payment.id.uuidString)-due", title: payment.name,
            body: "\(amount) is due today", date: dueAt9, center: center, now: now)
    }

    private static func add(
        id: String, title: String, body: String,
        date: Date, center: UNUserNotificationCenter, now: Date
    ) {
        guard date > now else { return } // don't schedule in the past
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }
}
