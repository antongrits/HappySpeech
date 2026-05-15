@testable import HappySpeech
import XCTest

// MARK: - LLMPromptsTests
//
// Phase 2.4 v25 — покрытие LLMPrompts.
// Тестируется: render(), token budgets, корректность структуры промптов.

final class LLMPromptsTests: XCTestCase {

    // MARK: - Token budgets: все > 0

    func test_maxTokens_routePlan_positive() {
        XCTAssertGreaterThan(LLMPrompts.MaxTokens.routePlan, 0)
    }

    func test_maxTokens_encouragement_smallerThanReport() {
        XCTAssertLessThan(LLMPrompts.MaxTokens.encouragement, LLMPrompts.MaxTokens.specialistReport)
    }

    func test_maxTokens_allPositive() {
        let budgets = [
            LLMPrompts.MaxTokens.routePlan,
            LLMPrompts.MaxTokens.microStory,
            LLMPrompts.MaxTokens.parentSummary,
            LLMPrompts.MaxTokens.encouragement,
            LLMPrompts.MaxTokens.reward,
            LLMPrompts.MaxTokens.finishSession,
            LLMPrompts.MaxTokens.adjustDifficulty,
            LLMPrompts.MaxTokens.errorAnalysis,
            LLMPrompts.MaxTokens.contentRecommend,
            LLMPrompts.MaxTokens.specialistReport,
            LLMPrompts.MaxTokens.fatigueDetection,
            LLMPrompts.MaxTokens.customPhrase
        ]
        for budget in budgets {
            XCTAssertGreaterThan(budget, 0, "Бюджет токенов должен быть > 0: \(budget)")
        }
    }

    // MARK: - Системные промпты: не пустые

    func test_systemRoutePlan_notEmpty() {
        XCTAssertFalse(LLMPrompts.systemRoutePlan.isEmpty)
    }

    func test_systemMicroStory_notEmpty() {
        XCTAssertFalse(LLMPrompts.systemMicroStory.isEmpty)
    }

    func test_systemParentSummary_notEmpty() {
        XCTAssertFalse(LLMPrompts.systemParentSummary.isEmpty)
    }

    func test_systemEncouragement_notEmpty() {
        XCTAssertFalse(LLMPrompts.systemEncouragement.isEmpty)
    }

    func test_systemReward_notEmpty() {
        XCTAssertFalse(LLMPrompts.systemReward.isEmpty)
    }

    func test_systemFinishSession_notEmpty() {
        XCTAssertFalse(LLMPrompts.systemFinishSession.isEmpty)
    }

    func test_systemAdjustDifficulty_notEmpty() {
        XCTAssertFalse(LLMPrompts.systemAdjustDifficulty.isEmpty)
    }

    func test_systemErrorAnalysis_notEmpty() {
        XCTAssertFalse(LLMPrompts.systemErrorAnalysis.isEmpty)
    }

    func test_systemContentRecommend_notEmpty() {
        XCTAssertFalse(LLMPrompts.systemContentRecommend.isEmpty)
    }

    func test_systemSpecialistReport_notEmpty() {
        XCTAssertFalse(LLMPrompts.systemSpecialistReport.isEmpty)
    }

    func test_systemFatigueDetection_notEmpty() {
        XCTAssertFalse(LLMPrompts.systemFatigueDetection.isEmpty)
    }

    func test_systemCustomPhrase_notEmpty() {
        XCTAssertFalse(LLMPrompts.systemCustomPhrase.isEmpty)
    }

    // MARK: - render(): базовые случаи

    func test_render_singlePlaceholder_substituted() {
        let result = LLMPrompts.render("Привет, {name}!", values: ["name": "Маша"])
        XCTAssertEqual(result, "Привет, Маша!")
    }

    func test_render_multiplePlaceholders_allSubstituted() {
        let result = LLMPrompts.render(
            "{child_name} {age} лет, звук {target_sound}",
            values: ["child_name": "Ваня", "age": "6", "target_sound": "Р"]
        )
        XCTAssertEqual(result, "Ваня 6 лет, звук Р")
    }

    func test_render_noPlaceholders_unchanged() {
        let template = "Просто текст без заменителей."
        let result = LLMPrompts.render(template, values: ["key": "val"])
        XCTAssertEqual(result, template)
    }

    func test_render_emptyValues_unchanged() {
        let template = "Текст с {placeholder}."
        let result = LLMPrompts.render(template, values: [:])
        XCTAssertEqual(result, template)
    }

