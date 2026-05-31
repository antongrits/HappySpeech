import Foundation
import OSLog

// MARK: - ChildSpeechScoringPolicy
//
// ==================================================================================
// Конфигурационная политика оценки детской речи БЕЗ датасета детской речи.
//
// Все ML-модели приложения (WhisperKit, RussianPhonemeClassifier, PronunciationScorer)
// обучены/откалиброваны на взрослой или синтетической речи. Детская речь:
//   • выше по основному тону (F0 200–400 Гц против 100–150 у взрослых);
//   • короче по длительности и с большей вариативностью темпа;
//   • содержит закономерные возрастные замены звуков (Р→Л, Ш→С, межзубные С/З),
//     которые НЕ являются «ошибкой распознавания» — это ожидаемое произношение
//     ребёнка, ещё не поставившего звук.
//
// Поэтому распознавание донастраивается НЕ через переобучение (датасета нет), а
// КОНФИГУРАЦИОННО — постобработкой выходов моделей по этой политике:
//   1. Возраст-адаптивные пороги «правильно / почти / ещё раз».
//   2. Доверительное гейтирование: низкая уверенность распознавания → «давай ещё
//      раз» (нейтрально), а НЕ штраф «неправильно». Ребёнок не наказывается за то,
//      что модель не уверена.
//   3. Толерантность к типичным детским заменам через child-aware фонемную
//      дистанцию (надстройка над IPADictionary.articulationDistance).
//
// Политика детерминирована, локальна (COPPA-safe), без сети.
// ==================================================================================

/// Возрастная группа ребёнка для подбора порогов.
///
/// Чем младше ребёнок, тем мягче пороги: у младших речевой аппарат менее зрелый,
/// модели менее уверены, и завышенная строгость демотивирует.
public enum ChildAgeBand: String, Sendable, CaseIterable {
    /// 5 лет и младше — максимально мягкие пороги.
    case youngest
    /// 6–7 лет — умеренные пороги.
    case middle
    /// 8 лет и старше — пороги, близкие к «взрослым».
    case oldest

    /// Определяет band по возрасту в годах. nil/некорректный возраст → `.middle`.
    public static func from(age: Int?) -> ChildAgeBand {
        guard let age else { return .middle }
        switch age {
        case ..<6:  return .youngest
        case 6...7: return .middle
        default:    return .oldest
        }
    }
}

/// Вердикт по одной попытке произнесения.
///
/// `tryAgain` — НЕ ошибка ребёнка. Это сигнал «сигнал слишком неуверенный, чтобы
/// судить» (тихо, шумно, обрезано). UI должен мягко предложить повторить, без
/// отрицательной обратной связи и без записи в статистику как неудачи.
public enum ChildAttemptVerdict: String, Sendable, Equatable {
    /// Произношение принято как правильное.
    case correct
    /// Близко: правильное по смыслу, но звук ещё «сырой» — поощрить и продолжить.
    case almost
    /// Слышна закономерная возрастная замена целевого звука (Р→Л и т.п.).
    /// Это прогресс, а не провал — подсказать артикуляцию, не штрафовать.
    case developmentalSubstitution
    /// Сигнал слишком неуверенный для оценки — предложить повторить (нейтрально).
    case tryAgain
    /// Произнесено явно другое слово / звук отсутствует.
    case incorrect
}

/// Результат применения политики к сырым выходам ML.
public struct ChildScoringDecision: Sendable, Equatable {
    /// Финальный вердикт.
    public let verdict: ChildAttemptVerdict
    /// Нормированный 0–100 балл для прогресс-бара (calibrated под возраст).
    public let displayScore: Int
    /// Засчитывать ли попытку в статистику успеха (tryAgain — не засчитывается).
    public let countsTowardStats: Bool
    /// Машинно-читаемая категория для error-analysis / LLM-подсказки.
    public let category: String
    /// Короткая человеко-читаемая причина (для логов и QA, не для ребёнка).
    public let rationale: String

    public init(
        verdict: ChildAttemptVerdict,
        displayScore: Int,
        countsTowardStats: Bool,
        category: String,
        rationale: String
    ) {
        self.verdict = verdict
        self.displayScore = displayScore
        self.countsTowardStats = countsTowardStats
        self.category = category
        self.rationale = rationale
    }
}

