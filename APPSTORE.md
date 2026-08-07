# Jarz — App Store submission kit

## Listing metadata (paste into App Store Connect)

**Name:** Jarz — Salary Planner
**Subtitle (30 chars max):** Plan your money into jars
**Category:** Finance
**Price:** Free

**Promotional text (170 chars max):**
Stop tracking, start planning. Split every paycheck into jars and always know what you can afford — down to your food budget for the day.

**Description:**

Jarz is a money *planner*, not an expense tracker.

Every payday you split your salary into jars — Food, Rent, Bills, Gifts, Savings, whatever fits your life. Every purchase comes out of its jar, so at any moment you see exactly what you can still afford. No banks, no accounts, no sync — just your plan.

WHY JARZ IS DIFFERENT
• A daily food budget: set how much you want to spend on food per day, and Jarz sets aside 31 days' worth on payday. After each purchase you see what's left for today — and how many full days are covered ahead.
• Fixed costs on autopilot: rent and bills are pre-filled automatically when your salary arrives.
• Honest balances: overspend a jar and it simply goes red. Your money, your call.
• Revision mode: count what's really on your cards and in cash, compare with the plan, and zero out the difference.
• Fully editable jars: rename, add, remove, reorder. Leftovers carry over — new salary just stacks on top.
• Your data stays on your phone. No account, no cloud, no tracking, no ads.

Built for people who plan their money forward instead of wondering where it went.

**Keywords (100 chars max):**
budget,envelope,salary,planner,jars,money,paycheck,spending,daily,cash,plan,finance

**Support URL:** https://github.com/antonpenkov1/jarz
**Privacy Policy URL:** https://antonpenkov1.github.io/jarz/privacy.html

## Privacy

App Privacy answers in App Store Connect: **Data Not Collected** (everything is stored locally, no analytics, no network calls).

Privacy policy page lives in `docs/privacy.html`, published at https://antonpenkov1.github.io/jarz/privacy.html via GitHub Pages.

## Review information

- Age rating: 4+ (no objectionable content)
- Export compliance: `ITSAppUsesNonExemptEncryption = NO` is already set in the project — no question at upload.
- Demo account: not needed (no login).

## Submission checklist

1. ✅ **Apple Developer Program** — оплачен (2026-07-25).
2. **Xcode → Settings → Accounts** — войти своим Apple ID; убедиться, что видна платная команда (без пометки «Personal Team»). Team ID можно посмотреть на developer.apple.com/account → Membership details.
3. В проекте: Signing & Capabilities → Team = платная команда, Automatically manage signing. (Bundle id `com.antonpenkov.jarz` зарегистрируется сам.) Постоянно: прописать `DEVELOPMENT_TEAM: <TeamID>` в project.yml, чтобы переживало `xcodegen generate`.
4. **App Store Connect** (appstoreconnect.apple.com) → My Apps → «+» → New App: платформа iOS, имя Jarz — Salary Planner, bundle id из списка, SKU например `jarz-001`.
5. Заполнить метаданные из этого файла + Privacy (Data Not Collected) + возрастной рейтинг (4+).
6. ✅ **Скриншоты** — сняты, лежат в `AppStore/screenshots/` (iPhone 15 Pro Max, 1290×2796): home, income, revision (с историей), settings.
7. В Xcode: выбрать destination **Any iOS Device (arm64)** → Product → **Archive** → Organizer → **Distribute App** → App Store Connect → Upload.
8. В App Store Connect: выбрать загруженный билд, отправить на ревью. Первое ревью обычно 1–3 дня.

## 1.1 (2026-08-07)

- iCloud-синхронизация ВКЛЮЧЕНА (private CloudKit DB; App Privacy остаётся «Data Not Collected» — данные в личном iCloud пользователя, разработчику недоступны).
- В описании на стор заменить пункт «Your data stays on your phone. No account, no cloud…» на:
  «Your data stays yours: stored on your phone and synced through your private iCloud — invisible to anyone else. No account, no tracking, no ads.»
- Локализации UI: ru, sr-Latn, es, it, fr, de (Localizable.xcstrings). Метаданные стора можно локализовать в ASC отдельно.
- What's New 1.1 (final, build 3):
  • Sync across your devices through your private iCloud.
  • Home screen widget: your food budget for today, always in sight.
  • Jarz now speaks Russian, Serbian, Spanish, Italian, French and German.
  • First-launch walkthrough: see how Jarz works in four short steps.
  • Add expenses faster: long-press any jar, or tap the +100/+500/+1000 chips.
  • Zero out a revision in one tap: book the difference straight into a jar.
  • Back up and restore: export your data and import it anywhere.
  • Pick your app icon, undo accidental deletes, and feel a gentle tap on every save.

## Assets

- App icon source: `IconDrafts/variant-b-night-jar.svg` (правки → перерендер: `rsvg-convert -w 1024 -h 1024 in.svg -o out.png`, затем убрать альфа-канал через sips как в AppIcon.png).
- Остальные варианты иконок сохранены в `IconDrafts/` на будущее.
