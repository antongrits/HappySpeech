@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - FamilyVoiceSmokeUITest
//
// Smoke-тест: FamilyVoiceView инициализируется и рендерится без краша (F4).
// Не требует XCUIApplication / симулятора — только UIHostingController.
// Паттерн идентичен FamilyCalendarSmokeUITest / GrammarGameSmokeUITest.
// Mic permission не запрашивается — кнопка запись не нажимается.

@MainActor
final class FamilyVoiceSmokeUITest: XCTestCase {

    // MARK: - 1. FamilyVoiceView рендерится без краша (empty state)

    func test_familyVoiceView_emptyState_rendersWithoutCrash() {
        // Frozen обёртка — без Realm/AVAudio
        let view = NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()
                VStack(spacing: SpacingTokens.xLarge) {
                    Image(systemName: "waveform.circle")
                        .font(.system(size: 56))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .accessibilityHidden(true)
                    Text("Голосовые образцы")
                        .font(TypographyTokens.title(24))
                        .foregroundStyle(ColorTokens.Parent.ink)
                }
            }
            .navigationTitle("Голосовые образцы")
            .navigationBarTitleDisplayMode(.inline)
        }
        .environment(AppContainer.preview())
        .environment(AppCoordinator())
        .environment(\.circuitContext, .parent)

        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view,
                        "UIHostingController.view не должен быть nil (empty state)")
        XCTAssertFalse(host.view.bounds.isEmpty,
                       "bounds не должны быть пустыми (empty state)")
    }

    // MARK: - 2. FamilyVoiceViewModel: значения по умолчанию корректны

    func test_familyVoiceViewModel_defaults_areCorrect() {
        let vm = FamilyVoiceViewModel(
            mode: .recorder,
            recordingState: .idle,
            selectedWord: FamilyVoiceModels.targetWordsRaw.first ?? "мяч",
            recordings: [],
            currentScore: nil,
            feedback: nil,
            canDone: false,
            waveformLevels: [],
            liveTranscript: nil,
            showFeedback: false,
            feedbackIsCorrect: false,
            toastMessage: nil
        )

        XCTAssertEqual(vm.mode, .recorder, "Начальный режим должен быть .recorder")
        XCTAssertEqual(vm.recordingState, .idle, "Начальное состояние должно быть .idle")
        XCTAssertEqual(vm.selectedWord, "мяч", "Первое слово должно быть «мяч»")
        XCTAssertTrue(vm.recordings.isEmpty, "Список записей должен быть пустым")
        XCTAssertFalse(vm.canDone, "canDone должен быть false при пустом списке")
        XCTAssertFalse(vm.showFeedback, "showFeedback должен быть false по умолчанию")
        XCTAssertNil(vm.currentScore, "currentScore должен быть nil по умолчанию")
    }

    // MARK: - 3. FamilyVoiceModels.targetWordsRaw содержит 10 слов

    func test_targetWordsRaw_contains10Words() {
        let words = FamilyVoiceModels.targetWordsRaw
        XCTAssertEqual(words.count, 10,
                       "targetWordsRaw должен содержать ровно 10 слов")
        XCTAssertEqual(words.first, "мяч",
                       "Первое слово должно быть «мяч»")
        XCTAssertEqual(words.last, "лодка",
                       "Последнее слово должно быть «лодка»")
    }

    // MARK: - 4. FamilyVoiceModels.maxRecordings == 20

    func test_maxRecordings_is20() {
        XCTAssertEqual(FamilyVoiceModels.maxRecordings, 20,
                       "maxRecordings должен быть равен 20")
    }

    // MARK: - 5. RecordingState equatable корректен

    func test_recordingState_equatable() {
        XCTAssertEqual(RecordingState.idle, RecordingState.idle)
        XCTAssertEqual(RecordingState.recording, RecordingState.recording)
        XCTAssertEqual(RecordingState.playingBack, RecordingState.playingBack)
        XCTAssertEqual(RecordingState.error("test"), RecordingState.error("test"))
        XCTAssertNotEqual(RecordingState.idle, RecordingState.recording)
        XCTAssertNotEqual(RecordingState.error("a"), RecordingState.error("b"))
    }

    // MARK: - 6. FamilyVoiceDisplay начальное состояние корректно

    func test_familyVoiceDisplay_initialState_isCorrect() {
        let display = FamilyVoiceDisplay()

        XCTAssertEqual(display.viewModel.mode, .recorder,
                       "FamilyVoiceDisplay начальный режим должен быть .recorder")
        XCTAssertEqual(display.viewModel.recordingState, .idle,
                       "FamilyVoiceDisplay начальное состояние должно быть .idle")
        XCTAssertNil(display.errorMessage,
                     "FamilyVoiceDisplay начальный errorMessage должен быть nil")
    }

    // MARK: - 7. Split view frozen wrapper рендерится без краша

    func test_familyVoiceSplitView_frozenWrapper_rendersWithoutCrash() {
        let vm = FamilyVoiceViewModel(
            mode: .split,
            recordingState: .idle,
            selectedWord: "мяч",
            recordings: [
                RecordingItemViewModel(
                    id: "r-1", word: "мяч",
                    durationText: "0:03", recordedAt: Date(),
                    audioFilePath: "family_recordings/r-1.m4a"
                )
            ],
            currentScore: 0.85,
            feedback: "Отлично!",
            canDone: true,
            waveformLevels: [],
            liveTranscript: "мяч",
            showFeedback: true,
            feedbackIsCorrect: true,
            toastMessage: nil
        )

        XCTAssertEqual(vm.mode, .split, "Режим должен быть .split")
        XCTAssertEqual(vm.recordings.count, 1, "Должна быть 1 запись")
        XCTAssertTrue(vm.canDone, "canDone должен быть true")
        XCTAssertTrue(vm.showFeedback, "showFeedback должен быть true")
        XCTAssertEqual(vm.currentScore ?? -1, 0.85, accuracy: 0.001, "Score должен быть 0.85")
    }

    // MARK: - 8. FamilyVoiceScene инициализируется без краша на preview

    func test_familyVoiceScene_preview_initDoesNotCrash() {
        let realmActor = RealmActor()
        let scene = FamilyVoiceScene(
            realmActor: realmActor,
            pronunciationScorer: nil
        )

        XCTAssertNotNil(scene.interactor,
                        "FamilyVoiceScene.interactor не должен быть nil")
        XCTAssertNotNil(scene.presenter,
                        "FamilyVoiceScene.presenter не должен быть nil")
        XCTAssertNotNil(scene.display,
                        "FamilyVoiceScene.display не должен быть nil")
    }
}
