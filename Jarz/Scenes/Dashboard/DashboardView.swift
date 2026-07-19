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
                        }
                        .buttonStyle(.plain)
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
            .onAppear { store.interactor?.load(request: .init()) }
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
    }
}
