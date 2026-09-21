import SwiftUI

enum ForgeTheme {
    static let copper = Color(red: 0.769, green: 0.471, blue: 0.227)
    static let navy = Color(red: 0.106, green: 0.220, blue: 0.290)
    static let paid = Color(red: 0.176, green: 0.490, blue: 0.345)
    static let overdue = Color(red: 0.70, green: 0.22, blue: 0.18)

    static let lead = Color(red: 0.36, green: 0.40, blue: 0.62)
    static let scheduled = Color(red: 0.18, green: 0.42, blue: 0.72)
    static let draft = Color(red: 0.33, green: 0.36, blue: 0.55)
    static let sent = Color(red: 0.12, green: 0.48, blue: 0.62)

    static func jobTint(_ status: JobStatus) -> Color {
        switch status {
        case .lead: return lead
        case .scheduled: return scheduled
        case .inProgress: return copper
        case .done: return paid
        }
    }

    static func quoteTint(_ status: QuoteStatus) -> Color {
        switch status {
        case .draft: return draft
        case .sent: return sent
        case .accepted: return paid
        case .declined: return overdue
        }
    }

    static func invoiceTint(_ status: InvoiceStatus) -> Color {
        switch status {
        case .draft: return draft
        case .sent: return sent
        case .paid: return paid
        case .overdue: return overdue
        }
    }
}
