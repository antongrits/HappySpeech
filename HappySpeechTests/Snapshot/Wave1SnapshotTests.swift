@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - Wave1SnapshotTests
//
// Фаза E: snapshot-тесты для 20 ранее непокрытых View (light + dark).
//
// Матрица: 20 View × 2 темы (Light/Dark) × 2 устройства (iPhoneSE3 375×667,
// iPhone17Pro 402×874) = до 80 PNG в __Snapshots__/Wave1/.
//
// Паттерн идентичен KeyScreensSnapshotTests:
//   UIHostingController + UIGraphicsImageRenderer (scale 2.0),
//   reduceMotion=true для детерминизма (замораживает HSMeshGradient/
//   TimelineView анимации), попиксельное сравнение через SnapshotTestHelper.
//
// VIP-view инициализируют interactor внутри `.task { ... }`; renderView()
// прокручивает main run loop (settleMainRunLoop), что даёт `.task`
// отработать синхронную часть до снятия кадра.
//
// Первый прогон ЗАПИСЫВАЕТ референсы (XCTFail «Записан новый референс») —
// это ожидаемо; второй прогон сравнивает и проходит зелёным.
// ==================================================================================

@MainActor
final class Wave1SnapshotTests: XCTestCase {

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

    // MARK: - 1. AchievementCalendarView (kid/parent, childId)

    func test_achievementCalendar_rendersInBothThemes() throws {
        let view = AchievementCalendarView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "AchievementCalendarView")
    }

    // MARK: - 2. AnimalSoundsBingoView (kid, childId)

    func test_animalSoundsBingo_rendersInBothThemes() throws {
        let view = AnimalSoundsBingoView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "AnimalSoundsBingoView")
    }

    // MARK: - 3. AudioMemoryGameView (kid, childId)

    func test_audioMemoryGame_rendersInBothThemes() throws {
        let view = AudioMemoryGameView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "AudioMemoryGameView")
    }

    // MARK: - 4. ColorAndSoundView (kid, childId)

    func test_colorAndSound_rendersInBothThemes() throws {
        let view = ColorAndSoundView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        // Палитра-карусель цвет↔звук даёт ~5.4–5.8% дрейфа между идентичными
        // рендерами (недетерминированный градиент) — допуск чуть выше дефолтного.
        try record(view, screen: "ColorAndSoundView", maxDiffRatio: 0.09)
    }

    // MARK: - 5. ConversationStartersParentView (parent, no args)

    func test_conversationStartersParent_rendersInBothThemes() throws {
        let view = ConversationStartersParentView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "ConversationStartersParentView")
    }

    // MARK: - 6. DailyMissionsHubView (kid, childId, needs AppCoordinator)

    func test_dailyMissionsHub_rendersInBothThemes() throws {
        let view = DailyMissionsHubView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "DailyMissionsHubView")
    }

    // MARK: - 7. EveningReflectionView (kid, childId)

    func test_eveningReflection_rendersInBothThemes() throws {
        let view = EveningReflectionView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "EveningReflectionView")
    }

    // MARK: - 8. MorningRoutineView (kid, childId, needs AppCoordinator)

    func test_morningRoutine_rendersInBothThemes() throws {
        let view = MorningRoutineView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "MorningRoutineView")
    }

    // MARK: - 9. FamilyHomeView (family, needs AppContainer + AppCoordinator)

    func test_familyHome_rendersInBothThemes() throws {
        let view = FamilyHomeView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "FamilyHomeView")
    }

    // MARK: - 10. FamilyVoiceMessageHubView (family, no args)

    func test_familyVoiceMessageHub_rendersInBothThemes() throws {
        let view = FamilyVoiceMessageHubView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "FamilyVoiceMessageHubView")
    }

    // MARK: - 11. GoalTrackerKidView (kid, childId, needs AppCoordinator)

    func test_goalTrackerKid_rendersInBothThemes() throws {
        let view = GoalTrackerKidView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "GoalTrackerKidView")
    }

    // MARK: - 12. HabitStreakDashboardView (parent, childId)

    func test_habitStreakDashboard_rendersInBothThemes() throws {
        let view = HabitStreakDashboardView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "HabitStreakDashboardView")
    }

    // MARK: - 13. BilingualModeView (kid, childId, needs AppCoordinator)

    func test_bilingualMode_rendersInBothThemes() throws {
        let view = BilingualModeView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "BilingualModeView")
    }

    // MARK: - 14. ChildAchievementShareView (kid, no args)

    func test_childAchievementShare_rendersInBothThemes() throws {
        let view = ChildAchievementShareView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "ChildAchievementShareView")
    }

    // MARK: - 15. ChildLanguageMilestonesView (parent, no args)

    func test_childLanguageMilestones_rendersInBothThemes() throws {
        let view = ChildLanguageMilestonesView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "ChildLanguageMilestonesView")
    }

    // MARK: - 16. ComparisonDashboardView (family) — SKIPPED
    //
    // ComparisonDashboardInteractor грузит данные через async-репозиторий, и
    // `viewModel.isLoading` остаётся true к моменту снятия кадра (settleMainRunLoop
    // не дожидается завершения async-загрузки). Снимок ловит `ProgressView`-спиннер
    // — недетерминированный кадр, поэтому baseline НЕ записываем. Требует доработки
    // рендера: либо синхронный preview-репозиторий с готовыми данными, либо
    // инжект уже-загруженного ViewModel в превью-режиме.
    func test_comparisonDashboard_rendersInBothThemes() throws {
        throw XCTSkip(
            "ComparisonDashboardView: async-загрузка не успевает завершиться к "
          + "снятию кадра → снимок ловит ProgressView. Требует синхронного "
          + "preview-репозитория. Baseline не записан."
        )
    }

    // MARK: - 17. DailyTimeCapView (parent, needs AppContainer + AppCoordinator)

    func test_dailyTimeCap_rendersInBothThemes() throws {
        let view = DailyTimeCapView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "DailyTimeCapView")
    }

    // MARK: - 18. SoundJournalKidView (kid, childId)

    func test_soundJournalKid_rendersInBothThemes() throws {
        let view = SoundJournalKidView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "SoundJournalKidView")
    }

    // MARK: - 19. WordOfTheDayView (kid, childId)

    func test_wordOfTheDay_rendersInBothThemes() throws {
        let view = WordOfTheDayView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "WordOfTheDayView")
    }

    // MARK: - 20. PalindromeHunterView (kid, childId)

    func test_palindromeHunter_rendersInBothThemes() throws {
        let view = PalindromeHunterView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "PalindromeHunterView")
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
            category: "Wave1",
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
