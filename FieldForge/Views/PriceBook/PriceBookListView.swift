import SwiftData
import SwiftUI

struct PriceBookListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PriceBookItem.name) private var items: [PriceBookItem]
    @Query private var shops: [BusinessProfile]

    @State private var search = ""
    @State private var editing: PriceBookItem?
    @State private var showNew = false
    @State private var itemToDelete: PriceBookItem?

    private var filtered: [PriceBookItem] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return items }
        return items.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.category.localizedCaseInsensitiveContains(query)
                || $0.detail.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filtered.isEmpty {
                    EmptyHint(
                        title: items.isEmpty ? "Empty price book" : "No matches",
                        message: items.isEmpty
                            ? "Add the labor and materials you quote every week."
                            : "Nothing matches that search.",
                        systemImage: "book.closed",
                        actionTitle: items.isEmpty ? "Add item" : "Clear search",
                        action: {
                            if items.isEmpty {
                                showNew = true
                            } else {
                                search = ""
                            }
                        }
                    )
                } else {
                    List {
                        Section {
                            Text(header)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(PriceCategory.allCases) { category in
                            let rows = filtered.filter { $0.category == category.rawValue }
                            if rows.isEmpty == false {
                                Section(category.rawValue) {
                                    ForEach(rows) { item in
                                        Button {
                                            editing = item
                                        } label: {
                                            PriceBookRow(item: item)
                                        }
                                        .buttonStyle(.plain)
                                        .swipeActions {
                                            Button(role: .destructive) {
                                                itemToDelete = item
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Price Book")
            .searchable(text: $search, prompt: "Labor or material")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNew = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add price book item")
                }
            }
            .sheet(item: $editing) { item in
                PriceBookFormView(item: item)
            }
            .sheet(isPresented: $showNew) {
                PriceBookFormView(item: nil)
            }
            .confirmationDialog(
                "Delete this price?",
                isPresented: Binding(
                    get: { itemToDelete != nil },
                    set: { if $0 == false { itemToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let itemToDelete {
                        context.delete(itemToDelete)
                        try? context.save()
                    }
                    itemToDelete = nil
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Quotes that already use it keep their own line items.")
            }
        }
    }

    private var header: String {
        let trade = shops.first?.trade ?? "Plumbing"
        return "\(trade) prices used on quotes. Tap a row to edit."
    }
}

private struct PriceBookRow: View {
    let item: PriceBookItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.category == PriceCategory.materials.rawValue ? "shippingbox" : "hammer")
                .font(.body.weight(.medium))
                .foregroundStyle(ForgeTheme.ink)
                .frame(width: 36, height: 36)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: ForgeTheme.Radius.s, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(item.name)
                        .font(ForgeType.rowTitle)
                        .foregroundStyle(.primary)
                }
                Text(item.detail)
                    .font(ForgeType.secondary)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(item.taxable ? "Taxable · per \(item.unit)" : "Not taxable · per \(item.unit)")
                    .font(ForgeType.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(FieldFormat.money(item.unitPrice))
                .font(ForgeType.rowMoney)
                .foregroundStyle(ForgeTheme.money)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
