import SwiftData
import SwiftUI

@main
struct FieldForgeApp: App {
    @State private var appLock = AppLock()
    private let container: ModelContainer = ForgeStore.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appLock)
        }
        .modelContainer(container)
    }
}

private struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppLock.self) private var appLock
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
        .accessibilityHidden(appLock.isLocked)
        .overlay {
            if appLock.isLocked {
                AppLockCover()
            }
        }
        .task {
            BusinessMigration.adoptLegacyShopIfNeeded(in: context)
            didCheckLegacy = true
        }
        .onChange(of: scenePhase) { _, phase in
            appLock.sceneChanged(phase)
            if phase == .active {
                Task { await InvoiceReminders.reschedule(in: context) }
            }
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
