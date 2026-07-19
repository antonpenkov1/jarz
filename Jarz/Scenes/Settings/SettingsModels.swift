import Foundation

enum Settings {
    enum Load {
        struct Request {}

        struct Response {
            let settings: AppSettings
            let categories: [BudgetCategory]
        }

        struct ViewModel {
            struct CategoryForm: Identifiable, Equatable {
                let id: UUID
                var name: String
            }
            let currencySymbol: String
            let dailyFoodText: String
            let apartmentText: String
            let billsText: String
            let foodCategoryId: UUID?
            let apartmentCategoryId: UUID?
            let billsCategoryId: UUID?
            let categories: [CategoryForm]
        }
    }

    enum SaveSettings {
        struct Request {
            let currencySymbol: String
            let dailyFoodText: String
            let apartmentText: String
            let billsText: String
            let foodCategoryId: UUID?
            let apartmentCategoryId: UUID?
            let billsCategoryId: UUID?
        }
    }

    enum AddCategory {
        struct Request { let name: String }
    }

    enum RenameCategory {
        struct Request { let id: UUID; let name: String }
    }

    enum DeleteCategory {
        struct Request { let id: UUID }
    }

    enum MoveCategory {
        struct Request { let from: IndexSet; let to: Int }
    }
}
