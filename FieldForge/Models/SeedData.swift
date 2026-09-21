import Foundation
import SwiftData

@MainActor
enum SeedData {
    static func seedIfNeeded(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<ShopProfile>())) ?? []
        guard existing.isEmpty else { return }

        let calendar = Calendar.current
        let now = Date.now

        let shop = ShopProfile(
            businessName: "Riverside Plumbing",
            ownerName: "Alex Rivera",
            trade: "Plumbing",
            cityLine: "Austin, TX"
        )
        context.insert(shop)

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

        let serviceCall = price(
            "Service call",
            detail: "Trip charge and diagnostic.",
            category: .labor,
            unit: "trip",
            price: 95
        )
        let faucetLabor = price(
            "Faucet install labor",
            detail: "Remove the old faucet and set the new one.",
            category: .labor,
            unit: "each",
            price: 175
        )
        let moen = price(
            "Moen pull-down kitchen faucet",
            detail: "Brushed nickel, with spray hose.",
            category: .materials,
            unit: "each",
            price: 168
        )
        let supplyLines = price(
            "Braided supply lines",
            detail: "Pair of stainless braided lines.",
            category: .materials,
            unit: "set",
            price: 28
        )
        let flush = price(
            "Water heater flush",
            detail: "Drain, flush sediment, check the anode.",
            category: .labor,
            unit: "each",
            price: 149
        )
        let snake = price(
            "Main drain snake",
            detail: "Cable the main cleanout.",
            category: .labor,
            unit: "each",
            price: 245
        )
        let disposalLabor = price(
            "Disposal install labor",
            detail: "Swap the unit and test for leaks.",
            category: .labor,
            unit: "each",
            price: 210
        )
        let disposalUnit = price(
            "1/2 HP garbage disposal",
            detail: "In-stock unit from the truck.",
            category: .materials,
            unit: "each",
            price: 189
        )
        [serviceCall, faucetLabor, moen, supplyLines, flush, snake, disposalLabor, disposalUnit]
            .forEach(context.insert)

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
        addLine(faucetLabor, quantity: 1, index: 0, quote: faucetQuote, context: context)
        addLine(moen, quantity: 1, index: 1, quote: faucetQuote, context: context)
        addLine(supplyLines, quantity: 1, index: 2, quote: faucetQuote, context: context)

        let disposalQuote = Quote(
            number: "Q-1038",
            status: .accepted,
            taxBasisPoints: 825,
            notes: "Parts were on the truck.",
            createdAt: disposalDate
        )
        context.insert(disposalQuote)
        disposalQuote.job = disposalJob
        addLine(serviceCall, quantity: 1, index: 0, quote: disposalQuote, context: context)
        addLine(disposalLabor, quantity: 1, index: 1, quote: disposalQuote, context: context)
        addLine(disposalUnit, quantity: 1, index: 2, quote: disposalQuote, context: context)

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

    private static func price(
        _ name: String,
        detail: String,
        category: PriceCategory,
        unit: String,
        price: Decimal
    ) -> PriceBookItem {
        PriceBookItem(
            name: name,
            detail: detail,
            category: category.rawValue,
            unit: unit,
            unitPrice: price,
            taxable: true
        )
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

@MainActor
enum SyncStub {
    /// Prototype stand-in for the offline queue. Clears the on-device dirty flags.
    static func markEverythingSynced(in context: ModelContext) {
        func clear<T: PersistentModel>(_ type: T.Type, update: (T) -> Void) {
            let rows = (try? context.fetch(FetchDescriptor<T>())) ?? []
            rows.forEach(update)
        }
        clear(Client.self) { $0.needsSync = false }
        clear(Job.self) { $0.needsSync = false }
        clear(PriceBookItem.self) { $0.needsSync = false }
        clear(Quote.self) { $0.needsSync = false }
        clear(Invoice.self) { $0.needsSync = false }
        try? context.save()
    }
}
