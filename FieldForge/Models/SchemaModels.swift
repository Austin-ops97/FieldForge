import Foundation
import SwiftData

@Model
final class ShopProfile {
    var businessName: String
    var ownerName: String
    var trade: String
    var cityLine: String
    var seededAt: Date

    init(businessName: String, ownerName: String, trade: String, cityLine: String, seededAt: Date = .now) {
        self.businessName = businessName
        self.ownerName = ownerName
        self.trade = trade
        self.cityLine = cityLine
        self.seededAt = seededAt
    }
}

@Model
final class BusinessProfile {
    var businessName: String
    var ownerName: String
    var trade: String
    var phone: String
    var email: String
    var cityLine: String
    var taxBasisPoints: Int
    var defaultQuoteNotes: String
    var defaultInvoiceTerms: String
    var createdAt: Date

    var tradeKit: TradeKit {
        get { TradeKit(rawValue: trade) ?? .plumbing }
        set { trade = newValue.rawValue }
    }

    init(
        businessName: String,
        ownerName: String,
        trade: String,
        phone: String = "",
        email: String = "",
        cityLine: String = "",
        taxBasisPoints: Int = 825,
        defaultQuoteNotes: String = "",
        defaultInvoiceTerms: String = "Payment due in 14 days.",
        createdAt: Date = .now
    ) {
        self.businessName = businessName
        self.ownerName = ownerName
        self.trade = trade
        self.phone = phone
        self.email = email
        self.cityLine = cityLine
        self.taxBasisPoints = taxBasisPoints
        self.defaultQuoteNotes = defaultQuoteNotes
        self.defaultInvoiceTerms = defaultInvoiceTerms
        self.createdAt = createdAt
    }
}

@Model
final class Client {
    var name: String
    var phone: String
    var email: String
    var address: String
    var notes: String
    var createdAt: Date
    var needsSync: Bool

    @Relationship(deleteRule: .cascade, inverse: \Job.client)
    var jobs: [Job] = []

    init(
        name: String,
        phone: String,
        email: String,
        address: String,
        notes: String,
        createdAt: Date = .now,
        needsSync: Bool = false
    ) {
        self.name = name
        self.phone = phone
        self.email = email
        self.address = address
        self.notes = notes
        self.createdAt = createdAt
        self.needsSync = needsSync
    }
}

@Model
final class Job {
    var title: String
    var statusRaw: String
    var scheduledAt: Date
    var address: String
    var notes: String
    var voiceMemoCaption: String
    var completedAt: Date?
    var createdAt: Date
    var needsSync: Bool

    var client: Client?

    @Relationship(deleteRule: .cascade, inverse: \JobPhoto.job)
    var photos: [JobPhoto] = []

    @Relationship(deleteRule: .cascade, inverse: \VoiceNote.job)
    var voiceNotes: [VoiceNote] = []

    @Relationship(deleteRule: .cascade, inverse: \Quote.job)
    var quotes: [Quote] = []

    var status: JobStatus {
        get { JobStatus(rawValue: statusRaw) ?? .lead }
        set { statusRaw = newValue.rawValue }
    }

    init(
        title: String,
        status: JobStatus,
        scheduledAt: Date,
        address: String,
        notes: String,
        voiceMemoCaption: String = "",
        completedAt: Date? = nil,
        createdAt: Date = .now,
        needsSync: Bool = false
    ) {
        self.title = title
        self.statusRaw = status.rawValue
        self.scheduledAt = scheduledAt
        self.address = address
        self.notes = notes
        self.voiceMemoCaption = voiceMemoCaption
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.needsSync = needsSync
    }
}

@Model
final class JobPhoto {
    var caption: String
    var symbolName: String
    var fileName: String
    var createdAt: Date
    var job: Job?

    init(caption: String, symbolName: String = "photo", fileName: String = "", createdAt: Date = .now) {
        self.caption = caption
        self.symbolName = symbolName
        self.fileName = fileName
        self.createdAt = createdAt
    }
}

@Model
final class VoiceNote {
    var fileName: String
    var duration: Double
    var createdAt: Date
    var job: Job?

    init(fileName: String, duration: Double, createdAt: Date = .now) {
        self.fileName = fileName
        self.duration = duration
        self.createdAt = createdAt
    }
}

@Model
final class PriceBookItem {
    var name: String
    var detail: String
    var category: String
    var unit: String
    var unitPrice: Decimal
    var taxable: Bool
    var createdAt: Date
    var needsSync: Bool

    init(
        name: String,
        detail: String,
        category: String,
        unit: String,
        unitPrice: Decimal,
        taxable: Bool,
        createdAt: Date = .now,
        needsSync: Bool = false
    ) {
        self.name = name
        self.detail = detail
        self.category = category
        self.unit = unit
        self.unitPrice = unitPrice
        self.taxable = taxable
        self.createdAt = createdAt
        self.needsSync = needsSync
    }
}

@Model
final class Quote {
    var number: String
    var statusRaw: String
    var taxBasisPoints: Int
    var notes: String
    var createdAt: Date
    var needsSync: Bool

    var job: Job?

    @Relationship(deleteRule: .cascade, inverse: \LineItem.quote)
    var lineItems: [LineItem] = []

    @Relationship(deleteRule: .cascade, inverse: \Invoice.quote)
    var invoice: Invoice?

    var status: QuoteStatus {
        get { QuoteStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    var isEditable: Bool {
        status == .draft || status == .sent
    }

    init(
        number: String,
        status: QuoteStatus,
        taxBasisPoints: Int,
        notes: String,
        createdAt: Date = .now,
        needsSync: Bool = false
    ) {
        self.number = number
        self.statusRaw = status.rawValue
        self.taxBasisPoints = taxBasisPoints
        self.notes = notes
        self.createdAt = createdAt
        self.needsSync = needsSync
    }
}

@Model
final class LineItem {
    var name: String
    var unit: String
    var quantity: Int
    var unitPrice: Decimal
    var taxable: Bool
    var sortIndex: Int
    var quote: Quote?

    init(
        name: String,
        unit: String,
        quantity: Int,
        unitPrice: Decimal,
        taxable: Bool,
        sortIndex: Int
    ) {
        self.name = name
        self.unit = unit
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.taxable = taxable
        self.sortIndex = sortIndex
    }
}

@Model
final class Invoice {
    var number: String
    var statusRaw: String
    var issuedAt: Date
    var dueAt: Date
    var paidAt: Date?
    var needsSync: Bool
    var quote: Quote?

    var status: InvoiceStatus {
        get { InvoiceStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    /// Sent invoices past their due date display as overdue without a separate write.
    var displayStatus: InvoiceStatus {
        if status == .paid { return .paid }
        if status == .draft { return .draft }
        if dueAt < Calendar.current.startOfDay(for: .now) { return .overdue }
        return status
    }

    var isOpen: Bool { status != .paid }

    init(
        number: String,
        status: InvoiceStatus,
        issuedAt: Date,
        dueAt: Date,
        paidAt: Date? = nil,
        needsSync: Bool = false
    ) {
        self.number = number
        self.statusRaw = status.rawValue
        self.issuedAt = issuedAt
        self.dueAt = dueAt
        self.paidAt = paidAt
        self.needsSync = needsSync
    }
}
