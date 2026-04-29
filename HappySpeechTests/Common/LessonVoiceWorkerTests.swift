@testable import HappySpeech
import AVFoundation
import XCTest

// MARK: - LessonVoiceWorkerTests (Блок A.7)
//
// 10 unit-тестов + 9 smoke-тестов для LessonVoiceWorker.
//
// Стратегия тестирования:
//   • phraseId(for:) и normalize(_:) — private; тестируем косвенно через JSON lookup.
//   • Маппинг читаем напрямую из JSON, который LessonVoiceWorker уже загрузил в singleton.
//   • Для async-тестов с воспроизведением: запускаем Task → через 80ms stop() → не зависает.
//   • Smoke на 9 Interactor'ов: инициализируются и cancel() без краша.
//
// Local Mocks (не конфликтуют с private-mock'ами других файлов — разные имена):
//   VWHapticMock, VWContentMock

// MARK: - Local Mocks для Smoke-тестов

private final class VWHapticMock: HapticService, @unchecked Sendable {
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {}
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {}
    func selection() {}
}

private final class VWContentMock: ContentService, @unchecked Sendable {
    func loadPack(id: String) async throws -> ContentPack {
        throw NSError(domain: "VWContentMock", code: 0)
    }
    func allPacks() async throws -> [ContentPackMeta] { [] }
    func bundledPacks() -> [ContentPackMeta] { [] }
}

// MARK: - Вспомогательный поиск app bundle (для JSON lookup)

private enum AppBundleFinder {
    static func appBundle(for testClass: AnyClass) -> URL? {
        let testBundleURL = Bundle(for: testClass).bundleURL
        var candidate = testBundleURL
        for _ in 0..<3 {
            candidate = candidate.deletingLastPathComponent()
            let appURL = candidate.appendingPathComponent("HappySpeech.app")
            if FileManager.default.fileExists(atPath: appURL.path) {
                return appURL
            }
        }
        return nil
    }

    static func loadPhraseMapping(for testClass: AnyClass) -> [String: String] {
        guard let appURL = appBundle(for: testClass) else { return [:] }
        let jsonURL = appURL.appendingPathComponent("lyalya-phrase-mapping.json")
        guard let data = try? Data(contentsOf: jsonURL),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return dict
    }
}

// MARK: - Тест 08: Загрузка маппинга

@MainActor
final class LessonVoiceWorkerMappingTests: XCTestCase {

    // MARK: - 08. JSON lyalya-phrase-mapping.json содержит ровно 735 записей

    func test_phraseMapping_loaded_735entries() throws {
        let mapping = AppBundleFinder.loadPhraseMapping(for: LessonVoiceWorkerMappingTests.self)
        try XCTSkipIf(mapping.isEmpty, "lyalya-phrase-mapping.json не найден в app bundle — пропуск теста на симуляторе без сборки")
        XCTAssertEqual(mapping.count, 735,
                       "lyalya-phrase-mapping.json должен содержать 735 записей")
    }
}

// MARK: - Тесты 01–04: Нормализация через JSON lookup

@MainActor
final class LessonVoiceWorkerNormalizationTests: XCTestCase {

    private var mapping: [String: String] = [:]

    override func setUp() async throws {
        try await super.setUp()
        mapping = AppBundleFinder.loadPhraseMapping(for: LessonVoiceWorkerNormalizationTests.self)
        try XCTSkipIf(mapping.isEmpty, "Маппинг не найден — пропускаем нормализационные тесты")
    }

    // MARK: - 01. "сани" присутствует с phraseId "sani"

    func test_phraseId_knownWord_sani_existsInMapping() {
        XCTAssertEqual(mapping["сани"], "sani",
                       "Ключ 'сани' в маппинге должен быть 'sani'")
    }

    // MARK: - 02. Все ключи маппинга — нижний регистр (как после normalize())

    func test_phraseMapping_keysAreLowercase() {
        // normalize() делает .lowercased() — значит все ключи должны быть строчные
        let upperKeys = mapping.keys.filter { $0 != $0.lowercased() }
        XCTAssertTrue(upperKeys.isEmpty,
                      "Все ключи маппинга должны быть lowercase; примеры нарушителей: \(upperKeys.prefix(3))")
    }

