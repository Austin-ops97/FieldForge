import SwiftData
import SwiftUI

struct GlobalSearchView: View {
    @Query(sort: \Client.name) private var clients: [Client]
    @Query(sort: \Job.scheduledAt, order: .reverse) private var jobs: [Job]
    @Query(sort: \Quote.createdAt, order: .reverse) private var quotes: [Quote]
    @Query(sort: \Invoice.issuedAt, order: .reverse) private var invoices: [Invoice]

    @State private var search = ""

    private var query: String {
        search.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var matchedClients: [Client] {
        guard query.isEmpty == false else { return [] }
        return clients.filter { client in
            [client.name, client.phone, client.address, client.email].contains { field in
                field.localizedCaseInsensitiveContains(query)
            }
        }
    }

    private var matchedJobs: [Job] {
        guard query.isEmpty == false else { return [] }
        return jobs.filter { job in
            [job.title, job.address, job.notes, job.client?.name ?? ""].contains { field in
                field.localizedCaseInsensitiveContains(query)
            }
        }
    }

    private var matchedQuotes: [Quote] {
        guard query.isEmpty == false else { return [] }
        return quotes.filter { quote in
            quote.number.localizedCaseInsensitiveContains(query)
                || (quote.job?.client?.name ?? "").localizedCaseInsensitiveContains(query)
                || (quote.job?.title ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    private var matchedInvoices: [Invoice] {
        guard query.isEmpty == false else { return [] }
        return invoices.filter { invoice in
            invoice.number.localizedCaseInsensitiveContains(query)
                || (invoice.quote?.job?.client?.name ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    private var isEmptyResult: Bool {
        query.isEmpty == false
            && matchedClients.isEmpty
            && matchedJobs.isEmpty
            && matchedQuotes.isEmpty
            && matchedInvoices.isEmpty
    }

    var body: some View {
        Group {
            if query.isEmpty {
                ContentUnavailableView(
                    "Search the shop",
                    systemImage: "magnifyingglass",
                    description: Text("Find a client, job, quote, or invoice number.")
                )
            } else if isEmptyResult {
                ContentUnavailableView(
                    "No matches",
                    systemImage: "magnifyingglass",
                    description: Text("Nothing on this iPhone matches “\(query)”.")
                )
            } else {
                List {
                    resultSection("Clients", rows: matchedClients) { client in
                        NavigationLink(value: client.forgeRoute) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(client.name)
                                    .font(ForgeType.rowTitle)
                                Text(client.address)
                                    .font(ForgeType.secondary)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    resultSection("Jobs", rows: matchedJobs) { job in
                        NavigationLink(value: job.forgeRoute) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(job.title)
                                    .font(ForgeType.rowTitle)
                                    .lineLimit(2)
                                Text(job.client?.name ?? "No client")
                                    .font(ForgeType.secondary)
                                    .foregroundStyle(.secondary)
                                StatusChip(title: job.status.label, tint: ForgeTheme.jobTint(job.status))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    resultSection("Quotes", rows: matchedQuotes) { quote in
                        NavigationLink(value: quote.forgeRoute) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(quote.number)
                                        .font(ForgeType.rowTitle)
                                    Text(quote.job?.title ?? "Job")
                                        .font(ForgeType.secondary)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                StatusChip(title: quote.status.label, tint: ForgeTheme.quoteTint(quote.status))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    resultSection("Invoices", rows: matchedInvoices) { invoice in
                        NavigationLink(value: invoice.forgeRoute) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(invoice.number)
                                        .font(ForgeType.rowTitle)
                                    Text(invoice.quote?.job?.client?.name ?? "No client")
                                        .font(ForgeType.secondary)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                StatusChip(
                                    title: invoice.displayStatus.label,
                                    tint: ForgeTheme.invoiceTint(invoice.displayStatus)
                                )
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Name, address, or number")
    }

    @ViewBuilder
    private func resultSection<T: Identifiable, Row: View>(
        _ title: String,
        rows: [T],
        @ViewBuilder row: @escaping (T) -> Row
    ) -> some View {
        if rows.isEmpty == false {
            Section(title) {
                ForEach(rows) { item in
                    row(item)
                }
            }
        }
    }
}
