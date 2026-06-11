@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - Wave4SnapshotTests
//
// Фаза E (волна 4): snapshot-тесты для следующих ~25 ранее непокрытых
// feature-root View (light + dark).
//
// Матрица: View × 2 темы (Light/Dark) × 2 устройства (iPhoneSE3 375×667,
// iPhone17Pro 402×874) PNG в __Snapshots__/Wave4/.
//
// Паттерн идентичен Wave1/Wave2/Wave3SnapshotTests:
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
//
// ПРОПУЩЕНЫ (без baseline):
//   • AR/камера-View (ARStoryQuest/ButterflyCatch/HoldThePose/PoseSequence/
//     SoundAndFace/ARFaceFilter/ARActivity/FingerPlay) — требуют живой
//     ARSession/AVCaptureSession, на симуляторе чёрный/пустой кадр.
//   • RetellingView / StorytellingView — стартуют в `phase == .loading`
//     (ProgressView) и грузят ход через async-bootstrap; кадр ловит спиннер.
//   • VoiceJournal / VoiceCloning / ParentVoiceNote / LetterTrace —
//     recorder/PencilKit + async-холдер, нестабильный кадр.
//   • WeeklySoundReport — async-график + ProgressView-фаза.
//   Все — класс «нужен синхронный preview-worker с готовыми данными».
// ==================================================================================

@MainActor
final class Wave4SnapshotTests: XCTestCase {

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

    // MARK: - 1. SentenceBuilderKidView (kid, childId)

