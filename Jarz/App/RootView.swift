import SwiftUI

struct RootView: View {
    @State private var selectedTab = RootView.initialTab
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardConfigurator.makeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)
            IncomeConfigurator.makeView()
                .tabItem { Label("Income", systemImage: "tray.and.arrow.down") }
                .tag(1)
            ReconciliationConfigurator.makeView()
                .tabItem { Label("Revision", systemImage: "scalemass") }
                .tag(2)
            SettingsConfigurator.makeView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(3)
        }
        .tint(Theme.ink)
        .onAppear {
            appearanceMode.apply()
            #if DEBUG
            // Screenshot hook: `-DemoAppearanceCycle 1` flips dark at 1s, back to light at 4s.
            if UserDefaults.standard.bool(forKey: "DemoAppearanceCycle") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { appearanceRaw = "dark" }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) { appearanceRaw = "light" }
            }
            #endif
        }
        .onChange(of: appearanceRaw) { appearanceMode.apply() }
    }

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    /// DEBUG-only screenshot/verification hook: launch with `-OpenTab 3`.
    private static var initialTab: Int {
        #if DEBUG
        if let value = UserDefaults.standard.string(forKey: "OpenTab"), let tab = Int(value) {
            return tab
        }
        #endif
        return 0
    }
}
