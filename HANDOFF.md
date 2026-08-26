# Jarz — handoff для агента

Контекст для продолжения работы над проектом в новом чате. Актуально на 2026-08-08.

## Что это

**Jarz** — личное iOS-приложение Антона (антон = владелец, русскоязычный, живёт в Сербии → валюта по умолчанию RSD): планировщик денег по методу конвертов. Философия: **планировать вперёд, а не трекать назад**. В день зарплаты деньги раскладываются по «копилкам» (jars), каждая трата списывается из своей копилки.

- Репозиторий: https://github.com/antonpenkov1/jarz (public, аккаунт `antonpenkov1`; `.xcodeproj` в gitignore — генерируется `xcodegen generate`)
- App Store: **опубликовано**, первое приложение Антона (1.0 вышла ~2026-08-05)
- Bundle id `com.antonpenkov.jarz`, виджет `com.antonpenkov.jarz.widget`
- Team ID `3UHRLQ9522` (платный Apple Developer, прописан в project.yml)
- Privacy policy: https://antonpenkov1.github.io/jarz/privacy.html (исходник в `docs/`)
- App Privacy в ASC: **Data Not Collected** (данные локально + личный iCloud пользователя — так и оставлять)

## Хронология версий

| Версия | Статус | Содержимое |
|---|---|---|
| 1.0 | вышла | базовое приложение (4 таба: Home, Income, Revision, Settings) |
| 1.0.1 | вышла | календарный план еды, цвета разницы ревизии, полные зоны тапа |
| 1.0.2 | вышла (как часть 1.1?) | онбординг 5 страниц, быстрая трата long-press + чипы |
| 1.1 | сабмичена (статус уточнить у Антона) | iCloud sync, виджет, 6 локализаций, zero-out ревизии, export/import, undo, хаптика, 3 иконки, Face-value полировка |
| 1.2 | **готова, НЕ загружена** — архив «Jarz 1.2 b2» в Organizer | переносы, цели копилок, недельная полоска в еде, рекап периода, Face ID, локальные уведомления, **критичная миграция store** |

**⚠️ Критично:** app group entitlement (добавлен в 1.1 для виджета) заставил SwiftData молча перенести дефолтный store в групповой контейнер → у пользователей 1.0.x после обновления на 1.1 данные «пропадают» (лежат по старому пути). Фикс — `migrateStoreToAppGroupIfNeeded()` в StorageWorker — уехал в 1.2. **1.2 надо выпустить как можно скорее.** What's New для ASC — в `APPSTORE.md`, секция 1.2.

## Архитектура и конвенции

- **SwiftUI + Clean Swift (VIP)**: каждая сцена = Models (Request/Response/ViewModel) + Interactor + Presenter + ViewStore (ObservableObject, `displayX`) + View; собирается `XConfigurator.makeView()`. Сцены: Dashboard, Income, Reconciliation (Revision), Settings, CategoryDetail, Recap, Onboarding (без VIP — статика).
- **Хранилище**: SwiftData (`Core/StorageWorker.swift`, синглтон) — модели `JarCategory` (+goalAmount/goalDate), `JarTransaction` (kind: allocation/expense/topUp/transferIn/transferOut), `JarSettings` (в т.ч. `foodPlanEnd`), `JarAccount`, `JarRevision`. CloudKit-правила: у всех атрибутов дефолты, без unique. DTO из `Core/Models.swift` — единственный интерфейс между worker и интеракторами. Store лежит в **app group** `group.com.antonpenkov.jarz`; каждый `save()` постит `stateDidChange`, пишет снапшот виджета (`WidgetShared`) и перепланирует уведомления (`Reminders.reschedule`).
- **iCloud**: `iCloudSyncEnabled = true` в StorageWorker + entitlements (CloudKit private DB); без аккаунта тихо падает в локальный store. Тумблера в приложении нет — управляется iOS; в Settings есть строка статуса On/Off.
- **Математика еды** (`FoodMath` в Core/Models.swift) — КЛЮЧЕВОЕ доменное решение (2026-08-05): план **привязан к календарю**. Income в еду фиксирует `foodPlanEnd` (= сегодня + floor(баланс/дневная норма) − 1). Доступно сегодня = `баланс − норма × дней_после_сегодня`. Остатки переезжают на завтра (1000+350=1350), перетрата «съедает» конкретные будущие дни (показывается красной датой возврата), Money in падает на сегодня, дата конца не двигается до следующего income. `FoodMath.plan`, `FoodMath.weekAhead` (недельная полоска), `FoodDay.phrase`.
- **Дизайн-система** `Core/Theme.swift`: «бутик-минимализм» — бумажный фон, чернила, serif-цифры (system serif), волосяные линии, один зелёный акцент. Все цвета — динамические UIColor (светлая+тёмная темы). Компоненты: SectionLabel (uppercase tracking), Hairline, AmountText, CapsuleButton, ProgressLine, AmountChips (+100/+500/+1000, добавляют), UndoToast, ShareSheet, Haptics. Тема приложения: System/Light/Dark через `overrideUserInterfaceStyle` на окнах (НЕ preferredColorScheme — он не сбрасывается, известный баг).
- **Локализация**: en + ru, sr-Latn, es, it, fr, de. `Jarz/Localizable.xcstrings` (162 ключа) **генерируется** скриптом — актуальная копия структуры в /tmp/gen_xcstrings.py может не существовать; при добавлении строк проще редактировать xcstrings напрямую или пересоздать генератор. Правила: динамические строки в презентерах через `String(localized:)`; компоненты с параметрами-строками — `LocalizedStringKey(text)`; `Text(условие ? "A" : "B")` НЕ локализуется — использовать тернарник из Text(); «jars» = Копилки/Tegle/Tarros/Barattoli/Bocaux/Töpfe. Плюралы через variations (ru: one/few/many/other).
- **Виджет** `JarzWidget/` (small+medium): читает JSON-снапшот из app group, сам пересчитывает FoodMath на каждую полночь (7 entries). Своя копия цветов WTheme — НЕ включать app'овский Theme.swift в таргет виджета (там extension-unavailable API). CFBundleVersion виджета должен совпадать с приложением (прописано `$(CURRENT_PROJECT_VERSION)` в project.yml → info.properties).
- **Известные ловушки SwiftUI**, уже съеденные: keyboard-тулбар в TabView пропадает (сделан свой `keyboardDoneButton()` через safeAreaInset + нотификации клавиатуры); `.buttonStyle(.plain)` не ловит тапы по пустоте (нужен `.contentShape(Rectangle())`); гигантские body валят тайпчекер (разбивать на computed props); SettingsView уже разбит (settingsList/behavioralList/decoratedList).

