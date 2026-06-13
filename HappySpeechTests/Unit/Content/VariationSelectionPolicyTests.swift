@testable import HappySpeech
import XCTest

// MARK: - VariationSelectionPolicyTests (gap #2)
// ==================================================================================
// Чистая детерминированная логика подбора РЕАЛЬНОЙ вариации контента под шаг
// маршрута по сигналам ребёнка (усталость / успешность / EF / ротация тем).
// Все кандидаты синтетические, но структурно идентичны `GeneratedActivity`
// генератора — тесты проверяют ИМЕННО политику выбора (без бандл-паков).
// ==================================================================================

// MARK: - GeneratedActivity factory (тест-стаб)

private extension GeneratedActivity {
    /// Собирает активность с заданными параметрами и одним реальным-подобным item.
    static func make(
        sound: String = "С",
        kind: Kind = .sound,
        stage: CorrectionStage = .wordInit,
        theme: String? = nil,
        template: TemplateType = .listenAndChoose,
        minAge: Int = 5,
        difficultyBand: ClosedRange<Int> = 2...2,
        itemCount: Int = 4
    ) -> GeneratedActivity {
        let items = (0..<itemCount).map { idx in
            ContentItem(
                id: "\(sound)-\(stage.rawValue)-\(theme ?? "x")-\(idx)",
                word: "слово\(idx)",
                imageAsset: "word_\(idx)",
                audioAsset: nil,
                hint: nil,
                stage: stage,
                difficulty: difficultyBand.lowerBound
            )
        }
        let themePart = theme.map { "_\($0)" } ?? ""
        return GeneratedActivity(
            id: "gen_\(sound)_\(stage.rawValue)\(themePart)_\(template.rawValue)_d\(difficultyBand.upperBound)",
            kind: kind,
            sound: sound,
            contrastSound: nil,
            stage: stage,
            theme: theme,
            template: template,
            minAge: minAge,
            difficultyBand: difficultyBand,
            items: items,
            requiresMic: false
        )
    }
}

private extension ChildAdaptiveSignals {
    static func make(
        workingStage: CorrectionStage = .wordInit,
        fatigue: FatigueLevel = .fresh,
        recentSuccessRate: Double = 0.7,
        easinessFactor: Double = 2.5,
        consecutiveWrong: Int = 0,
        themeRotationSeed: Int = 0
    ) -> ChildAdaptiveSignals {
        ChildAdaptiveSignals(
            workingStage: workingStage,
            fatigue: fatigue,
            recentSuccessRate: recentSuccessRate,
            easinessFactor: easinessFactor,
            consecutiveWrong: consecutiveWrong,
            themeRotationSeed: themeRotationSeed
        )
    }
}

final class VariationSelectionPolicyTests: XCTestCase {

    // MARK: - DifficultyIntent

    func testIntent_tiredChild_isEasiest() {
        let signals = ChildAdaptiveSignals.make(fatigue: .tired, recentSuccessRate: 0.95, easinessFactor: 2.8)
        XCTAssertEqual(VariationSelectionPolicy.difficultyIntent(for: signals), .easiest,
                       "усталость перекрывает всё — самая лёгкая вариация")
    }

    func testIntent_strugglingStreak_isEasiest() {
        let signals = ChildAdaptiveSignals.make(fatigue: .fresh, recentSuccessRate: 0.9,
                                                easinessFactor: 2.8, consecutiveWrong: 2)
        XCTAssertEqual(VariationSelectionPolicy.difficultyIntent(for: signals), .easiest,
                       "серия ошибок → упрощаем даже на свежести")
    }

    func testIntent_confidentFresh_isChallenging() {
        let signals = ChildAdaptiveSignals.make(fatigue: .fresh, recentSuccessRate: 0.9, easinessFactor: 2.5)
        XCTAssertEqual(VariationSelectionPolicy.difficultyIntent(for: signals), .challenging,
                       "уверен + свеж → повышаем сложность")
    }

    func testIntent_lowSuccess_isEasiest() {
        let signals = ChildAdaptiveSignals.make(fatigue: .normal, recentSuccessRate: 0.4, easinessFactor: 2.0)
        XCTAssertEqual(VariationSelectionPolicy.difficultyIntent(for: signals), .easiest,
                       "низкая успешность → errorless практика")
    }

    func testIntent_midrange_isModerate() {
        let signals = ChildAdaptiveSignals.make(fatigue: .normal, recentSuccessRate: 0.7, easinessFactor: 2.2)
        XCTAssertEqual(VariationSelectionPolicy.difficultyIntent(for: signals), .moderate,
                       "средние сигналы → умеренная сложность")
    }

    // MARK: - allowsThemedVariation