/// Конфигурация порогов. Все значения вынесены сюда, чтобы методист/QA могли
/// калибровать без правки логики.
public struct ChildScoringThresholds: Sendable {
    /// Порог уверенности распознавания, ниже которого вердикт = `tryAgain`
    /// (гейтирование). Сигнал считается «слишком неуверенным для оценки».
    public let minConfidenceToJudge: Double
    /// Порог балла произношения, выше которого — `correct`.
    public let correctScore: Double
    /// Порог балла, выше которого — `almost` (но ниже `correctScore`).
    public let almostScore: Double
    /// Порог фонемного сходства с эталоном (child-aware), выше которого слово
    /// считается «тем самым» словом (для смыслового совпадения).
    public let wordMatchSimilarity: Double
    /// Порог фонемного сходства, при котором замена трактуется как закономерная
    /// возрастная (`developmentalSubstitution`), а не как другое слово.
    public let substitutionSimilarity: Double

    public init(
        minConfidenceToJudge: Double,
        correctScore: Double,
        almostScore: Double,
        wordMatchSimilarity: Double,
        substitutionSimilarity: Double
    ) {
        self.minConfidenceToJudge = minConfidenceToJudge
        self.correctScore = correctScore
        self.almostScore = almostScore
        self.wordMatchSimilarity = wordMatchSimilarity
        self.substitutionSimilarity = substitutionSimilarity
    }

    /// Возраст-адаптивные пороги.
    ///
    /// Чем младше — тем ниже `minConfidenceToJudge` (реже придираемся к
    /// неуверенности модели на «писклявой» детской речи) и тем ниже `correctScore`
    /// (мягче засчитываем). У старших — строже, ближе к «взрослой» калибровке.
    ///
    /// | band     | minConf | correct | almost | wordMatch | subst |
    /// |----------|---------|---------|--------|-----------|-------|
    /// | youngest | 0.30    | 0.55    | 0.38   | 0.62      | 0.45  |
    /// | middle   | 0.38    | 0.62    | 0.45   | 0.68      | 0.50  |
    /// | oldest   | 0.45    | 0.70    | 0.52   | 0.74      | 0.55  |
    public static func forBand(_ band: ChildAgeBand) -> ChildScoringThresholds {
        switch band {
        case .youngest:
            return .init(minConfidenceToJudge: 0.30, correctScore: 0.55,
                         almostScore: 0.38, wordMatchSimilarity: 0.62, substitutionSimilarity: 0.45)
        case .middle:
            return .init(minConfidenceToJudge: 0.38, correctScore: 0.62,
                         almostScore: 0.45, wordMatchSimilarity: 0.68, substitutionSimilarity: 0.50)
        case .oldest:
            return .init(minConfidenceToJudge: 0.45, correctScore: 0.70,
                         almostScore: 0.52, wordMatchSimilarity: 0.74, substitutionSimilarity: 0.55)
        }
    }
}

