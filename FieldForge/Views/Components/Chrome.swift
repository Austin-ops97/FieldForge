import SwiftUI

struct StatusChip: View {
    var title: String
    var tint: Color

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(tint.opacity(0.16), in: Capsule())
            .accessibilityLabel("Status \(title)")
    }
}

struct FilterChip: View {
    var title: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(selected ? ForgeTheme.copper : Color(.secondarySystemFill), in: Capsule())
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

struct SyncBadge: View {
    var body: some View {
        Image(systemName: "icloud.slash")
            .font(.caption.weight(.semibold))
            .foregroundStyle(ForgeTheme.copper)
            .accessibilityLabel("Waiting to sync")
    }
}

struct PrimaryButton: View {
    var title: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 14))
    }
}

struct EmptyHint: View {
    var title: String
    var message: String
    var systemImage: String

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text(message))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {
    func forgeRoutes() -> some View {
        navigationDestination(for: Client.self) { client in
            ClientDetailView(client: client)
        }
        .navigationDestination(for: Job.self) { job in
            JobDetailView(job: job)
        }
        .navigationDestination(for: Quote.self) { quote in
            QuoteBuilderView(quote: quote)
        }
        .navigationDestination(for: Invoice.self) { invoice in
            InvoiceDetailView(invoice: invoice)
        }
    }
}
