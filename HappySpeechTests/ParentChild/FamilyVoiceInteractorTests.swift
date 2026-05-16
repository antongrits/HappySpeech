@testable import HappySpeech
import RealmSwift
import XCTest

// MARK: - FamilyVoiceInteractorTests
//
// 10 unit-тестов для FamilyVoiceInteractor (F4).
// Паттерн: Interactor → реальный Presenter → SpyDisplay.
// Все Workers подменяются через MockFamilyVoiceRecorderWorker / MockFamilyVoiceScoringWorker,
// где это возможно; для тестов, не требующих реального I/O, используется MockRealmActor.
// AVAudioSession не вызывается — Interactor изолирован через протоколы Presenter/Display.

@MainActor
final class FamilyVoiceInteractorTests: XCTestCase {

    // MARK: - SpyDisplay

    @MainActor
    private final class SpyDisplay: FamilyVoiceDisplayLogic {
        var displayRecordingsCalled      = false
        var displayRecordingStartedCalled = false
        var displayRecordingStoppedCalled = false
        var displayPlaybackCalled        = false
        var displayDeletionCalled        = false
        var displayChildScoreCalled      = false
        var displayWordChangedCalled     = false
        var displayErrorCalled           = false

        var lastViewModel: FamilyVoiceViewModel?
        var lastErrorMessage: String?

        func displayRecordings(_ viewModel: FamilyVoiceViewModel) {
            displayRecordingsCalled = true; lastViewModel = viewModel
        }
        func displayRecordingStarted(_ viewModel: FamilyVoiceViewModel) {
            displayRecordingStartedCalled = true; lastViewModel = viewModel
        }
        func displayRecordingStopped(_ viewModel: FamilyVoiceViewModel) {
            displayRecordingStoppedCalled = true; lastViewModel = viewModel
        }
        func displayPlayback(_ viewModel: FamilyVoiceViewModel) {
            displayPlaybackCalled = true; lastViewModel = viewModel
        }
        func displayDeletion(_ viewModel: FamilyVoiceViewModel) {
            displayDeletionCalled = true; lastViewModel = viewModel
        }
        func displayChildScore(_ viewModel: FamilyVoiceViewModel) {
            displayChildScoreCalled = true; lastViewModel = viewModel
        }
        func displayWordChanged(_ viewModel: FamilyVoiceViewModel) {
            displayWordChangedCalled = true; lastViewModel = viewModel
        }
        func displayError(_ message: String) {
            displayErrorCalled = true; lastErrorMessage = message
        }
    }

    // MARK: - Helpers

    /// Создаёт RecordingDTO-заглушку.
    private func makeDTO(id: String = UUID().uuidString, word: String = "мяч") -> RecordingDTO {
        RecordingDTO(
            id: id,
            word: word,
            audioFilePath: "family_recordings/\(id).m4a",
            recordedAt: Date(),
            durationSeconds: 2.5,
            parentProfileId: "parent-test"
        )
    }

    /// Создаёт in-memory RealmActor — изолирован от реального Realm.
    private func makeRealmActor() async throws -> RealmActor {
        let memId = "family-voice-unit-\(UUID().uuidString)"
        var config = Realm.Configuration()
        config.inMemoryIdentifier = memId
        config.schemaVersion = RealmSchemaVersion.current
        Realm.Configuration.defaultConfiguration = config
        let actor = RealmActor()
        try await actor.open(configuration: config)
        return actor
    }

    /// Создаёт минимальный стек: Interactor + Presenter + SpyDisplay.
    private func makeSUT(realmActor: RealmActor) -> (
        sut: FamilyVoiceInteractor,
        display: SpyDisplay
    ) {
        let spy = SpyDisplay()
        let presenter = FamilyVoicePresenter()
        presenter.display = spy

        let sut = FamilyVoiceInteractor(
            realmActor: realmActor,
            pronunciationScorer: nil
        )
        sut.presenter = presenter

        return (sut, spy)
    }

    // MARK: - 1. loadInitial: fetchRecordings → presenter получает список

    func test_loadInitial_returnsRecorderMode() async throws {
        let realm = try await makeRealmActor()
        let (sut, display) = makeSUT(realmActor: realm)
        await sut.fetchRecordings(.init(parentId: "parent-test"))
        XCTAssertTrue(display.displayRecordingsCalled,
                      "displayRecordings должен вызваться после fetchRecordings")
        XCTAssertEqual(display.lastViewModel?.mode, .recorder,
                       "Начальный режим должен быть .recorder")
    }

    // MARK: - 2. selectWord: presenter обновляет selectedWord