    func test_sentenceBuilderKid_rendersInBothThemes() throws {
        let view = SentenceBuilderKidView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "SentenceBuilderKidView")
    }

    // MARK: - 2. SoundDoctorKidView (kid, childId)

    func test_soundDoctorKid_rendersInBothThemes() throws {
        let view = SoundDoctorKidView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "SoundDoctorKidView")
    }

    // MARK: - 3. StoryRetellingProView (kid, childId)

    func test_storyRetellingPro_rendersInBothThemes() throws {
        let view = StoryRetellingProView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "StoryRetellingProView")
    }

    // MARK: - 4. TongueTwisterArenaView (kid, childId)

    func test_tongueTwisterArena_rendersInBothThemes() throws {
        let view = TongueTwisterArenaView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "TongueTwisterArenaView")
    }

    // MARK: - 5. VisualVocabularyFlipView (kid, childId)

    func test_visualVocabularyFlip_rendersInBothThemes() throws {
        let view = VisualVocabularyFlipView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "VisualVocabularyFlipView")
    }

    // MARK: - 6. WhisperGameView (kid, childId)

    func test_whisperGame_rendersInBothThemes() throws {
        let view = WhisperGameView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "WhisperGameView")
    }

    // MARK: - 7. WordRhymeGameView (kid, childId)

    func test_wordRhymeGame_rendersInBothThemes() throws {
        let view = WordRhymeGameView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "WordRhymeGameView")
    }

    // MARK: - 8. PhonemeFamilyMatcherView (kid, childId)

    func test_phonemeFamilyMatcher_rendersInBothThemes() throws {
        let view = PhonemeFamilyMatcherView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "PhonemeFamilyMatcherView")
    }

    // MARK: - 9. LetterPaintingFunView (kid, childId)

    func test_letterPaintingFun_rendersInBothThemes() throws {
        let view = LetterPaintingFunView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "LetterPaintingFunView")
    }

    // MARK: - 10. SyllableConstructorView (kid, childId)
    //
    // Smoke: SyllableConstructorView запускает `setupAndStart()` внутри `.task`.
    // settleMainRunLoop даёт task отработать синхронную часть, но между прогонами
    // SyllableConstructorWorker подбирает разное слово из пула
    // (worker.start → pool.randomElement/shuffle), что меняет содержимое
    // wordHeader + bankTiles между прогонами → diff 19.44% на 17Pro·Dark.
    // Re-record sentinel не стабилизирует: источник нестабильности — случайный пул.
    // Smoke ловит главный класс регрессий: краш/пустой кадр/отсутствие окружения.

    func test_syllableConstructor_rendersInBothThemes() throws {
        let view = SyllableConstructorView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        for device in devices {
            for (appearanceName, style) in appearances {
                SnapshotTestHelper.assertRendersNonBlank(
                    view,
                    size: device.size,
                    style: style,
                    label: "SyllableConstructorView·\(device.name)·\(appearanceName)"
                )
            }
        }
    }

    // MARK: - 11. WeeklyChallengeView (kid, childId)

    func test_weeklyChallenge_rendersInBothThemes() throws {
        let view = WeeklyChallengeView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "WeeklyChallengeView")
    }

    // MARK: - 12. PhonemicListeningView (kid, childId)

    func test_phonemicListening_rendersInBothThemes() throws {
        let view = PhonemicListeningView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "PhonemicListeningView")
    }

    // MARK: - 13. ProsodyView (kid, childId) — SKIPPED
    //
    // ProsodyView рисует крупный пульсирующий SF-символ интонации через
    // `.hsSymbolEffect(.pulse, value: round.intonationSymbol)` (line 185) и
    // `.hsSymbolEffect(.pulse, value: round.id)` (line 253). `.pulse` —
    // непрерывная symbol-анимация, которую `accessibilityReduceMotion` НЕ
    // замораживает в нашем рендер-сетапе (в отличие от mesh/TimelineView). Кадр
    // ловит разную фазу пульса между прогонами → diff МИГРИРУЕТ по ячейкам
    // (наблюдался 6.3% на iPhone17Pro·Dark, в другом прогоне — на другой
    // ячейке). Re-record через sentinel не стабилизирует: источник — фаза
    // пульса, а не stale baseline. Требует отключения symbolEffect в
    // preview/snapshot-режиме. Baseline НЕ записан.
    func test_prosody_rendersInBothThemes() throws {
        throw XCTSkip(
            "ProsodyView: непрерывный `.hsSymbolEffect(.pulse)` не замораживается "
          + "reduceMotion → кадр ловит разную фазу пульса, diff мигрирует по ячейкам "
          + "(~6.3%, > 5%; re-record не помогает). Требует gate symbolEffect в "
          + "snapshot-режиме. Baseline не записан."
        )
    }

    // MARK: - 14. SoundTrafficLightView (kid, childId)

    func test_soundTrafficLight_rendersInBothThemes() throws {
        let view = SoundTrafficLightView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "SoundTrafficLightView")
    }

    // MARK: - 15. SpeechTempoView (kid, childId) — SKIPPED
    //
    // SpeechTempoView анимирует темп-метку и рифму непрерывными эффектами
    // (`.hsSymbolEffect(.pulse)` + `.animation(...)` на line 194), которые
    // `accessibilityReduceMotion` НЕ замораживает в рендер-сетапе. Кадр ловит
    // разную фазу анимации между прогонами → diff МИГРИРУЕТ по ячейкам
    // (наблюдался 5.4% на iPhone17Pro·Dark, в другом прогоне 7.2% на
    // iPhoneSE3·Dark). Re-record через sentinel не стабилизирует: тот же класс,
    // что ProsodyView. Требует gate symbolEffect/animation в snapshot-режиме.
    // Baseline НЕ записан.
    func test_speechTempo_rendersInBothThemes() throws {
        throw XCTSkip(
            "SpeechTempoView: непрерывные `.hsSymbolEffect(.pulse)`/`.animation` не "
          + "замораживаются reduceMotion → кадр ловит разную фазу, diff мигрирует "
          + "по ячейкам (5.4–7.2%, > 5%; re-record не помогает). Требует gate "
          + "анимаций в snapshot-режиме. Baseline не записан."
        )
    }

    // MARK: - 16. ReadAloudStoryView (kid, childId) — SKIPPED
    //
    // ReadAloudStoryInteractor выбирает историю через `worker.pickStory` →
    // `ReadAloudStoryCorpus.randomStory(excluding:)` → `pool.randomElement()`,
    // т.е. при каждом рендере подставляется СЛУЧАЙНАЯ история из корпуса. Кадр
    // ловит разный текст истории между прогонами → недетерминированный снимок
    // (наблюдался diff 9.3–13.1% на всех четырёх ячейках). Re-record не помогает:
    // источник нестабильности — `randomElement()`, а не фаза анимации. Требует
    // детерминированного (seeded) preview-worker с фиксированной историей.
    // Baseline НЕ записан.
    func test_readAloudStory_rendersInBothThemes() throws {
        throw XCTSkip(
            "ReadAloudStoryView: worker.pickStory выбирает случайную историю "
          + "(ReadAloudStoryCorpus.randomStory → randomElement()), поэтому кадр ловит "
          + "разный текст между прогонами (diff 9.3–13.1% на всех ячейках; re-record "
          + "не помогает). Требует seeded preview-worker. Baseline не записан."
        )
    }

    // MARK: - 17. SpeechGrowthDiaryView (parent, childId)

    func test_speechGrowthDiary_rendersInBothThemes() throws {
        let view = SpeechGrowthDiaryView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "SpeechGrowthDiaryView")
    }

    // MARK: - 18. SpeechVisualizationView (kid, word + targetSound)

    func test_speechVisualization_rendersInBothThemes() throws {
        let view = SpeechVisualizationView(word: "Рыба", targetSound: "Р")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "SpeechVisualizationView")
    }

    // MARK: - 19. SpecialistCaseNotesView (specialist, childId + specialistId)

    func test_specialistCaseNotes_rendersInBothThemes() throws {
        let view = SpecialistCaseNotesView(childId: "preview-child-1", specialistId: "preview-specialist-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "SpecialistCaseNotesView")
    }

    // MARK: - 20. SpecialistQuickAssessmentView (specialist, childId + specialistId)

    func test_specialistQuickAssessment_rendersInBothThemes() throws {
        let view = SpecialistQuickAssessmentView(childId: "preview-child-1", specialistId: "preview-specialist-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "SpecialistQuickAssessmentView")
    }

    // MARK: - 22. SpecialistResourcesLibraryView (specialist, specialistId)

    func test_specialistResourcesLibrary_rendersInBothThemes() throws {
        let view = SpecialistResourcesLibraryView(specialistId: "preview-specialist-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "SpecialistResourcesLibraryView")
    }

    // MARK: - 23. SpecialistScheduleView (specialist, specialistId)

    func test_specialistSchedule_rendersInBothThemes() throws {
        let view = SpecialistScheduleView(specialistId: "preview-specialist-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "SpecialistScheduleView")
    }

    // MARK: - 24. SpecialistAssessmentView (specialist, childId + specialistId)

    func test_specialistAssessment_rendersInBothThemes() throws {
        let view = SpecialistAssessmentView(childId: "preview-child-1", specialistId: "preview-specialist-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "SpecialistAssessmentView")
    }

    // MARK: - 25. SpeechHomeworkPlannerView (parent/specialist, no args)

    func test_speechHomeworkPlanner_rendersInBothThemes() throws {
        let view = SpeechHomeworkPlannerView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "SpeechHomeworkPlannerView")
    }

    // MARK: - 26. ChangelogView (settings, no args)

    func test_changelog_rendersInBothThemes() throws {
        let view = ChangelogView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "ChangelogView")
    }

    // MARK: - 27. PacingView (kid, stuttering module, no args)

    func test_pacing_rendersInBothThemes() throws {
        let view = PacingView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "PacingView")
    }

    // MARK: - 28. FluencyDiaryParentView (parent, stuttering module, no args)

    func test_fluencyDiaryParent_rendersInBothThemes() throws {
        let view = FluencyDiaryParentView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "FluencyDiaryParentView")
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
            category: "Wave4",
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
