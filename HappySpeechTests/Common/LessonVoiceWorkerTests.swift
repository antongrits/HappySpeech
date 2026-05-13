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
    var isAvailable: Bool { true }
    func play(pattern: HapticPattern) async {}
    func setIntensityScale(_ scale: Float) {}
    func stop() async {}
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

// MARK: - JSON lookup helper
//
// Block 3.2 v23: тесты грузят JSON из host app bundle.
//
// Path resolution:
//   • Test bundle живёт по пути `<HappySpeech.app>/PlugIns/HappySpeechTests.xctest/`.
//   • Из URL test-bundle уходим на 2 уровня вверх → получаем `HappySpeech.app/`.
//   • JSON копируется в корень app bundle (project.yml: HappySpeech/Resources/** → resources).
//   • `Bundle.main` в xctest = test helper, НЕ app — поэтому путь через test-bundle URL.
//
// JSON schema:
//   После плана v22 JSON стал гетерогенным: одни ключи отображаются в String
//   ("сани" → "sani"), другие — в объект с metadata
//   ("v18c/word_analysis_intro_v1.m4a" → { "text": "...", "category": "..." }).
//   Поэтому декодируем в `[String: JSONValue]` и оставляем только flat-mappings
//   (String → String). Тесты проверяют именно эти legacy-ключи.

private enum JSONValue: Decodable {
    case string(String)
    case object([String: JSONValue])
    case other

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .string(str)
        } else if let obj = try? container.decode([String: JSONValue].self) {
            self = .object(obj)
        } else {
            self = .other
        }
    }
}

private enum PhraseMappingLoader {
    static func appBundleURL(for testClass: AnyClass) -> URL {
        // .../HappySpeech.app/PlugIns/HappySpeechTests.xctest
        //   → .../HappySpeech.app/PlugIns
        //   → .../HappySpeech.app
        Bundle(for: testClass).bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// Загружает flat (String → String) подмножество маппинга.
    /// Игнорирует nested object entries (v18c/*.m4a → metadata dict).
    static func load(for testClass: AnyClass) -> [String: String] {
        let jsonURL = appBundleURL(for: testClass)
            .appendingPathComponent("lyalya-phrase-mapping.json")
        guard let data = try? Data(contentsOf: jsonURL),
              let raw = try? JSONDecoder().decode([String: JSONValue].self, from: data) else {
            return [:]
        }
        var flat: [String: String] = [:]
        for (key, value) in raw {
            if case .string(let str) = value {
                flat[key] = str
            }
        }
        return flat
    }
}

// MARK: - Тест 08: Загрузка маппинга

@MainActor
final class LessonVoiceWorkerMappingTests: XCTestCase {

    // MARK: - 08. JSON lyalya-phrase-mapping.json содержит как минимум 700 flat-записей
    //
    // Точное число flat-mappings (String→String) растёт со временем при добавлении
    // новых слов. Snapshot-assert на >= 700 защищает от регрессии (удалённые слова),
    // но не ломается при добавлении новых.

    func test_phraseMapping_loaded_atLeast700FlatEntries() {
        let mapping = PhraseMappingLoader.load(for: LessonVoiceWorkerMappingTests.self)
        XCTAssertFalse(mapping.isEmpty,
                       "lyalya-phrase-mapping.json должен быть в host app bundle (project.yml resources phase)")
        XCTAssertGreaterThanOrEqual(mapping.count, 700,
                                    "Ожидалось >= 700 flat-маппингов; получено \(mapping.count)")
    }
}

// MARK: - Тесты 01–04: Нормализация через JSON lookup

@MainActor
final class LessonVoiceWorkerNormalizationTests: XCTestCase {

    private var mapping: [String: String] = [:]

    override func setUp() async throws {
        try await super.setUp()
        mapping = PhraseMappingLoader.load(for: LessonVoiceWorkerNormalizationTests.self)
        XCTAssertFalse(mapping.isEmpty,
                       "Маппинг должен быть доступен в host app bundle")
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
        mapping = PhraseMappingLoader.load(for: LessonVoiceWorkerYoTests.self)
        XCTAssertFalse(mapping.isEmpty,
                       "Маппинг должен быть доступен в host app bundle")
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
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms — дать Task запуститься
        LessonVoiceWorker.shared.stop()
        // Таймаут 3s — TTS на симуляторе инициализируется медленнее физического устройства
        await fulfillment(of: [expectation], timeout: 3.0)
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
