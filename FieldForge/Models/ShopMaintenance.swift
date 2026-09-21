import Foundation
import SwiftData

@MainActor
enum BusinessMigration {
    static func adoptLegacyShopIfNeeded(in context: ModelContext) {
        let profiles = (try? context.fetch(FetchDescriptor<BusinessProfile>())) ?? []
        guard profiles.isEmpty else { return }
        let shops = (try? context.fetch(FetchDescriptor<ShopProfile>())) ?? []
        guard let shop = shops.first else { return }
        let profile = BusinessProfile(
            businessName: shop.businessName,
            ownerName: shop.ownerName,
            trade: shop.trade,
            cityLine: shop.cityLine,
            taxBasisPoints: 825,
            defaultQuoteNotes: "",
            defaultInvoiceTerms: "Payment due in 14 days."
        )
        context.insert(profile)
        try? context.save()
    }
}

@MainActor
enum OperationalData {
    static func removeShopWork(in context: ModelContext, save: Bool = true) {
        let photos = (try? context.fetch(FetchDescriptor<JobPhoto>())) ?? []
        photos.forEach { MediaFiles.remove($0.fileName) }
        let notes = (try? context.fetch(FetchDescriptor<VoiceNote>())) ?? []
        notes.forEach { MediaFiles.remove($0.fileName) }

        let clients = (try? context.fetch(FetchDescriptor<Client>())) ?? []
        let ownedJobIDs = Set(clients.flatMap { $0.jobs.map(\.persistentModelID) })
        let jobs = (try? context.fetch(FetchDescriptor<Job>())) ?? []
        for job in jobs where ownedJobIDs.contains(job.persistentModelID) == false {
            context.delete(job)
        }
        clients.forEach(context.delete)
        let prices = (try? context.fetch(FetchDescriptor<PriceBookItem>())) ?? []
        prices.forEach(context.delete)
        if save {
            try? context.save()
        }
    }
}
