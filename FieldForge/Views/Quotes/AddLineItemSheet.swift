import SwiftData
import SwiftUI

struct AddLineItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PriceBookItem.name) private var items: [PriceBookItem]
    @State private var search = ""
    @State private var showCustom = false
    @State private var quantity = 1

    var onPick: (PriceBookItem, Int) -> Void
    var onCustom: (String, String, Decimal, Bool, Int) -> Void

    private var filtered: [PriceBookItem] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return items }
        return items.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.category.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Stepper(value: $quantity, in: 1...99) {
                        Text("Quantity \(quantity)")
                            .font(.body.weight(.semibold))
                    }
                    .frame(minHeight: 44)
                    Button {
                        showCustom = true
                    } label: {
                        Label("Custom line", systemImage: "square.and.pencil")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                } footer: {
                    Text("Set the quantity, then tap a price to add it. Totals update on the quote.")
                }
                Section("Price book") {
                    if items.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("The price book is empty.")
                                .font(.body.weight(.semibold))
                            Text("Use a custom line for this quote, or add prices in the Price Book tab.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button("Custom line") { showCustom = true }
                                .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 6)
                    } else if filtered.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No prices match that search.")
                                .font(.body.weight(.semibold))
                            Button("Clear search") { search = "" }
                                .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 6)
                    } else {
                        ForEach(filtered) { item in
                            Button {
                                onPick(item, quantity)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.name)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text("\(item.category) · per \(item.unit)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(FieldFormat.money(item.unitPrice))
                                        .font(ForgeType.rowMoney)
                                        .foregroundStyle(ForgeTheme.money)
                                }
                                .frame(minHeight: 48)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add line item")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Search the price book")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showCustom) {
                CustomLineSheet(quantity: quantity) { name, unit, price, taxable, lineQuantity in
                    onCustom(name, unit, price, taxable, lineQuantity)
                    dismiss()
                }
            }
        }
    }
}

private struct CustomLineSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var unit = "each"
    @State private var priceText = ""
    @State private var taxable = true
    @State private var quantity: Int

    var onSave: (String, String, Decimal, Bool, Int) -> Void

    init(quantity: Int, onSave: @escaping (String, String, Decimal, Bool, Int) -> Void) {
        _quantity = State(initialValue: quantity)
        self.onSave = onSave
    }

    private var price: Decimal? { FieldFormat.parsePrice(priceText) }

    private var canSave: Bool {
        guard name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return false }
        guard let price else { return false }
        return price >= 0
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Unit", text: $unit)
                TextField("Price", text: $priceText)
                    .keyboardType(.decimalPad)
                Stepper(value: $quantity, in: 1...99) {
                    Text("Quantity \(quantity)")
                }
                .frame(minHeight: 44)
                Toggle("Taxable", isOn: $taxable)
            }
            .navigationTitle("Custom line")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                FormSaveBar(title: "Add", enabled: canSave) {
                    guard let price else { return }
                    onSave(
                        name.trimmingCharacters(in: .whitespacesAndNewlines),
                        unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "each" : unit,
                        price,
                        taxable,
                        quantity
                    )
                    dismiss()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
