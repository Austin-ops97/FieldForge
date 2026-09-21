import SwiftData
import SwiftUI

@main
struct FieldForgeApp: App {
    private let container: ModelContainer = ForgeStore.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

private struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [BusinessProfile]
    @State private var didCheckLegacy = false

    var body: some View {
        Group {
            if profiles.isEmpty && didCheckLegacy == false {
                ShopLoadingView()
            } else if profiles.isEmpty {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .task {
            BusinessMigration.adoptLegacyShopIfNeeded(in: context)
            didCheckLegacy = true
        }
    }
}

private struct ShopLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(ForgeTheme.ink)
            Text("FieldForge")
                .font(ForgeType.section)
            ProgressView()
                .tint(ForgeTheme.ink)
            Text("Loading the shop on this iPhone")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
