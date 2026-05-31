@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - Wave5AsyncSnapshotTests
//
// Фаза E (волна 5): детерминированные snapshot-тесты для четырёх ранее
// SKIPPED-View, которые в Wave2/Wave3/Wave4 ловили async-`ProgressView`-спиннер:
//   • ComparisonDashboardView  (был SKIP в Wave2 — async charts load)
//   • AchievementWallView      (был SKIP в Wave2 — async wall load)
//   • CoPlayView               (был SKIP в Wave3 — async setupAndStart)
//   • KaraokePitchView         (был SKIP в Wave3 — async startSession / фаза Canvas)
//
// ПОДХОД (наименее инвазивный seam per-view):
//   Каждый из четырёх View получил DEBUG-only `init(... previewState:)`,
//   который (1) инжектит уже-загруженный holder/viewModel прямо в `@State`
//   через `State(initialValue:)` и (2) выставляет приватный
//   `skipBootstrapForSnapshot = true`, из-за которого `.task`-bootstrap
//   делает ранний `return` и НЕ перетирает инжектированное состояние
//   async-загрузкой. Прод-инициализаторы (`init()` / `init(childId:)`) не
//   затрагиваются — async-путь приложения работает как прежде. Весь seam под
//   `#if DEBUG`.
//
// Снимок ловит SETTLED-кадр с реальным контентом (графики / стена значков /
// брифинг / pitch-Canvas), а не `ProgressView`. Stub-данные фиксированы
// (без random/UUID-зависимой раскладки, влияющей на пиксели), поэтому кадр
// детерминирован между прогонами.
//
// Матрица: View × 2 темы (Light/Dark) × 2 устройства (iPhoneSE3 375×667,
// iPhone17Pro 402×874). PNG в __Snapshots__/Wave5Async/.
//
// Рендер-сетап идентичен Wave1–Wave4: UIHostingController + UIGraphicsImageRenderer
// (scale 2.0), reduceMotion=true (замораживает HSMeshGradient/symbolEffect),
// попиксельное сравнение через SnapshotTestHelper.
//
// Первый прогон ЗАПИСЫВАЕТ референсы (XCTFail «Записан новый референс») —
// это ожидаемо; второй прогон сравнивает и проходит зелёным.
// ==================================================================================

@MainActor
final class Wave5AsyncSnapshotTests: XCTestCase {

    // MARK: - Device matrix

    private struct DeviceConfig {
        let name: String
        let size: CGSize
    }

    private let devices: [DeviceConfig] = [
        DeviceConfig(name: "iPhoneSE3",   size: CGSize(width: 375, height: 667)),
        DeviceConfig(name: "iPhone17Pro", size: CGSize(width: 402, height: 874))
    ]

    private let appearances: [(String, UIUserInterfaceStyle)] = [
        ("Light", .light),
        ("Dark",  .dark)
    ]

    // MARK: - 1. ComparisonDashboardView (parent, charts)

