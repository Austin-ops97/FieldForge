import SwiftData
import SwiftUI

/// Hashable navigation value. SwiftData `@Model` types are not used as
/// `NavigationLink` values, because this SDK does not treat them as `Hashable`.
enum ForgeRoute: Hashable {
    case client(PersistentIdentifier)
    case job(PersistentIdentifier)
    case quote(PersistentIdentifier)
    case invoice(PersistentIdentifier)
}

extension Client {
    var forgeRoute: ForgeRoute { .client(persistentModelID) }
}

extension Job {
    var forgeRoute: ForgeRoute { .job(persistentModelID) }
}

extension Quote {
    var forgeRoute: ForgeRoute { .quote(persistentModelID) }
}

extension Invoice {
    var forgeRoute: ForgeRoute { .invoice(persistentModelID) }
}

struct ForgeDestination: View {
    @Environment(\.modelContext) private var context
    let route: ForgeRoute

    var body: some View {
        switch route {
        case .client(let id):
            if let client = lookup(id, as: Client.self) {
                ClientDetailView(client: client)
            } else {
                MissingRecord(kind: "client")
            }
        case .job(let id):
            if let job = lookup(id, as: Job.self) {
                JobDetailView(job: job)
            } else {
                MissingRecord(kind: "job")
            }
        case .quote(let id):
            if let quote = lookup(id, as: Quote.self) {
                QuoteBuilderView(quote: quote)
            } else {
                MissingRecord(kind: "quote")
            }
        case .invoice(let id):
            if let invoice = lookup(id, as: Invoice.self) {
                InvoiceDetailView(invoice: invoice)
            } else {
                MissingRecord(kind: "invoice")
            }
        }
    }

    private func lookup<T: PersistentModel>(_ id: PersistentIdentifier, as type: T.Type) -> T? {
        let rows = (try? context.fetch(FetchDescriptor<T>())) ?? []
        return rows.first { $0.persistentModelID == id }
    }
}

private struct MissingRecord: View {
    var kind: String

    var body: some View {
        ContentUnavailableView(
            "Missing \(kind)",
            systemImage: "questionmark.circle",
            description: Text("That record is no longer on this iPhone.")
        )
    }
}
