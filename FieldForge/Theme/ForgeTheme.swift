import SwiftUI

enum ForgeTheme {
    static let copper = Color(red: 0.769, green: 0.471, blue: 0.227)
    static let navy = Color(red: 0.106, green: 0.220, blue: 0.290)
    static let paid = Color(red: 0.176, green: 0.490, blue: 0.345)
    static let overdue = Color(red: 0.70, green: 0.22, blue: 0.18)

    static func jobTint(_ status: JobStatus) -> Color {
        switch status {
        case .lead: return .secondary
        case .scheduled: return .blue
        case .inProgress: return copper
        case .done: return paid
        }
    }

    static func quoteTint(_ status: QuoteStatus) -> Color {
        switch status {
        case .draft: return .secondary
        case .sent: return .blue
        case .accepted: return paid
        case .declined: return overdue
        }
    }

    static func invoiceTint(_ status: InvoiceStatus) -> Color {
        switch status {
        case .draft: return .secondary
        case .sent: return .blue
        case .paid: return paid
        case .overdue: return overdue
        }
    }
}