    func test_comparisonDashboard_rendersInBothThemes() throws {
        let view = ComparisonDashboardView(previewState: Self.makeComparisonViewModel())
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "ComparisonDashboardView")
    }

    // MARK: - 2. AchievementWallView (kid, badge wall)

    func test_achievementWall_rendersInBothThemes() throws {
        let view = AchievementWallView(
            childId: "preview-child-1",
            previewState: Self.makeAchievementWallHolder()
        )
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        try record(view, screen: "AchievementWallView")
    }

    // MARK: - 3. CoPlayView (kid+adult, briefing)

    func test_coPlay_rendersInBothThemes() throws {
        let view = CoPlayView(
            childId: "preview-child-1",
            previewState: Self.makeCoPlayHolder()
        )
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        try record(view, screen: "CoPlayView")
    }

    // MARK: - 4. KaraokePitchView (kid, pitch-Canvas)

    func test_karaokePitch_rendersInBothThemes() throws {
        let view = KaraokePitchView(
            childId: "preview-child-1",
            previewState: Self.makeKaraokeHolder()
        )
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        try record(view, screen: "KaraokePitchView")
    }

    // MARK: - Stub builders (фиксированные, детерминированные)

    /// Два ребёнка с фиксированными временными рядами — graphs settled-кадр.
    private static func makeComparisonViewModel() -> ComparisonDashboardViewModel {
        let vm = ComparisonDashboardViewModel()
        vm.isLoading = false
        vm.children = [
            makeChildData(
                id: "c1",
                name: "Маша",
                successBase: 0.55,
                successStep: 0.04,
                accuracies: [("С", 0.82), ("Ш", 0.66), ("Р", 0.48), ("Л", 0.74)],
                minutesPattern: [8, 12, 6, 15, 10, 14, 9],
                streak: 12,
                totalMinutes: 184
            ),
            makeChildData(
                id: "c2",
                name: "Петя",
                successBase: 0.42,
                successStep: 0.05,
                accuracies: [("С", 0.70), ("Ш", 0.55), ("Р", 0.61), ("Л", 0.58)],
                minutesPattern: [5, 9, 11, 7, 13, 6, 12],
                streak: 7,
                totalMinutes: 142
            )
        ]
        return vm
    }

    private static func makeChildData(
        id: String,
        name: String,
        successBase: Double,
        successStep: Double,
        accuracies: [(String, Double)],
        minutesPattern: [Double],
        streak: Int,
        totalMinutes: Int
    ) -> ComparisonDashboard.ChildComparisonData {
        let weekly: [ComparisonDashboard.WeekPoint] = (1...7).map { week in
            ComparisonDashboard.WeekPoint(
                weekLabel: "Нед. \(week)",
                weekIndex: week,
                successRate: min(1.0, successBase + successStep * Double(week - 1))
            )
        }
        let sounds: [ComparisonDashboard.SoundPoint] = accuracies.map {
            ComparisonDashboard.SoundPoint(sound: $0.0, accuracy: $0.1)
        }
        let daily: [ComparisonDashboard.DayPoint] = minutesPattern.enumerated().map { idx, mins in
            ComparisonDashboard.DayPoint(
                dayLabel: "Д\(idx + 1)",
                dayIndex: idx + 1,
                minutes: mins
            )
        }
        return ComparisonDashboard.ChildComparisonData(
            id: id,
            name: name,
            colorTheme: "primary",
            avatarStyle: "fox",
            weeklySuccess: weekly,
            soundAccuracy: sounds,
            dailyPracticeMinutes: daily,
            currentStreak: streak,
            totalMinutes: totalMinutes
        )
    }

    /// 9 значков (микс unlocked/locked, все три rarity) — settled wall.
    private static func makeAchievementWallHolder() -> AchievementWallViewModelHolder {
        let holder = AchievementWallViewModelHolder()
        let cells: [AchievementWallCellViewModel] = [
            makeCell(id: "firstSoundMastered", title: "Первый звук", icon: "star.fill",
                     unlocked: true, rarity: .common),
            makeCell(id: "fiveSoundsMastered", title: "Пять звуков", icon: "star.circle.fill",
                     unlocked: true, rarity: .rare),
            makeCell(id: "allSoundsMastered", title: "Все звуки", icon: "crown.fill",
                     unlocked: false, rarity: .legendary),
            makeCell(id: "streak7Days", title: "7 дней подряд", icon: "flame.fill",
                     unlocked: true, rarity: .common),
            makeCell(id: "streak30Days", title: "30 дней", icon: "flame.circle.fill",
                     unlocked: false, rarity: .rare),
            makeCell(id: "streak100Days", title: "100 дней", icon: "trophy.fill",
                     unlocked: false, rarity: .legendary),
            makeCell(id: "played10Rounds", title: "10 игр", icon: "gamecontroller.fill",
                     unlocked: true, rarity: .common),
            makeCell(id: "played50Rounds", title: "50 игр", icon: "rosette",
                     unlocked: true, rarity: .rare),
            makeCell(id: "played100Rounds", title: "100 игр", icon: "medal.fill",
                     unlocked: false, rarity: .legendary)
        ]
        holder.loadVM = AchievementWallModels.LoadWall.ViewModel(
            heroTitle: "Стена Маши",
            heroSubtitle: "Открыто 5 из 9",
            cells: cells,
            accessibilitySummary: "Стена достижений Маши, открыто 5 из 9"
        )
        return holder
    }

    private static func makeCell(
        id: String,
        title: String,
        icon: String,
        unlocked: Bool,
        rarity: AchievementRarity
    ) -> AchievementWallCellViewModel {
        AchievementWallCellViewModel(
            id: id,
            title: title,
            iconName: icon,
            isUnlocked: unlocked,
            rarity: rarity,
            accessibilityLabel: "\(title), \(unlocked ? "открыто" : "закрыто")"
        )
    }

    /// Брифинг совместной игры (showBriefing=true) — первый кадр CoPlay.
    private static func makeCoPlayHolder() -> CoPlayViewModelHolder {
        let holder = CoPlayViewModelHolder()
        let firstTurn = CoPlayModels.Start.TurnViewModel(
            id: "turn-1",
            role: .adult,
            line: "Скажи: «Мяу-мяу»",
            instruction: "Покажи, как мяукает кошка",
            roleLabel: "Ход взрослого",
            progressLabel: "Ход 1 из 6",
            progressFraction: 1.0 / 6.0,
            accessibilityLabel: "Ход взрослого. Скажи мяу-мяу"
        )
        holder.startVM = CoPlayModels.Start.ViewModel(
            title: "Занятие вместе",
            activityTitle: "Кто как говорит?",
            symbolName: "person.2.fill",
            adultBriefing: "По очереди показывайте, как говорят животные. "
                + "Сначала вы — образец, потом малыш повторяет за вами.",
            totalTurns: 6,
            firstTurn: firstTurn
        )
        holder.currentTurn = firstTurn
        holder.showBriefing = true
        holder.isFinished = false
        return holder
    }

    /// Загруженная фраза + эталонный pitch-контур, фаза `.ready` —
    /// settled-кадр Canvas (модель-линия видна, live-линии нет до записи).
    private static func makeKaraokeHolder() -> KaraokePitchViewModelHolder {
        let holder = KaraokePitchViewModelHolder()
        let phrase = KaraokePhrase(
            id: "kr-preview-1",
            text: "Какой красивый день!",
            intonation: "exclamation",
            intonationSymbol: "exclamationmark.circle"
        )
        holder.startVM = KaraokePitchModels.Start.ViewModel(
            phraseText: phrase.text,
            intonationSymbol: phrase.intonationSymbol,
            modelContour: KaraokePitchCorpus.modelContour(for: phrase),
            totalPhrases: 20,
            currentIndex: 0,
            accessibilityLabel: "Фраза: \(phrase.text). Восклицание."
        )
        holder.phase = .ready
        return holder
    }

    // MARK: - Rendering engine

    private func render<V: View>(
        _ view: V,
        size: CGSize,
        style: UIUserInterfaceStyle,
        reduceMotion: Bool = true
    ) -> UIImage {
        SnapshotTestHelper.renderView(view, size: size, style: style, reduceMotion: reduceMotion)
    }

    // MARK: - Reference storage

    private func snapshotURL(screen: String, device: String, appearance: String) -> URL {
        SnapshotTestHelper.snapshotURL(
            testClass: Self.self,
            category: "Wave5Async",
            screen: screen,
            device: device,
            appearance: appearance
        )
    }

    // MARK: - Record / compare

    private func record<V: View>(
        _ view: V,
        screen: String,
        maxDiffRatio: Double = SnapshotTestHelper.defaultMaxDiffRatio,
        reduceMotion: Bool = true
    ) throws {
        for device in devices {
            for (appearanceName, style) in appearances {
                let image = render(view, size: device.size, style: style, reduceMotion: reduceMotion)
                let url = snapshotURL(screen: screen, device: device.name, appearance: appearanceName)
                let label = "\(screen)·\(device.name)·\(appearanceName)"
                try SnapshotTestHelper.assertPixelMatch(
                    image,
                    referenceURL: url,
                    maxDiffRatio: maxDiffRatio,
                    label: label
                )
            }
        }
    }
}
