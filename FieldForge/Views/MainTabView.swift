import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
            ClientsListView()
                .tabItem { Label("Clients", systemImage: "person.2.fill") }
            JobsListView()
                .tabItem { Label("Jobs", systemImage: "wrench.and.screwdriver.fill") }
            PriceBookListView()
                .tabItem { Label("Price Book", systemImage: "book.closed.fill") }
        }
        .tint(ForgeTheme.copper)
    }
}