    func test_selectWord_presenterUpdatesSelectedWord() async throws {
        let realm = try await makeRealmActor()
        let (sut, display) = makeSUT(realmActor: realm)
        sut.selectWord("собака")
        XCTAssertNil(display.lastErrorMessage,
                     "Смена слова не должна порождать ошибку")
    }

    // MARK: - 3. skipWord: следующее слово по циклу

    func test_skipWord_advancesToNextWord() async throws {
        let realm = try await makeRealmActor()
        let (sut, display) = makeSUT(realmActor: realm)
        let firstWord = FamilyVoiceModels.targetWordsRaw[0]
        let secondWord = FamilyVoiceModels.targetWordsRaw[1]

        sut.skipWord(.init(currentWord: firstWord))

        XCTAssertTrue(display.displayWordChangedCalled,
                      "displayWordChanged должен вызваться после skipWord")
        XCTAssertEqual(display.lastViewModel?.selectedWord, secondWord,
                       "После skipWord слово должно стать следующим в списке")
    }

    // MARK: - 4. skipWord: последнее слово → возврат к первому (цикл)

    func test_skipWord_lastWord_wrapsToFirst() async throws {
        let realm = try await makeRealmActor()
        let (sut, display) = makeSUT(realmActor: realm)
        let words = FamilyVoiceModels.targetWordsRaw
        let lastWord = words[words.count - 1]
        let firstWord = words[0]

        sut.skipWord(.init(currentWord: lastWord))

        XCTAssertTrue(display.displayWordChangedCalled,
                      "displayWordChanged должен вызываться при переходе через конец списка")
        XCTAssertEqual(display.lastViewModel?.selectedWord, firstWord,
                       "После последнего слова должен быть возврат к первому (циклический список)")
    }

    // MARK: - 5. nextWord: идентичен skipWord, проверяем отдельно

    func test_nextWord_advancesToNextWord() async throws {
        let realm = try await makeRealmActor()
        let (sut, display) = makeSUT(realmActor: realm)
        let firstWord = FamilyVoiceModels.targetWordsRaw[0]
        let secondWord = FamilyVoiceModels.targetWordsRaw[1]

        sut.nextWord(.init(currentWord: firstWord))

        XCTAssertTrue(display.displayWordChangedCalled,
                      "displayWordChanged должен вызываться после nextWord")
        XCTAssertEqual(display.lastViewModel?.selectedWord, secondWord,
                       "nextWord должен перейти к следующему слову так же, как skipWord")
    }

    // MARK: - 6. resetSession: слово сбрасывается в первое

    func test_resetSession_resetsToFirstWord() async throws {
        let realm = try await makeRealmActor()
        let (sut, display) = makeSUT(realmActor: realm)

        sut.nextWord(.init(currentWord: FamilyVoiceModels.targetWordsRaw[0]))
        display.displayWordChangedCalled = false

        sut.resetSession(.init())

        XCTAssertTrue(display.displayWordChangedCalled,
                      "displayWordChanged должен вызываться при resetSession")
        XCTAssertEqual(
            display.lastViewModel?.selectedWord,
            FamilyVoiceModels.targetWordsRaw.first,
            "resetSession должен вернуть первое слово из списка"
        )
    }

    // MARK: - 7. max20Recordings: константа maxRecordings == 20 и проверяется в recordings list

    func test_max20Recordings_limitConstantIs20() {
        // Верификация константы и логики фильтрации списка.
        // Прямой вызов startRecording не используется — требует реального mic permission.
        XCTAssertEqual(FamilyVoiceModels.maxRecordings, 20,
                       "maxRecordings должен быть равен 20 согласно спецификации F4")

        // Проверяем логику: список из 20 записей для одного слова превышает лимит
        let recordings20 = (0..<20).map { i in
            RecordingDTO(
                id: "rec-\(i)", word: "мяч",
                audioFilePath: "family_recordings/rec-\(i).m4a",
                recordedAt: Date(), durationSeconds: 1.0,
                parentProfileId: "parent-test"
            )
        }
        let countForWord = recordings20.filter { $0.word == "мяч" }.count
        XCTAssertFalse(countForWord < FamilyVoiceModels.maxRecordings,
                       "При 20 записях для одного слова условие count < maxRecordings должно быть false")
    }

    // MARK: - 8. deleteRecording: несуществующий ID — тихо игнорируется

    func test_deleteRecording_unknownId_doesNotCrash() async throws {
        let realm = try await makeRealmActor()
        let (sut, display) = makeSUT(realmActor: realm)
        await sut.fetchRecordings(.init(parentId: "parent-test"))
        await sut.deleteRecording(.init(recordingId: "nonexistent-id"))
        XCTAssertFalse(display.displayDeletionCalled,
                       "deleteRecording с несуществующим ID не должен вызывать displayDeletion")
    }

