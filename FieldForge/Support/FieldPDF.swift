import UIKit

struct PDFModel {
    var shopName: String
    var ownerLine: String
    var kind: String
    var number: String
    var status: String
    var clientName: String
    var clientDetail: String
    var jobTitle: String
    var jobAddress: String
    var dateLine: String
    var rows: [(qty: String, name: String, amount: String)]
    var subtotal: String
    var taxLabel: String
    var tax: String
    var total: String
    var notes: String
}

enum FieldPDF {
    @MainActor
    static func quoteFile(_ quote: Quote, shop: ShopProfile?) -> URL? {
        let totals = MoneyMath.summarize(items: quote.lineItems, taxBasisPoints: quote.taxBasisPoints)
        let model = PDFModel(
            shopName: shop?.businessName ?? "FieldForge",
            ownerLine: ownerLine(shop),
            kind: "QUOTE",
            number: quote.number,
            status: quote.status.label,
            clientName: quote.job?.client?.name ?? "No client",
            clientDetail: clientDetail(quote.job?.client),
            jobTitle: quote.job?.title ?? "Job",
            jobAddress: quote.job?.address ?? "",
            dateLine: "Quoted \(quote.createdAt.formatted(date: .abbreviated, time: .omitted))",
            rows: rows(from: quote.lineItems),
            subtotal: FieldFormat.money(totals.subtotal),
            taxLabel: "Tax \(FieldFormat.taxPercent(basisPoints: quote.taxBasisPoints))",
            tax: FieldFormat.money(totals.tax),
            total: FieldFormat.money(totals.total),
            notes: quote.notes
        )
        return write(model, filename: "\(quote.number).pdf")
    }

    @MainActor
    static func invoiceFile(_ invoice: Invoice, shop: ShopProfile?) -> URL? {
        let quote = invoice.quote
        let totals = MoneyMath.summarize(items: quote?.lineItems ?? [], taxBasisPoints: quote?.taxBasisPoints ?? 0)
        let model = PDFModel(
            shopName: shop?.businessName ?? "FieldForge",
            ownerLine: ownerLine(shop),
            kind: "INVOICE",
            number: invoice.number,
            status: invoice.displayStatus.label,
            clientName: quote?.job?.client?.name ?? "No client",
            clientDetail: clientDetail(quote?.job?.client),
            jobTitle: quote?.job?.title ?? "Job",
            jobAddress: quote?.job?.address ?? "",
            dateLine: "Issued \(invoice.issuedAt.formatted(date: .abbreviated, time: .omitted))  ·  Due \(invoice.dueAt.formatted(date: .abbreviated, time: .omitted))",
            rows: rows(from: quote?.lineItems ?? []),
            subtotal: FieldFormat.money(totals.subtotal),
            taxLabel: "Tax \(FieldFormat.taxPercent(basisPoints: quote?.taxBasisPoints ?? 0))",
            tax: FieldFormat.money(totals.tax),
            total: FieldFormat.money(totals.total),
            notes: quote?.notes ?? ""
        )
        return write(model, filename: "\(invoice.number).pdf")
    }

    private static func ownerLine(_ shop: ShopProfile?) -> String {
        guard let shop else { return "Solo field OS" }
        return "\(shop.ownerName) · \(shop.trade) · \(shop.cityLine)"
    }

    private static func clientDetail(_ client: Client?) -> String {
        guard let client else { return "" }
        return [client.address, client.phone, client.email]
            .filter { $0.isEmpty == false }
            .joined(separator: "\n")
    }

    private static func rows(from items: [LineItem]) -> [(qty: String, name: String, amount: String)] {
        items.sorted { $0.sortIndex < $1.sortIndex }.map { item in
            let amount = MoneyMath.lineTotal(unitPrice: item.unitPrice, quantity: item.quantity)
            return ("\(item.quantity)", "\(item.name) · \(item.unit)", FieldFormat.money(amount))
        }
    }

    private static func write(_ model: PDFModel, filename: String) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            PDFCanvas(context: context, page: pageRect).render(model)
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

private final class PDFCanvas {
    let context: UIGraphicsPDFRendererContext
    let page: CGRect
    var y: CGFloat = 48
    let margin: CGFloat = 40

    init(context: UIGraphicsPDFRendererContext, page: CGRect) {
        self.context = context
        self.page = page
    }

