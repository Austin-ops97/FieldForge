import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query private var shops: [BusinessProfile]
    @Query(sort: \Job.scheduledAt) private var jobs: [Job]
    @Query private var invoices: [Invoice]

    @State private var path = NavigationPath()
    @State private var showNewJob = false
    @State private var showNewQuote = false
    @State private var pendingRoute: TodayRoute?

    private var shop: BusinessProfile? { shops.first }

    private var openInvoices: [Invoice] {
        invoices
            .filter { $0.isOpen }
            .sorted { $0.dueAt < $1.dueAt }
    }

    private var overdueInvoices: [Invoice] {
        openInvoices.filter { $0.displayStatus == .overdue }
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

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: ForgeTheme.Space.m) {
                    shopHeader
                    ledgerCard
                    actionRow
                    jobSection(title: "On the board", jobs: todaysJobs, empty: "Nothing on the board today.")
                    jobSection(title: "Coming up", jobs: upcomingJobs, empty: "No jobs in the next week.")
                }
                .padding(.horizontal, ForgeTheme.Space.s)
                .padding(.bottom, ForgeTheme.Space.l)
            }
            .background(ForgeTheme.canvas)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink {
                        GlobalSearchView()
                    } label: {
                        Image(systemName: "text.magnifyingglass")
                    }
                    .accessibilityLabel("Search")
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
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
        }
    }

    private var shopHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(shop?.businessName ?? "FieldForge")
                .font(.title3.weight(.semibold))
            Text("\(shopLine) · On this iPhone only")
                .font(ForgeType.secondary)
                .foregroundStyle(.secondary)
            Text("Works offline. No account.")
                .font(ForgeType.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, ForgeTheme.Space.xxs)
        .accessibilityElement(children: .combine)
    }

    private var shopLine: String {
        guard let shop else { return "Solo field OS" }
        return "\(shop.ownerName) · \(shop.trade)"
    }

    private var ledgerCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink {
                MoneyOwedView()
            } label: {
                VStack(alignment: .leading, spacing: ForgeTheme.Space.xxs) {
                    HStack {
                        Text("Outstanding")
                            .font(ForgeType.overline)
                            .textCase(.uppercase)
                            .tracking(0.6)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(.white.opacity(0.68))
                    Text(FieldFormat.money(amountOwed))
                        .font(ForgeType.heroMoney)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(openInvoiceCaption)
                        .font(ForgeType.secondary)
                        .foregroundStyle(.white.opacity(0.72))
                }
                .padding(ForgeTheme.Space.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(ForgePressStyle())
            .accessibilityHint("Opens unpaid invoices")

            if overdueInvoices.isEmpty == false {
                Rectangle()
                    .fill(.white.opacity(0.14))
                    .frame(height: 1)
                    .padding(.horizontal, ForgeTheme.Space.s)
                ForEach(overdueInvoices) { invoice in
                    NavigationLink(value: invoice.forgeRoute) {
                        OverdueLedgerRow(invoice: invoice)
                    }
                    .buttonStyle(ForgePressStyle())
                }
            }
        }
        .background(ForgeTheme.ink, in: RoundedRectangle(cornerRadius: ForgeTheme.Radius.l, style: .continuous))
    }

    private var openInvoiceCaption: String {
        let open = openInvoices.count == 1 ? "1 open invoice" : "\(openInvoices.count) open invoices"
        guard overdueInvoices.isEmpty == false else {
            return openInvoices.isEmpty ? "Nothing outstanding" : open
        }
        let late = overdueInvoices.count == 1 ? "1 overdue" : "\(overdueInvoices.count) overdue"
        return "\(late) · \(open)"
    }

    private var actionRow: some View {
        VStack(spacing: ForgeTheme.Space.xs) {
            HStack(spacing: ForgeTheme.Space.xs) {
                QuietActionButton(title: "New Job", systemImage: "plus") {
                    showNewJob = true
                }
                QuietActionButton(title: "New Quote", systemImage: "doc.text") {
                    showNewQuote = true
                }
            }
            HStack(spacing: ForgeTheme.Space.xs) {
                NavigationLink {
                    WeekBoardView()
                } label: {
                    quietLinkLabel("Week", systemImage: "calendar")
                }
                NavigationLink {
                    ReportsView()
                } label: {
                    quietLinkLabel("Reports", systemImage: "chart.bar")
                }
            }
        }
    }

    private func quietLinkLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(ForgeTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, ForgeTheme.Space.xs)
            .background(ForgeTheme.surface, in: RoundedRectangle(cornerRadius: ForgeTheme.Radius.m, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: ForgeTheme.Radius.m, style: .continuous)
                    .strokeBorder(ForgeTheme.border, lineWidth: 1)
            }
    }

    private func jobSection(title: String, jobs: [Job], empty: String) -> some View {
        VStack(alignment: .leading, spacing: ForgeTheme.Space.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(ForgeType.section)
                Spacer()
                if jobs.isEmpty == false {
                    Text("\(jobs.count)")
                        .font(ForgeType.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if jobs.isEmpty {
                VStack(alignment: .leading, spacing: ForgeTheme.Space.xs) {
                    Text(empty)
                        .font(ForgeType.secondary)
                        .foregroundStyle(.secondary)
                    Button("New job") { showNewJob = true }
                        .font(ForgeType.rowTitle)
                        .foregroundStyle(ForgeTheme.ink)
                        .frame(minHeight: 44, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(ForgeTheme.Space.s)
                .forgeCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(jobs.enumerated()), id: \.element.persistentModelID) { index, job in
                        if index > 0 {
                            Rectangle()
                                .fill(ForgeTheme.border)
                                .frame(height: 1)
                                .padding(.leading, ForgeTheme.Space.s)
                        }
                        NavigationLink(value: job.forgeRoute) {
                            TodayJobRow(job: job)
                        }
                        .buttonStyle(ForgePressStyle())
                    }
                }
                .forgeCard()
            }
        }
    }

    private func openPending() {
        guard let pendingRoute else { return }
        switch pendingRoute {
        case .job(let job):
            path.append(job.forgeRoute)
        case .quote(let quote):
            path.append(quote.forgeRoute)
        }
        self.pendingRoute = nil
    }
}

private enum TodayRoute {
    case job(Job)
    case quote(Quote)
}

private struct TodayJobRow: View {
    let job: Job

    var body: some View {
        HStack(alignment: .top, spacing: ForgeTheme.Space.xs) {
            Text(job.scheduledAt.formatted(date: .omitted, time: .shortened))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(ForgeTheme.ink)
                .frame(width: 88, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                        Text(job.title)
                            .font(ForgeType.rowTitle)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                Text(job.client?.name ?? "No client")
                    .font(ForgeType.secondary)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                StatusChip(title: job.status.label, tint: ForgeTheme.jobTint(job.status))
            }
            Spacer(minLength: 0)
        }
        .padding(ForgeTheme.Space.s)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct MoneyOwedView: View {
    @Environment(\.modelContext) private var context
    @Query private var invoices: [Invoice]
    @State private var showNewQuote = false
    @State private var quoteToOpen: Quote?
    @State private var showQuote = false
    @State private var quoteCreatedThisSession = false

    private var openInvoices: [Invoice] {
        invoices.filter { $0.isOpen }.sorted { $0.dueAt < $1.dueAt }
    }

    var body: some View {
        Group {
            if openInvoices.isEmpty {
                EmptyHint(
                    title: "All caught up",
                    message: "Open invoices show up here until you mark them paid.",
                    systemImage: "checkmark.circle",
                    actionTitle: "New quote",
                    action: { showNewQuote = true }
                )
            } else {
                List(openInvoices) { invoice in
                    NavigationLink(value: invoice.forgeRoute) {
                        InvoiceRow(invoice: invoice)
                    }
                    .listRowBackground(rowBackground(invoice))
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Money owed")
        .sheet(isPresented: $showNewQuote, onDismiss: {
            if quoteCreatedThisSession {
                showQuote = true
            }
            quoteCreatedThisSession = false
        }) {
            JobPickerSheet { job in
                quoteToOpen = QuoteActions.makeDraft(for: job, in: context)
                quoteCreatedThisSession = true
            }
        }
        .navigationDestination(isPresented: $showQuote) {
            if let quoteToOpen {
                QuoteBuilderView(quote: quoteToOpen)
            }
        }
    }

    private func rowBackground(_ invoice: Invoice) -> Color {
        invoice.displayStatus == .overdue
            ? ForgeTheme.overdue.opacity(0.08)
            : Color(.secondarySystemGroupedBackground)
    }
}

private struct OverdueLedgerRow: View {
    let invoice: Invoice

    private var total: Decimal {
        guard let quote = invoice.quote else { return 0 }
        return MoneyMath.summarize(items: quote.lineItems, taxBasisPoints: quote.taxBasisPoints).total
    }

    var body: some View {
        HStack(alignment: .center, spacing: ForgeTheme.Space.xs) {
            VStack(alignment: .leading, spacing: 2) {
                Text(invoice.number)
                    .font(ForgeType.rowTitle)
                    .foregroundStyle(.white)
                Text(invoice.quote?.job?.client?.name ?? "No client")
                    .font(ForgeType.caption)
                    .foregroundStyle(.white.opacity(0.68))
                Text("Due \(invoice.dueAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(ForgeType.caption)
                    .foregroundStyle(.white.opacity(0.68))
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(FieldFormat.money(total))
                    .font(ForgeType.rowMoney)
                    .foregroundStyle(.white)
                Text("Overdue")
                    .font(ForgeType.overline)
                    .foregroundStyle(Color(red: 1, green: 0.74, blue: 0.70))
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.horizontal, ForgeTheme.Space.s)
        .padding(.vertical, ForgeTheme.Space.xs)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens invoice")
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
                    .font(ForgeType.rowTitle)
                Text(invoice.quote?.job?.client?.name ?? "No client")
                    .font(ForgeType.secondary)
                    .foregroundStyle(.secondary)
                Text("Due \(invoice.dueAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(invoice.displayStatus == .overdue ? ForgeType.overline : ForgeType.caption)
                    .foregroundStyle(invoice.displayStatus == .overdue ? ForgeTheme.overdue : .secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(FieldFormat.money(total))
                    .font(ForgeType.rowMoney)
                    .foregroundStyle(invoice.displayStatus == .overdue ? ForgeTheme.overdue : ForgeTheme.money)
                StatusChip(title: invoice.displayStatus.label, tint: ForgeTheme.invoiceTint(invoice.displayStatus))
            }
        }
        .padding(.vertical, 6)
    }
}