    func testThemed_notAllowedWhenTired() {
        let signals = ChildAdaptiveSignals.make(fatigue: .tired, recentSuccessRate: 0.95)
        XCTAssertFalse(VariationSelectionPolicy.allowsThemedVariation(for: signals))
    }

    func testThemed_notAllowedWhenStruggling() {
        let signals = ChildAdaptiveSignals.make(fatigue: .fresh, recentSuccessRate: 0.95, consecutiveWrong: 2)
        XCTAssertFalse(VariationSelectionPolicy.allowsThemedVariation(for: signals))
    }

    func testThemed_notAllowedWhenLowSuccess() {
        let signals = ChildAdaptiveSignals.make(fatigue: .fresh, recentSuccessRate: 0.6)
        XCTAssertFalse(VariationSelectionPolicy.allowsThemedVariation(for: signals),
                       "ниже порога высокой успешности — без тематической нагрузки")
    }

    func testThemed_allowedWhenFreshAndHighSuccess() {
        let signals = ChildAdaptiveSignals.make(fatigue: .fresh, recentSuccessRate: 0.9)
        XCTAssertTrue(VariationSelectionPolicy.allowsThemedVariation(for: signals))
    }

    // MARK: - selectVariation: совместимость

    func testSelect_returnsNilWhenNoTemplateMatch() {
        let candidates = [GeneratedActivity.make(template: .sorting)]
        let result = VariationSelectionPolicy.selectVariation(
            template: .memory, stage: .wordInit, candidates: candidates,
            signals: .make(), childAge: 6
        )
        XCTAssertNil(result, "нет кандидата с нужным шаблоном — nil (шаг остаётся базовым)")
    }

    func testSelect_returnsNilWhenStageMismatch() {
        let candidates = [GeneratedActivity.make(stage: .syllable, template: .listenAndChoose)]
        let result = VariationSelectionPolicy.selectVariation(
            template: .listenAndChoose, stage: .wordFinal, candidates: candidates,
            signals: .make(), childAge: 6
        )
        XCTAssertNil(result, "звуковой кандидат другого этапа не подходит")
    }

    func testSelect_respectsAgeGate() {
        let candidates = [GeneratedActivity.make(template: .listenAndChoose, minAge: 7)]
        let young = VariationSelectionPolicy.selectVariation(
            template: .listenAndChoose, stage: .wordInit, candidates: candidates,
            signals: .make(), childAge: 5
        )
        XCTAssertNil(young, "возрастной гейт отсекает вариацию 7+ для 5-летнего")
        let older = VariationSelectionPolicy.selectVariation(
            template: .listenAndChoose, stage: .wordInit, candidates: candidates,
            signals: .make(), childAge: 8
        )
        XCTAssertNotNil(older, "8-летнему вариация 7+ доступна")
    }

    func testSelect_themedCandidateMatchesPositionalStep() {
        // Тематический кандидат нормализован к wordInit — должен подойти к wordMed.
        let candidates = [
            GeneratedActivity.make(kind: .themed, stage: .wordInit, theme: "animals", template: .listenAndChoose)
        ]
        let result = VariationSelectionPolicy.selectVariation(
            template: .listenAndChoose, stage: .wordMed, candidates: candidates,
            signals: .make(fatigue: .fresh, recentSuccessRate: 0.9), childAge: 6
        )
        XCTAssertEqual(result?.theme, "animals",
                       "тематический wordInit-кандидат подходит для позиционного шага wordMed")
    }

    // MARK: - selectVariation: сложностной выбор

    func testSelect_easiestPicksLowestDifficulty() {
        let candidates = [
            GeneratedActivity.make(template: .listenAndChoose, difficultyBand: 1...1),
            GeneratedActivity.make(template: .listenAndChoose, difficultyBand: 3...3),
            GeneratedActivity.make(template: .listenAndChoose, difficultyBand: 2...2)
        ]
        // tired → easiest
        let result = VariationSelectionPolicy.selectVariation(
            template: .listenAndChoose, stage: .wordInit, candidates: candidates,
            signals: .make(fatigue: .tired), childAge: 6
        )
        XCTAssertEqual(result?.difficultyBand, 1...1, "усталость → самая лёгкая вариация")
    }

    func testSelect_challengingPicksHighestDifficulty() {
        let candidates = [
            GeneratedActivity.make(template: .listenAndChoose, difficultyBand: 1...1),
            GeneratedActivity.make(template: .listenAndChoose, difficultyBand: 4...4),
            GeneratedActivity.make(template: .listenAndChoose, difficultyBand: 2...2)
        ]
        let result = VariationSelectionPolicy.selectVariation(
            template: .listenAndChoose, stage: .wordInit, candidates: candidates,
            signals: .make(fatigue: .fresh, recentSuccessRate: 0.9, easinessFactor: 2.6), childAge: 6
        )
        XCTAssertEqual(result?.difficultyBand, 4...4, "уверенный свежий ребёнок → максимальная сложность")
    }

