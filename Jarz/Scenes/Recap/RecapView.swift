import SwiftUI

protocol RecapDisplayLogic: AnyObject {
    func displayRecap(viewModel: Recap.Load.ViewModel)
}

final class RecapViewStore: ObservableObject, RecapDisplayLogic {
    @Published var viewModel: Recap.Load.ViewModel = .empty
    var interactor: RecapBusinessLogic?

    func displayRecap(viewModel: Recap.Load.ViewModel) {
        self.viewModel = viewModel
    }
}

enum RecapConfigurator {
    static func makeView() -> RecapView {
        let store = RecapViewStore()
        let presenter = RecapPresenter()
        presenter.view = store
        store.interactor = RecapInteractor(presenter: presenter)
        return RecapView(store: store)
    }
}

/// Plan vs reality for the current period (since the last income day).
struct RecapView: View {
    @StateObject private var store: RecapViewStore

    init(store: RecapViewStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel("Period recap")
                    .padding(.top, 20)

                if store.viewModel.isEmpty {
                    Text("No income recorded yet — the recap starts with your first payday.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.secondary)
                        .padding(.top, 16)
                } else {
                    Text(store.viewModel.totalSpentText)
                        .font(Theme.serif(56, .regular))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .padding(.top, 12)
                    (Text("spent ") + Text(store.viewModel.periodText))
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.secondary)
                        .padding(.top, 4)

                    if let foodLine = store.viewModel.foodLine {
                        Text(foodLine)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.accent)
                            .padding(.top, 20)
                    }
                    if let topLine = store.viewModel.topSpendingLine {
                        Text(topLine)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.secondary)
                            .padding(.top, 6)
                    }

                    HStack {
                        SectionLabel("Jars")
                        Spacer()
                        Text("spent / added")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.secondary)
                    }
                    .padding(.top, 36)
                    .padding(.bottom, 4)

                    ForEach(store.viewModel.rows) { row in
                        HStack(alignment: .firstTextBaseline) {
                            Text(row.name)
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            AmountText(text: row.amountsText, size: 15,
                                       color: row.isOver ? Theme.negative : Theme.ink)
                        }
                        .padding(.vertical, 14)
                        Hairline()
                    }

                    if !store.viewModel.pastRows.isEmpty {
                        SectionLabel("Past periods")
                            .padding(.top, 40)
                            .padding(.bottom, 4)

                        ForEach(store.viewModel.pastRows) { period in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(period.rangeText)
                                        .font(.system(size: 15))
                                        .foregroundStyle(Theme.ink)
                                    Spacer()
                                    AmountText(text: period.amountsText, size: 14,
                                               color: Theme.secondary)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Rectangle().fill(Theme.hairline)
                                        Rectangle().fill(Theme.accent)
                                            .frame(width: geo.size.width * period.barValue)
                                    }
                                }
                                .frame(height: 3)
                            }
                            .padding(.vertical, 12)
                            Hairline()
                        }
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.interactor?.load(request: .init()) }
    }
}
