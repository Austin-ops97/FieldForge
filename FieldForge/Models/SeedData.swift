import Foundation
import SwiftData

@MainActor
enum SeedData {
    static func loadPriceKit(_ trade: TradeKit, in context: ModelContext) {
        TradeKits.makeItems(for: trade).forEach(context.insert)
        try? context.save()
    }

    static func loadDemo(_ trade: TradeKit, in context: ModelContext) {
        if trade == .plumbing {
            loadPlumbingDemo(in: context)
        } else {
            loadStarterDemo(trade, in: context)
        }
    }

    static func replacePriceBook(with trade: TradeKit, in context: ModelContext) {
        let items = (try? context.fetch(FetchDescriptor<PriceBookItem>())) ?? []
        items.forEach(context.delete)
        loadPriceKit(trade, in: context)
    }

    static func loadPlumbingDemo(in context: ModelContext) {
        let calendar = Calendar.current
        let now = Date.now
        let kit = TradeKits.makeItems(for: .plumbing)
        kit.forEach(context.insert)
        func priced(_ name: String) -> PriceBookItem {
            kit.first { $0.name == name } ?? kit[0]
        }

        let maria = Client(
            name: "Maria Chen",
            phone: "(512) 555-0142",
            email: "maria.chen@email.test",
            address: "412 Oak Street, Austin, TX 78704",
            notes: "Text before you arrive. Friendly dog in the backyard.",
            createdAt: days(from: now, -40, calendar: calendar)
        )
        let james = Client(
            name: "James Whitaker",
            phone: "(512) 555-0198",
            email: "james.whitaker@email.test",
            address: "88 Maple Avenue, Austin, TX 78745",
            notes: "Water heater is in the garage. Gate code 4412.",
            createdAt: days(from: now, -20, calendar: calendar)
        )
        let priya = Client(
            name: "Priya Nair",
            phone: "(512) 555-0177",
            email: "priya.nair@email.test",
            address: "19 Cedar Lane, Austin, TX 78702",
            notes: "Rental. Call the tenant, Sam, before walking the drain.",
            createdAt: days(from: now, -6, calendar: calendar)
        )
        [maria, james, priya].forEach(context.insert)

        let faucetJob = Job(
            title: "Kitchen faucet replacement",
            status: .inProgress,
            scheduledAt: clock(on: now, hour: 9, minute: 0, calendar: calendar),
            address: maria.address,
            notes: "Cartridge is cracked. Customer wants a pull-down sprayer. Shutoff valves are stiff.",
            voiceMemoCaption: "0:18 · wants brushed nickel",
            createdAt: days(from: now, -1, calendar: calendar)
        )
        faucetJob.client = maria
        context.insert(faucetJob)
        addPhoto("Supply lines", symbol: "drop.fill", job: faucetJob, context: context)
        addPhoto("Old faucet", symbol: "wrench.and.screwdriver", job: faucetJob, context: context)

        let heaterJob = Job(
            title: "Water heater flush",
            status: .scheduled,
            scheduledAt: clock(on: now, hour: 13, minute: 30, calendar: calendar),
            address: james.address,
            notes: "50-gal gas heater. Last flush unknown. Check the anode if the drain runs clear.",
            createdAt: days(from: now, -2, calendar: calendar)
        )
        heaterJob.client = james
        context.insert(heaterJob)
        addPhoto("Garage heater", symbol: "flame.fill", job: heaterJob, context: context)

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let drainJob = Job(
            title: "Main line slow drain",
            status: .lead,
            scheduledAt: clock(on: tomorrow, hour: 10, minute: 0, calendar: calendar),
            address: priya.address,
            notes: "Kitchen and hall bath gurgle. Likely the main cleanout in the alley.",
            createdAt: days(from: now, -1, calendar: calendar)
        )
        drainJob.client = priya
        context.insert(drainJob)

        let disposalDate = days(from: now, -8, calendar: calendar)
        let disposalJob = Job(
            title: "Garbage disposal install",
            status: .done,
            scheduledAt: clock(on: disposalDate, hour: 11, minute: 0, calendar: calendar),
            address: maria.address,
            notes: "Replaced a seized 1/3 HP unit with a 1/2 HP. Ran both sinks. No leaks.",
            completedAt: clock(on: disposalDate, hour: 11, minute: 0, calendar: calendar),
            createdAt: days(from: now, -9, calendar: calendar)
        )
        disposalJob.client = maria
        context.insert(disposalJob)
        addPhoto("New disposal", symbol: "wrench.fill", job: disposalJob, context: context)

        let faucetQuote = Quote(
            number: "Q-1042",
            status: .draft,
            taxBasisPoints: 825,
            notes: "Includes haul-away of the old faucet.",
            createdAt: days(from: now, -1, calendar: calendar)
        )
        context.insert(faucetQuote)
        faucetQuote.job = faucetJob
        addLine(priced("Faucet install labor"), quantity: 1, index: 0, quote: faucetQuote, context: context)
        addLine(priced("Moen pull-down kitchen faucet"), quantity: 1, index: 1, quote: faucetQuote, context: context)
        addLine(priced("Braided supply lines"), quantity: 1, index: 2, quote: faucetQuote, context: context)

        let disposalQuote = Quote(
            number: "Q-1038",
            status: .accepted,
            taxBasisPoints: 825,
            notes: "Parts were on the truck.",
            createdAt: disposalDate
        )
        context.insert(disposalQuote)
        disposalQuote.job = disposalJob
        addLine(priced("Service call"), quantity: 1, index: 0, quote: disposalQuote, context: context)
        addLine(priced("Disposal install labor"), quantity: 1, index: 1, quote: disposalQuote, context: context)
        addLine(priced("1/2 HP garbage disposal"), quantity: 1, index: 2, quote: disposalQuote, context: context)

        let issued = disposalDate
        let due = calendar.date(byAdding: .day, value: 3, to: issued) ?? issued
        let invoice = Invoice(
            number: "INV-220",
            status: .sent,
            issuedAt: issued,
            dueAt: due
        )
        context.insert(invoice)
        invoice.quote = disposalQuote
        disposalQuote.invoice = invoice

        try? context.save()
    }

