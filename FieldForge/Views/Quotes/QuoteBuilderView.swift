import SwiftData
import SwiftUI

struct QuoteBuilderView: View {
    @Environment(\.modelContext) private var context
    @Query private var shops: [BusinessProfile]
    @Bindable var quote: Quote

    @State private var showAdd = false
    @State private var showInvoice = false
    @State private var openedInvoice: Invoice?
    @State private var confirmDecline = false
    @State private var lineToDelete: LineItem?
    @State private var showDraftSaved = false
    @State private var shareURL: URL?
    @State private var shareFailed = false
    @State private var notesDraft = ""
    @State private var notesReady = false

    private var items: [LineItem] {
        quote.lineItems.sorted { $0.sortIndex < $1.sortIndex }
    }

    private var totals: QuoteTotals {
        MoneyMath.summarize(items: quote.lineItems, taxBasisPoints: quote.taxBasisPoints)
    }

    var body: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: ForgeTheme.Space.xs) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(quote.number)
                            .font(ForgeType.section)
                        if let job = quote.job {
                            Text(job.title)
                                .font(ForgeType.secondary)
                            Text(job.client?.name ?? "No client")
                                .font(ForgeType.secondary)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 8) {
                        Text(FieldFormat.money(totals.total))
                            .font(ForgeType.money)
                            .foregroundStyle(ForgeTheme.money)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        StatusChip(title: quote.status.label, tint: ForgeTheme.quoteTint(quote.status))
                    }
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
                                        lineToDelete = item
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
                        .font(ForgeType.money)
                        .foregroundStyle(ForgeTheme.money)
                }
            }

            Section("Notes on the quote") {
                if quote.isEditable {
                    TextField("Shown to the customer", text: $notesDraft, axis: .vertical)
                        .lineLimit(3...6)
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
            ToolbarItemGroup(placement: .topBarTrailing) {
                PDFShareButton(fileURL: $shareURL, failed: $shareFailed, accessibilityLabel: "Share quote PDF") {
                    commitNotes()
                    return FieldPDF.quoteFile(quote, shop: shops.first)
                }
                if quote.isEditable {
                    Menu {
                        if quote.status == .draft {
                            Button("Mark sent") {
                                quote.status = .sent
                                quote.needsSync = true
                            }
                        }
                        Button("Decline quote", role: .destructive) {
                            confirmDecline = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Quote actions")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .sheet(isPresented: $showAdd) {
            AddLineItemSheet { item, quantity in
                QuoteActions.addPriceBookItem(item, quantity: quantity, to: quote, in: context)
            } onCustom: { name, unit, price, taxable, quantity in
                QuoteActions.addCustomLine(
                    name: name,
                    unit: unit,
                    unitPrice: price,
                    taxable: taxable,
                    quantity: quantity,
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
        .confirmationDialog(
            "Remove this line?",
            isPresented: Binding(
                get: { lineToDelete != nil },
                set: { if $0 == false { lineToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove line", role: .destructive) {
                if let lineToDelete {
                    context.delete(lineToDelete)
                    quote.needsSync = true
                }
                lineToDelete = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The total updates when the line is removed.")
        }
        .alert("Draft saved", isPresented: $showDraftSaved) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(quote.number) is a draft on this iPhone. Accept it when the customer says yes.")
        }
        .pdfShareSheet(url: $shareURL, failed: $shareFailed)
        .onAppear {
            guard notesReady == false else { return }
            notesDraft = quote.notes
            notesReady = true
        }
        .onDisappear(perform: commitNotes)
    }

    private func commitNotes() {
        guard notesReady, quote.isEditable else { return }
        let trimmed = notesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != quote.notes else { return }
        quote.notes = trimmed
        quote.needsSync = true
        try? context.save()
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
                if quote.status == .draft {
                    Button {
                        commitNotes()
                        QuoteActions.saveDraft(quote, in: context)
                        showDraftSaved = true
                    } label: {
                        Label("Save draft", systemImage: "square.and.arrow.down")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: ForgeTheme.Radius.m))
                    .tint(ForgeTheme.ink)
                }
                Button {
                    commitNotes()
                    openedInvoice = QuoteActions.accept(quote, in: context)
                    if openedInvoice != nil {
                        ForgeHaptic.success()
                    }
                    showInvoice = openedInvoice != nil
                } label: {
                    Label("Accept quote", systemImage: "checkmark")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: ForgeTheme.Radius.m))
                .tint(ForgeTheme.accent)
                .disabled(items.isEmpty)
                if items.isEmpty {
                    Text("Add a line item before accepting.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text("Share sends a PDF. The draft stays on this iPhone.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, ForgeTheme.Space.s)
        .padding(.top, ForgeTheme.Space.xs)
        .padding(.bottom, ForgeTheme.Space.xxs)
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
                        .font(ForgeType.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                Text(FieldFormat.money(amount))
                    .font(ForgeType.rowMoney)
                    .foregroundStyle(ForgeTheme.money)
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
