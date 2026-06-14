@testable import HappySpeech
import XCTest

// MARK: - WordRhymeGameWorkerTests
//
// Покрытие чистой логики рифмовки игры «Найди рифму» (WordRhymeGameWorker).
// Интерактор уже покрыт через MockWorker — здесь тестируются именно статические
// pure-методы Worker'а, которые интерактор не достаёт:
//
//   • rhymeTail(of:) — извлечение рифмующегося «хвоста» (последние 2 буквы),
//     нормализация регистра/пробелов, отсев коротких слов (<3 букв), игнор
//     не-буквенных символов.
//   • makeRounds(from:) — группировка по хвосту, выбор слов-цели с рифмой,
//     подбор 2 дистракторов из НЕрифмующихся слов, лимит roundsPerSession,
//     корректность correctOptionId, отсутствие повторов целей.
//   • buildRounds(childId:) — async-путь через ChildRepository (включая пустой
//     childId и падение репозитория) с реальным KidWordContentProvider.
//
// Worker @MainActor → класс теста @MainActor.

@MainActor
final class WordRhymeGameWorkerTests: XCTestCase {

    // MARK: - Helpers

    private func word(_ text: String, id: String? = nil) -> KidWordContentProvider.GameWord {
        KidWordContentProvider.GameWord(
            id: id ?? "id-\(text)",
            text: text,
            asset: "word_\(text)",
            soundFamily: "Р"
        )
    }

    // MARK: - rhymeTail: базовая логика

    func test_rhymeTail_returnsLastTwoLetters() {
        XCTAssertEqual(WordRhymeGameWorker.rhymeTail(of: "кошка"), "ка")
        XCTAssertEqual(WordRhymeGameWorker.rhymeTail(of: "ложка"), "ка")
        XCTAssertEqual(WordRhymeGameWorker.rhymeTail(of: "рыба"), "ба")
    }

    func test_rhymeTail_isCaseInsensitive() {
        XCTAssertEqual(WordRhymeGameWorker.rhymeTail(of: "Кошка"),
                       WordRhymeGameWorker.rhymeTail(of: "кошка"))
        XCTAssertEqual(WordRhymeGameWorker.rhymeTail(of: "ДОМИК"),
                       WordRhymeGameWorker.rhymeTail(of: "домик"))
    }

    func test_rhymeTail_trimsWhitespace() {
        XCTAssertEqual(WordRhymeGameWorker.rhymeTail(of: "  кошка  "), "ка")
    }

    func test_rhymeTail_ignoresNonLetters() {
        // Дефис/пробел/цифры не считаются буквами — берутся последние 2 БУКВЫ.
        XCTAssertEqual(WordRhymeGameWorker.rhymeTail(of: "па-та"), "та")
    }

    func test_rhymeTail_tooShortReturnsEmpty() {
        // < 3 букв → пустой хвост (рифма не определяется).
        XCTAssertEqual(WordRhymeGameWorker.rhymeTail(of: "ум"), "")
        XCTAssertEqual(WordRhymeGameWorker.rhymeTail(of: "я"), "")
        XCTAssertEqual(WordRhymeGameWorker.rhymeTail(of: ""), "")
    }

    func test_rhymeTail_exactlyThreeLetters() {
        XCTAssertEqual(WordRhymeGameWorker.rhymeTail(of: "дом"), "ом")
    }

    func test_rhymeTail_rhymingWordsShareTail() {
        // Слова рифмуются ⇔ совпадает хвост.
        XCTAssertEqual(WordRhymeGameWorker.rhymeTail(of: "рак"),
                       WordRhymeGameWorker.rhymeTail(of: "мак"))
        XCTAssertNotEqual(WordRhymeGameWorker.rhymeTail(of: "рак"),
                          WordRhymeGameWorker.rhymeTail(of: "дом"))
    }

    // MARK: - makeRounds: пустой/недостаточный пул

    func test_makeRounds_emptyPool_returnsNoRounds() {
        XCTAssertTrue(WordRhymeGameWorker.makeRounds(from: []).isEmpty)
    }

