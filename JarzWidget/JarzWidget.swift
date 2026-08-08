import WidgetKit
import SwiftUI

// Boutique palette, duplicated from the app's Theme (the app file pulls in
// extension-unavailable UIKit API, so the widget keeps its own copy).
private enum WTheme {
    static let bg = dynamic(light: (0.970, 0.965, 0.948), dark: (0.082, 0.080, 0.074))
    static let ink = dynamic(light: (0.090, 0.088, 0.080), dark: (0.925, 0.915, 0.885))
    static let secondary = dynamic(light: (0.52, 0.51, 0.47), dark: (0.60, 0.59, 0.55))
    static let hairline = dynamic(light: (0.862, 0.850, 0.812), dark: (0.205, 0.200, 0.185))
    static let accent = dynamic(light: (0.10, 0.42, 0.30), dark: (0.38, 0.66, 0.51))
    static let negative = dynamic(light: (0.72, 0.22, 0.20), dark: (0.87, 0.45, 0.42))

    private static func dynamic(
        light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)
    ) -> Color {
        Color(UIColor { trait in
            let rgb = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
    }
}

struct FoodEntry: TimelineEntry {
    let date: Date
    let snapshot: FoodSnapshot?
}

struct FoodProvider: TimelineProvider {
    func placeholder(in context: Context) -> FoodEntry {
        FoodEntry(date: Date(), snapshot: FoodSnapshot(
            name: NSLocalizedString("Food", comment: ""),
            balance: 28300, daily: 1000, planEnd: nil, currencySymbol: "RSD"))
    }

    func getSnapshot(in context: Context, completion: @escaping (FoodEntry) -> Void) {
        completion(FoodEntry(date: Date(), snapshot: WidgetShared.load() ?? placeholder(in: context).snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FoodEntry>) -> Void) {
        let snapshot = WidgetShared.load()
        let calendar = Calendar.current
        var entries = [FoodEntry(date: Date(), snapshot: snapshot)]
        // One entry per upcoming midnight so the day budget rolls over
        // even if the app isn't opened.
        var day = calendar.startOfDay(for: Date())
        for _ in 0..<7 {
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            entries.append(FoodEntry(date: day, snapshot: snapshot))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct FoodWidgetView: View {
    var entry: FoodEntry
    @Environment(\.widgetFamily) private var family

    private var isAccessory: Bool {
        family == .accessoryRectangular || family == .accessoryInline
    }

    var body: some View {
        Group {
            if let snapshot = entry.snapshot,
               let plan = FoodMath.plan(balance: snapshot.balance, daily: snapshot.daily,
                                        planEnd: snapshot.planEnd, now: entry.date) {
                if isAccessory {
                    accessory(snapshot: snapshot, plan: plan)
                } else {
                    card(snapshot: snapshot, plan: plan)
                }
            } else {
                VStack(spacing: 6) {
                    Text("Jarz")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(isAccessory ? AnyShapeStyle(.primary) : AnyShapeStyle(WTheme.secondary))
                    Text("Set a daily food budget in Settings")
                        .font(.system(size: 13))
                        .foregroundStyle(isAccessory ? AnyShapeStyle(.primary) : AnyShapeStyle(WTheme.ink))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .containerBackground(for: .widget) {
            if isAccessory {
                Color.clear
            } else {
                WTheme.bg
            }
        }
    }

    @ViewBuilder
    private func accessory(snapshot: FoodSnapshot, plan: FoodMath.FoodPlan) -> some View {
        let amount = MoneyFormat.amount(snapshot.balance < 0 ? snapshot.balance : plan.available)
        switch family {
        case .accessoryInline:
            Text("\(snapshot.name): \(amount)")
        default:
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.name.uppercased())
                    .font(.caption2)
                    .opacity(0.7)
                Text(amount)
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                Text(FoodDay.phrase(for: plan.dayDate, relativeTo: entry.date))
                    .font(.caption2)
                    .opacity(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func card(snapshot: FoodSnapshot, plan: FoodMath.FoodPlan) -> some View {
        let isNegative = snapshot.balance < 0
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(snapshot.name.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(WTheme.secondary)
                Spacer()
                if family == .systemMedium {
                    Text(MoneyFormat.money(snapshot.balance, symbol: snapshot.currencySymbol))
                        .font(.system(size: 12, weight: .medium, design: .serif))
                        .foregroundStyle(WTheme.secondary)
                }
            }

            Spacer(minLength: 4)

            Text(MoneyFormat.amount(isNegative ? snapshot.balance : plan.available))
                .font(.system(size: family == .systemMedium ? 40 : 32, weight: .regular, design: .serif))
                .foregroundStyle(isNegative ? WTheme.negative : WTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            if isNegative {
                Text("over budget")
                    .font(.system(size: 12))
                    .foregroundStyle(WTheme.negative)
            } else {
                (Text("\(snapshot.currencySymbol) left for ")
                    .foregroundColor(WTheme.secondary)
                 + Text(FoodDay.phrase(for: plan.dayDate, relativeTo: entry.date))
                    .foregroundColor(plan.isAhead ? WTheme.negative : WTheme.secondary))
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 4)

            if !isNegative {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(WTheme.hairline)
                        Rectangle().fill(WTheme.accent)
                            .frame(width: geo.size.width * progress(plan: plan, daily: snapshot.daily))
                    }
                }
                .frame(height: 2)
                HStack {
                    Text("until \(FoodDay.dateText(plan.planEnd))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(WTheme.accent)
                    if family == .systemMedium {
                        Spacer()
                        quickButton(amount: 100)
                        quickButton(amount: 500)
                    }
                }
                .padding(.top, 5)
            }
        }
    }

    /// Interactive one-tap expense straight from the widget (iOS 17).
    private func quickButton(amount: Int) -> some View {
        Button(intent: LogFoodExpenseIntent(amount: Double(amount))) {
            Text("−\(amount)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WTheme.ink)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().stroke(WTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func progress(plan: FoodMath.FoodPlan, daily: Decimal) -> Double {
        guard plan.available > 0, daily > 0 else { return 0 }
        return min(1, (plan.available as NSDecimalNumber).doubleValue / (daily as NSDecimalNumber).doubleValue)
    }
}

struct FoodWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "JarzFoodWidget", provider: FoodProvider()) { entry in
            FoodWidgetView(entry: entry)
        }
        .configurationDisplayName("Food today")
        .description("What's left to spend on food today.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct JarzWidgetBundle: WidgetBundle {
    var body: some Widget {
        FoodWidget()
    }
}
