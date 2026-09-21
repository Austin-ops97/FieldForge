import Foundation
import SwiftData

@MainActor
enum QuoteActions {
    @discardableResult
    static func makeDraft(for job: Job, in context: ModelContext) -> Quote {
        let profile = (try? context.fetch(FetchDescriptor<BusinessProfile>()))?.first
        let quote = Quote(
            number: DocumentNumbers.nextQuoteNumber(in: context),
            status: .draft,
            taxBasisPoints: profile?.taxBasisPoints ?? 825,
            notes: profile?.defaultQuoteNotes ?? "",
            needsSync: true
        )
        context.insert(quote)
        quote.job = job
        job.needsSync = true
        try? context.save()
        return quote
    }

    static func addPriceBookItem(
        _ source: PriceBookItem,
        quantity: Int = 1,
        to quote: Quote,
        in context: ModelContext
    ) {
        let item = LineItem(
            name: source.name,
            unit: source.unit,
            quantity: max(1, quantity),
            unitPrice: source.unitPrice,
            taxable: source.taxable,
            sortIndex: nextSortIndex(in: quote)
        )
        context.insert(item)
        item.quote = quote
        quote.needsSync = true
        try? context.save()
    }

    static func addCustomLine(
        name: String,
        unit: String,
        unitPrice: Decimal,
        taxable: Bool,
        quantity: Int = 1,
        to quote: Quote,
        in context: ModelContext
    ) {
        let item = LineItem(
            name: name,
            unit: unit,
            quantity: max(1, quantity),
            unitPrice: unitPrice,
            taxable: taxable,
            sortIndex: nextSortIndex(in: quote)
        )
        context.insert(item)
        item.quote = quote
        quote.needsSync = true
        try? context.save()
    }

    @discardableResult
    static func accept(_ quote: Quote, in context: ModelContext) -> Invoice? {
        guard quote.isEditable, quote.lineItems.isEmpty == false else { return quote.invoice }
        quote.status = .accepted
        quote.needsSync = true
        if let existing = quote.invoice {
            try? context.save()
            return existing
        }
        let now = Date.now
        let due = Calendar.current.date(byAdding: .day, value: 14, to: now) ?? now
        let invoice = Invoice(
            number: DocumentNumbers.nextInvoiceNumber(in: context),
            status: .sent,
            issuedAt: now,
            dueAt: due,
            needsSync: true
        )
        context.insert(invoice)
        invoice.quote = quote
        try? context.save()
        return invoice
    }

    static func saveDraft(_ quote: Quote, in context: ModelContext) {
        guard quote.status != .accepted else { return }
        quote.status = .draft
        quote.needsSync = true
        try? context.save()
    }

    static func markPaid(_ invoice: Invoice, in context: ModelContext) {
        guard invoice.status != .paid else { return }
        invoice.status = .paid
        invoice.paidAt = .now
        invoice.needsSync = true
        try? context.save()
    }

    private static func nextSortIndex(in quote: Quote) -> Int {
        (quote.lineItems.map(\.sortIndex).max() ?? -1) + 1
    }
}