    func test_makeRounds_noRhymingPairs_returnsNoRounds() {
        // Все хвосты разные → нет пар для рифмы → раундов нет.
        let pool = [word("кошка"), word("рыба"), word("домик"), word("стул")]
        let rounds = WordRhymeGameWorker.makeRounds(from: pool)
        XCTAssertTrue(rounds.isEmpty, "Без рифмующихся пар раунды не строятся")
    }

    // MARK: - makeRounds: одна рифмующаяся пара даёт раунд (если есть дистракторы)

    func test_makeRounds_singleRhymePairWithDistractors_buildsOneRound() {
        // кошка/ложка рифмуются (хвост «ка»); рыба/столб — дистракторы.
        let pool = [word("кошка"), word("ложка"), word("рыба"), word("столб")]
        let rounds = WordRhymeGameWorker.makeRounds(from: pool)
        XCTAssertEqual(rounds.count, 1)

        guard let round = rounds.first else {
            XCTFail("Ожидался ровно один раунд")
            return
        }
        // Цель — первое слово группы «ка».
        XCTAssertEqual(round.targetWord.lowercased(), "кошка")
        // 3 варианта: 1 рифма + 2 дистрактора.
        XCTAssertEqual(round.options.count, 3)
        // Правильный вариант реально присутствует и это рифма «ложка».
        let correct = round.options.first { $0.id == round.correctOptionId }
        XCTAssertNotNil(correct)
        XCTAssertEqual(correct?.word.lowercased(), "ложка")
    }

    // MARK: - makeRounds: правильный вариант рифмуется с целью, дистракторы — нет

    func test_makeRounds_correctOptionRhymes_distractorsDoNot() {
        let pool = [word("кошка"), word("ложка"), word("рыба"), word("банан")]
        let rounds = WordRhymeGameWorker.makeRounds(from: pool)
        guard let round = rounds.first else {
            XCTFail("Ожидался хотя бы один раунд")
            return
        }
        let targetTail = WordRhymeGameWorker.rhymeTail(of: round.targetWord)
        for option in round.options {
            let optionTail = WordRhymeGameWorker.rhymeTail(of: option.word)
            if option.id == round.correctOptionId {
                XCTAssertEqual(optionTail, targetTail, "Правильный вариант должен рифмоваться с целью")
            } else {
                XCTAssertNotEqual(optionTail, targetTail, "Дистрактор НЕ должен рифмоваться с целью")
            }
        }
    }

    // MARK: - makeRounds: correctOptionId всегда указывает на существующий вариант

    func test_makeRounds_correctOptionIdAlwaysResolves() {
        let pool = [
            word("кошка"), word("ложка"),
            word("рыба"), word("шуба"),
            word("ракета"), word("конфета"),
            word("банан"), word("диван")
        ]
        let rounds = WordRhymeGameWorker.makeRounds(from: pool)
        XCTAssertFalse(rounds.isEmpty)
        for round in rounds {
            let ids = Set(round.options.map(\.id))
            XCTAssertTrue(ids.contains(round.correctOptionId),
                          "correctOptionId '\(round.correctOptionId)' отсутствует среди options")
            XCTAssertEqual(round.options.count, 3, "Каждый раунд имеет ровно 3 варианта")
        }
    }

    // MARK: - makeRounds: лимит roundsPerSession

    func test_makeRounds_capsAtRoundsPerSession() {
        // Готовим МНОГО рифмующихся пар (больше, чем roundsPerSession=6).
        var pool: [KidWordContentProvider.GameWord] = []
        let pairs = [
            ("кошка", "ложка"), ("рыба", "шуба"), ("ракета", "конфета"),
            ("банан", "диван"), ("мишка", "книжка"), ("лужа", "стужа"),
            ("каша", "Маша"), ("сова", "трава"), ("рука", "мука")
        ]
        for (a, b) in pairs {
            pool.append(word(a))
            pool.append(word(b))
        }
        let rounds = WordRhymeGameWorker.makeRounds(from: pool)
        XCTAssertLessThanOrEqual(rounds.count, WordRhymeGameWorker.roundsPerSession,
            "Число раундов не превышает roundsPerSession=\(WordRhymeGameWorker.roundsPerSession)")
    }

    // MARK: - makeRounds: цели не повторяются между раундами

