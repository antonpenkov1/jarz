import Foundation
import UserNotifications

/// Fully local, opt-in reminders. Content is precomputed for the next week
/// from current data every time the store changes; morning and evening
/// amounts therefore reflect the state as of the last app use.
enum Reminders {
    static let morningKey = "remindMorning"
    static let eveningKey = "remindEvening"
    static let revisionKey = "remindRevision"

    private static let idPrefix = "jarz.reminder."

    /// Everything the scheduler needs, captured on the main actor so the
    /// notification-center callback never touches the store.
    private struct Payload {
        var morningOn: Bool
        var eveningOn: Bool
        var revisionOn: Bool
        var balance: Decimal
        var daily: Decimal
        var planEnd: Date?
        var symbol: String
        var hasFood: Bool
        var recurrings: [(name: String, amount: Decimal, jarName: String, dayOfMonth: Int)]
    }

    static func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    @MainActor
    static func reschedule(worker: StorageWorker) {
        let defaults = UserDefaults.standard
        let settings = worker.settings()
        let hasFood = settings.foodCategoryId != nil && settings.dailyFoodAmount > 0
        let payload = Payload(
            morningOn: defaults.bool(forKey: morningKey),
            eveningOn: defaults.bool(forKey: eveningKey),
            revisionOn: defaults.bool(forKey: revisionKey),
            balance: settings.foodCategoryId.map { worker.balance(of: $0) } ?? 0,
            daily: settings.dailyFoodAmount,
            planEnd: settings.foodPlanEnd,
            symbol: settings.currencySymbol,
            hasFood: hasFood,
            recurrings: worker.recurrings().map {
                ($0.name, $0.amount, worker.category(id: $0.categoryId)?.name ?? "", $0.dayOfMonth)
            }
        )

        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let ours = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ours)
            schedule(payload, center: center)
        }
    }

    private static func schedule(_ payload: Payload, center: UNUserNotificationCenter) {
        let calendar = Calendar.current

        if payload.hasFood {
            for offset in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: offset,
                                              to: calendar.startOfDay(for: Date())) else { continue }

                if payload.morningOn,
                   let fire = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day),
                   fire > Date(),
                   let plan = FoodMath.plan(balance: payload.balance, daily: payload.daily,
                                            planEnd: payload.planEnd, now: fire),
                   !plan.isAhead, plan.available > 0 {
                    add(center: center, id: "\(idPrefix)morning.\(offset)", fireDate: fire,
                        body: String(localized: "Food today: \(MoneyFormat.money(plan.available, symbol: payload.symbol))"))
                }

                if payload.eveningOn,
                   let fire = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: day),
                   fire > Date(),
                   let plan = FoodMath.plan(balance: payload.balance, daily: payload.daily,
                                            planEnd: payload.planEnd, now: fire),
                   !plan.isAhead, plan.available > 0 {
                    add(center: center, id: "\(idPrefix)evening.\(offset)", fireDate: fire,
                        body: String(localized: "Left today: \(MoneyFormat.money(plan.available, symbol: payload.symbol)) — it rolls over to tomorrow."))
                }
            }
        }

        if payload.revisionOn {
            let content = UNMutableNotificationContent()
            content.title = "Jarz"
            content.body = String(localized: "Time for a revision — count your cards and cash.")
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 14 * 24 * 3600, repeats: true)
            center.add(UNNotificationRequest(identifier: "\(idPrefix)revision",
                                             content: content, trigger: trigger))
        }

        // Heads-up on the morning a recurring payment gets logged (next 30 days).
        let horizon = calendar.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        for (index, recurring) in payload.recurrings.enumerated() {
            var components = calendar.dateComponents([.year, .month], from: Date())
            components.day = recurring.dayOfMonth
            components.hour = 10
            for monthOffset in 0...1 {
                guard let base = calendar.date(from: components),
                      let fire = calendar.date(byAdding: .month, value: monthOffset, to: base),
                      fire > Date(), fire <= horizon else { continue }
                let money = MoneyFormat.money(recurring.amount, symbol: payload.symbol)
                add(center: center,
                    id: "\(idPrefix)recurring.\(index).\(monthOffset)",
                    fireDate: fire,
                    body: String(localized: "\(recurring.name) — \(money) from \(recurring.jarName)"))
            }
        }
    }

    private static func add(center: UNUserNotificationCenter, id: String, fireDate: Date, body: String) {
        let content = UNMutableNotificationContent()
        content.title = "Jarz"
        content.body = body
        content.sound = .default
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
