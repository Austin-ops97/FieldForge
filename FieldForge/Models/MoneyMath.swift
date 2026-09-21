import Foundation
import SwiftData

struct QuoteTotals: Equatable {
    var subtotal: Decimal
    var tax: Decimal
    var total: Decimal
}

enum MoneyMath {
    static func cents(_ value: Decimal) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, 2, .plain)
        return output
    }

    static func lineTotal(unitPrice: Decimal, quantity: Int) -> Decimal {
        cents(unitPrice * Decimal(quantity))
    }

    static func summarize(items: [LineItem], taxBasisPoints: Int) -> QuoteTotals {
        let ordered = items
        let subtotal = ordered.reduce(Decimal(0)) { partial, item in
            partial + lineTotal(unitPrice: item.unitPrice, quantity: item.quantity)
        }
        let taxable = ordered.filter(\.taxable).reduce(Decimal(0)) { partial, item in
            partial + lineTotal(unitPrice: item.unitPrice, quantity: item.quantity)
        }
        let tax = cents(taxable * Decimal(taxBasisPoints) / Decimal(10_000))
        return QuoteTotals(subtotal: subtotal, tax: tax, total: cents(subtotal + tax))
    }
}

enum FieldFormat {
    static func money(_ value: Decimal) -> String {
        value.formatted(.currency(code: "USD"))
    }

    static func taxPercent(basisPoints: Int) -> String {
        (Decimal(basisPoints) / Decimal(10_000))
            .formatted(.percent.precision(.fractionLength(2)))
    }

    static func parsePrice(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        if let value = Decimal(string: trimmed, locale: .current) { return value }
        return Decimal(string: trimmed, locale: Locale(identifier: "en_US_POSIX"))
    }

    static func priceField(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }
}

enum ShareSummary {
    static func quote(_ quote: Quote, shop: String) -> String {
        let totals = MoneyMath.summarize(items: quote.lineItems, taxBasisPoints: quote.taxBasisPoints)
        var lines = ["\(shop)", "Quote \(quote.number)", ""]
        if let client = quote.job?.client?.name {
            lines.append("For \(client)")
        }
        if let title = quote.job?.title {
            lines.append(title)
        }
        lines.append("")
        for item in quote.lineItems.sorted(by: { $0.sortIndex < $1.sortIndex }) {
            let amount = MoneyMath.lineTotal(unitPrice: item.unitPrice, quantity: item.quantity)
            lines.append("\(item.quantity) \(item.unit) · \(item.name) — \(FieldFormat.money(amount))")
        }
        lines.append("")
        lines.append("Subtotal \(FieldFormat.money(totals.subtotal))")
        lines.append("Tax \(FieldFormat.taxPercent(basisPoints: quote.taxBasisPoints)) \(FieldFormat.money(totals.tax))")
        lines.append("Total \(FieldFormat.money(totals.total))")
        if quote.notes.isEmpty == false {
            lines.append("")
            lines.append(quote.notes)
        }
        lines.append("")
        lines.append("Shared from FieldForge. PDF export comes later.")
        return lines.joined(separator: "\n")
    }

    static func invoice(_ invoice: Invoice, shop: String) -> String {
        guard let quote = invoice.quote else {
            return "\(shop)\nInvoice \(invoice.number)"
        }
        var text = Self.quote(quote, shop: shop)
        text = text.replacingOccurrences(of: "Quote \(quote.number)", with: "Invoice \(invoice.number)\nFrom quote \(quote.number)")
        text += "\nStatus: \(invoice.displayStatus.label)"
        return text
    }
}

@MainActor
enum DocumentNumbers {
    static func nextQuoteNumber(in context: ModelContext) -> String {
        let quotes = (try? context.fetch(FetchDescriptor<Quote>())) ?? []
        let maxNumber = quotes.compactMap { parse($0.number) }.max() ?? 1040
        return "Q-\(maxNumber + 1)"
    }

    static func nextInvoiceNumber(in context: ModelContext) -> String {
        let invoices = (try? context.fetch(FetchDescriptor<Invoice>())) ?? []
        let maxNumber = invoices.compactMap { parse($0.number) }.max() ?? 219
        return "INV-\(maxNumber + 1)"
    }

    private static func parse(_ number: String) -> Int? {
        guard let digits = number.split(separator: "-").last else { return nil }
        return Int(digits)
    }
}