    func test_makeRounds_targetsAreUnique() {
        let pool = [
            word("кошка"), word("ложка"),
            word("рыба"), word("шуба"),
            word("ракета"), word("конфета")
        ]
        let rounds = WordRhymeGameWorker.makeRounds(from: pool)
        let targets = rounds.map { $0.targetWord.lowercased() }
        XCTAssertEqual(Set(targets).count, targets.count, "Слова-цели не должны повторяться")
    }

    // MARK: - makeRounds: слова короче 3 букв (пустой хвост) пропускаются

    func test_makeRounds_skipsWordsWithEmptyTail() {
        // «ум»/«ах» дают пустой хвост → не образуют рифму-группу.
        let pool = [word("ум"), word("ах"), word("ёж"), word("уж")]
        let rounds = WordRhymeGameWorker.makeRounds(from: pool)
        XCTAssertTrue(rounds.isEmpty)
    }

    // MARK: - buildRounds (async): пустой childId не падает и не лезет в репозиторий

    func test_buildRounds_emptyChildId_usesDefaultGroupWithoutFetch() async {
        let repo = RhymeSpyChildRepository()
        let worker = WordRhymeGameWorker(childRepository: repo)
        let rounds = await worker.buildRounds(childId: "")
        XCTAssertFalse(repo.fetchCalled, "При пустом childId репозиторий не должен запрашиваться")
        // Контент берётся из реального KidWordContentProvider (свистящие по дефолту)
        // — раунды могут быть, но главное: нет краша и контракт соблюдён.
        for round in rounds {
            XCTAssertEqual(round.options.count, 3)
            XCTAssertTrue(round.options.contains { $0.id == round.correctOptionId })
        }
    }

    // MARK: - buildRounds (async): валидный childId → fetch вызван

    func test_buildRounds_validChildId_fetchesTargetSounds() async {
        let child = ChildProfileDTO(
            id: "c1", name: "Тест", age: 6, targetSounds: ["Р", "Л"], parentId: "p1"
        )
        let repo = RhymeSpyChildRepository(children: [child])
        let worker = WordRhymeGameWorker(childRepository: repo)
        let rounds = await worker.buildRounds(childId: "c1")
        XCTAssertTrue(repo.fetchCalled, "Для непустого childId Worker запрашивает профиль")
        XCTAssertEqual(repo.lastFetchedId, "c1")
        // Раунды (если есть) корректны по контракту.
        XCTAssertLessThanOrEqual(rounds.count, WordRhymeGameWorker.roundsPerSession)
    }

    // MARK: - buildRounds (async): падение репозитория обрабатывается мягко

    func test_buildRounds_repositoryThrows_doesNotCrash() async {
        let repo = RhymeSpyChildRepository(children: [])  // fetch(id:) бросит entityNotFound
        let worker = WordRhymeGameWorker(childRepository: repo)
        let rounds = await worker.buildRounds(childId: "missing")
        XCTAssertTrue(repo.fetchCalled)
        // Ошибка проглочена → fallback на дефолтную группу, без краша.
        XCTAssertLessThanOrEqual(rounds.count, WordRhymeGameWorker.roundsPerSession)
    }
}

// MARK: - RhymeSpyChildRepository

/// Шпион поверх логики MockChildRepository: фиксирует факт/аргумент вызова fetch.
private final class RhymeSpyChildRepository: ChildRepository, @unchecked Sendable {
    private let children: [ChildProfileDTO]
    private(set) var fetchCalled = false
    private(set) var lastFetchedId: String?

    init(children: [ChildProfileDTO] = [.preview]) {
        self.children = children
    }

    func fetchAll() async throws -> [ChildProfileDTO] { children }

    func fetch(id: String) async throws -> ChildProfileDTO {
        fetchCalled = true
        lastFetchedId = id
        guard let child = children.first(where: { $0.id == id }) else {
            throw AppError.entityNotFound(id)
        }
        return child
    }

    func save(_ profile: ChildProfileDTO) async throws {}
    func delete(id: String) async throws {}
    func updateProgress(childId: String, sound: String, rate: Double) async throws {}
    func updateStreak(childId: String, streak: Int) async throws {}
    func updateSessionAggregates(
        childId: String,
        lastSessionAt: Date,
        addedMinutes: Int,
        streak: Int
    ) async throws {}
}
