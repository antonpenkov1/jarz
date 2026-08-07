import SwiftUI

/// First-launch walkthrough: what Jarz is, how to set it up, how to live with
/// it. Static content — no interactor/presenter needed. Re-openable from
/// Settings ("How Jarz works").
struct OnboardingView: View {
    let onDone: () -> Void
    @State private var page = OnboardingView.initialPage
    private static let pageCount = 5

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                SectionLabel("Jarz")
                Spacer()
                if page < Self.pageCount - 1 {
                    Button("Skip") { onDone() }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.secondary)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)

            TabView(selection: $page) {
                welcomePage.tag(0)
                setupPage.tag(1)
                paydayPage.tag(2)
                everyDayPage.tag(3)
                revisionPage.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeOut(duration: 0.25), value: page)

            HStack(spacing: 8) {
                ForEach(0..<Self.pageCount, id: \.self) { index in
                    Circle()
                        .fill(index == page ? Theme.ink : Theme.hairline)
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.top, 8)

            CapsuleButton(title: page == Self.pageCount - 1 ? "Start planning" : "Next") {
                if page < Self.pageCount - 1 {
                    page += 1
                } else {
                    onDone()
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    // MARK: Pages

    private var welcomePage: some View {
        pageView(
            step: "Welcome",
            title: "Plan your money into jars",
            text: "Jarz is a planner, not an expense tracker. Every payday you split your salary into jars — Food, Rent, Savings, whatever fits your life. Every purchase comes out of its jar, so you always know what you can still afford."
        ) {
            VStack(spacing: 0) {
                jarRow("Food", "31 000 RSD")
                jarRow("Apartment", "40 000 RSD")
                jarRow("Savings", "12 000 RSD")
            }
        }
    }

    private var setupPage: some View {
        pageView(
            step: "Step 1 · Set up",
            title: "Tell Jarz your fixed life",
            text: "In Settings, choose your daily food budget and your monthly rent and bills. Jarz will pre-fill them automatically every payday — you only decide about the rest."
        ) {
            VStack(spacing: 0) {
                jarRow("Food, per day", "1 000")
                jarRow("Apartment, per month", "40 000")
                jarRow("Bills, per month", "8 000")
            }
        }
    }

    private var paydayPage: some View {
        pageView(
            step: "Step 2 · Payday",
            title: "Split your salary",
            text: "Got paid? Open Income, enter the amount and distribute it. Fixed costs are already filled in. Leftovers in jars carry over — new money just stacks on top."
        ) {
            VStack(spacing: 0) {
                jarRow("Food", "31 000", hint: "auto: 1 000 × 31 days")
                jarRow("Apartment", "40 000", hint: "auto: monthly fixed")
                jarRow("Gifts", "3 000")
            }
        }
    }

    private var everyDayPage: some View {
        pageView(
            step: "Step 3 · Every day",
            title: "Food lives day by day",
            text: "Your food money is laid out over real calendar days. Don't spend today's budget — tomorrow gets more. Overspend — Jarz shows the exact day your budget comes back, in red."
        ) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Food")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    AmountText(text: "28 300 RSD", size: 15, color: Theme.secondary)
                }
                Text("1 350")
                    .font(Theme.serif(54, .regular))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 2)
                (Text("RSD left for ").foregroundColor(Theme.secondary)
                 + Text("today, 7 Aug").foregroundColor(Theme.secondary))
                    .font(.system(size: 14))
                    .padding(.bottom, 12)
                ProgressLine(progress: 0.35)
                Text("+28 days · until 4 Sep")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 10)
            }
        }
    }

    private var revisionPage: some View {
        pageView(
            step: "Step 4 · Revision",
            title: "Stay honest",
            text: "Once in a while, count the real money on your cards and in cash. Jarz compares it with the plan — record what slipped through and start the week clean."
        ) {
            VStack(spacing: 0) {
                jarRow("Planned in app", "142 800 RSD")
                jarRow("Counted for real", "145 300 RSD")
                HStack(alignment: .firstTextBaseline) {
                    Text("Difference")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    AmountText(text: "+2 500 RSD", size: 16, color: Theme.accent)
                }
                .padding(.vertical, 12)
                Hairline()
            }
        }
    }

    // MARK: Building blocks

    private func pageView(
        step: String, title: String, text: String,
        @ViewBuilder illustration: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(step)
                .padding(.top, 36)
            Text(LocalizedStringKey(title))
                .font(Theme.serif(34, .medium))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
            Text(LocalizedStringKey(text))
                .font(.system(size: 16))
                .foregroundStyle(Theme.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
            Spacer(minLength: 24)
            illustration()
            Spacer(minLength: 36)
        }
        .padding(.horizontal, 28)
    }

    private func jarRow(_ name: String, _ amount: String, hint: String? = nil) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey(name))
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.ink)
                    if let hint {
                        Text(LocalizedStringKey(hint))
                            .textCase(.uppercase)
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(Theme.accent)
                    }
                }
                Spacer()
                AmountText(text: amount, size: 16)
            }
            .padding(.vertical, 12)
            Hairline()
        }
    }

    /// DEBUG-only screenshot hook: launch with `-OnboardingPage 2`.
    private static var initialPage: Int {
        #if DEBUG
        if let value = UserDefaults.standard.string(forKey: "OnboardingPage"), let page = Int(value) {
            return min(max(page, 0), pageCount - 1)
        }
        #endif
        return 0
    }
}
