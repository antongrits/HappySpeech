import Foundation
import OSLog

// MARK: - LocalLLMServiceLive
// ==================================================================================
// Реализует LocalLLMService через on-device Qwen2.5-1.5B-Instruct (MLX Swift).
//
// Tier A (arm64): MLX inference → ChildSafetyValidator → парсинг → rule-based если нужно.
// Tier C (x86_64 / модель недоступна): rule-based напрямую.
//
// Модель поставляется внутри бандла приложения (`Resources/Models/LLM/`) —
// загрузок во время работы нет, модель доступна полностью offline.
// Загрузка в память — lazy, при первом обращении (см. `MLXEngine`).
// ==================================================================================

public final class LocalLLMServiceLive: LocalLLMService, @unchecked Sendable {

    // MARK: - State

    nonisolated(unsafe) private var _isModelLoaded: Bool = false

    /// Модель встроена в бандл — всегда доступна.
    public var isModelDownloaded: Bool { LLMModelManager.bundledModelURL(for: .qwen15b) != nil }
    public var isModelLoaded: Bool { _isModelLoaded }

    public init() {}

    /// Идентификатор встроенной MLX 4-bit модели Qwen2.5-1.5B.
    public static let mlxModelId = "mlx-community/Qwen2.5-1.5B-Instruct-4bit"

    // MARK: - Generate: Parent Summary

    public func generateParentSummary(request: ParentSummaryRequest) async throws -> ParentSummaryResponse {
#if arch(arm64)
        do {
            let prompt = buildParentSummaryPrompt(request: request)
            let raw = try await MLXEngine.shared.generate(
                prompt: prompt,
                maxTokens: 256,
                temperature: 0.3
            )
            if ChildSafetyValidator.validate(raw), let parsed = parseParentSummaryJSON(raw) {
                _isModelLoaded = true
                return parsed
            }
        } catch {
            HSLogger.llm.warning("LocalLLMService: MLX parentSummary failed: \(error.localizedDescription), fallback")
        }
#endif
        return _ruleBasedParentSummary(request: request)
    }

    // MARK: - Generate: Route

    public func generateRoute(request: RoutePlannerRequest) async throws -> RoutePlannerResponse {
#if arch(arm64)
        do {
            let prompt = buildRoutePrompt(request: request)
            let raw = try await MLXEngine.shared.generate(
                prompt: prompt,
                maxTokens: 256,
                temperature: 0.5
            )
            if ChildSafetyValidator.validate(raw), let parsed = parseRoutePlannerJSON(raw) {
                _isModelLoaded = true
                return parsed
            }
        } catch {
            HSLogger.llm.warning("LocalLLMService: MLX generateRoute failed: \(error.localizedDescription), fallback")
        }
#endif
        return _ruleBasedRoute(request: request)
    }

    // MARK: - Generate: Micro Story

    public func generateMicroStory(request: MicroStoryRequest) async throws -> MicroStoryResponse {
#if arch(arm64)
        do {
            let prompt = buildMicroStoryPrompt(request: request)
            let raw = try await MLXEngine.shared.generate(
                prompt: prompt,
                maxTokens: 128,
                temperature: 0.7
            )
            if ChildSafetyValidator.validate(raw) {
                _isModelLoaded = true
                return parseMicroStoryOrFallback(raw: raw, request: request)
            }
            HSLogger.llm.warning("LocalLLMService: ChildSafetyValidator rejected micro story, using rule-based")
        } catch {
            HSLogger.llm.warning("LocalLLMService: MLX microStory failed: \(error.localizedDescription), fallback")
        }
#endif
        return _ruleBasedMicroStory(request: request)
    }

    // MARK: - Generate: Child Error Hint (углублённый error-analysis decision point)

    public func generateChildErrorHint(request: ChildErrorHintRequest) async throws -> ChildErrorHintResponse {
#if arch(arm64)
        do {
            let prompt = buildChildErrorHintPrompt(request: request)
            let raw = try await MLXEngine.shared.generate(
                prompt: prompt,
                maxTokens: 160,
                temperature: 0.4
            )
            if ChildSafetyValidator.validate(raw), let parsed = parseChildErrorHintJSON(raw, request: request) {
                _isModelLoaded = true
                return parsed
            }
            HSLogger.llm.warning("LocalLLMService: errorHint MLX rejected/unparsed, rule-based")
        } catch {
            HSLogger.llm.warning("LocalLLMService: MLX errorHint failed: \(error.localizedDescription), fallback")
        }
#endif
        return ChildErrorHintResponse.ruleBased(for: request)
    }

