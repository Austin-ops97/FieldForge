import SwiftData
import SwiftUI

struct PriceBookListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PriceBookItem.name) private var items: [PriceBookItem]
    @Query private var shops: [ShopProfile]

    @State private var search = ""
    @State private var editing: PriceBookItem?
    @State private var showNew = false

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
                            : "Try another name or category.",
                        systemImage: "book.closed"
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
                                                context.delete(item)
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
            Image(systemName: item.category == PriceCategory.materials.rawValue ? "shippingbox.fill" : "hammer.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(ForgeTheme.copper)
                .frame(width: 36, height: 36)
                .background(ForgeTheme.copper.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(item.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    if item.needsSync { SyncBadge() }
                }
                Text(item.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(item.taxable ? "Taxable · per \(item.unit)" : "Not taxable · per \(item.unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(FieldFormat.money(item.unitPrice))
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
