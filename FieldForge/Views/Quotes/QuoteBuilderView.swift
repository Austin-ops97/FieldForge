import SwiftData
import SwiftUI

struct QuoteBuilderView: View {
    @Environment(\.modelContext) private var context
    @Query private var shops: [ShopProfile]
    @Bindable var quote: Quote

    @State private var showAdd = false
    @State private var showInvoice = false
    @State private var openedInvoice: Invoice?
    @State private var confirmDecline = false

    private var shopName: String { shops.first?.businessName ?? "FieldForge" }

    private var items: [LineItem] {
        quote.lineItems.sorted { $0.sortIndex < $1.sortIndex }
    }

    private var totals: QuoteTotals {
        MoneyMath.summarize(items: quote.lineItems, taxBasisPoints: quote.taxBasisPoints)
    }

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(quote.number)
                            .font(.title3.weight(.bold))
                        if let job = quote.job {
                            Text(job.title)
                                .font(.subheadline)
                            Text(job.client?.name ?? "No client")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    StatusChip(title: quote.status.label, tint: ForgeTheme.quoteTint(quote.status))
                }
                .padding(.vertical, 4)
            }

            Section {
                if items.isEmpty {
                    Text("Add a price-book item to price this job.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(items) { item in
                        LineItemRow(item: item, editable: quote.isEditable)
                            .swipeActions {
                                if quote.isEditable {
                                    Button(role: .destructive) {
                                        context.delete(item)
                                        quote.needsSync = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }
                if quote.isEditable {
                    Button {
                        showAdd = true
                    } label: {
                        Label("Add line item", systemImage: "plus")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                }
            } header: {
                Text("Line items")
            }

            Section("Tax and total") {
                if quote.isEditable {
                    Stepper(value: $quote.taxBasisPoints, in: 0...1_500, step: 25) {
                        Text("Tax \(FieldFormat.taxPercent(basisPoints: quote.taxBasisPoints))")
                    }
                    .onChange(of: quote.taxBasisPoints) { _, _ in
                        quote.needsSync = true
                    }
                } else {
                    LabeledContent("Tax", value: FieldFormat.taxPercent(basisPoints: quote.taxBasisPoints))
                }
                LabeledContent("Subtotal", value: FieldFormat.money(totals.subtotal))
                LabeledContent("Tax", value: FieldFormat.money(totals.tax))
                LabeledContent("Total") {
                    Text(FieldFormat.money(totals.total))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(ForgeTheme.navy)
                }
            }

            Section("Notes on the quote") {
                if quote.isEditable {
                    TextField("Shown to the customer", text: $quote.notes, axis: .vertical)
                        .lineLimit(3...6)
                        .onChange(of: quote.notes) { _, _ in
                            quote.needsSync = true
                        }
                } else if quote.notes.isEmpty {
                    Text("No notes")
                        .foregroundStyle(.secondary)
                } else {
                    Text(quote.notes)
                }
            }

            if quote.status == .declined {
                Section {
                    Text("This quote was declined. The job is still open if you want a new quote.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Quote")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: ShareSummary.quote(quote, shop: shopName)) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share quote summary")
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .sheet(isPresented: $showAdd) {
            AddLineItemSheet { item in
                QuoteActions.addPriceBookItem(item, to: quote, in: context)
            } onCustom: { name, unit, price, taxable in
                QuoteActions.addCustomLine(
                    name: name,
                    unit: unit,
                    unitPrice: price,
                    taxable: taxable,
                    to: quote,
                    in: context
                )
            }
        }
        .navigationDestination(isPresented: $showInvoice) {
            if let openedInvoice {
                InvoiceDetailView(invoice: openedInvoice)
            }
        }
        .confirmationDialog("Decline this quote?", isPresented: $confirmDecline, titleVisibility: .visible) {
            Button("Decline quote", role: .destructive) {
                quote.status = .declined
                quote.needsSync = true
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 10) {
            if quote.status == .accepted {
                PrimaryButton(title: "View invoice", systemImage: "dollarsign.circle") {
                    openedInvoice = quote.invoice
                    showInvoice = quote.invoice != nil
                }
            } else if quote.isEditable {
                HStack(spacing: 10) {
                    if quote.status == .draft {
                        Button("Mark sent") {
                            quote.status = .sent
                            quote.needsSync = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    Button("Decline") {
                        confirmDecline = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                Button {
                    openedInvoice = QuoteActions.accept(quote, in: context)
                    showInvoice = openedInvoice != nil
                } label: {
                    Label("Accept quote", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .disabled(items.isEmpty)
            }
            Text("Saved on this iPhone")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }
}

private struct LineItemRow: View {
    @Bindable var item: LineItem
    var editable: Bool

    private var amount: Decimal {
        MoneyMath.lineTotal(unitPrice: item.unitPrice, quantity: item.quantity)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body.weight(.semibold))
                Text("\(item.quantity) \(item.unit) · \(FieldFormat.money(item.unitPrice))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if item.taxable {
                    Text("Taxable")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ForgeTheme.copper)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                Text(FieldFormat.money(amount))
                    .font(.body.weight(.semibold))
                if editable {
                    Stepper("Quantity", value: $item.quantity, in: 1...99)
                        .labelsHidden()
                        .accessibilityValue("\(item.quantity)")
                        .onChange(of: item.quantity) { _, _ in
                            item.quote?.needsSync = true
                        }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
