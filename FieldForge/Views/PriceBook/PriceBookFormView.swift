import SwiftData
import SwiftUI

struct PriceBookFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var item: PriceBookItem?

    @State private var name = ""
    @State private var detail = ""
    @State private var category: PriceCategory = .labor
    @State private var unit = "each"
    @State private var priceText = ""
    @State private var taxable = true
    @State private var didLoad = false
    @State private var confirmDelete = false

    private var price: Decimal? { FieldFormat.parsePrice(priceText) }

    private var canSave: Bool {
        guard name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return false }
        guard let price else { return false }
        return price >= 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name", text: $name)
                    TextField("What it covers", text: $detail, axis: .vertical)
                        .lineLimit(2...4)
                    Picker("Category", selection: $category) {
                        ForEach(PriceCategory.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    TextField("Unit", text: $unit)
                }
                Section("Price") {
                    TextField("0.00", text: $priceText)
                        .keyboardType(.decimalPad)
                    Toggle("Taxable", isOn: $taxable)
                }
                if item != nil {
                    Section {
                        Button("Delete item", role: .destructive) {
                            confirmDelete = true
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
            .navigationTitle(item == nil ? "New Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(canSave == false)
                }
            }
            .onAppear(perform: load)
            .confirmationDialog("Delete this price?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let item {
                        context.delete(item)
                        try? context.save()
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Quotes that already use it keep their own line items.")
            }
        }
    }

    private func load() {
        guard didLoad == false else { return }
        didLoad = true
        guard let item else { return }
        name = item.name
        detail = item.detail
        category = PriceCategory(rawValue: item.category) ?? .labor
        unit = item.unit
        priceText = FieldFormat.priceField(item.unitPrice)
        taxable = item.taxable
    }

    private func save() {
        guard let price else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedUnit = trimmedUnit.isEmpty ? "each" : trimmedUnit

        if let item {
            item.name = trimmedName
            item.detail = trimmedDetail
            item.category = category.rawValue
            item.unit = resolvedUnit
            item.unitPrice = price
            item.taxable = taxable
            item.needsSync = true
        } else {
            let newItem = PriceBookItem(
                name: trimmedName,
                detail: trimmedDetail,
                category: category.rawValue,
                unit: resolvedUnit,
                unitPrice: price,
                taxable: taxable,
                needsSync: true
            )
            context.insert(newItem)
        }
        try? context.save()
        dismiss()
    }
}
