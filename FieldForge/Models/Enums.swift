import Foundation

enum JobStatus: String, Codable, CaseIterable, Identifiable {
    case lead
    case scheduled
    case inProgress
    case done

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lead: "Lead"
        case .scheduled: "Scheduled"
        case .inProgress: "In Progress"
        case .done: "Done"
        }
    }
}

enum QuoteStatus: String, Codable, CaseIterable, Identifiable {
    case draft
    case sent
    case accepted
    case declined

    var id: String { rawValue }

    var label: String {
        switch self {
        case .draft: "Draft"
        case .sent: "Sent"
        case .accepted: "Accepted"
        case .declined: "Declined"
        }
    }
}

enum InvoiceStatus: String, Codable, CaseIterable, Identifiable {
    case draft
    case sent
    case paid
    case overdue

    var id: String { rawValue }

    var label: String {
        switch self {
        case .draft: "Draft"
        case .sent: "Sent"
        case .paid: "Paid"
        case .overdue: "Overdue"
        }
    }
}

enum TradeKit: String, CaseIterable, Identifiable {
    case plumbing = "Plumbing"
    case hvac = "HVAC"
    case electrical = "Electrical"
    case handyman = "Handyman"

    var id: String { rawValue }
    var label: String { rawValue }
}

enum PriceCategory: String, CaseIterable, Identifiable {
    case labor = "Labor"
    case materials = "Materials"

    var id: String { rawValue }
}
