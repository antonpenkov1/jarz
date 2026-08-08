import SwiftUI
import LocalAuthentication

enum AppLock {
    static let storageKey = "appLockEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: storageKey)
    }

    static func authenticate(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        // Face ID / Touch ID with the device passcode as fallback.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            completion(true) // no protection available — don't lock the user out
            return
        }
        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: String(localized: "Unlock your budget")
        ) { success, _ in
            DispatchQueue.main.async { completion(success) }
        }
    }
}

/// Paper-and-ink lock screen shown over the app until Face ID passes.
struct LockScreenView: View {
    let onUnlock: () -> Void
    @State private var attempted = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            SectionLabel("Jarz")
            Text("Locked")
                .font(Theme.serif(44, .regular))
                .foregroundStyle(Theme.ink)
                .padding(.top, 10)
            Spacer()
            CapsuleButton(title: "Unlock") {
                tryUnlock()
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg.ignoresSafeArea())
        .onAppear {
            guard !attempted else { return }
            attempted = true
            tryUnlock()
        }
    }

    private func tryUnlock() {
        AppLock.authenticate { success in
            if success { onUnlock() }
        }
    }
}
