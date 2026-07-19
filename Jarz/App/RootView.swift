import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            DashboardConfigurator.makeView()
                .tabItem { Label("Home", systemImage: "house") }
            IncomeConfigurator.makeView()
                .tabItem { Label("Income", systemImage: "tray.and.arrow.down") }
            ReconciliationConfigurator.makeView()
                .tabItem { Label("Revision", systemImage: "scalemass") }
            SettingsConfigurator.makeView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Theme.ink)
    }
}
