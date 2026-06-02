@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - Wave3SnapshotTests
//
// Фаза E (волна 3): snapshot-тесты для следующих ~25 ранее непокрытых
// feature-root View (light + dark).
//
// Матрица: View × 2 темы (Light/Dark) × 2 устройства (iPhoneSE3 375×667,
// iPhone17Pro 402×874) PNG в __Snapshots__/Wave3/.
//
// Паттерн идентичен Wave1/Wave2SnapshotTests:
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
final class Wave3SnapshotTests: XCTestCase {

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

    // MARK: - 1. CoPlayView (kid+parent, childId) — SKIPPED
    //
    // CoPlayView грузит ход через `.task { await setupAndStart() }` (async-worker,
    // childRepository + corpus) и анимирует смену хода `.animation(value: turn.id)`.
    // К моменту снятия кадра async-bootstrap не успевает settle стабильно: кадр
    // ловит разную фазу появления хода → недетерминированный снимок (наблюдался
    // diff ~6.5–8.5%, область мигрирует между iPhoneSE3·Dark / iPhone17Pro·Dark /
    // SE·Light между прогонами). Re-record в settled-режиме не стабилизирует.
    // Тот же класс, что AchievementWallView в Wave2. Требует синхронного
    // preview-worker с готовым первым ходом. Baseline НЕ записан.
    func test_coPlay_rendersInBothThemes() throws {
        throw XCTSkip(
            "CoPlayView: async-bootstrap (setupAndStart) не успевает стабильно settle "
          + "к снятию кадра → снимок ловит разную фазу появления хода (diff ~6.5–8.5%, "
          + "мигрирует между устройствами/темами; re-record не помогает). Требует "
          + "синхронного preview-worker. Baseline не записан."
        )
    }

    // MARK: - 2. CustomWordListView (specialist, specialistId)

    func test_customWordList_rendersInBothThemes() throws {
        let view = CustomWordListView(specialistId: "preview-specialist-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "CustomWordListView")
    }

    // MARK: - 3. DemoModeView (no args)

    func test_demoMode_rendersInBothThemes() throws {
        let view = DemoModeView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "DemoModeView")
    }

    // MARK: - 4. AchievementsView (kid, childId)