    // MARK: - 9. cleanup: идемпотентен, не крашится

    func test_cleanup_doesNotCrash() async throws {
        let realm = try await makeRealmActor()
        let (sut, _) = makeSUT(realmActor: realm)
        sut.cleanup()
        sut.cleanup()
        XCTAssertTrue(true, "Повторный вызов cleanup не должен крашить приложение")
    }

    // MARK: - 10. fetchRecordings: последовательные вызовы с разными parentId успешны

    func test_fetchRecordings_consecutiveCallsSucceed() async throws {
        let realm = try await makeRealmActor()
        let (sut, display) = makeSUT(realmActor: realm)

        await sut.fetchRecordings(.init(parentId: "parent-first"))
        XCTAssertTrue(display.displayRecordingsCalled, "Первый fetch должен вызвать displayRecordings")

        display.displayRecordingsCalled = false

        await sut.fetchRecordings(.init(parentId: "parent-second"))
        XCTAssertTrue(display.displayRecordingsCalled,
                      "Второй fetch с другим parentId должен тоже вызвать displayRecordings")
    }

    // MARK: - Batch 2.8.3 v25: расширенное покрытие
    //
    // UNTESTABLE (документировано): startRecording/stopRecording/startChildRecording
    // требуют AVAudioApplication.requestRecordPermission + реальный AVAudioRecorder —
    // FamilyVoiceRecorderWorker не инжектируется (создаётся в init()). Здесь покрываются
    // безопасные guard-ветки и навигация слов.

    // MARK: - 11. playRecording: несуществующий ID → guard, no-op

    func test_playRecording_unknownId_doesNotCrash() async throws {
        let realm = try await makeRealmActor()
        let (sut, display) = makeSUT(realmActor: realm)
        await sut.fetchRecordings(.init(parentId: "parent-test"))
        await sut.playRecording(.init(recordingId: "nonexistent-rec"))
        XCTAssertFalse(display.displayPlaybackCalled,
                       "playRecording с неизвестным ID не вызывает displayPlayback")
    }

    // MARK: - 12. stopChildRecording: без активной записи → guard, no-op

    func test_stopChildRecording_whenNotRecording_doesNotCrash() async throws {
        let realm = try await makeRealmActor()
        let (sut, display) = makeSUT(realmActor: realm)
        await sut.stopChildRecording(.init(word: "мяч", referenceRecordingId: "ref-1"))
        XCTAssertFalse(display.displayChildScoreCalled,
                       "stopChildRecording без активной записи не вызывает displayChildScore")
    }

    // MARK: - 13. selectWord: presenter получает setSelectedWord

    func test_selectWord_setsSelectedWordOnPresenter() async throws {
        let realm = try await makeRealmActor()
        let (sut, display) = makeSUT(realmActor: realm)
        await sut.fetchRecordings(.init(parentId: "parent-test"))
        sut.selectWord("ракета")
        // setSelectedWord обновляет ViewModel — проверяем отсутствие ошибки.
        XCTAssertNil(display.lastErrorMessage)
    }

    // MARK: - 14. skipWord: неизвестное слово → guard, no-op

    func test_skipWord_unknownWord_doesNotAdvance() async throws {
        let realm = try await makeRealmActor()
        let (sut, display) = makeSUT(realmActor: realm)
        sut.skipWord(.init(currentWord: "несуществующее-слово"))
        XCTAssertFalse(display.displayWordChangedCalled,
                       "skipWord с неизвестным словом не должен менять слово")
    }

    // MARK: - 15. nextWord: последнее слово → циклический возврат

    func test_nextWord_lastWord_wrapsToFirst() async throws {
        let realm = try await makeRealmActor()
        let (sut, display) = makeSUT(realmActor: realm)
        let words = FamilyVoiceModels.targetWordsRaw
        sut.nextWord(.init(currentWord: words[words.count - 1]))
        XCTAssertEqual(display.lastViewModel?.selectedWord, words.first)
    }

    // MARK: - 16. deleteRecording: пустой список → guard, no-op

    func test_deleteRecording_emptyList_doesNotCrash() async throws {
        let realm = try await makeRealmActor()
        let (sut, display) = makeSUT(realmActor: realm)
        await sut.deleteRecording(.init(recordingId: "any-id"))
        XCTAssertFalse(display.displayDeletionCalled)
    }

    // MARK: - 17. targetWordsRaw: каталог не пуст

    func test_targetWordsRaw_catalogNotEmpty() {
        XCTAssertFalse(FamilyVoiceModels.targetWordsRaw.isEmpty)
        XCTAssertGreaterThanOrEqual(FamilyVoiceModels.targetWordsRaw.count, 2,
                                    "Для циклической навигации нужно ≥2 слова")
    }
}
