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
            List {
                if let food = store.viewModel.foodCard {
                    Section {
                        NavigationLink(value: foodCategoryId) {
                            foodCard(food)
                        }
                    }
                }
                Section("Categories") {
                    ForEach(store.viewModel.rows) { row in
                        NavigationLink(value: row.id) {
                            HStack {
                                Text(row.name)
                                Spacer()
                                Text(row.balanceText)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(row.isNegative ? .red : .primary)
                            }
                        }
                    }
                }
                Section {
                    HStack {
                        Text("Total planned")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(store.viewModel.totalText)
                            .fontWeight(.bold)
                    }
                }
            }
            .navigationTitle("Jarz")
            .navigationDestination(for: UUID.self) { categoryId in
                CategoryDetailConfigurator.makeView(categoryId: categoryId)
            }
            .onAppear { store.interactor?.load(request: .init()) }
            .onReceive(NotificationCenter.default.publisher(for: StorageWorker.stateDidChange)) { _ in
                store.interactor?.load(request: .init())
            }
        }
    }

    // The food card links to the food category's detail screen. The id is not
    // part of the view model rows, so resolve it from settings directly.
    private var foodCategoryId: UUID {
        StorageWorker.shared.state.settings.foodCategoryId ?? UUID()
    }

    private func foodCard(_ food: Dashboard.Load.ViewModel.FoodCard) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(food.name)
                    .font(.headline)
                Spacer()
                Text(food.balanceText)
                    .font(.headline)
                    .foregroundStyle(food.isNegative ? .red : .primary)
            }
            Text(food.currentDayText)
                .font(.title3.weight(.semibold))
                .foregroundStyle(food.isNegative ? .red : .green)
            if !food.isNegative {
                ProgressView(value: food.dayProgress)
                    .tint(.green)
                Text(food.daysAheadText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
