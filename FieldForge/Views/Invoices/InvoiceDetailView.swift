import SwiftData
import SwiftUI

struct InvoiceDetailView: View {
    @Environment(\.modelContext) private var context
    @Query private var shops: [ShopProfile]
    @Bindable var invoice: Invoice
    @State private var shareURL: URL?
    @State private var shareFailed = false

    private var quote: Quote? { invoice.quote }

    private var items: [LineItem] {
        (quote?.lineItems ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    private var invoiceTotalColor: Color {
        if invoice.status == .paid { return ForgeTheme.paid }
        if invoice.displayStatus == .overdue { return ForgeTheme.overdue }
        return ForgeTheme.navy
    }

    private var totals: QuoteTotals {
        MoneyMath.summarize(items: quote?.lineItems ?? [], taxBasisPoints: quote?.taxBasisPoints ?? 0)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(invoice.number)
                            .font(.title2.weight(.bold))
                        Spacer()
                        StatusChip(
                            title: invoice.displayStatus.label,
                            tint: ForgeTheme.invoiceTint(invoice.displayStatus)
                        )
                    }
                    Text(FieldFormat.money(totals.total))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(invoiceTotalColor)
                    if let paidAt = invoice.paidAt, invoice.status == .paid {
                        Text("Paid \(paidAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.subheadline)
                            .foregroundStyle(ForgeTheme.paid)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Bill to") {
                if let client = quote?.job?.client {
                    NavigationLink(value: client) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(client.name)
                                .font(.body.weight(.semibold))
                            Text(client.address)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                if let job = quote?.job {
                    NavigationLink(value: job) {
                        Label(job.title, systemImage: "wrench.and.screwdriver")
                            .frame(minHeight: 36, alignment: .leading)
                    }
                }
                if let quote {
                    NavigationLink(value: quote) {
                        Label("From \(quote.number)", systemImage: "doc.text")
                            .frame(minHeight: 36, alignment: .leading)
                    }
                }
            }

            Section("Line items") {
                if items.isEmpty {
                    Text("This invoice has no line items.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(items) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name)
                                    .font(.body.weight(.semibold))
                                Text("\(item.quantity) \(item.unit)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(FieldFormat.money(MoneyMath.lineTotal(unitPrice: item.unitPrice, quantity: item.quantity)))
                        }
                        .padding(.vertical, 4)
                    }
                }
                LabeledContent("Subtotal", value: FieldFormat.money(totals.subtotal))
                LabeledContent("Tax", value: FieldFormat.money(totals.tax))
                LabeledContent("Total", value: FieldFormat.money(totals.total))
            }

            Section("Dates") {
                LabeledContent("Issued", value: invoice.issuedAt.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Due", value: invoice.dueAt.formatted(date: .abbreviated, time: .omitted))
                if invoice.displayStatus == .overdue {
                    Label("Past due", systemImage: "exclamationmark.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(ForgeTheme.overdue)
                        .frame(minHeight: 36, alignment: .leading)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Invoice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PDFShareButton(fileURL: $shareURL, failed: $shareFailed, accessibilityLabel: "Share invoice PDF") {
                    FieldPDF.invoiceFile(invoice, shop: shops.first)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if invoice.status == .paid {
                    Label("Marked paid", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(ForgeTheme.paid)
                } else {
                    Button {
                        QuoteActions.markPaid(invoice, in: context)
                    } label: {
                        Label("Mark Paid", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
                }
                Text(invoice.status == .paid ? "Share sends a PDF of this paid invoice." : "Share sends a PDF. Mark paid when the money lands.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
        .pdfShareSheet(url: $shareURL, failed: $shareFailed)
    }
}
