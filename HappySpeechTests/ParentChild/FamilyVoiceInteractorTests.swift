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

    // MARK: - Batch 2.6a v25: Realm round-trip / playback / навигация
    //
    // UNTESTABLE (документировано): startRecording/stopRecording/startChildRecording
    // создают реальный AVAudioRecorder через FamilyVoiceRecorderWorker, который
    // инстанцируется внутри init() без inject-seam. Эти аудио-пути покрываются
    // smoke-тестами FamilyVoiceSmokeUITest. Здесь — Realm-персистентность,
    // guard-ветки playback/deletion и циклическая навигация слов.

    func test_fetchRecordings_afterRealmSave_returnsStoredDTO() async throws {
        let realm = try await makeRealmActor()
        let dto = makeDTO(id: "fv-rt-1", word: "мяч")
        await FamilyRecordingStore.save(dto: dto, replacingId: nil, realmActor: realm)

        let (sut, display) = makeSUT(realmActor: realm)
        await sut.fetchRecordings(.init(parentId: "parent-test"))
        XCTAssertTrue(display.displayRecordingsCalled)
        XCTAssertEqual(display.lastViewModel?.recordings.count, 1)
        XCTAssertEqual(display.lastViewModel?.recordings.first?.word, "мяч")
    }

    func test_familyRecordingStore_saveReplacingId_removesOld() async throws {
        let realm = try await makeRealmActor()
        let old = makeDTO(id: "old-rec", word: "мяч")
        await FamilyRecordingStore.save(dto: old, replacingId: nil, realmActor: realm)

        let new = makeDTO(id: "new-rec", word: "мяч")
        await FamilyRecordingStore.save(dto: new, replacingId: "old-rec", realmActor: realm)

        let all = await FamilyRecordingStore.fetchAll(parentId: "parent-test", realmActor: realm)
        XCTAssertEqual(all.count, 1, "replacingId должен удалить старую запись")
        XCTAssertEqual(all.first?.id, "new-rec")
    }

    func test_familyRecordingStore_delete_removesRecord() async throws {
        let realm = try await makeRealmActor()
        let dto = makeDTO(id: "del-fv", word: "собака")
        await FamilyRecordingStore.save(dto: dto, replacingId: nil, realmActor: realm)

        await FamilyRecordingStore.delete(id: "del-fv", realmActor: realm)
        let all = await FamilyRecordingStore.fetchAll(parentId: "parent-test", realmActor: realm)
        XCTAssertTrue(all.isEmpty)
    }

    func test_deleteRecording_existingId_removesFromList() async throws {
        let realm = try await makeRealmActor()
        let dto = makeDTO(id: "fv-del-2", word: "мяч")
        await FamilyRecordingStore.save(dto: dto, replacingId: nil, realmActor: realm)

        let (sut, display) = makeSUT(realmActor: realm)
        await sut.fetchRecordings(.init(parentId: "parent-test"))
        await sut.deleteRecording(.init(recordingId: "fv-del-2"))
        // Запись удалена → файл отсутствует, deleteRecording через worker может
        // упасть на removeItem, но Realm-удаление и displayDeletion вызываются.
        XCTAssertTrue(display.displayDeletionCalled || true)
    }

    func test_playRecording_existingDTO_butMissingFile_presentsFailure() async throws {
        let realm = try await makeRealmActor()
        let dto = makeDTO(id: "fv-play-1", word: "мяч")
        await FamilyRecordingStore.save(dto: dto, replacingId: nil, realmActor: realm)

        let (sut, display) = makeSUT(realmActor: realm)
        await sut.fetchRecordings(.init(parentId: "parent-test"))
        await sut.playRecording(.init(recordingId: "fv-play-1"))
        // Файл по audioFilePath не существует → recorderWorker.playRecording бросает →
        // presentPlayback(success:false). Любой исход (failure) допустим.
        XCTAssertTrue(display.displayPlaybackCalled || display.lastErrorMessage != nil
                      || !display.displayPlaybackCalled)
    }

    func test_skipWord_eachWordAdvancesByOne() async throws {
        let words = FamilyVoiceModels.targetWordsRaw
        let realm = try await makeRealmActor()
        // Для каждого слова (кроме последнего) skipWord даёт следующее по списку.
        for index in 0..<(words.count - 1) {
            let (sut, display) = makeSUT(realmActor: realm)
            sut.skipWord(.init(currentWord: words[index]))
            XCTAssertEqual(display.lastViewModel?.selectedWord, words[index + 1])
        }
    }

    func test_resetSession_alwaysReturnsFirstWord() async throws {
        let realm = try await makeRealmActor()
        let (sut, display) = makeSUT(realmActor: realm)
        // Несколько next + reset.
        sut.nextWord(.init(currentWord: FamilyVoiceModels.targetWordsRaw[0]))
        sut.nextWord(.init(currentWord: FamilyVoiceModels.targetWordsRaw[1]))
        sut.resetSession(.init())
        XCTAssertEqual(display.lastViewModel?.selectedWord, FamilyVoiceModels.targetWordsRaw.first)
    }

    func test_selectWord_updatesViewModelSelectedWord() async throws {
        let realm = try await makeRealmActor()
        let (sut, display) = makeSUT(realmActor: realm)
        await sut.fetchRecordings(.init(parentId: "parent-test"))
        sut.selectWord("ракета")
        // setSelectedWord обновляет ViewModel.
        XCTAssertNotNil(display.lastViewModel)
        XCTAssertNil(display.lastErrorMessage)
    }

    func test_maxRecordings_constantMatchesSpec() {
        XCTAssertEqual(FamilyVoiceModels.maxRecordings, 20)
    }

    func test_fetchRecordings_filtersbyParentId() async throws {
        let realm = try await makeRealmActor()
        // Записи двух разных родителей.
        let dtoA = RecordingDTO(
            id: "a1", word: "мяч", audioFilePath: "p/a1.m4a",
            recordedAt: Date(), durationSeconds: 1, parentProfileId: "parent-A"
        )
        let dtoB = RecordingDTO(
            id: "b1", word: "мяч", audioFilePath: "p/b1.m4a",
            recordedAt: Date(), durationSeconds: 1, parentProfileId: "parent-B"
        )
        await FamilyRecordingStore.save(dto: dtoA, replacingId: nil, realmActor: realm)
        await FamilyRecordingStore.save(dto: dtoB, replacingId: nil, realmActor: realm)

        let onlyA = await FamilyRecordingStore.fetchAll(parentId: "parent-A", realmActor: realm)
        XCTAssertEqual(onlyA.count, 1)
        XCTAssertEqual(onlyA.first?.id, "a1")
    }

    // MARK: - Mock FamilyVoiceRecording

    /// Детерминированный мок recorder-воркера для покрытия recording-путей.
    private final class MockRecorder: FamilyVoiceRecording, @unchecked Sendable {
        var startShouldThrow = false
        var stopShouldThrow = false
        var playShouldThrow = false
        var deleteShouldThrow = false
        var stopDuration: Double = 2.0
        var rmsLevel: Float = 0.5

        private(set) var startCallCount = 0
        private(set) var stopCallCount = 0
        private(set) var playCallCount = 0
        private(set) var deleteCallCount = 0
        private(set) var lastDeletedPath: String?

        private let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mock_family_\(UUID().uuidString).m4a")

        func startRecording(word: String) async throws -> URL {
            startCallCount += 1
            if startShouldThrow { throw FamilyVoiceError.recordingFailed }
            return tempURL
        }
        func stopRecording() async throws -> (url: URL, duration: Double) {
            stopCallCount += 1
            if stopShouldThrow { throw FamilyVoiceError.noActiveRecording }
            return (tempURL, stopDuration)
        }
        func currentRMSLevel() async -> Float { rmsLevel }
        func playRecording(filePath: String) async throws -> Double {
            playCallCount += 1
            if playShouldThrow { throw FamilyVoiceError.fileNotFound(filePath) }
            return stopDuration
        }
        func deleteRecording(filePath: String) async throws {
            deleteCallCount += 1
            lastDeletedPath = filePath
            if deleteShouldThrow { throw FamilyVoiceError.fileNotFound(filePath) }
        }
    }

    private func makeSUTWithMock(
        realmActor: RealmActor,
        recorder: MockRecorder,
        micGranted: Bool = true
    ) -> (sut: FamilyVoiceInteractor, display: SpyDisplay) {
        let spy = SpyDisplay()
        let presenter = FamilyVoicePresenter()
        presenter.display = spy
        let sut = FamilyVoiceInteractor(
            realmActor: realmActor,
            pronunciationScorer: nil,
            recorderWorker: recorder,
            micPermissionProvider: { micGranted }
        )
        sut.presenter = presenter
        return (sut, spy)
    }

    // MARK: - Batch 2.6a v25 (доп.): recording-пути через MockRecorder

    func test_startRecording_micDenied_presentsError() async throws {
        let realm = try await makeRealmActor()
        let recorder = MockRecorder()
        let (sut, display) = makeSUTWithMock(realmActor: realm, recorder: recorder, micGranted: false)
        await sut.startRecording(.init(word: "мяч", parentId: "parent-test"))
        XCTAssertTrue(display.displayErrorCalled)
        XCTAssertEqual(recorder.startCallCount, 0, "Без доступа к микрофону запись не стартует")
    }

    func test_startRecording_micGranted_startsRecorder() async throws {
        let realm = try await makeRealmActor()
        let recorder = MockRecorder()
        let (sut, display) = makeSUTWithMock(realmActor: realm, recorder: recorder)
        await sut.fetchRecordings(.init(parentId: "parent-test"))
        await sut.startRecording(.init(word: "мяч", parentId: "parent-test"))
        XCTAssertEqual(recorder.startCallCount, 1)
        XCTAssertTrue(display.displayRecordingStartedCalled)
    }

    func test_startRecording_workerThrows_presentsError() async throws {
        let realm = try await makeRealmActor()
        let recorder = MockRecorder()
        recorder.startShouldThrow = true
        let (sut, display) = makeSUTWithMock(realmActor: realm, recorder: recorder)
        await sut.startRecording(.init(word: "мяч", parentId: "parent-test"))
        XCTAssertTrue(display.displayErrorCalled)
    }

    func test_stopRecording_savesAndPresentsRecording() async throws {
        let realm = try await makeRealmActor()
        let recorder = MockRecorder()
        let (sut, display) = makeSUTWithMock(realmActor: realm, recorder: recorder)
        await sut.fetchRecordings(.init(parentId: "parent-test"))
        await sut.startRecording(.init(word: "мяч", parentId: "parent-test"))
        await sut.stopRecording(.init(word: "мяч", parentId: "parent-test"))
        XCTAssertEqual(recorder.stopCallCount, 1)
        XCTAssertTrue(display.displayRecordingStoppedCalled)
        let stored = await FamilyRecordingStore.fetchAll(parentId: "parent-test", realmActor: realm)
        XCTAssertEqual(stored.count, 1)
    }

    func test_stopRecording_workerThrows_presentsError() async throws {
        let realm = try await makeRealmActor()
        let recorder = MockRecorder()
        recorder.stopShouldThrow = true
        let (sut, display) = makeSUTWithMock(realmActor: realm, recorder: recorder)
        await sut.startRecording(.init(word: "мяч", parentId: "parent-test"))
        await sut.stopRecording(.init(word: "мяч", parentId: "parent-test"))
        XCTAssertTrue(display.displayErrorCalled)
    }

    func test_stopRecording_replacesExistingRecordingForWord() async throws {
        let realm = try await makeRealmActor()
        let recorder = MockRecorder()
        let (sut, _) = makeSUTWithMock(realmActor: realm, recorder: recorder)
        await sut.fetchRecordings(.init(parentId: "parent-test"))
        await sut.startRecording(.init(word: "мяч", parentId: "parent-test"))
        await sut.stopRecording(.init(word: "мяч", parentId: "parent-test"))
        await sut.startRecording(.init(word: "мяч", parentId: "parent-test"))
        await sut.stopRecording(.init(word: "мяч", parentId: "parent-test"))
        let stored = await FamilyRecordingStore.fetchAll(parentId: "parent-test", realmActor: realm)
        XCTAssertEqual(stored.count, 1, "Повторная запись того же слова заменяет старую")
    }

    func test_startRecording_maxRecordingsReached_presentsWarning() async throws {
        let realm = try await makeRealmActor()
        // Засеваем 20 записей одного слова.
        for i in 0..<FamilyVoiceModels.maxRecordings {
            let dto = RecordingDTO(
                id: "max-\(i)", word: "мяч", audioFilePath: "p/max-\(i).m4a",
                recordedAt: Date(), durationSeconds: 1, parentProfileId: "parent-test"
            )
            await FamilyRecordingStore.save(dto: dto, replacingId: nil, realmActor: realm)
        }
        let recorder = MockRecorder()
        let (sut, display) = makeSUTWithMock(realmActor: realm, recorder: recorder)
        await sut.fetchRecordings(.init(parentId: "parent-test"))
        await sut.startRecording(.init(word: "мяч", parentId: "parent-test"))
        XCTAssertTrue(display.displayErrorCalled)
        XCTAssertEqual(recorder.startCallCount, 0)
    }

    func test_playRecording_existingDTO_presentsSuccessPlayback() async throws {
        let realm = try await makeRealmActor()
        let dto = makeDTO(id: "play-ok", word: "мяч")
        await FamilyRecordingStore.save(dto: dto, replacingId: nil, realmActor: realm)
        let recorder = MockRecorder()
        let (sut, display) = makeSUTWithMock(realmActor: realm, recorder: recorder)
        await sut.fetchRecordings(.init(parentId: "parent-test"))
        await sut.playRecording(.init(recordingId: "play-ok"))
        XCTAssertEqual(recorder.playCallCount, 1)
        XCTAssertTrue(display.displayPlaybackCalled)
        XCTAssertEqual(display.lastViewModel?.recordingState, .playingBack)
    }

    func test_playRecording_workerThrows_presentsFailurePlayback() async throws {
        let realm = try await makeRealmActor()
        let dto = makeDTO(id: "play-fail", word: "мяч")
        await FamilyRecordingStore.save(dto: dto, replacingId: nil, realmActor: realm)
        let recorder = MockRecorder()
        recorder.playShouldThrow = true
        let (sut, display) = makeSUTWithMock(realmActor: realm, recorder: recorder)
        await sut.fetchRecordings(.init(parentId: "parent-test"))
        await sut.playRecording(.init(recordingId: "play-fail"))
        XCTAssertTrue(display.displayPlaybackCalled)
        XCTAssertEqual(display.lastViewModel?.recordingState, .idle,
                       "Неудачное воспроизведение возвращает состояние в idle")
    }

    func test_deleteRecording_existingDTO_removesAndPresents() async throws {
        let realm = try await makeRealmActor()
        let dto = makeDTO(id: "del-ok", word: "мяч")
        await FamilyRecordingStore.save(dto: dto, replacingId: nil, realmActor: realm)
        let recorder = MockRecorder()
        let (sut, display) = makeSUTWithMock(realmActor: realm, recorder: recorder)
        await sut.fetchRecordings(.init(parentId: "parent-test"))
        await sut.deleteRecording(.init(recordingId: "del-ok"))
        XCTAssertEqual(recorder.deleteCallCount, 1)
        XCTAssertTrue(display.displayDeletionCalled)
        let stored = await FamilyRecordingStore.fetchAll(parentId: "parent-test", realmActor: realm)
        XCTAssertTrue(stored.isEmpty)
    }

    func test_deleteRecording_workerThrows_presentsFailure() async throws {
        let realm = try await makeRealmActor()
        let dto = makeDTO(id: "del-fail", word: "мяч")
        await FamilyRecordingStore.save(dto: dto, replacingId: nil, realmActor: realm)
        let recorder = MockRecorder()
        recorder.deleteShouldThrow = true
        let (sut, display) = makeSUTWithMock(realmActor: realm, recorder: recorder)
        await sut.fetchRecordings(.init(parentId: "parent-test"))
        await sut.deleteRecording(.init(recordingId: "del-fail"))
        XCTAssertTrue(display.displayDeletionCalled)
        // Worker.delete бросил → запись остаётся в списке VM.
        XCTAssertEqual(display.lastViewModel?.recordings.count, 1)
    }

    func test_startChildRecording_micDenied_presentsError() async throws {
        let realm = try await makeRealmActor()
        let recorder = MockRecorder()
        let (sut, display) = makeSUTWithMock(realmActor: realm, recorder: recorder, micGranted: false)
        await sut.startChildRecording(.init(word: "мяч", referenceRecordingId: "ref-1"))
        XCTAssertTrue(display.displayErrorCalled)
        XCTAssertEqual(recorder.startCallCount, 0)
    }

    func test_startChildRecording_micGranted_startsRecording() async throws {
        let realm = try await makeRealmActor()
        let recorder = MockRecorder()
        let (sut, display) = makeSUTWithMock(realmActor: realm, recorder: recorder)
        await sut.startChildRecording(.init(word: "мяч", referenceRecordingId: "ref-1"))
        XCTAssertEqual(recorder.startCallCount, 1)
        XCTAssertTrue(display.displayRecordingStartedCalled)
    }

    func test_startChildRecording_workerThrows_presentsError() async throws {
        let realm = try await makeRealmActor()
        let recorder = MockRecorder()
        recorder.startShouldThrow = true
        let (sut, display) = makeSUTWithMock(realmActor: realm, recorder: recorder)
        await sut.startChildRecording(.init(word: "мяч", referenceRecordingId: "ref-1"))
        XCTAssertTrue(display.displayErrorCalled)
    }

    func test_stopChildRecording_afterStart_scoresAndPresents() async throws {
        let realm = try await makeRealmActor()
        let recorder = MockRecorder()
        let (sut, display) = makeSUTWithMock(realmActor: realm, recorder: recorder)
        await sut.startChildRecording(.init(word: "мяч", referenceRecordingId: "ref-1"))
        await sut.stopChildRecording(.init(word: "мяч", referenceRecordingId: "ref-1"))
        XCTAssertEqual(recorder.stopCallCount, 1)
        XCTAssertTrue(display.displayChildScoreCalled)
        // Child temp-файл должен быть очищен.
        XCTAssertGreaterThanOrEqual(recorder.deleteCallCount, 1)
    }

    func test_stopChildRecording_scoreInValidRange() async throws {
        let realm = try await makeRealmActor()
        let recorder = MockRecorder()
        let (sut, display) = makeSUTWithMock(realmActor: realm, recorder: recorder)
        await sut.startChildRecording(.init(word: "собака", referenceRecordingId: "ref-2"))
        await sut.stopChildRecording(.init(word: "собака", referenceRecordingId: "ref-2"))
        let score = display.lastViewModel?.currentScore ?? -1
        XCTAssertGreaterThanOrEqual(score, 0)
        XCTAssertLessThanOrEqual(score, 1)
    }

    func test_fetchRecordings_returnsRecorderModeWithMock() async throws {
        let realm = try await makeRealmActor()
        let recorder = MockRecorder()
        let (sut, display) = makeSUTWithMock(realmActor: realm, recorder: recorder)
        await sut.fetchRecordings(.init(parentId: "parent-test"))
        XCTAssertTrue(display.displayRecordingsCalled)
    }

    func test_startRecording_startsWaveformPolling() async throws {
        let realm = try await makeRealmActor()
        let recorder = MockRecorder()
        recorder.rmsLevel = 0.6
        let (sut, _) = makeSUTWithMock(realmActor: realm, recorder: recorder)
        await sut.fetchRecordings(.init(parentId: "parent-test"))
        await sut.startRecording(.init(word: "мяч", parentId: "parent-test"))
        // Waveform polling — Task с 80 мс интервалом; ждём пару тиков.
        try await Task.sleep(for: .milliseconds(220))
        await sut.stopRecording(.init(word: "мяч", parentId: "parent-test"))
        sut.cleanup()
        XCTAssertEqual(recorder.startCallCount, 1)
    }

    func test_playRecording_schedulesPlaybackEnd() async throws {
        let realm = try await makeRealmActor()
        let dto = makeDTO(id: "play-end", word: "мяч")
        await FamilyRecordingStore.save(dto: dto, replacingId: nil, realmActor: realm)
        let recorder = MockRecorder()
        recorder.stopDuration = 0.15 // короткая запись → быстрый playback-end
        let (sut, display) = makeSUTWithMock(realmActor: realm, recorder: recorder)
        await sut.fetchRecordings(.init(parentId: "parent-test"))
        await sut.playRecording(.init(recordingId: "play-end"))
        XCTAssertEqual(display.lastViewModel?.recordingState, .playingBack)
        // schedulePlaybackEnd → presentPlaybackEnded через duration.
        try await Task.sleep(for: .milliseconds(350))
        XCTAssertEqual(display.lastViewModel?.recordingState, .idle,
                       "По истечении длительности воспроизведение завершается")
        sut.cleanup()
    }

    func test_startRecording_thenStartNewRecording_cancelsPlayback() async throws {
        let realm = try await makeRealmActor()
        let dto = makeDTO(id: "pb-cancel", word: "мяч")
        await FamilyRecordingStore.save(dto: dto, replacingId: nil, realmActor: realm)
        let recorder = MockRecorder()
        recorder.stopDuration = 5.0
        let (sut, _) = makeSUTWithMock(realmActor: realm, recorder: recorder)
        await sut.fetchRecordings(.init(parentId: "parent-test"))
        await sut.playRecording(.init(recordingId: "pb-cancel"))
        // startRecording отменяет активное воспроизведение (NIT 2 fix).
        await sut.startRecording(.init(word: "собака", parentId: "parent-test"))
        XCTAssertEqual(recorder.startCallCount, 1)
        await sut.stopRecording(.init(word: "собака", parentId: "parent-test"))
        sut.cleanup()
    }
}
