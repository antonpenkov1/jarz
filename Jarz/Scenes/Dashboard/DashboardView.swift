import SwiftUI

protocol DashboardDisplayLogic: AnyObject {
    func displayDashboard(viewModel: Dashboard.Load.ViewModel)
}

final class DashboardViewStore: ObservableObject, DashboardDisplayLogic {
    @Published var viewModel: Dashboard.Load.ViewModel = .empty
    var interactor: DashboardBusinessLogic?

    func displayDashboard(viewModel: Dashboard.Load.ViewModel) {
        self.viewModel = viewModel
    }
}

enum DashboardConfigurator {
    static func makeView() -> DashboardView {
        let store = DashboardViewStore()
        let presenter = DashboardPresenter()
        presenter.view = store
        store.interactor = DashboardInteractor(presenter: presenter)
        return DashboardView(store: store)
    }
}

struct DashboardView: View {
    @StateObject private var store: DashboardViewStore
    @State private var quickExpenseTarget: QuickExpenseTarget?

    init(store: DashboardViewStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel("Jarz")
                        .padding(.top, 20)

                    if let food = store.viewModel.foodCard {
                        NavigationLink(value: foodCategoryId) {
                            heroSection(food)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(LongPressGesture(minimumDuration: 0.35).onEnded { _ in
                            quickExpenseTarget = QuickExpenseTarget(id: foodCategoryId, name: food.name)
                        })
                    }

                    SectionLabel("Jars")
                        .padding(.top, 44)
                        .padding(.bottom, 4)

                    ForEach(store.viewModel.rows) { row in
                        NavigationLink(value: row.id) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(row.name)
                                    .font(.system(size: 17))
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                AmountText(text: row.balanceText,
                                           color: row.isNegative ? Theme.negative : Theme.ink)
                            }
                            .padding(.vertical, 17)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(LongPressGesture(minimumDuration: 0.35).onEnded { _ in
                            quickExpenseTarget = QuickExpenseTarget(id: row.id, name: row.name)
                        })
                        Hairline()
                    }

                    HStack(alignment: .firstTextBaseline) {
                        SectionLabel("Total planned")
                        Spacer()
                        AmountText(text: store.viewModel.totalText, size: 20)
                    }
                    .padding(.top, 28)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
            .background(Theme.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { categoryId in
                CategoryDetailConfigurator.makeView(categoryId: categoryId)
            }
            .sheet(item: $quickExpenseTarget) { target in
                QuickExpenseSheet(
                    target: target,
                    onSave: { amount, note in
                        store.interactor?.addExpense(request: .init(
                            categoryId: target.id, amount: amount, note: note))
                        quickExpenseTarget = nil
                    },
                    onCancel: { quickExpenseTarget = nil }
                )
            }
            .onAppear {
                #if DEBUG
                // Screenshot hook: `-DemoFood carry|over|topup` builds a food
                // scenario through the real storage path.
                if let scenario = UserDefaults.standard.string(forKey: "DemoFood") {
                    seedFoodScenario(scenario)
                }
                // Screenshot hook: `-QuickExpense 1` opens the quick sheet for food.
                if UserDefaults.standard.bool(forKey: "QuickExpense") {
                    let id = foodCategoryId
                    let name = StorageWorker.shared.category(id: id)?.name ?? "Food"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        quickExpenseTarget = QuickExpenseTarget(id: id, name: name)
                    }
                }
                #endif
                store.interactor?.load(request: .init())
            }
            .onReceive(NotificationCenter.default.publisher(for: StorageWorker.stateDidChange)) { _ in
                store.interactor?.load(request: .init())
            }
        }
        .tint(Theme.ink)
    }

    // The food card links to the food category's detail screen. The id is not
    // part of the view model rows, so resolve it from settings directly.
    private var foodCategoryId: UUID {
        StorageWorker.shared.settings().foodCategoryId ?? UUID()
    }

    #if DEBUG
    private func seedFoodScenario(_ scenario: String) {
        let worker = StorageWorker.shared
        var settings = worker.settings()
        guard let foodId = settings.foodCategoryId else { return }
        for t in worker.transactions(categoryId: foodId) {
            worker.deleteTransaction(id: t.id)
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        settings.dailyFoodAmount = 1000
        switch scenario {
        case "carry": // income yesterday, underspent yesterday → today 1000 + 350
            worker.addTransaction(categoryId: foodId, kind: .allocation, amount: 30000, note: "Income", date: yesterday)
            worker.addTransaction(categoryId: foodId, kind: .expense, amount: 650, note: "Groceries", date: yesterday)
            settings.foodPlanEnd = calendar.date(byAdding: .day, value: 29, to: yesterday)
        case "over": // income today, blew 3500 today → money resumes in 3 days
            worker.addTransaction(categoryId: foodId, kind: .allocation, amount: 30000, note: "Income", date: today)
            worker.addTransaction(categoryId: foodId, kind: .expense, amount: 3500, note: "Feast", date: today)
            settings.foodPlanEnd = calendar.date(byAdding: .day, value: 29, to: today)
        case "topup": // money in lands on today, plan end untouched
            worker.addTransaction(categoryId: foodId, kind: .allocation, amount: 30000, note: "Income", date: today)
            worker.addTransaction(categoryId: foodId, kind: .topUp, amount: 2000, note: "Cashback", date: today)
            settings.foodPlanEnd = calendar.date(byAdding: .day, value: 29, to: today)
        default:
            break
        }
        worker.saveSettings(settings)
    }
    #endif

    private func heroSection(_ food: Dashboard.Load.ViewModel.FoodCard) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(food.name)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.ink)
                Spacer()
                AmountText(text: food.balanceText, color: Theme.secondary)
            }
            .padding(.top, 40)

            Text(food.heroText)
                .font(Theme.serif(84, .regular))
                .foregroundStyle(food.isNegative ? Theme.negative : Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .padding(.top, 6)

            (Text(food.heroCaption)
                .foregroundColor(food.isNegative ? Theme.negative : Theme.secondary)
             + Text(food.heroCaptionDay)
                .foregroundColor(food.isDayAhead ? Theme.negative : Theme.secondary))
                .font(.system(size: 16))
                .padding(.bottom, 20)

            if !food.isNegative {
                ProgressLine(progress: food.dayProgress)
                Text(food.daysText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 12)
            }
        }
        .contentShape(Rectangle())
    }
}
