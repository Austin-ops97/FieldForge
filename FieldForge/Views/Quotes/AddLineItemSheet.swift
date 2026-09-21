import SwiftData
import SwiftUI

struct AddLineItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PriceBookItem.name) private var items: [PriceBookItem]
    @State private var search = ""
    @State private var showCustom = false

    var onPick: (PriceBookItem) -> Void
    var onCustom: (String, String, Decimal, Bool) -> Void

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
                    Button {
                        showCustom = true
                    } label: {
                        Label("Custom line", systemImage: "square.and.pencil")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                }
                Section("Price book") {
                    if filtered.isEmpty {
                        Text("No price-book items match.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filtered) { item in
                            Button {
                                onPick(item)
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
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
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
                CustomLineSheet { name, unit, price, taxable in
                    onCustom(name, unit, price, taxable)
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

    var onSave: (String, String, Decimal, Bool) -> Void

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
                Toggle("Taxable", isOn: $taxable)
            }
            .navigationTitle("Custom line")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let price else { return }
                        onSave(
                            name.trimmingCharacters(in: .whitespacesAndNewlines),
                            unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "each" : unit,
                            price,
                            taxable
                        )
                        dismiss()
                    }
                    .disabled(canSave == false)
                }
            }
        }
    }
}
