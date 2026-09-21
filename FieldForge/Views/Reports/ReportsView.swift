import SwiftData
import SwiftUI

struct ReportsView: View {
    @Query private var invoices: [Invoice]
    @Query private var jobs: [Job]
    @Query private var clients: [Client]

    @State private var shareURL: URL?
    @State private var shareFailed = false

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        let money = moneySnapshot
        ScrollView {
            VStack(alignment: .leading, spacing: ForgeTheme.Space.m) {
                ledger(money)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    metricCard(title: "Paid this week", value: FieldFormat.money(money.paidWeek))
                    metricCard(title: "Paid this month", value: FieldFormat.money(money.paidMonth))
                    metricCard(title: "Done this week", value: "\(money.doneWeek)")
                    metricCard(title: "Done this month", value: "\(money.doneMonth)")
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

    private func ledger(_ money: MoneySnapshot) -> some View {
        VStack(alignment: .leading, spacing: ForgeTheme.Space.xxs) {
            Text("Unpaid")
                .font(ForgeType.overline)
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.68))
            Text(FieldFormat.money(money.unpaid))
                .font(ForgeType.heroMoney)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(overdueCaption(money))
                .font(ForgeType.secondary)
                .foregroundStyle(.white.opacity(0.72))
            if money.overdueCount > 0 {
                Text("Overdue \(FieldFormat.money(money.overdue))")
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

    private func overdueCaption(_ money: MoneySnapshot) -> String {
        let open = money.openCount == 1 ? "1 open invoice" : "\(money.openCount) open invoices"
        guard money.overdueCount > 0 else {
            return money.openCount == 0 ? "Nothing outstanding" : open
        }
        let late = money.overdueCount == 1 ? "1 overdue" : "\(money.overdueCount) overdue"
        return "\(late) · \(open)"
    }

    private var moneySnapshot: MoneySnapshot {
        let week = weekInterval
        let month = monthInterval
        var unpaid = Decimal(0)
        var overdue = Decimal(0)
        var openCount = 0
        var overdueCount = 0
        var paidWeek = Decimal(0)
        var paidMonth = Decimal(0)
        for invoice in invoices {
            let total = invoiceTotal(invoice)
            if invoice.isOpen {
                openCount += 1
                unpaid += total
                if invoice.displayStatus == .overdue {
                    overdueCount += 1
                    overdue += total
                }
            }
            if invoice.status == .paid, let paidAt = invoice.paidAt {
                if week.contains(paidAt) { paidWeek += total }
                if month.contains(paidAt) { paidMonth += total }
            }
        }
        var doneWeek = 0
        var doneMonth = 0
        for job in jobs where job.status == .done {
            let when = job.completedAt ?? job.scheduledAt
            if week.contains(when) { doneWeek += 1 }
            if month.contains(when) { doneMonth += 1 }
        }
        return MoneySnapshot(
            unpaid: unpaid,
            openCount: openCount,
            overdue: overdue,
            overdueCount: overdueCount,
            paidWeek: paidWeek,
            paidMonth: paidMonth,
            doneWeek: doneWeek,
            doneMonth: doneMonth
        )
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

    private func invoiceTotal(_ invoice: Invoice) -> Decimal {
        guard let quote = invoice.quote else { return 0 }
        return MoneyMath.summarize(items: quote.lineItems, taxBasisPoints: quote.taxBasisPoints).total
    }
}

private struct MoneySnapshot {
    var unpaid: Decimal
    var openCount: Int
    var overdue: Decimal
    var overdueCount: Int
    var paidWeek: Decimal
    var paidMonth: Decimal
    var doneWeek: Int
    var doneMonth: Int
}