    // MARK: - Prompt Builders

    private func buildParentSummaryPrompt(request: ParentSummaryRequest) -> String {
        let rate = request.totalAttempts > 0
            ? Int(Double(request.correctAttempts) / Double(request.totalAttempts) * 100)
            : 0
        return """
        Ты помощник для родителей детей, занимающихся с логопедом.
        Напиши краткое резюме занятия и домашнее задание в JSON формате.
        Ребёнок: \(request.childName), звук: «\(request.targetSound)», \
        правильно: \(rate)%, продолжительность: \(request.sessionDurationSec / 60) мин.
        Ошибки: \(request.errorWords.prefix(3).joined(separator: ", ")).
        Ответь только JSON: {"parent_summary": "...", "home_task": "..."}
        """
    }

    private func buildRoutePrompt(request: RoutePlannerRequest) -> String {
        return """
        Составь план занятия для ребёнка \(request.age) лет.
        Звук: «\(request.targetSound)», успешность: \(Int(request.recentSuccessRate * 100))%, \
        усталость: \(request.fatigueLevel).
        Выбери 3 шаблона из: \(request.availableTemplates.prefix(8).joined(separator: ", ")).
        Ответь только JSON: {"route": [{"template": "...", "difficulty": 1, "wordCount": 8, "durationTargetSec": 180}], "sessionMaxDurationSec": 600}
        """
    }

    private func buildMicroStoryPrompt(request: MicroStoryRequest) -> String {
        let words = request.wordPool.prefix(5).joined(separator: ", ")
        return """
        Напиши короткую добрую историю для ребёнка \(request.age) лет \
        про звук «\(request.targetSound)». \
        Используй слова: \(words). Максимум 3 предложения. Только история, без пояснений.
        """
    }

    private func buildChildErrorHintPrompt(request r: ChildErrorHintRequest) -> String {
        // Встраиваем артикуляционную базу прямо в промпт — Qwen2.5-1.5B не знает
        // русскую логопедическую методику, поэтому даём ей опору. Просим строгий JSON.
        return """
        Ты — добрый помощник логопеда для ребёнка \(r.age) лет. Разбери одну попытку \
        произнести слово и дай две подсказки: ребёнку (очень коротко, тепло, без слова \
        «неправильно») и родителю (конкретная артикуляция).

        Данные попытки:
        — слово: «\(r.word)»
        — целевой звук: «\(r.targetSound)»
        — что услышала программа: «\(r.asrTranscript)» (уверенность \(pct(r.asrConfidence)))
        — оценка произношения: \(pct(r.pronunciationScore))
        — предварительная категория: \(r.policyCategory)

        Памятка по артикуляции (используй при подсказке родителю):
        — Р: язык вверху за зубами, кончик вибрирует;
        — Л: кончик языка упирается в верхние зубы;
        — Ш/Ж/Щ/Ч: язык «чашечкой» к нёбу, губы округлены;
        — С/З/Ц: язык за нижними зубами, тонкая струя воздуха;
        — К/Г/Х: спинка языка поднимается к нёбу сзади.

        Категории ошибки: soundDistortion, soundOmission, soundReplacement, hesitation, correct, uncertain.
        Если уверенность ниже 0.35 — категория uncertain, подсказка ребёнку «давай ещё разок».

        Ответь ТОЛЬКО JSON без markdown:
        {"category":"...","child_hint":"...","parent_hint":"..."}
        """
    }

    private func pct(_ x: Double) -> String { "\(Int((max(0, min(1, x)) * 100).rounded()))%" }

