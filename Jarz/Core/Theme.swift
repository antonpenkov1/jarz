import SwiftUI

/// Boutique-minimal design system: warm paper background, ink text,
/// serif numerals, hairline separators, a single green accent.
/// Every color has a light (paper) and dark (night) variant; UIColor
/// dynamic providers keep UIKit appearance APIs (tab bar) dynamic too.
enum Theme {
    static let bgUI = dynamicUI(light: (0.970, 0.965, 0.948), dark: (0.082, 0.080, 0.074))
    static let inkUI = dynamicUI(light: (0.090, 0.088, 0.080), dark: (0.925, 0.915, 0.885))
    static let hairlineUI = dynamicUI(light: (0.862, 0.850, 0.812), dark: (0.205, 0.200, 0.185))

    static let bg = Color(bgUI)
    static let ink = Color(inkUI)
    static let hairline = Color(hairlineUI)
    static let secondary = Color(dynamicUI(light: (0.52, 0.51, 0.47), dark: (0.60, 0.59, 0.55)))
    static let accent = Color(dynamicUI(light: (0.10, 0.42, 0.30), dark: (0.38, 0.66, 0.51)))
    static let negative = Color(dynamicUI(light: (0.72, 0.22, 0.20), dark: (0.87, 0.45, 0.42)))

    static func serif(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    private static func dynamicUI(
        light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)
    ) -> UIColor {
        UIColor { trait in
            let rgb = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        }
    }
}

/// App-wide appearance preference, applied in RootView and picked in Settings.
enum AppearanceMode: String, CaseIterable {
    case system, light, dark

    static let storageKey = "appearance"

    var uiStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// Overrides the trait on the app's windows. More reliable than
    /// `preferredColorScheme`, which never resets back to system (nil).
    func apply() {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { $0.overrideUserInterfaceStyle = uiStyle }
    }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
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

/// Tracks software-keyboard visibility. Used instead of the native keyboard
/// toolbar (`ToolbarItemGroup(placement: .keyboard)`), which unreliably
/// disappears inside a TabView.
private final class KeyboardObserver: ObservableObject {
    @Published var isVisible = false
    private var tokens: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        tokens.append(center.addObserver(
            forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.isVisible = true })
        tokens.append(center.addObserver(
            forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.isVisible = false })
    }

    deinit { tokens.forEach(NotificationCenter.default.removeObserver) }
}

private struct KeyboardDoneBar: ViewModifier {
    @StateObject private var keyboard = KeyboardObserver()

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            if keyboard.isVisible {
                HStack {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Theme.bg)
                .overlay(alignment: .top) { Hairline() }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: keyboard.isVisible)
    }
}

extension View {
    /// "Done" bar pinned above the keyboard; attach once per screen that has text fields.
    func keyboardDoneButton() -> some View {
        modifier(KeyboardDoneBar())
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