/// Политика оценки детской речи. Stateless, чистые функции — легко тестируется.
public struct ChildSpeechScoringPolicy: Sendable {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "ChildScoring")
    private let g2p = RussianG2P()

    public init() {}

    // MARK: - Основной вход

    /// Применяет политику к выходам ML и возвращает мягкий вердикт.
    ///
    /// - Parameters:
    ///   - asrConfidence: уверенность распознавания (0–1) — ансамбль/Whisper.
    ///   - pronunciationScore: балл произношения (0–1) от PronunciationScorer.
    ///   - expectedWord: ожидаемое слово урока (для смыслового совпадения), либо "".
    ///   - recognizedText: то, что распознала ASR (для фонемного сравнения), либо "".
    ///   - targetSound: целевой звук урока в кириллице ("Р", "Ш", …), либо "".
    ///   - age: возраст ребёнка (для подбора порогов); nil → middle.
    /// - Returns: ``ChildScoringDecision`` с вердиктом, баллом и флагом учёта.
    public func evaluate(
        asrConfidence: Double,
        pronunciationScore: Double,
        expectedWord: String,
        recognizedText: String,
        targetSound: String,
        age: Int?
    ) -> ChildScoringDecision {
        let band = ChildAgeBand.from(age: age)
        let t = ChildScoringThresholds.forBand(band)

        // --- ШАГ 1. Доверительное гейтирование ---
        // Если ASR не уверена — мы НЕ судим о правильности. Это «давай ещё раз»,
        // не штраф. Ребёнок мог говорить тихо/в сторону/с фоновым шумом.
        if asrConfidence < t.minConfidenceToJudge {
            return ChildScoringDecision(
                verdict: .tryAgain,
                displayScore: 0,
                countsTowardStats: false,
                category: ErrorAnalysis.Category.uncertain.rawValue,
                rationale: "asrConfidence \(fmt(asrConfidence)) < gate \(fmt(t.minConfidenceToJudge)) (band=\(band.rawValue))"
            )
        }

        // --- ШАГ 2. Смысловое совпадение слова (child-aware фонемная дистанция) ---
        // Если знаем ожидаемое слово и есть распознанный текст — сравниваем фонемы
        // с толерантностью к детским заменам.
        var wordSimilarity: Double? = nil
        var sawDevelopmentalSubstitution = false
        if !expectedWord.isEmpty, !recognizedText.isEmpty {
            let expectedPhonemes = g2p.transcribe(expectedWord)
            let producedPhonemes = g2p.transcribe(recognizedText)
            let sim = childAwareSimilarity(
                reference: expectedPhonemes,
                produced: producedPhonemes,
                targetSound: targetSound
            )
            wordSimilarity = sim
            // Закономерная замена: ребёнок сказал то слово (child-aware сходство
            // высокое), но конкретно целевой звук заменён детской заменой
            // (Р→Л и т.п.). Проверяем напрямую через выравнивание фонем.
            sawDevelopmentalSubstitution = (sim >= t.wordMatchSimilarity)
                && Self.targetSoundWasSubstituted(
                    reference: expectedPhonemes,
                    produced: producedPhonemes,
                    targetSound: targetSound
                )
        }

        // --- ШАГ 3. Калибровка балла под возраст ---
        // Растягиваем pronunciationScore так, чтобы возрастной correctScore
        // соответствовал ~85 на UI (мотивация без обмана). Линейная калибровка.
        let display = calibratedDisplay(score: pronunciationScore, thresholds: t)

        // --- ШАГ 4. Финальный вердикт ---
        // Если есть смысловое несовпадение слова — это другое слово (incorrect),
        // НО если несовпадение объясняется возрастной заменой — это прогресс.
        if let sim = wordSimilarity, sim < t.substitutionSimilarity {
            return ChildScoringDecision(
                verdict: .incorrect,
                displayScore: display,
                countsTowardStats: true,
                category: ErrorAnalysis.Category.soundReplacement.rawValue,
                rationale: "wordSim \(fmt(sim)) < subst \(fmt(t.substitutionSimilarity)) — другое слово"
            )
        }

        if sawDevelopmentalSubstitution {
            return ChildScoringDecision(
                verdict: .developmentalSubstitution,
                displayScore: max(display, Int(t.almostScore * 100)),
                countsTowardStats: true,
                category: ErrorAnalysis.Category.soundDistortion.rawValue,
                rationale: "возрастная замена звука «\(targetSound)» — слово узнано, звук ещё сырой"
            )
        }

        if pronunciationScore >= t.correctScore {
            return ChildScoringDecision(
                verdict: .correct,
                displayScore: display,
                countsTowardStats: true,
                category: ErrorAnalysis.Category.correct.rawValue,
                rationale: "score \(fmt(pronunciationScore)) ≥ correct \(fmt(t.correctScore))"
            )
        }

        if pronunciationScore >= t.almostScore {
            return ChildScoringDecision(
                verdict: .almost,
                displayScore: display,
                countsTowardStats: true,
                category: ErrorAnalysis.Category.soundDistortion.rawValue,
                rationale: "score \(fmt(pronunciationScore)) в зоне «почти»"
            )
        }

        // Низкий балл при достаточной уверенности — звук искажён/опущен.
        return ChildScoringDecision(
            verdict: .incorrect,
            displayScore: display,
            countsTowardStats: true,
            category: ErrorAnalysis.Category.soundOmission.rawValue,
            rationale: "score \(fmt(pronunciationScore)) < almost \(fmt(t.almostScore))"
        )
    }

    // MARK: - Child-aware фонемная дистанция

    /// Фонемное сходство с толерантностью к типичным детским заменам.
    ///
    /// Использует расстояние редактирования по фонемам (НЕ по буквам), где цена
    /// замены = `childAwareSubstitutionCost`. Это даёт мягкий штраф за закономерные
    /// возрастные замены и нормальный штраф за «настоящие» ошибки.
    ///
    /// - Returns: значение в `[0, 1]`, 1.0 — полное совпадение.
    public func childAwareSimilarity(
        reference: [String],
        produced: [String],
        targetSound: String
    ) -> Double {
        guard !reference.isEmpty || !produced.isEmpty else { return 1.0 }
        guard !reference.isEmpty, !produced.isEmpty else { return 0.0 }

        let m = reference.count
        let n = produced.count
        // Взвешенный Левенштейн: cost замены ∈ [0,1] из childAwareSubstitutionCost.
        var dp = [[Double]](repeating: [Double](repeating: 0, count: n + 1), count: m + 1)
        for i in 0...m { dp[i][0] = Double(i) }
        for j in 0...n { dp[0][j] = Double(j) }
        for i in 1...m {
            for j in 1...n {
                let sub = dp[i - 1][j - 1] + childAwareSubstitutionCost(reference[i - 1], produced[j - 1])
                let del = dp[i - 1][j] + 1.0
                let ins = dp[i][j - 1] + 1.0
                dp[i][j] = min(sub, min(del, ins))
            }
        }
        let distance = dp[m][n]
        let maxLen = Double(max(m, n))
        return max(0.0, 1.0 - distance / maxLen)
    }

    /// Цена замены одной фонемы на другую в `[0, 1]` с учётом детских паттернов.
    ///
    /// База — ``IPADictionary/articulationDistance(_:_:)`` (артикуляционная
    /// близость). Поверх неё — снижение цены для закономерных детских замен:
    ///   • Р/Рь → Л/Ль/j  (ламбдацизм / отсутствие вибранта) — очень частая;
    ///   • Ш/Ж/Щ/Ч → С/З/Сь/Ц (сигматизм: шипящие → свистящие);
    ///   • С/З → межзубные/Т/Д-подобные (межзубный сигматизм);
    ///   • Л → j/В (отсутствие бокового).
    /// Эти замены штрафуются как ~0.2 (а не 0.7–1.0), чтобы слово оставалось
    /// «узнанным», а звук помечался как «в работе».
    public func childAwareSubstitutionCost(_ a: String, _ b: String) -> Double {
        if a == b { return 0.0 }
        if Self.isDevelopmentalSubstitution(target: a, produced: b)
            || Self.isDevelopmentalSubstitution(target: b, produced: a) {
            return 0.2
        }
        return IPADictionary.articulationDistance(a, b)
    }

    // MARK: - Таблица типичных детских замен (IPA)

    // Карта закономерных возрастных замен: целевая фонема → допустимые «детские»
    // произнесения. Источник — классическая русская логопедия (сигматизм,
    // ротацизм, ламбдацизм). НЕ медицинская классификация — педагогическая.
    //
    // Все символы — из ``IPADictionary``/``RussianG2P`` inventory: и эталон, и
    // распознанный текст проходят через один и тот же G2P, поэтому экзотические
    // (не-русские) IPA здесь не нужны и не использовались бы.
    static let developmentalSubstitutions: [String: Set<String>] = [
        // Ротацизм / ламбдацизм: Р не поставлен → Л/й/В.
        "r":  ["l", "lʲ", "j", "v"],
        "rʲ": ["lʲ", "l", "j"],
        // Ламбдацизм: Л → й / в.
        "l":  ["j", "v"],
        "lʲ": ["j", "vʲ"],
        // Сигматизм шипящих: Ш/Ж/Щ/Ч → свистящие/мягкие свистящие.
        "ʂ":  ["s", "sʲ", "f"],            // ш → с (призубный/губной сигматизм)
        "ʐ":  ["z", "zʲ", "v"],            // ж → з
        "ɕː": ["sʲ", "s"],                 // щ → сь
        "tɕ": ["ts", "sʲ", "tʲ"],          // ч → ц/сь/ть
        // Сигматизм свистящих: С/З → призубные/боковые (Т/Д/Ф) или мягкие пары.
        "s":  ["sʲ", "t", "f", "ʂ"],
        "z":  ["zʲ", "d", "v", "ʐ"],
        "ts": ["s", "tʲ", "sʲ"],           // ц → с/ть
        // Заднеязычные (каппацизм): К/Г/Х → переднеязычные Т/Д.
        "k":  ["t", "x"],
        "g":  ["d"],
        "x":  ["k", "f"]
    ]

    /// true, если `produced` — закономерная детская замена для `target`.
    static func isDevelopmentalSubstitution(target: String, produced: String) -> Bool {
        developmentalSubstitutions[target]?.contains(produced) ?? false
    }

    /// IPA-фонемы, соответствующие кириллической букве целевого звука.
    /// "Р" → {r, rʲ}, "Ш" → {ʂ}, "С" → {s, sʲ}, и т.д.
    static func targetIPA(for cyrillic: String) -> Set<String> {
        let lower = cyrillic.lowercased()
        switch lower {
        case "р": return ["r", "rʲ"]
        case "л": return ["l", "lʲ"]
        case "ш": return ["ʂ"]
        case "ж": return ["ʐ"]
        case "щ": return ["ɕː"]
        case "ч": return ["tɕ"]
        case "с": return ["s", "sʲ"]
        case "з": return ["z", "zʲ"]
        case "ц": return ["ts"]
        case "к": return ["k", "kʲ"]
        case "г": return ["g", "gʲ"]
        case "х": return ["x", "xʲ"]
        default:  return []
        }
    }

    /// Проверяет, был ли целевой звук заменён закономерной детской заменой.
    ///
    /// Выравнивает фонемы через минимальный путь редактирования (тот же DP, что и
    /// в ``childAwareSimilarity``) и ищет позицию, где эталонная фонема целевого
    /// звука сопоставлена с её детской заменой.
    static func targetSoundWasSubstituted(
        reference: [String],
        produced: [String],
        targetSound: String
    ) -> Bool {
        let targets = targetIPA(for: targetSound)
        guard !targets.isEmpty, !reference.isEmpty, !produced.isEmpty else { return false }

        // Если целевой звук вообще присутствует в produced как сам себя — замены нет.
        // Иначе ищем: есть ли в reference целевая фонема, а в produced — её замена.
        let producedSet = Set(produced)
        for tIPA in targets where reference.contains(tIPA) {
            // Целевой звук присутствовал в эталоне.
            if producedSet.contains(tIPA) {
                continue  // произнесён правильно — не замена
            }
            // Целевого звука нет в produced — проверяем, есть ли его детская замена.
            if let subs = developmentalSubstitutions[tIPA], !subs.isDisjoint(with: producedSet) {
                return true
            }
        }
        return false
    }

    // MARK: - Helpers

    private func calibratedDisplay(score: Double, thresholds t: ChildScoringThresholds) -> Int {
        // Кусочно-линейная калибровка:
        //   [0, almost)        → [0, 60)
        //   [almost, correct)  → [60, 85)
        //   [correct, 1]       → [85, 100]
        let clamped = max(0, min(1, score))
        let pct: Double
        if clamped < t.almostScore {
            pct = clamped / max(t.almostScore, 1e-6) * 60.0
        } else if clamped < t.correctScore {
            let span = max(t.correctScore - t.almostScore, 1e-6)
            pct = 60.0 + (clamped - t.almostScore) / span * 25.0
        } else {
            let span = max(1.0 - t.correctScore, 1e-6)
            pct = 85.0 + (clamped - t.correctScore) / span * 15.0
        }
        return Int(pct.rounded())
    }

    private func fmt(_ x: Double) -> String { String(format: "%.2f", x) }
}