    private func parseChildErrorHintJSON(_ text: String, request: ChildErrorHintRequest) -> ChildErrorHintResponse? {
        guard let data = extractJSON(text),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let childHint = (obj["child_hint"] as? String ?? obj["childHint"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let parentHint = (obj["parent_hint"] as? String ?? obj["parentHint"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !childHint.isEmpty, !parentHint.isEmpty else { return nil }
        // Категорию валидируем по известному множеству; иначе берём policyCategory.
        let known = Set(["soundDistortion", "soundOmission", "soundReplacement", "hesitation", "correct", "uncertain"])
        let rawCat = (obj["category"] as? String) ?? request.policyCategory
        let category = known.contains(rawCat) ? rawCat : request.policyCategory
        return ChildErrorHintResponse(category: category, childHint: childHint, parentHint: parentHint)
    }

    // MARK: - JSON Parsers

    private func parseParentSummaryJSON(_ text: String) -> ParentSummaryResponse? {
        guard let data = extractJSON(text),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let summary = obj["parent_summary"] as? String,
              let task = obj["home_task"] as? String,
              !summary.isEmpty, !task.isEmpty else { return nil }
        return ParentSummaryResponse(parentSummary: summary, homeTask: task)
    }

    private func parseRoutePlannerJSON(_ text: String) -> RoutePlannerResponse? {
        guard let data = extractJSON(text),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let routeArr = obj["route"] as? [[String: Any]] else { return nil }
        let items = routeArr.compactMap { item -> RoutePlannerResponse.RouteItem? in
            guard let template = item["template"] as? String else { return nil }
            return RoutePlannerResponse.RouteItem(
                template: template,
                difficulty: item["difficulty"] as? Int ?? 1,
                wordCount: item["wordCount"] as? Int ?? 8,
                durationTargetSec: item["durationTargetSec"] as? Int ?? 180
            )
        }
        guard !items.isEmpty else { return nil }
        let maxDur = obj["sessionMaxDurationSec"] as? Int ?? 600
        return RoutePlannerResponse(route: items, sessionMaxDurationSec: maxDur)
    }

    private func parseMicroStoryOrFallback(raw: String, request: MicroStoryRequest) -> MicroStoryResponse {
        // Разбиваем текст на предложения по . ! ?
        let sentences = raw
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(3)
            .map { $0 }
        guard !sentences.isEmpty else { return _ruleBasedMicroStory(request: request) }
        let gaps = [MicroStoryResponse.GapPosition(
            sentenceIndex: sentences.count - 1,
            word: request.wordPool.first ?? request.targetSound,
            imageHint: "story"
        )]
        return MicroStoryResponse(sentences: sentences, gapPositions: gaps)
    }

    private func extractJSON(_ text: String) -> Data? {
        guard let firstBrace = text.firstIndex(of: "{"),
              let lastBrace = text.lastIndex(of: "}"),
              firstBrace < lastBrace else { return nil }
        return String(text[firstBrace...lastBrace]).data(using: .utf8)
    }

    // MARK: - Rule-based Fallbacks

    private func _ruleBasedParentSummary(request: ParentSummaryRequest) -> ParentSummaryResponse {
        let rate = request.totalAttempts > 0
            ? Int(Double(request.correctAttempts) / Double(request.totalAttempts) * 100)
            : 0
        let errorList = request.errorWords.prefix(3).joined(separator: ", ")
        let summary = "\(request.childName) отработал звук «\(request.targetSound)» — " +
            "\(rate)% правильно за \(request.sessionDurationSec / 60) мин. " +
            "Ошибки: \(errorList.isEmpty ? "нет" : errorList)."
        let task = "Повторите слова: \(errorList.isEmpty ? "любые слова со звуком \(request.targetSound)" : errorList)."
        return ParentSummaryResponse(parentSummary: summary, homeTask: task)
    }

    private func _ruleBasedRoute(request: RoutePlannerRequest) -> RoutePlannerResponse {
        let templates: [TemplateType]
        switch request.recentSuccessRate {
        case 0.8...:
            templates = [.repeatAfterModel, .storyCompletion, .minimalPairs]
        case 0.5..<0.8:
            templates = [.listenAndChoose, .dragAndMatch, .puzzleReveal]
        default:
            templates = [.articulationImitation, .breathing, .listenAndChoose]
        }
        let maxDuration = request.fatigueLevel >= 2 ? 600 : 900
        let items = templates.prefix(3).map { t in
            RoutePlannerResponse.RouteItem(
                template: t.rawValue,
                difficulty: max(1, Int(request.recentSuccessRate * 3)),
                wordCount: 8,
                durationTargetSec: 180
            )
        }
        return RoutePlannerResponse(route: Array(items), sessionMaxDurationSec: maxDuration)
    }

    private func _ruleBasedMicroStory(request: MicroStoryRequest) -> MicroStoryResponse {
        let words = request.wordPool.prefix(3)
        let sound = request.targetSound
        let sentences = [
            "Жил-был маленький \(words.first ?? sound).",
            "Он любил играть и \(words.dropFirst().first ?? "петь").",
            "Однажды он нашёл \(words.last ?? "друга")."
        ]
        let gaps = [MicroStoryResponse.GapPosition(
            sentenceIndex: 2,
            word: words.last ?? sound,
            imageHint: "friend"
        )]
        return MicroStoryResponse(sentences: sentences, gapPositions: gaps)
    }
}