    // MARK: - 03. "мяч" присутствует в маппинге без пунктуации

    func test_phraseId_myach_existsWithoutPunctuation() {
        XCTAssertEqual(mapping["мяч"], "myach",
                       "Ключ 'мяч' → phraseId 'myach' должен присутствовать")
    }

    // MARK: - 04. Несуществующее слово отсутствует в маппинге

    func test_phraseId_nonexistentWord_absentFromMapping() {
        XCTAssertNil(mapping["ksdjfhsl_xtest_xyz"],
                     "Случайная строка не должна присутствовать в маппинге")
    }
}

// MARK: - Тест 05: ё/е нормализация

@MainActor
final class LessonVoiceWorkerYoTests: XCTestCase {

    private var mapping: [String: String] = [:]

    override func setUp() async throws {
        try await super.setUp()
        mapping = AppBundleFinder.loadPhraseMapping(for: LessonVoiceWorkerYoTests.self)
        try XCTSkipIf(mapping.isEmpty, "Маппинг не найден — пропускаем ё-тест")
    }

    // MARK: - 05. "самолёт" (с ё) есть в маппинге, "самолет" (без ё) — нет прямым ключом

    func test_phraseMapping_yo_samolyot_existsWithYo_absentWithoutYo() {
        // Прямой ключ с ё
        XCTAssertEqual(mapping["самолёт"], "samolyot",
                       "Ключ 'самолёт' с ё должен быть → samolyot")
        // Без ё — нет прямого ключа; worker делает е→ё fallback самостоятельно
        XCTAssertNil(mapping["самолет"],
                     "'самолет' без ё не должен быть прямым ключом — worker делает е→ё fallback")
    }
}

// MARK: - Тесты 06–07: Управление воспроизведением

@MainActor
final class LessonVoiceWorkerPlaybackTests: XCTestCase {

    // MARK: - 06. stop() до любого speak не крашит

    func test_stop_beforeAnySpeak_doesNotCrash() {
        XCTAssertNoThrow(
            LessonVoiceWorker.shared.stop(),
            "stop() без предшествующего speak не должен крашить"
        )
    }

    // MARK: - 07. Повторный stop() не крашит — continuation guard nil-safe

    func test_stop_doubleCall_doesNotCrash() {
        LessonVoiceWorker.shared.stop()
        XCTAssertNoThrow(
            LessonVoiceWorker.shared.stop(),
            "Второй stop() не должен крашить — continuation уже nil"
        )
    }
}

// MARK: - Тест 09: AVAudioSession

@MainActor
final class LessonVoiceWorkerAudioSessionTests: XCTestCase {

    // MARK: - 09. После speak с несуществующим словом AVAudioSession.category == .playback

    func test_audioSession_afterSpeakFallback_categoryIsPlayback() async {
        // Несуществующее слово → TTS fallback → ensurePlaybackSession() вызывается перед TTS
        let speakTask = Task {
            await LessonVoiceWorker.shared.speak("zzz_xtest_nonexistent_token_abc")
        }
        // 80ms достаточно чтобы ensurePlaybackSession() отработал (sync вызов до async TTS)
        try? await Task.sleep(nanoseconds: 80_000_000)
        LessonVoiceWorker.shared.stop()
        speakTask.cancel()

        let category = AVAudioSession.sharedInstance().category
        XCTAssertEqual(category, .playback,
                       "После speak() AVAudioSession.category должен быть .playback")
    }
}

// MARK: - Тест 10: Граничные случаи

@MainActor
final class LessonVoiceWorkerEdgeCaseTests: XCTestCase {

    // MARK: - 10a. Пустая строка → guard !text.isEmpty → возврат немедленно
    //
    // Используем XCTestExpectation с таймаутом вместо TaskGroup (Swift 6 sending).

