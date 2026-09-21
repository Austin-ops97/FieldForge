import SwiftUI

struct StatusChip: View {
    var title: String
    var tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
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
    var tint: Color = ForgeTheme.copper
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(selected ? tint : Color(.secondarySystemFill), in: Capsule())
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
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
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