    func render(_ model: PDFModel) {
        paintHeader(model)
        y = 118
        text(model.ownerLine, size: 11, color: .secondaryLabel)
        gap(8)
        text("Status: \(model.status)", size: 13, weight: .semibold, color: statusColor(model.status))
        text(model.dateLine, size: 12, color: .secondaryLabel)
        gap(14)
        text("Bill to", size: 11, weight: .semibold, color: .secondaryLabel)
        text(model.clientName, size: 16, weight: .semibold)
        if model.clientDetail.isEmpty == false {
            text(model.clientDetail, size: 12, color: .darkText)
        }
        gap(12)
        text("Job", size: 11, weight: .semibold, color: .secondaryLabel)
        text(model.jobTitle, size: 15, weight: .semibold)
        if model.jobAddress.isEmpty == false {
            text(model.jobAddress, size: 12, color: .darkText)
        }
        gap(16)
        rule()
        columns(qty: "Qty", name: "Description", amount: "Amount", header: true)
        rule()
        if model.rows.isEmpty {
            text("No line items", size: 12, color: .secondaryLabel)
        } else {
            for row in model.rows {
                columns(qty: row.qty, name: row.name, amount: row.amount, header: false)
            }
        }
        rule()
        gap(8)
        totalRow("Subtotal", value: model.subtotal, emphasize: false)
        totalRow(model.taxLabel, value: model.tax, emphasize: false)
        totalRow("Total", value: model.total, emphasize: true)
        if model.notes.isEmpty == false {
            gap(16)
            text("Notes", size: 11, weight: .semibold, color: .secondaryLabel)
            text(model.notes, size: 12, color: .darkText)
        }
        gap(18)
        text("Generated by FieldForge on this iPhone.", size: 10, color: .secondaryLabel)
    }

    private func paintHeader(_ model: PDFModel) {
        let navy = UIColor(red: 0.106, green: 0.220, blue: 0.290, alpha: 1)
        navy.setFill()
        context.cgContext.fill(CGRect(x: 0, y: 0, width: page.width, height: 96))
        absolute(model.shopName, in: CGRect(x: margin, y: 28, width: 340, height: 28), size: 22, weight: .bold, color: .white)
        absolute(model.kind, in: CGRect(x: 340, y: 26, width: page.width - margin - 340, height: 16), size: 12, weight: .semibold, color: UIColor(red: 0.93, green: 0.72, blue: 0.48, alpha: 1), alignment: .right)
        absolute(model.number, in: CGRect(x: 340, y: 46, width: page.width - margin - 340, height: 24), size: 18, weight: .bold, color: .white, alignment: .right)
    }

    private func columns(qty: String, name: String, amount: String, header: Bool) {
        let weight: UIFont.Weight = header ? .semibold : .regular
        let color: UIColor = header ? .secondaryLabel : .darkText
        let size: CGFloat = header ? 11 : 12
        ensure(22)
        let row = y
        absolute(qty, in: CGRect(x: margin, y: row, width: 40, height: 18), size: size, weight: weight, color: color)
        absolute(name, in: CGRect(x: margin + 48, y: row, width: 340, height: 18), size: size, weight: weight, color: color)
        absolute(amount, in: CGRect(x: page.width - margin - 120, y: row, width: 120, height: 18), size: size, weight: weight, color: color, alignment: .right)
        y = row + 22
    }

    private func totalRow(_ label: String, value: String, emphasize: Bool) {
        ensure(24)
        let row = y
        let size: CGFloat = emphasize ? 16 : 13
        let weight: UIFont.Weight = emphasize ? .bold : .regular
        let color: UIColor = emphasize ? UIColor(red: 0.106, green: 0.220, blue: 0.290, alpha: 1) : .darkText
        absolute(label, in: CGRect(x: 300, y: row, width: 140, height: 22), size: size, weight: weight, color: color, alignment: .right)
        absolute(value, in: CGRect(x: page.width - margin - 120, y: row, width: 120, height: 22), size: size, weight: weight, color: color, alignment: .right)
        y = row + (emphasize ? 28 : 22)
    }

    private func text(_ string: String, size: CGFloat, weight: UIFont.Weight = .regular, color: UIColor = .darkText) {
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        let width = page.width - margin * 2
        let bounds = (string as NSString).boundingRect(
            with: CGSize(width: width, height: 800),
            options: [.usesLineFragmentOrigin],
            attributes: attrs,
            context: nil
        )
        let height = ceil(bounds.height)
        ensure(height + 2)
        (string as NSString).draw(in: CGRect(x: margin, y: y, width: width, height: height), withAttributes: attrs)
        y += height + 3
    }

    private func absolute(
        _ string: String,
        in rect: CGRect,
        size: CGFloat,
        weight: UIFont.Weight,
        color: UIColor,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        (string as NSString).draw(in: rect, withAttributes: attrs)
    }

    private func rule() {
        ensure(8)
        UIColor.separator.setStroke()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y))
        path.addLine(to: CGPoint(x: page.width - margin, y: y))
        path.lineWidth = 0.5
        path.stroke()
        y += 8
    }

    private func gap(_ amount: CGFloat) {
        ensure(amount)
        y += amount
    }

    private func ensure(_ height: CGFloat) {
        if y + height <= page.height - 36 { return }
        context.beginPage()
        y = 40
    }

    private func statusColor(_ status: String) -> UIColor {
        switch status {
        case "Paid", "Accepted", "Done":
            return UIColor(red: 0.176, green: 0.490, blue: 0.345, alpha: 1)
        case "Overdue", "Declined":
            return UIColor(red: 0.70, green: 0.22, blue: 0.18, alpha: 1)
        case "In Progress":
            return UIColor(red: 0.769, green: 0.471, blue: 0.227, alpha: 1)
        default:
            return UIColor(red: 0.18, green: 0.42, blue: 0.72, alpha: 1)
        }
    }
}
