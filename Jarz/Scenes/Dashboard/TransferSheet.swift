import SwiftUI

/// Move money between jars: source, target, amount — one operation,
/// a paired record lands in both histories.
struct TransferSheet: View {
    struct JarOption: Identifiable, Hashable {
        let id: UUID
        let name: String
    }

    let jars: [JarOption]
    /// When set, the source jar is fixed (transfer opened from a category screen).
    var fixedFrom: JarOption?
    let onSave: (UUID, UUID, Decimal) -> Void
    let onCancel: () -> Void

    @State private var fromId: UUID?
    @State private var toId: UUID?
    @State private var amountText = ""
    @FocusState private var amountFocused: Bool

    private var canSave: Bool {
        guard let fromId, let toId, fromId != toId,
              let amount = MoneyFormat.parse(amountText), amount > 0 else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                HStack {
                    SectionLabel("From")
                    Spacer()
                    if let fixedFrom {
                        Text(fixedFrom.name)
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.ink)
                    } else {
                        jarPicker(selection: $fromId)
                    }
                }
                Hairline()
                HStack {
                    SectionLabel("To")
                    Spacer()
                    jarPicker(selection: $toId)
                }
                Hairline()

                VStack(spacing: 10) {
                    TextField("0", text: $amountText)
                        .font(Theme.serif(52, .regular))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.ink)
                        .focused($amountFocused)
                    Hairline()
                }
                .padding(.top, 8)

                AmountChips { value in
                    let current = MoneyFormat.parse(amountText) ?? 0
                    amountText = "\(NSDecimalNumber(decimal: current + value))"
                }

                Spacer()
            }
            .padding(28)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Transfer between jars")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(Theme.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let fromId, let toId, let amount = MoneyFormat.parse(amountText) {
                            onSave(fromId, toId, amount)
                            Haptics.success()
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.ink)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if let fixedFrom {
                    fromId = fixedFrom.id
                    if toId == nil { toId = jars.first(where: { $0.id != fixedFrom.id })?.id }
                } else {
                    if fromId == nil { fromId = jars.first?.id }
                    if toId == nil { toId = jars.dropFirst().first?.id }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func jarPicker(selection: Binding<UUID?>) -> some View {
        Picker("", selection: selection) {
            ForEach(jars) { jar in
                Text(jar.name).tag(UUID?.some(jar.id))
            }
        }
        .pickerStyle(.menu)
        .tint(Theme.ink)
    }
}
