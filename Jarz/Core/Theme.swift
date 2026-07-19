import SwiftUI

/// Boutique-minimal design system: warm paper background, ink text,
/// serif numerals, hairline separators, a single green accent.
enum Theme {
    static let bg = Color(red: 0.970, green: 0.965, blue: 0.948)
    static let ink = Color(red: 0.090, green: 0.088, blue: 0.080)
    static let secondary = Color(red: 0.52, green: 0.51, blue: 0.47)
    static let hairline = Color(red: 0.862, green: 0.850, blue: 0.812)
    static let accent = Color(red: 0.10, green: 0.42, blue: 0.30)
    static let negative = Color(red: 0.72, green: 0.22, blue: 0.20)

    static func serif(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1)
    }
}

/// Small-caps tracked label used for section headers.
struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .tracking(2.4)
            .foregroundStyle(Theme.secondary)
    }
}

struct AmountText: View {
    let text: String
    var size: CGFloat = 17
    var color: Color = Theme.ink
    var body: some View {
        Text(text)
            .font(Theme.serif(size))
            .foregroundStyle(color)
    }
}

struct CapsuleButton: View {
    let title: String
    var disabled: Bool = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(Theme.ink))
        }
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
    }
}

extension View {
    /// "Done" above the keyboard; attach once per screen that has text fields.
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
            }
        }
    }
}

/// 2pt progress line used instead of a stock progress bar.
struct ProgressLine: View {
    let progress: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.hairline)
                Rectangle().fill(Theme.accent)
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 2)
    }
}
