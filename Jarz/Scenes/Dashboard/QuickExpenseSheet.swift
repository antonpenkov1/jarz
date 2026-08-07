import SwiftUI

struct QuickExpenseTarget: Identifiable {
    let id: UUID
    let name: String
}

/// Long-press on a jar row opens this: amount, optional note, save.
/// Two taps fewer than going through the category screen.
struct QuickExpenseSheet: View {
    let target: QuickExpenseTarget
    let onSave: (Decimal, String) -> Void
    let onCancel: () -> Void

    @State private var amountText = ""
    @State private var note = ""
    @FocusState private var amountFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    TextField("0", text: $amountText)
                        .font(Theme.serif(52, .regular))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.ink)
                        .focused($amountFocused)
                    Hairline()
                }

                AmountChips { value in
                    let current = MoneyFormat.parse(amountText) ?? 0
                    amountText = "\(NSDecimalNumber(decimal: current + value))"
                }

                TextField("Note (optional)", text: $note)
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(28)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Spend from \(target.name)")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(Theme.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let amount = MoneyFormat.parse(amountText), amount > 0 {
                            onSave(amount, note)
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.ink)
                    .disabled((MoneyFormat.parse(amountText) ?? 0) <= 0)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { amountFocused = true }
            }
        }
        .presentationDetents([.medium])
    }
}