    // MARK: - selectVariation: тематический режим

    func testSelect_prefersThemedWhenAllowed() {
        let candidates = [
            GeneratedActivity.make(kind: .sound, stage: .wordInit, theme: nil, template: .listenAndChoose, difficultyBand: 2...2),
            GeneratedActivity.make(kind: .themed, stage: .wordInit, theme: "food", template: .listenAndChoose, difficultyBand: 2...2)
        ]
        let result = VariationSelectionPolicy.selectVariation(
            template: .listenAndChoose, stage: .wordInit, candidates: candidates,
            signals: .make(fatigue: .fresh, recentSuccessRate: 0.9), childAge: 6
        )
        XCTAssertEqual(result?.kind, .themed, "при разрешающих сигналах предпочитаем тематическую вариацию")
        XCTAssertEqual(result?.theme, "food")
    }

    func testSelect_avoidsThemedWhenTired() {
        let candidates = [
            GeneratedActivity.make(kind: .sound, stage: .wordInit, theme: nil, template: .listenAndChoose, difficultyBand: 1...1),
            GeneratedActivity.make(kind: .themed, stage: .wordInit, theme: "food", template: .listenAndChoose, difficultyBand: 1...1)
        ]
        let result = VariationSelectionPolicy.selectVariation(
            template: .listenAndChoose, stage: .wordInit, candidates: candidates,
            signals: .make(fatigue: .tired), childAge: 6
        )
        XCTAssertEqual(result?.kind, .sound, "усталость → внетематическая звуковая работа")
    }

    func testSelect_fallsBackToThemedWhenNoNonThemedAvailable() {
        // Только тематический кандидат, ребёнок устал (темы не разрешены) — но лучше
        // реальный тематический контент, чем пропуск шага.
        let candidates = [
            GeneratedActivity.make(kind: .themed, stage: .wordInit, theme: "food", template: .listenAndChoose)
        ]
        let result = VariationSelectionPolicy.selectVariation(
            template: .listenAndChoose, stage: .wordInit, candidates: candidates,
            signals: .make(fatigue: .tired), childAge: 6
        )
        XCTAssertNotNil(result, "если внетематических нет — мягкий откат к тематической вариации")
        XCTAssertEqual(result?.kind, .themed)
    }

    // MARK: - Ротация тем (детерминизм)

    func testThemeRotation_isDeterministicAndCycles() {
        let themed = [
            GeneratedActivity.make(kind: .themed, theme: "animals", template: .listenAndChoose),
            GeneratedActivity.make(kind: .themed, theme: "food", template: .listenAndChoose),
            GeneratedActivity.make(kind: .themed, theme: "toys", template: .listenAndChoose)
        ]
        let themes = VariationSelectionPolicy.sortedThemes(in: themed)
        XCTAssertEqual(themes, ["animals", "food", "toys"], "темы в стабильном лексикографическом порядке")

        // seed циклически выбирает тему — детерминированно.
        func chosenTheme(seed: Int) -> String? {
            VariationSelectionPolicy.selectVariation(
                template: .listenAndChoose, stage: .wordInit, candidates: themed,
                signals: .make(fatigue: .fresh, recentSuccessRate: 0.9, themeRotationSeed: seed),
                childAge: 6
            )?.theme
        }
        XCTAssertEqual(chosenTheme(seed: 0), "animals")
        XCTAssertEqual(chosenTheme(seed: 1), "food")
        XCTAssertEqual(chosenTheme(seed: 2), "toys")
        XCTAssertEqual(chosenTheme(seed: 3), "animals", "ротация зацикливается (mod count)")
        // Повторный вызов с тем же seed — тот же результат (детерминизм).
        XCTAssertEqual(chosenTheme(seed: 1), "food")
    }

    // MARK: - pickByDifficulty (тай-брейк по id)

    func testPickByDifficulty_stableTieBreakById() {
        let a = GeneratedActivity.make(sound: "С", template: .memory, difficultyBand: 2...2)
        let b = GeneratedActivity.make(sound: "Ш", template: .memory, difficultyBand: 2...2)
        let picked = VariationSelectionPolicy.pickByDifficulty(from: [b, a], intent: .easiest)
        // Оба difficulty=2 → тай-брейк по меньшему id; порядок входа не влияет.
        XCTAssertEqual(picked?.id, min(a.id, b.id), "равная сложность → стабильный тай-брейк по id")
    }
}