    func test_speak_emptyString_returnsImmediatelyWithoutCrash() async {
        let expectation = expectation(description: "speak('') завершился")
        Task { @MainActor in
            await LessonVoiceWorker.shared.speak("")
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 0.3)
    }

    // MARK: - 10b. speak + немедленный stop() → завершается без зависания

    func test_speak_withImmediateStop_doesNotHang() async {
        let expectation = expectation(description: "speak('мяч') завершился после stop()")
        Task { @MainActor in
            await LessonVoiceWorker.shared.speak("мяч")
            expectation.fulfill()
        }
        try? await Task.sleep(nanoseconds: 20_000_000) // 20ms — дать Task запуститься
        LessonVoiceWorker.shared.stop()
        await fulfillment(of: [expectation], timeout: 0.5)
    }
}

// MARK: - Smoke-тесты: 9 Interactor'ов использующих LessonVoiceWorker
//
// Проверяем: init без краша + cancel/stop без краша.
// Это верхнеуровневые smoke-тесты — не тестируют бизнес-логику полностью.

@MainActor
final class LessonVoiceWorkerSmokeInteractorTests: XCTestCase {

    // MARK: - Smoke 1: BingoInteractor.cancel() без loadGame

    func test_bingo_cancel_beforeLoadGame_doesNotCrash() {
        let sut = BingoInteractor()
        XCTAssertNoThrow(
            sut.cancel(),
            "BingoInteractor.cancel() без loadGame не должен крашить"
        )
    }

    // MARK: - Smoke 2: ListenAndChooseInteractor инициализируется с ContentService mock

    func test_listenAndChoose_init_doesNotCrash() {
        XCTAssertNoThrow(
            { _ = ListenAndChooseInteractor(contentService: VWContentMock()) }(),
            "ListenAndChooseInteractor(contentService:) не должен крашить"
        )
    }

    // MARK: - Smoke 3: VisualAcousticInteractor инициализируется без параметров

    func test_visualAcoustic_init_doesNotCrash() {
        XCTAssertNoThrow(
            { _ = VisualAcousticInteractor() }(),
            "VisualAcousticInteractor() не должен крашить"
        )
    }

    // MARK: - Smoke 4: MinimalPairsInteractor инициализируется без параметров

    func test_minimalPairs_init_doesNotCrash() {
        XCTAssertNoThrow(
            { _ = MinimalPairsInteractor() }(),
            "MinimalPairsInteractor() не должен крашить"
        )
    }

    // MARK: - Smoke 5: StoryCompletionInteractor инициализируется (NSObject subclass)

    func test_storyCompletion_init_doesNotCrash() {
        XCTAssertNoThrow(
            { _ = StoryCompletionInteractor() }(),
            "StoryCompletionInteractor() не должен крашить"
        )
    }

    // MARK: - Smoke 6: NarrativeQuestInteractor инициализируется (presenter = nil)

    func test_narrativeQuest_init_doesNotCrash() {
        XCTAssertNoThrow(
            { _ = NarrativeQuestInteractor(presenter: nil) }(),
            "NarrativeQuestInteractor(presenter: nil) не должен крашить"
        )
    }

    // MARK: - Smoke 7: RhythmInteractor инициализируется с soundGroup

    func test_rhythm_init_doesNotCrash() {
        XCTAssertNoThrow(
            { _ = RhythmInteractor(soundGroup: "whistling") }(),
            "RhythmInteractor(soundGroup:) не должен крашить"
        )
    }

    // MARK: - Smoke 8: SortingInteractor инициализируется с HapticService mock

    func test_sorting_init_doesNotCrash() {
        XCTAssertNoThrow(
            { _ = SortingInteractor(hapticService: VWHapticMock()) }(),
            "SortingInteractor(hapticService:) не должен крашить"
        )
    }

    // MARK: - Smoke 9: MemoryInteractor инициализируется с HapticService mock

    func test_memory_init_doesNotCrash() {
        XCTAssertNoThrow(
            { _ = MemoryInteractor(hapticService: VWHapticMock()) }(),
            "MemoryInteractor(hapticService:) не должен крашить"
        )
    }
}
