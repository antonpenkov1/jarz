import AppIntents

struct JarzShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogFoodExpenseIntent(),
            phrases: [
                "Log a food expense in \(.applicationName)",
                "Spend on food in \(.applicationName)",
            ],
            shortTitle: "Log food expense",
            systemImageName: "fork.knife"
        )
        AppShortcut(
            intent: FoodLeftIntent(),
            phrases: [
                "How much is left for food in \(.applicationName)",
                "Food budget in \(.applicationName)",
            ],
            shortTitle: "Food left today",
            systemImageName: "circle.dashed"
        )
    }
}