## Сборка и инструменты

```sh
# проект
xcodegen generate
xcodebuild -project Jarz.xcodeproj -scheme Jarz -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
# архив для App Store (кладётся в Organizer)
xcodebuild -project Jarz.xcodeproj -scheme Jarz -destination 'generic/platform=iOS' archive \
  -archivePath ~/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)/"Jarz X.Y.xcarchive" -allowProvisioningUpdates
```
Загрузка в ASC — руками Антона: Xcode → Organizer → Distribute App → Upload. Версии в `project.yml` (MARKETING_VERSION/CURRENT_PROJECT_VERSION в ОБОИХ таргетах).

Симулятор: iPhone 17 Pro `7B4BBA74-57BB-42D9-98D7-7E68D0C272E0` (UDID может смениться после обновления Xcode — смотреть `xcrun simctl list devices available`). Скриншоты: `xcrun simctl io <UDID> screenshot f.png`. Тапать по симулятору нельзя (нет assistive access) — для проверки экранов используются **DEBUG launch-хуки** (вырезаются из release):

- `-OpenTab N` (0..3) — открыть таб; `-OpenFood 1`, `-OpenRecap 1`, `-OpenTransfer 1`, `-QuickExpense 1`
- `-DemoFood carry|over|topup|showcase` — сценарии еды; showcase = полные копилки + цели (для маркетинга)
- `-DemoIncome 1` — заполнить форму дохода; `-DemoRevision 1` — демо-ревизия; `-FocusSalary 1`
- `-OnboardingPage N`, `-hasSeenOnboarding 0`, `-appearance dark`, `-DemoAppearanceCycle 1`
- Русский UI: `-AppleLanguages "(ru)"`

## App Store ассеты

- `APPSTORE.md` — метаданные, чеклист сабмита, What's New по версиям (блоки в ``` — копипаст в ASC как есть).
- `AppStore/marketing/` — 6 рекламных постеров 1284×2778 (бумажный фон + New York serif заголовок + телефон в рамке): home, food, recap, transfer, income, revision. Порядок в ASC: первые три видны на установочном листе. Генератор `AppStore/make_marketing.py` (Pillow; сырые скрины кладутся в /tmp/jarz-raw/).
- `AppStore/screenshots*` — старые «голые» скрины (заменены постерами).
- Иконки: `IconDrafts/`, в ассетах 3 appiconset (AppIcon=Ink, AppIconPaper, AppIconJar) + превью-имиджсеты.

## Стиль работы с Антоном

- Общение по-русски; коммиты/код/сторовые тексты по-английски.
- Он проверяет на своём устройстве через Xcode; агент проверяет на симуляторе скриншотами через DEBUG-хуки, каждую фичу — визуально.
- Коммитить и пушить после каждой законченной фичи (он это ожидает). Формат коммитов: краткий императив + подробности, без трейлеров и упоминаний ассистента.
- ASC-действия (загрузка билда, заполнение полей) делает сам — давать точные пошаговые инструкции.

## Открытые хвосты / идеи на будущее

1. **Выпустить 1.2** (архив «Jarz 1.2 b2» готов) — из-за миграции store это срочно, если 1.1 в проде.
2. Идеи на 1.3 (обсуждены, одобрены как направление): **интерактивный виджет + Siri/App Shortcuts** (AppIntents, кнопки −100/−500 на виджете, локскрин-виджет), локализованные метаданные стора (6 языков), видео-превью для ASC, Featuring Nomination в ASC.
3. Меньшее: время уведомлений сейчас фиксированное (9:00/21:00) — можно дать пикеры; редактирование транзакций-переносов запрещено (пара разъедется) — можно сделать парное редактирование.
4. NoRep (второй проект, WOD-таймер, отдельное приложение в соседней папке) — свой бэклог: скриншоты обновить, Watch, монетизация. Не смешивать с Jarz.
