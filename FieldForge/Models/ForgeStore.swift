import Foundation
import SwiftData

enum ForgeStore {
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([
            ShopProfile.self,
            BusinessProfile.self,
            Client.self,
            Job.self,
            JobPhoto.self,
            VoiceNote.self,
            PriceBookItem.self,
            Quote.self,
            LineItem.self,
            Invoice.self
        ])
        if let container = try? open(schema, inMemory: inMemory) {
            return container
        }
        if inMemory == false {
            wipeDefaultStore()
            if let container = try? open(schema, inMemory: false) {
                return container
            }
        }
        fatalError("FieldForge could not open its on-device store.")
    }

    private static func open(_ schema: Schema, inMemory: Bool) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func wipeDefaultStore() {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let names = ["default.store", "default.store-shm", "default.store-wal"]
        for name in names {
            try? FileManager.default.removeItem(at: support.appendingPathComponent(name))
        }
    }
}
