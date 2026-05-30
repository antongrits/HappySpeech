@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - Wave2SnapshotTests
//
// Фаза E (волна 2): snapshot-тесты для следующих 25 ранее непокрытых
// feature-root View (light + dark).
//
// Матрица: 25 View × 2 темы (Light/Dark) × 2 устройства (iPhoneSE3 375×667,
// iPhone17Pro 402×874) = до 100 PNG в __Snapshots__/Wave2/.
//
// Паттерн идентичен Wave1SnapshotTests:
//   UIHostingController + UIGraphicsImageRenderer (scale 2.0),
//   reduceMotion=true для детерминизма (замораживает HSMeshGradient/
//   TimelineView анимации), попиксельное сравнение через SnapshotTestHelper.
//
// VIP-view инициализируют interactor внутри `.task { ... }`; renderView()
// прокручивает main run loop (settleMainRunLoop), что даёт `.task`
// отработать синхронную часть до снятия кадра. Окружение:
//   .environment(AppCoordinator()).environment(AppContainer.preview())
//
// Первый прогон ЗАПИСЫВАЕТ референсы (XCTFail «Записан новый референс») —
// это ожидаемо; второй прогон сравнивает и проходит зелёным.
// ==================================================================================

@MainActor
final class Wave2SnapshotTests: XCTestCase {

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

    // MARK: - 1. AchievementWallView (kid, childId) — SKIPPED
    //
    // AchievementWallInteractor грузит стену достижений через async-репозиторий;
    // к моменту снятия кадра `loadWall` не успевает завершиться, и view показывает
    // `ProgressView().controlSize(.large)` (line 116). Часть кадров ловит спиннер,
    // часть — частично загруженный грид → недетерминированный снимок (наблюдался
    // diff до 48% между прогонами на iPhoneSE3·Dark). Тот же класс проблемы, что у
    // ComparisonDashboardView в Wave1. Требует синхронного preview-репозитория с
    // готовыми ячейками. Baseline НЕ записан.
    func test_achievementWall_rendersInBothThemes() throws {
        throw XCTSkip(
            "AchievementWallView: async-загрузка стены не успевает завершиться к "
          + "снятию кадра → снимок ловит ProgressView / частичный грид (diff до 48%). "
          + "Требует синхронного preview-репозитория. Baseline не записан."
        )
    }

    // MARK: - 2. ArticulationGymView (kid, childId, default soundGroup)

    func test_articulationGym_rendersInBothThemes() throws {
        let view = ArticulationGymView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "ArticulationGymView")
    }

    // MARK: - 3. AssignedHomeworkView (specialist, specialistId)

    func test_assignedHomework_rendersInBothThemes() throws {
        let view = AssignedHomeworkView(specialistId: "preview-specialist-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "AssignedHomeworkView")
    }

    // MARK: - 4. BedtimeModeView (kid, childId)

    func test_bedtimeMode_rendersInBothThemes() throws {
        let view = BedtimeModeView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "BedtimeModeView")
    }

    // MARK: - 5. BreatheAndSpeakView (kid, childId)

    func test_breatheAndSpeak_rendersInBothThemes() throws {
        let view = BreatheAndSpeakView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "BreatheAndSpeakView")
    }

    // MARK: - 6. ComprehensionDetectiveView (kid, childId)

    func test_comprehensionDetective_rendersInBothThemes() throws {
        let view = ComprehensionDetectiveView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "ComprehensionDetectiveView")
    }

    // MARK: - 7. CulturalContentView (kid, childId)

    func test_culturalContent_rendersInBothThemes() throws {
        let view = CulturalContentView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "CulturalContentView")
    }

    // MARK: - 8. CustomizationView (kid, no args)

    func test_customization_rendersInBothThemes() throws {
        let view = CustomizationView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "CustomizationView")
    }

    // MARK: - 9. DailyChallengeView (kid, childId)

    func test_dailyChallenge_rendersInBothThemes() throws {
        let view = DailyChallengeView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "DailyChallengeView")
    }

    // MARK: - 10. DailyRitualsLyalyaView (kid, default kind)

    func test_dailyRitualsLyalya_rendersInBothThemes() throws {
        let view = DailyRitualsLyalyaView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "DailyRitualsLyalyaView")
    }

    // MARK: - 11. DailyStreakView (kid, childId + childName)

    func test_dailyStreak_rendersInBothThemes() throws {
        let view = DailyStreakView(childId: "preview-child-1", childName: "Маша")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "DailyStreakView")
    }

    // MARK: - 12. DialectAdaptationView (kid, childId)

    func test_dialectAdaptation_rendersInBothThemes() throws {
        let view = DialectAdaptationView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "DialectAdaptationView")
    }

    // MARK: - 13. FamilyAchievementsView (family, familyId)

    func test_familyAchievements_rendersInBothThemes() throws {
        let view = FamilyAchievementsView(familyId: "preview-family-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "FamilyAchievementsView")
    }

    // MARK: - 14. FamilyAwardsCabinetView (parent, parentId)

    func test_familyAwardsCabinet_rendersInBothThemes() throws {
        let view = FamilyAwardsCabinetView(parentId: "preview-parent-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "FamilyAwardsCabinetView")
    }

    // MARK: - 15. FamilyChallengeView (parent, parentId)

    func test_familyChallenge_rendersInBothThemes() throws {
        let view = FamilyChallengeView(parentId: "preview-parent-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "FamilyChallengeView")
    }

    // MARK: - 16. FamilyLeaderboardView (parent, parentId)

    func test_familyLeaderboard_rendersInBothThemes() throws {
        let view = FamilyLeaderboardView(parentId: "preview-parent-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "FamilyLeaderboardView")
    }

    // MARK: - 17. HelpCenterView (parent, no args)

    func test_helpCenter_rendersInBothThemes() throws {
        let view = HelpCenterView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "HelpCenterView")
    }

    // MARK: - 18. LexicalThemesView (kid, childId)

    func test_lexicalThemes_rendersInBothThemes() throws {
        let view = LexicalThemesView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "LexicalThemesView")
    }

    // MARK: - 19. LyalyaMailView (kid, childId)

    func test_lyalyaMail_rendersInBothThemes() throws {
        let view = LyalyaMailView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "LyalyaMailView")
    }

    // MARK: - 20. ParentGuideView (parent, childId)

    func test_parentGuide_rendersInBothThemes() throws {
        let view = ParentGuideView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "ParentGuideView")
    }

    // MARK: - 21. ParentInsightsTimelineView (parent, childId)

    func test_parentInsightsTimeline_rendersInBothThemes() throws {
        let view = ParentInsightsTimelineView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "ParentInsightsTimelineView")
    }

    // MARK: - 22. PlainProgressView (parent, childId)

    func test_plainProgress_rendersInBothThemes() throws {
        let view = PlainProgressView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "PlainProgressView")
    }

    // MARK: - 23. RewardShopView (kid, childId)

    func test_rewardShop_rendersInBothThemes() throws {
        let view = RewardShopView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "RewardShopView")
    }

    // MARK: - 24. SoundDictionaryView (kid/parent, no args)

    func test_soundDictionary_rendersInBothThemes() throws {
        let view = SoundDictionaryView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "SoundDictionaryView")
    }

    // MARK: - 25. WordBankView (kid, childId)

    func test_wordBank_rendersInBothThemes() throws {
        let view = WordBankView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "WordBankView")
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
            category: "Wave2",
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
