import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query private var shops: [ShopProfile]
    @Query(sort: \Job.scheduledAt) private var jobs: [Job]
    @Query private var invoices: [Invoice]
    @Query private var clients: [Client]
    @Query private var quotes: [Quote]
    @Query private var priceItems: [PriceBookItem]

    @State private var path = NavigationPath()
    @State private var showNewJob = false
    @State private var showNewQuote = false
    @State private var pendingRoute: TodayRoute?
    @State private var showSyncNote = false

    private var shop: ShopProfile? { shops.first }

    private var openInvoices: [Invoice] {
        invoices
            .filter { $0.isOpen }
            .sorted { $0.dueAt < $1.dueAt }
    }

    private var amountOwed: Decimal {
        openInvoices.reduce(Decimal(0)) { partial, invoice in
            guard let quote = invoice.quote else { return partial }
            return partial + MoneyMath.summarize(items: quote.lineItems, taxBasisPoints: quote.taxBasisPoints).total
        }
    }

    private var todaysJobs: [Job] {
        jobs.filter { Calendar.current.isDateInToday($0.scheduledAt) }
    }

    private var upcomingJobs: [Job] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
        let end = calendar.date(byAdding: .day, value: 8, to: start) ?? start
        return jobs.filter { job in
            job.scheduledAt >= start && job.scheduledAt < end && job.status != .done
        }
    }

    private var pendingSyncCount: Int {
        clients.filter(\.needsSync).count
            + jobs.filter(\.needsSync).count
            + quotes.filter(\.needsSync).count
            + invoices.filter(\.needsSync).count
            + priceItems.filter(\.needsSync).count
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    shopHeader
                    moneyCard
                    actionRow
                    jobSection(title: "Today", jobs: todaysJobs, empty: "Nothing on the board today.")
                    jobSection(title: "Coming up", jobs: upcomingJobs, empty: "No jobs in the next week.")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        SyncStub.markEverythingSynced(in: context)
                        showSyncNote = true
                    } label: {
                        Image(systemName: pendingSyncCount > 0 ? "icloud.slash" : "checkmark.icloud")
                    }
                    .accessibilityLabel("Sync now")
                }
            }
            .forgeRoutes()
            .sheet(isPresented: $showNewJob, onDismiss: openPending) {
                JobFormView(job: nil) { job in
                    pendingRoute = .job(job)
                }
            }
            .sheet(isPresented: $showNewQuote, onDismiss: openPending) {
                JobPickerSheet { job in
                    let quote = QuoteActions.makeDraft(for: job, in: context)
                    pendingRoute = .quote(quote)
                }
            }
            .alert("Sync stub", isPresented: $showSyncNote) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("On-device changes are marked synced. This prototype does not upload them.")
            }
        }
    }

    private var shopHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(shop?.businessName ?? "FieldForge")
                .font(.title2.weight(.bold))
            Text(shopLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Label("Saved on this iPhone", systemImage: "iphone")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ForgeTheme.navy)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(ForgeTheme.copper.opacity(0.15), in: Capsule())
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var shopLine: String {
        guard let shop else { return "Solo field OS" }
        return "\(shop.ownerName) · \(shop.trade)"
    }

    private var moneyCard: some View {
        NavigationLink {
            MoneyOwedView()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Money owed")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                }
                .foregroundStyle(.white.opacity(0.85))
                Text(FieldFormat.money(amountOwed))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(openInvoiceCaption)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ForgeTheme.navy, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens unpaid invoices")
    }

    private var openInvoiceCaption: String {
        switch openInvoices.count {
        case 0: "Nothing outstanding"
        case 1: "1 open invoice"
        default: "\(openInvoices.count) open invoices"
        }
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                showNewJob = true
            } label: {
                actionLabel("New Job", systemImage: "plus")
            }
            Button {
                showNewQuote = true
            } label: {
                actionLabel("New Quote", systemImage: "doc.text")
            }
        }
        .buttonStyle(.plain)
    }

    private func actionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(ForgeTheme.copper.opacity(0.45), lineWidth: 1)
            }
    }

    private func jobSection(title: String, jobs: [Job], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.bold))
            if jobs.isEmpty {
                Text(empty)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(jobs) { job in
                        NavigationLink(value: job) {
                            TodayJobCard(job: job)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func openPending() {
        guard let pendingRoute else { return }
        switch pendingRoute {
        case .job(let job):
            path.append(job)
        case .quote(let quote):
            path.append(quote)
        }
        self.pendingRoute = nil
    }
}

private enum TodayRoute {
    case job(Job)
    case quote(Quote)
}

private struct TodayJobCard: View {
    let job: Job

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(job.scheduledAt.formatted(date: .omitted, time: .shortened))
                .font(.subheadline.weight(.semibold))
                .frame(width: 76, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(job.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    if job.needsSync { SyncBadge() }
                }
                Text(job.client?.name ?? "No client")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(job.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            StatusChip(title: job.status.label, tint: ForgeTheme.jobTint(job.status))
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct MoneyOwedView: View {
    @Query private var invoices: [Invoice]

    private var openInvoices: [Invoice] {
        invoices.filter { $0.isOpen }.sorted { $0.dueAt < $1.dueAt }
    }

    var body: some View {
        Group {
            if openInvoices.isEmpty {
                EmptyHint(
                    title: "All caught up",
                    message: "Open invoices show up here until you mark them paid.",
                    systemImage: "checkmark.circle"
                )
            } else {
                List(openInvoices) { invoice in
                    NavigationLink(value: invoice) {
                        InvoiceRow(invoice: invoice)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Money owed")
    }
}

struct InvoiceRow: View {
    let invoice: Invoice

    private var total: Decimal {
        guard let quote = invoice.quote else { return 0 }
        return MoneyMath.summarize(items: quote.lineItems, taxBasisPoints: quote.taxBasisPoints).total
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.number)
                    .font(.body.weight(.semibold))
                Text(invoice.quote?.job?.client?.name ?? "No client")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Due \(invoice.dueAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(FieldFormat.money(total))
                    .font(.body.weight(.semibold))
                StatusChip(title: invoice.displayStatus.label, tint: ForgeTheme.invoiceTint(invoice.displayStatus))
            }
        }
        .padding(.vertical, 6)
    }
}
