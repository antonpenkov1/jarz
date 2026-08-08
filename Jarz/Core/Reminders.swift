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

    static func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    static func reschedule(worker: StorageWorker) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let ours = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ours)

            let defaults = UserDefaults.standard
            let settings = worker.settings()
            guard let foodId = settings.foodCategoryId, settings.dailyFoodAmount > 0 else {
                scheduleRevisionIfEnabled(center: center, defaults: defaults)
                return
            }
            let balance = worker.balance(of: foodId)
            let symbol = settings.currencySymbol
            let calendar = Calendar.current

            for offset in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: offset,
                                              to: calendar.startOfDay(for: Date())) else { continue }

                if defaults.bool(forKey: morningKey),
                   let fire = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day),
                   fire > Date(),
                   let plan = FoodMath.plan(balance: balance, daily: settings.dailyFoodAmount,
                                            planEnd: settings.foodPlanEnd, now: fire),
                   !plan.isAhead, plan.available > 0 {
                    add(center: center, id: "\(idPrefix)morning.\(offset)", fireDate: fire,
                        body: String(localized: "Food today: \(MoneyFormat.money(plan.available, symbol: symbol))"))
                }

                if defaults.bool(forKey: eveningKey),
                   let fire = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: day),
                   fire > Date(),
                   let plan = FoodMath.plan(balance: balance, daily: settings.dailyFoodAmount,
                                            planEnd: settings.foodPlanEnd, now: fire),
                   !plan.isAhead, plan.available > 0 {
                    add(center: center, id: "\(idPrefix)evening.\(offset)", fireDate: fire,
                        body: String(localized: "Left today: \(MoneyFormat.money(plan.available, symbol: symbol)) — it rolls over to tomorrow."))
                }
            }

            scheduleRevisionIfEnabled(center: center, defaults: defaults)
        }
    }

    private static func scheduleRevisionIfEnabled(center: UNUserNotificationCenter, defaults: UserDefaults) {
        guard defaults.bool(forKey: revisionKey) else { return }
        let content = UNMutableNotificationContent()
        content.title = "Jarz"
        content.body = String(localized: "Time for a revision — count your cards and cash.")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 14 * 24 * 3600, repeats: true)
        center.add(UNNotificationRequest(identifier: "\(idPrefix)revision",
                                         content: content, trigger: trigger))
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