    private static func loadStarterDemo(_ trade: TradeKit, in context: ModelContext) {
        let calendar = Calendar.current
        let now = Date.now
        TradeKits.makeItems(for: trade).forEach(context.insert)
        let samples = TradeKits.starterJobs(for: trade)
        var clientsByName: [String: Client] = [:]
        for sample in samples {
            let client: Client
            if let existing = clientsByName[sample.clientName] {
                client = existing
            } else {
                client = Client(
                    name: sample.clientName,
                    phone: sample.phone,
                    email: "",
                    address: sample.address,
                    notes: sample.clientNotes
                )
                context.insert(client)
                clientsByName[sample.clientName] = client
            }
            let when = calendar.date(byAdding: .day, value: sample.dayOffset, to: now) ?? now
            let job = Job(
                title: sample.title,
                status: sample.status,
                scheduledAt: clock(on: when, hour: sample.hour, minute: 0, calendar: calendar),
                address: sample.address,
                notes: sample.notes,
                completedAt: sample.status == .done ? clock(on: when, hour: sample.hour, minute: 0, calendar: calendar) : nil
            )
            context.insert(job)
            job.client = client
        }
        try? context.save()
    }

    private static func addLine(
        _ source: PriceBookItem,
        quantity: Int,
        index: Int,
        quote: Quote,
        context: ModelContext
    ) {
        let item = LineItem(
            name: source.name,
            unit: source.unit,
            quantity: quantity,
            unitPrice: source.unitPrice,
            taxable: source.taxable,
            sortIndex: index
        )
        context.insert(item)
        item.quote = quote
    }

    private static func addPhoto(_ caption: String, symbol: String, job: Job, context: ModelContext) {
        let photo = JobPhoto(caption: caption, symbolName: symbol)
        context.insert(photo)
        photo.job = job
    }

    private static func days(from date: Date, _ offset: Int, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: offset, to: date) ?? date
    }

    private static func clock(on date: Date, hour: Int, minute: Int, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }
}
