import Foundation
import SwiftData

enum ForgeStore {
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([
            ShopProfile.self,
            Client.self,
            Job.self,
            JobPhoto.self,
            PriceBookItem.self,
            Quote.self,
            LineItem.self,
            Invoice.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("FieldForge could not open its on-device store: \(error)")
        }
    }
}
