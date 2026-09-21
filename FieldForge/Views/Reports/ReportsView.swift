import SwiftData
import SwiftUI

struct ReportsView: View {
    @Query private var invoices: [Invoice]
    @Query private var jobs: [Job]
    @Query private var clients: [Client]

    @State private var shareURL: URL?
    @State private var shareFailed = false

    private var calendar: Calendar { Calendar.current }

    private var openInvoices: [Invoice] {
        invoices.filter(\.isOpen)
    }

    private var overdueInvoices: [Invoice] {
        openInvoices.filter { $0.displayStatus == .overdue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ForgeTheme.Space.m) {
                ledger
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    metricCard(title: "Paid this week", value: FieldFormat.money(paid(in: weekInterval)))
                    metricCard(title: "Paid this month", value: FieldFormat.money(paid(in: monthInterval)))
                    metricCard(title: "Done this week", value: "\(completed(in: weekInterval))")
                    metricCard(title: "Done this month", value: "\(completed(in: monthInterval))")
                }
                VStack(spacing: ForgeTheme.Space.xs) {
                    Button {
                        shareURL = CSVExport.invoicesFile(invoices)
                        if shareURL == nil { shareFailed = true }
                    } label: {
                        Label("Export invoices CSV", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: ForgeTheme.Radius.m))
                    .tint(ForgeTheme.accent)

                    Button {
                        shareURL = CSVExport.clientsFile(clients)
                        if shareURL == nil { shareFailed = true }
                    } label: {
                        Label("Export clients CSV", systemImage: "person.2")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: ForgeTheme.Radius.m))
                    .tint(ForgeTheme.ink)
                }
                Text("Done counts jobs marked done whose finish date falls in the period. Paid uses the date you marked the invoice paid.")
                    .font(ForgeType.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(ForgeTheme.Space.s)
        }
        .background(ForgeTheme.canvas)
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.inline)
        .fileShareSheet(
            url: $shareURL,
            failed: $shareFailed,
            failureTitle: "Couldn't export the CSV",
            failureMessage: "The records are still on this iPhone. Try the export again."
        )
    }

    private var ledger: some View {
        VStack(alignment: .leading, spacing: ForgeTheme.Space.xxs) {
            Text("Unpaid")
                .font(ForgeType.overline)
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.68))
            Text(FieldFormat.money(sum(openInvoices)))
                .font(ForgeType.heroMoney)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(overdueCaption)
                .font(ForgeType.secondary)
                .foregroundStyle(.white.opacity(0.72))
            if overdueInvoices.isEmpty == false {
                Text("Overdue \(FieldFormat.money(sum(overdueInvoices)))")
                    .font(ForgeType.overline)
                    .foregroundStyle(Color(red: 1, green: 0.74, blue: 0.70))
                    .padding(.top, 4)
            }
        }
        .padding(ForgeTheme.Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeTheme.ink, in: RoundedRectangle(cornerRadius: ForgeTheme.Radius.l, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(ForgeType.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(ForgeType.money)
                .foregroundStyle(ForgeTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(ForgeTheme.Space.s)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .forgeCard()
        .accessibilityElement(children: .combine)
    }

    private var overdueCaption: String {
        let open = openInvoices.count == 1 ? "1 open invoice" : "\(openInvoices.count) open invoices"
        guard overdueInvoices.isEmpty == false else {
            return openInvoices.isEmpty ? "Nothing outstanding" : open
        }
        let late = overdueInvoices.count == 1 ? "1 overdue" : "\(overdueInvoices.count) overdue"
        return "\(late) · \(open)"
    }

    private var weekInterval: DateInterval {
        let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    private var monthInterval: DateInterval {
        let start = calendar.dateInterval(of: .month, for: .now)?.start ?? calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    private func paid(in interval: DateInterval) -> Decimal {
        let rows = invoices.filter { invoice in
            guard invoice.status == .paid, let paidAt = invoice.paidAt else { return false }
            return interval.contains(paidAt)
        }
        return sum(rows)
    }

    private func completed(in interval: DateInterval) -> Int {
        jobs.filter { job in
            guard job.status == .done else { return false }
            let when = job.completedAt ?? job.scheduledAt
            return interval.contains(when)
        }.count
    }

    private func sum(_ rows: [Invoice]) -> Decimal {
        rows.reduce(Decimal(0)) { partial, invoice in
            guard let quote = invoice.quote else { return partial }
            return partial + MoneyMath.summarize(items: quote.lineItems, taxBasisPoints: quote.taxBasisPoints).total
        }
    }
}