    func test_render_extraValues_ignored() {
        let result = LLMPrompts.render("Привет {name}!", values: ["name": "Катя", "extra": "лишнее"])
        XCTAssertEqual(result, "Привет Катя!")
    }

    func test_render_unknownPlaceholder_remains() {
        let result = LLMPrompts.render("{known} и {unknown}", values: ["known": "A"])
        XCTAssertEqual(result, "A и {unknown}")
    }

    func test_render_emptyTemplate_emptyResult() {
        let result = LLMPrompts.render("", values: ["k": "v"])
        XCTAssertEqual(result, "")
    }

    // MARK: - Пользовательские шаблоны: содержат ключевые плейсхолдеры

    func test_userRoutePlanTemplate_containsChildName() {
        XCTAssertTrue(LLMPrompts.userRoutePlanTemplate.contains("{child_name}"))
    }

    func test_userMicroStoryTemplate_containsTargetSound() {
        XCTAssertTrue(LLMPrompts.userMicroStoryTemplate.contains("{target_sound}"))
    }

    func test_userParentSummaryTemplate_containsRate() {
        XCTAssertTrue(LLMPrompts.userParentSummaryTemplate.contains("{rate}"))
    }

    func test_userEncouragementTemplate_containsResult() {
        XCTAssertTrue(LLMPrompts.userEncouragementTemplate.contains("{result}"))
    }

    func test_userRewardTemplate_containsStreak() {
        XCTAssertTrue(LLMPrompts.userRewardTemplate.contains("{streak}"))
    }

    func test_userFinishSessionTemplate_containsFatigue() {
        XCTAssertTrue(LLMPrompts.userFinishSessionTemplate.contains("{fatigue}"))
    }

    func test_userAdjustDifficultyTemplate_containsAttempts() {
        XCTAssertTrue(LLMPrompts.userAdjustDifficultyTemplate.contains("{attempts_json}"))
    }

    func test_userErrorAnalysisTemplate_containsAsrTranscript() {
        XCTAssertTrue(LLMPrompts.userErrorAnalysisTemplate.contains("{asr_transcript}"))
    }

    func test_userContentRecommendTemplate_containsTargetSounds() {
        XCTAssertTrue(LLMPrompts.userContentRecommendTemplate.contains("{target_sounds}"))
    }

    func test_userSpecialistReportTemplate_containsSessionsJson() {
        XCTAssertTrue(LLMPrompts.userSpecialistReportTemplate.contains("{sessions_json}"))
    }

    func test_userFatigueDetectionTemplate_containsSilenceRatio() {
        XCTAssertTrue(LLMPrompts.userFatigueDetectionTemplate.contains("{silence_ratio}"))
    }

    func test_userCustomPhraseTemplate_containsTemplateType() {
        XCTAssertTrue(LLMPrompts.userCustomPhraseTemplate.contains("{template_type}"))
    }

    // MARK: - Системные промпты содержат "JSON"

    func test_systemPrompts_allMentionJSON() {
        let systems = [
            LLMPrompts.systemRoutePlan,
            LLMPrompts.systemMicroStory,
            LLMPrompts.systemParentSummary,
            LLMPrompts.systemEncouragement,
            LLMPrompts.systemReward,
            LLMPrompts.systemFinishSession,
            LLMPrompts.systemAdjustDifficulty,
            LLMPrompts.systemErrorAnalysis,
            LLMPrompts.systemContentRecommend,
            LLMPrompts.systemSpecialistReport,
            LLMPrompts.systemFatigueDetection,
            LLMPrompts.systemCustomPhrase
        ]
        for system in systems {
            XCTAssertTrue(system.uppercased().contains("JSON"),
                "Системный промпт должен упоминать JSON: \(system.prefix(60))...")
        }
    }

    // MARK: - render() с шаблоном encouragement (end-to-end)

    func test_render_encouragementTemplate_substitutesAll() {
        let values: [String: String] = [
            "child_name": "Маша",
            "word": "рыба",
            "target_sound": "Р",
            "result": "правильно",
            "streak": "3"
        ]
        let result = LLMPrompts.render(LLMPrompts.userEncouragementTemplate, values: values)
        // Проверяем что конкретные плейсхолдеры заменены (не проверяем JSON-фигурные скобки шаблона)
        for key in values.keys {
            XCTAssertFalse(result.contains("{\(key)}"), "Плейсхолдер {\(key)} должен быть заменён")
        }
        XCTAssertTrue(result.contains("Маша"))
        XCTAssertTrue(result.contains("рыба"))
    }
}
