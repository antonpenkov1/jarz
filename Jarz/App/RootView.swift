import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            DashboardConfigurator.makeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            IncomeConfigurator.makeView()
                .tabItem { Label("Income", systemImage: "tray.and.arrow.down.fill") }
            ReconciliationConfigurator.makeView()
                .tabItem { Label("Revision", systemImage: "scalemass.fill") }
            SettingsConfigurator.makeView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}
