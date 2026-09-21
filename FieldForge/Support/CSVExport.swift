import Foundation

enum CSVExport {
    @MainActor
    static func invoicesFile(_ invoices: [Invoice]) -> URL? {
        var lines = ["Number,Client,Job,Issued,Due,Paid,Status,Subtotal,Tax,Total"]
        let sorted = invoices.sorted { $0.issuedAt > $1.issuedAt }
        for invoice in sorted {
            let quote = invoice.quote
            let totals = MoneyMath.summarize(items: quote?.lineItems ?? [], taxBasisPoints: quote?.taxBasisPoints ?? 0)
            let paid = invoice.paidAt?.formatted(date: .abbreviated, time: .omitted) ?? ""
            lines.append([
                invoice.number,
                quote?.job?.client?.name ?? "",
                quote?.job?.title ?? "",
                invoice.issuedAt.formatted(date: .abbreviated, time: .omitted),
                invoice.dueAt.formatted(date: .abbreviated, time: .omitted),
                paid,
                invoice.displayStatus.label,
                FieldFormat.priceField(totals.subtotal),
                FieldFormat.priceField(totals.tax),
                FieldFormat.priceField(totals.total)
            ].map(field).joined(separator: ","))
        }
        return write(lines, filename: "FieldForge-invoices.csv")
    }

    @MainActor
    static func clientsFile(_ clients: [Client]) -> URL? {
        var lines = ["Name,Phone,Email,Address,Notes"]
        for client in clients.sorted(by: { $0.name < $1.name }) {
            lines.append([
                client.name,
                client.phone,
                client.email,
                client.address,
                client.notes
            ].map(field).joined(separator: ","))
        }
        return write(lines, filename: "FieldForge-clients.csv")
    }

    private static func field(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private static func write(_ lines: [String], filename: String) -> URL? {
        let text = lines.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}
