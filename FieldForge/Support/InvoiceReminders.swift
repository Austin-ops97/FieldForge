import Foundation
import SwiftData
import UserNotifications

/// Local morning alerts for invoices that are due or overdue. Nothing is sent to a server.
@MainActor
enum InvoiceReminders {
    private static let enabledKey = "fieldforge.reminders.enabled"
    private static let idPrefix = "fieldforge.invoice."
    private static let morningHour = 8
    private static let requestCap = 60

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    enum EnableFailure: LocalizedError, Equatable {
        case denied
        case unavailable

        var opensSettings: Bool { self == .denied }

        var errorDescription: String? {
            switch self {
            case .denied:
                return "Notifications are off for FieldForge. Turn them on in Settings to get a morning reminder."
            case .unavailable:
                return "Reminders couldn’t be turned on."
            }
        }
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool, in context: ModelContext) async throws -> Int {
        let center = UNUserNotificationCenter.current()
        if enabled == false {
            UserDefaults.standard.set(false, forKey: enabledKey)
            await removeOurs(center)
            return 0
        }
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            let granted: Bool
            do {
                granted = try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                throw EnableFailure.unavailable
            }
            guard granted else { throw EnableFailure.denied }
        case .denied:
            throw EnableFailure.denied
        case .authorized, .provisional, .ephemeral:
            break
        @unknown default:
            break
        }
        UserDefaults.standard.set(true, forKey: enabledKey)
        return await rebuild(invoices(in: context), center: center)
    }

    @discardableResult
    static func reschedule(in context: ModelContext) async -> Int {
        guard isEnabled else { return 0 }
        return await rebuild(invoices(in: context), center: .current())
    }

    static func pendingCount() async -> Int {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return pending.reduce(into: 0) { count, request in
            if request.identifier.hasPrefix(idPrefix) {
                count += 1
            }
        }
    }

    private static func invoices(in context: ModelContext) -> [Invoice] {
        let all = (try? context.fetch(FetchDescriptor<Invoice>())) ?? []
        return all
            .filter { $0.status != .paid && $0.status != .draft }
            .sorted { $0.dueAt < $1.dueAt }
    }

    private struct PendingAlert {
        var identifier: String
        var title: String
        var body: String
        var components: DateComponents
        var repeats: Bool
    }

    @discardableResult
    private static func rebuild(_ invoices: [Invoice], center: UNUserNotificationCenter) async -> Int {
        let now = Date.now
        let calendar = Calendar.current
        var pending: [PendingAlert] = []
        for invoice in invoices {
            if pending.count >= requestCap { break }
            for alert in alerts(for: invoice, now: now, calendar: calendar) {
                if pending.count >= requestCap { break }
                pending.append(alert)
            }
        }
        await removeOurs(center)
        for alert in pending {
            let content = UNMutableNotificationContent()
            content.title = alert.title
            content.body = alert.body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: alert.components, repeats: alert.repeats)
            try? await center.add(UNNotificationRequest(identifier: alert.identifier, content: content, trigger: trigger))
        }
        return pending.count
    }

    private static func alerts(for invoice: Invoice, now: Date, calendar: Calendar) -> [PendingAlert] {
        if invoice.dueAt < calendar.startOfDay(for: now) {
            var components = DateComponents()
            components.hour = morningHour
            components.minute = 0
            return [PendingAlert(
                identifier: idPrefix + invoice.number + ".overdue",
                title: "Overdue invoice",
                body: body(for: invoice, overdue: true),
                components: components,
                repeats: true
            )]
        }
        guard let dueMorning = morning(on: invoice.dueAt, calendar: calendar) else { return [] }
        var scheduled: [PendingAlert] = []
        if dueMorning > now {
            scheduled.append(PendingAlert(
                identifier: idPrefix + invoice.number + ".due",
                title: "Invoice due today",
                body: body(for: invoice, overdue: false),
                components: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueMorning),
                repeats: false
            ))
        }
        if let late = calendar.date(byAdding: .day, value: 1, to: dueMorning), late > now {
            scheduled.append(PendingAlert(
                identifier: idPrefix + invoice.number + ".late",
                title: "Overdue invoice",
                body: body(for: invoice, overdue: true),
                components: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: late),
                repeats: false
            ))
        }
        return scheduled
    }

    private static func body(for invoice: Invoice, overdue: Bool) -> String {
        let client = invoice.quote?.job?.client?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let who = client.isEmpty ? "" : " for \(client)"
        if overdue {
            return "\(invoice.number)\(who) is overdue."
        }
        return "\(invoice.number)\(who) is due today."
    }

    private static func morning(on day: Date, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = morningHour
        components.minute = 0
        return calendar.date(from: components)
    }

    private static func removeOurs(_ center: UNUserNotificationCenter) async {
        let pending = await center.pendingNotificationRequests()
        let delivered = await center.deliveredNotifications()
        let pendingIDs = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        let deliveredIDs = delivered.map(\.request.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pendingIDs)
        center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
    }
}