    func test_achievements_rendersInBothThemes() throws {
        let view = AchievementsView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "AchievementsView")
    }

    // MARK: - 5. ProfileEditorView (parent, childId)

    func test_profileEditor_rendersInBothThemes() throws {
        let view = ProfileEditorView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "ProfileEditorView")
    }

    // MARK: - 6. ImitationLabView (kid, childId)

    func test_imitationLab_rendersInBothThemes() throws {
        let view = ImitationLabView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "ImitationLabView")
    }

    // MARK: - 7. KaraokePitchView (kid, childId) — SKIPPED
    //
    // KaraokePitchView грузит эталон через async-bootstrap (`holder.startVM`/`phase`)
    // и рисует pitch-Canvas (модель + live-контур) с гейтом по `holder.phase`. К
    // моменту снятия кадра фаза загрузки (idle/loaded) недетерминирована: снимок
    // ловит разное состояние Canvas → diff ~8.2–8.8% мигрирует между SE·Light и
    // SE·Dark между прогонами. Re-record в settled-режиме не стабилизирует. Тот же
    // класс async-load, что AchievementWall/CoPlay. Требует синхронного
    // preview-worker с готовым modelContour. Baseline НЕ записан.
    func test_karaokePitch_rendersInBothThemes() throws {
        throw XCTSkip(
            "KaraokePitchView: async-загрузка эталона/фазы не успевает стабильно settle "
          + "к снятию кадра → pitch-Canvas ловит разное состояние (diff ~8.2–8.8%, "
          + "мигрирует между темами; re-record не помогает). Требует синхронного "
          + "preview-worker с modelContour. Baseline не записан."
        )
    }

    // MARK: - 8. LiteracyStartView (kid, targetSound + childId)

    func test_literacyStart_rendersInBothThemes() throws {
        let view = LiteracyStartView(targetSound: "Р", childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "LiteracyStartView")
    }

    // MARK: - 9. LogopedistChatView (parent↔specialist, parentId + specialistId)
    //
    // v32: snapshot ловит SETTLED-кадр с реальной перепиской (а не пустой
    // loading-state) через DEBUG-only `previewState` seam. Стейт детерминирован.

    @MainActor
    func test_logopedistChat_rendersInBothThemes() throws {
        let view = LogopedistChatView(
            parentId: "preview-parent-1",
            specialistId: "preview-specialist-1",
            previewState: Self.makeChatHolder()
        )
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        try record(view, screen: "LogopedistChatView")
    }

    // MARK: - 9b. LogopedistChatView — connect form (не подключён)

    @MainActor
    func test_logopedistChatConnectForm_rendersInBothThemes() throws {
        let view = LogopedistChatView(
            parentId: "preview-parent-1",
            specialistId: "preview-specialist-1",
            previewState: Self.makeConnectFormHolder()
        )
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        try record(view, screen: "LogopedistChatConnectForm")
    }

    // MARK: - Chat holders (deterministic)

    @MainActor
    private static func makeChatHolder() -> LogopedistChatViewModelHolder {
        let holder = LogopedistChatViewModelHolder()
        let rows = [
            LogopedistChatModels.Load.MessageRow(
                id: "s1", isFromParent: false, text: "Добрый день! Звук «С» стал стабильнее.",
                timeLabel: "10:15", statusLabel: "", statusSymbol: nil, isRead: true,
                attachment: nil, accessibilityLabel: "Логопед, Добрый день, 10:15"
            ),
            LogopedistChatModels.Load.MessageRow(
                id: "p1", isFromParent: true, text: "Спасибо! Дома повторяем каждый день.",
                timeLabel: "10:20", statusLabel: "Прочитано", statusSymbol: "checkmark.circle.fill",
                isRead: true, attachment: nil, accessibilityLabel: "Вы, Спасибо, 10:20"
            ),
            LogopedistChatModels.Load.MessageRow(
                id: "p2", isFromParent: true, text: "Прикладываю запись занятия.",
                timeLabel: "10:21", statusLabel: "Отправлено", statusSymbol: "checkmark",
                isRead: false,
                attachment: LogopedistChatModels.Load.AttachmentRow(
                    id: "att", title: "Запись занятия", symbolName: "waveform", durationLabel: "28 сек"
                ),
                accessibilityLabel: "Вы, запись занятия, 10:21"
            )
        ]
        let section = LogopedistChatModels.Load.DaySection(
            id: "today", dateLabel: "Сегодня", messages: rows
        )
        holder.loadVM = LogopedistChatModels.Load.ViewModel(
            specialistName: "Ирина Петрова",
            credentials: "Логопед-дефектолог",
            onlineStatusLabel: "В сети",
            isOnline: true,
            isConnected: true,
            connectionHint: nil,
            emptyStateHint: nil,
            messages: rows,
            composerEnabled: true,
            sections: [section],
            showConnectForm: false,
            outboxLabel: nil,
            unreadBadge: nil
        )
        return holder
    }

    @MainActor
    private static func makeConnectFormHolder() -> LogopedistChatViewModelHolder {
        let holder = LogopedistChatViewModelHolder()
        holder.loadVM = LogopedistChatModels.Load.ViewModel(
            specialistName: "Логопед не подключён",
            credentials: "—",
            onlineStatusLabel: nil,
            isOnline: false,
            isConnected: false,
            connectionHint: nil,
            emptyStateHint: "Подключите логопеда вашего ребёнка",
            messages: [],
            composerEnabled: false,
            sections: [],
            showConnectForm: true,
            outboxLabel: nil,
            unreadBadge: nil
        )
        return holder
    }

    // MARK: - 10. LogorhythmicsView (kid, childId)

    func test_logorhythmics_rendersInBothThemes() throws {
        let view = LogorhythmicsView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "LogorhythmicsView")
    }

    // MARK: - 11. LyalyaPersonalCoachView (kid, childId)

    func test_lyalyaPersonalCoach_rendersInBothThemes() throws {
        let view = LyalyaPersonalCoachView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "LyalyaPersonalCoachView")
    }

    // MARK: - 12. MusicalSoundDrumsView (kid, childId)

    func test_musicalSoundDrums_rendersInBothThemes() throws {
        let view = MusicalSoundDrumsView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "MusicalSoundDrumsView")
    }

    // MARK: - 13. NeurolinguistInsightsView (specialist, childId)

    func test_neurolinguistInsights_rendersInBothThemes() throws {
        let view = NeurolinguistInsightsView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "NeurolinguistInsightsView")
    }

    // MARK: - 14. ObjectDescriptionMapView (kid, childId)

    func test_objectDescriptionMap_rendersInBothThemes() throws {
        let view = ObjectDescriptionMapView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "ObjectDescriptionMapView")
    }

    // MARK: - 15. OralStoryCreatorView (kid, childId)

    func test_oralStoryCreator_rendersInBothThemes() throws {
        let view = OralStoryCreatorView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "OralStoryCreatorView")
    }

    // MARK: - 16. ParentDailyDigestView (parent, no args)

    func test_parentDailyDigest_rendersInBothThemes() throws {
        let view = ParentDailyDigestView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "ParentDailyDigestView")
    }

    // MARK: - 17. ParentInspirationBoardView (parent, no args)

    func test_parentInspirationBoard_rendersInBothThemes() throws {
        let view = ParentInspirationBoardView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "ParentInspirationBoardView")
    }

    // MARK: - 18. ParentMoodCheckInView (parent, no args)

    func test_parentMoodCheckIn_rendersInBothThemes() throws {
        let view = ParentMoodCheckInView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "ParentMoodCheckInView")
    }

    // MARK: - 20. PhonemeJourneyMapView (kid, childId)

    func test_phonemeJourneyMap_rendersInBothThemes() throws {
        let view = PhonemeJourneyMapView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "PhonemeJourneyMapView")
    }

    // MARK: - 21. PracticeReminderKidView (kid, childId)

    func test_practiceReminderKid_rendersInBothThemes() throws {
        let view = PracticeReminderKidView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "PracticeReminderKidView")
    }

    // MARK: - 22. PronunciationLeaderboardView (parent, parentId)

    func test_pronunciationLeaderboard_rendersInBothThemes() throws {
        let view = PronunciationLeaderboardView(parentId: "preview-parent-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "PronunciationLeaderboardView")
    }

    // MARK: - 23. SoundExplorerMapView (kid, childId)

    func test_soundExplorerMap_rendersInBothThemes() throws {
        let view = SoundExplorerMapView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "SoundExplorerMapView")
    }

    // MARK: - 24. SoundOfTheDayView (kid, childId)

    func test_soundOfTheDay_rendersInBothThemes() throws {
        let view = SoundOfTheDayView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "SoundOfTheDayView")
    }

    // MARK: - 25. SpeechRiddlesView (kid, childId)

    func test_speechRiddles_rendersInBothThemes() throws {
        let view = SpeechRiddlesView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "SpeechRiddlesView")
    }

    // MARK: - 26. StoryEndingMakerView (kid, childId)

    func test_storyEndingMaker_rendersInBothThemes() throws {
        let view = StoryEndingMakerView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "StoryEndingMakerView")
    }

    // MARK: - 27. WeeklyParentTipView (parent, no args)

    func test_weeklyParentTip_rendersInBothThemes() throws {
        let view = WeeklyParentTipView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "WeeklyParentTipView")
    }

    // MARK: - 28. WeeklyRecapView (parent, no args)

    func test_weeklyRecap_rendersInBothThemes() throws {
        let view = WeeklyRecapView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "WeeklyRecapView")
    }

    // MARK: - 29. WordOfTheDayView (kid, childId)

    func test_wordOfTheDay_rendersInBothThemes() throws {
        let view = WordOfTheDayView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "WordOfTheDayView")
    }

    // MARK: - 30. SpeechNormsEncyclopediaView (parent/specialist, default age)

    func test_speechNormsEncyclopedia_rendersInBothThemes() throws {
        let view = SpeechNormsEncyclopediaView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "SpeechNormsEncyclopediaView")
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
            category: "Wave3",
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
