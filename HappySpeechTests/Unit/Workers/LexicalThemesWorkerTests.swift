@testable import HappySpeech
import XCTest

// MARK: - LexicalThemesWorkerTests
//
// Фаза E, Волна 7. Покрывает: loadThemes (порог освоения ≥0.75 + парсинг
// префикса lex.), buildThemeSession (методическая прогрессия раундов, лимит
// roundsPerSession, неизвестная тема → nil). FSRS-методы recordReview/dueCount
// требуют RealmActor — покрыт path "без realmActor" (граница: dueCount = 0,
// recordReview — no-op). Полная FSRS-математика покрыта FSRSSchedulerTests.

@MainActor
final class LexicalThemesWorkerTests: XCTestCase {

    private func child(
        id: String = "c-1",
        progress: [String: Double] = [:]
    ) -> ChildProfileDTO {
        ChildProfileDTO(id: id, name: "Тест", age: 7, targetSounds: ["Р"],
                        parentId: "p-1", progressSummary: progress)
    }

    private func firstThemeId() throws -> String {
        guard let id = LexicalThemesCorpus.themes.first?.id else {
            throw XCTSkip("Корпус лексических тем пуст в тест-таргете")
        }
        return id
    }

    // MARK: - loadThemes: mastery threshold

    func test_loadThemes_returnsCorpusThemes() async {
        let repo = MockChildRepository(children: [child()])
        let sut = LexicalThemesWorker(childRepository: repo)

        let response = await sut.loadThemes(childId: "c-1")

        XCTAssertEqual(response.themes.map(\.id), LexicalThemesCorpus.themes.map(\.id))
    }

    func test_loadThemes_marksThemeMasteredWhenRateAtThreshold() async throws {
        let themeId = try firstThemeId()
        let repo = MockChildRepository(children: [
            child(progress: ["lex.\(themeId)": 0.75])
        ])
        let sut = LexicalThemesWorker(childRepository: repo)

        let response = await sut.loadThemes(childId: "c-1")

        XCTAssertTrue(response.masteredThemeIds.contains(themeId),
                      "0.75 — на пороге, тема освоена")
    }

    func test_loadThemes_belowThreshold_notMastered() async throws {
        let themeId = try firstThemeId()
        let repo = MockChildRepository(children: [
            child(progress: ["lex.\(themeId)": 0.74])
        ])
        let sut = LexicalThemesWorker(childRepository: repo)

        let response = await sut.loadThemes(childId: "c-1")

        XCTAssertFalse(response.masteredThemeIds.contains(themeId))
    }

    func test_loadThemes_ignoresNonLexPrefixedKeys() async {
        let repo = MockChildRepository(children: [
            child(progress: ["Р": 0.9, "lex.": 0.9])
        ])
        let sut = LexicalThemesWorker(childRepository: repo)

        let response = await sut.loadThemes(childId: "c-1")

        // "Р" не имеет префикса lex. → не считается темой.
        XCTAssertFalse(response.masteredThemeIds.contains("Р"))
    }

    func test_loadThemes_repositoryFailure_returnsThemesWithEmptyMastery() async {
        let repo = MockChildRepository(children: [])
        let sut = LexicalThemesWorker(childRepository: repo)

        let response = await sut.loadThemes(childId: "missing")

        XCTAssertTrue(response.masteredThemeIds.isEmpty)
        XCTAssertEqual(response.themes.map(\.id), LexicalThemesCorpus.themes.map(\.id))
    }

    // MARK: - buildThemeSession: progression + limits

    func test_buildThemeSession_unknownTheme_returnsNil() {
        let repo = MockChildRepository(children: [child()])
        let sut = LexicalThemesWorker(childRepository: repo)

        XCTAssertNil(sut.buildThemeSession(themeId: "no-such-theme"))
    }

    func test_buildThemeSession_knownTheme_buildsBoundedRounds() throws {
        let themeId = try firstThemeId()
        let repo = MockChildRepository(children: [child()])
        let sut = LexicalThemesWorker(childRepository: repo)

        let response = try XCTUnwrap(sut.buildThemeSession(themeId: themeId))

        XCTAssertEqual(response.theme.id, themeId)
        XCTAssertFalse(response.rounds.isEmpty)
        // Не больше лимита сессии и не больше числа слов темы.
        let cap = min(LexicalThemesCorpus.roundsPerSession, response.theme.words.count)
        XCTAssertLessThanOrEqual(response.rounds.count, cap)
    }

    func test_buildThemeSession_roundsFollowMethodicalKindOrder() throws {
        let themeId = try firstThemeId()
        let repo = MockChildRepository(children: [child()])
        let sut = LexicalThemesWorker(childRepository: repo)

        let response = try XCTUnwrap(sut.buildThemeSession(themeId: themeId))

        // Прогрессия типов: naming → generalization → oddOneOut → action.
        let kinds = response.rounds.map(\.kind)
        let expectedOrder: [LexicalGameKind] = [.naming, .generalization, .oddOneOut, .action]
        // Каждый присутствующий kind должен идти не раньше своего места в прогрессии.
        var lastRank = -1
        for kind in kinds {
            let rank = expectedOrder.firstIndex(of: kind) ?? Int.max
            XCTAssertGreaterThanOrEqual(rank, lastRank,
                "Раунды должны идти по методической прогрессии")
            lastRank = rank
        }
    }

    func test_buildThemeSession_roundsBelongToTheme() throws {
        let themeId = try firstThemeId()
        let repo = MockChildRepository(children: [child()])
        let sut = LexicalThemesWorker(childRepository: repo)

        let response = try XCTUnwrap(sut.buildThemeSession(themeId: themeId))
        XCTAssertTrue(response.rounds.allSatisfy { $0.themeId == themeId })
    }

    // MARK: - FSRS path without realmActor (boundary)

    func test_dueCount_withoutRealmActor_returnsZero() async {
        let repo = MockChildRepository(children: [child()])
        let sut = LexicalThemesWorker(childRepository: repo) // realmActor = nil

        let count = await sut.dueCount(childId: "c-1", at: Date())
        XCTAssertEqual(count, 0)
    }

    func test_recordReview_withoutRealmActor_doesNotCrash() async {
        let repo = MockChildRepository(children: [child()])
        let sut = LexicalThemesWorker(childRepository: repo)
        await sut.recordReview(childId: "c-1", wordId: "w-1", wasCorrect: true)
    }
}
