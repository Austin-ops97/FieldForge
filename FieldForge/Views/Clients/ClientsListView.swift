import SwiftData
import SwiftUI

struct ClientsListView: View {
    @Query(sort: \Client.name) private var clients: [Client]
    @State private var search = ""
    @State private var showNew = false

    private var filtered: [Client] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return clients }
        return clients.filter { client in
            client.name.localizedCaseInsensitiveContains(query)
                || client.address.localizedCaseInsensitiveContains(query)
                || client.phone.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filtered.isEmpty {
                    EmptyHint(
                        title: clients.isEmpty ? "No clients yet" : "No matches",
                        message: clients.isEmpty
                            ? "Add the people you quote and invoice."
                            : "Nothing matches that search.",
                        systemImage: "person.2",
                        actionTitle: clients.isEmpty ? "New client" : "Clear search",
                        action: {
                            if clients.isEmpty {
                                showNew = true
                            } else {
                                search = ""
                            }
                        }
                    )
                } else {
                    List(filtered) { client in
                        NavigationLink(value: client) {
                            ClientRow(client: client)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Clients")
            .searchable(text: $search, prompt: "Name, street, or phone")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNew = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New client")
                }
            }
            .forgeRoutes()
            .sheet(isPresented: $showNew) {
                ClientFormView(client: nil)
            }
        }
    }
}

private struct ClientRow: View {
    let client: Client

    var body: some View {
        HStack(spacing: 12) {
            Text(initials)
                .font(.headline)
                .foregroundStyle(ForgeTheme.navy)
                .frame(width: 44, height: 44)
                .background(ForgeTheme.copper.opacity(0.2), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(client.name)
                        .font(.body.weight(.semibold))
                    if client.needsSync { SyncBadge() }
                }
                Text(client.address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(jobCount)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var initials: String {
        let parts = client.name.split(separator: " ")
        let letters = parts.prefix(2).compactMap(\.first)
        return String(letters).uppercased()
    }

    private var jobCount: String {
        let count = client.jobs.count
        return count == 1 ? "1 job" : "\(count) jobs"
    }
}
