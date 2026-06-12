import Foundation

// MARK: - PhonemeDefect

/// Тип дефекта произношения одной фонемы по данным GOP-скоринга.
///
/// Классификация выполняется по правилам логопедической педагогики (не клиническая).
/// Используется для формирования «Фонемного паспорта» и адаптации плана упражнений.
///
/// ## Честные границы
/// Классификатор основан на относительных порогах и правилах. Он НЕ является
/// медицинским диагностическим инструментом и НЕ ставит клинических диагнозов.
/// Все выводы — педагогические эвристики для построения упражнений.
public enum PhonemeDefect: String, Sendable, Equatable, CaseIterable {
    /// Фонема произнесена правильно (margin выше верхнего порога τ₁).
    case correct
    /// Искажение: целевая фонема побеждает конкурента, но с малым margin (зона [τ₀, τ₁]).
    /// Звук «сырой» — нужна дополнительная тренировка.
    case distortion
    /// Закономерная возрастная замена: конкурирующая фонема побеждает, пара входит
    /// в таблицу типичных детских замен (ротацизм, сигматизм, ламбдацизм и т.п.).
    /// Это ожидаемый возрастной паттерн, не штрафуется.
    case developmentalSubstitution
    /// Нетипичная замена: конкурент побеждает, но пара НЕ входит в таблицу детских замен.
    case unexpectedSubstitution
    /// Пропуск: blank-класс доминирует в спане, фонема не произнесена.
    case omission
    /// Недостаточно данных для классификации (пустой спан или blank-доминант без конкурента).
    case uncertain
}

// MARK: - PhonemeDefectResult

/// Результат классификации дефекта для одной фонемы.
public struct PhonemeDefectResult: Sendable, Equatable {
    /// IPA-символ целевой фонемы.
    public let phoneme: String
    /// Тип дефекта.
    public let defect: PhonemeDefect
    /// GOP-показатель, по которому принято решение.
    public let gop: Float
    /// Средняя апостериорная вероятность целевой фонемы.
    public let avgPosterior: Float
    /// IPA-символ конкурирующей фонемы (для замен / искажений).
    public let competitorIPA: String?
    /// Доля кадров спана с blank-доминантой.
    public let blankDominanceFraction: Float
    /// Человеко-читаемое краткое описание (для логов / QA, не для ребёнка).
    public let rationale: String

    public init(
        phoneme: String,
        defect: PhonemeDefect,
        gop: Float,
        avgPosterior: Float,
        competitorIPA: String?,
        blankDominanceFraction: Float,
        rationale: String
    ) {
        self.phoneme = phoneme
        self.defect = defect
        self.gop = gop
        self.avgPosterior = avgPosterior
        self.competitorIPA = competitorIPA
        self.blankDominanceFraction = blankDominanceFraction
        self.rationale = rationale
    }
}

// MARK: - DefectThresholds

/// Пороговые значения для классификации дефекта фонемы.
///
/// Все пороги вынесены отдельно для калибровки методистом или QA-инженером
/// без изменения логики классификатора.
public struct DefectThresholds: Sendable {
    /// Нижний порог GOP: ниже → рассматривается как замена/пропуск (конкурент сильнее).
    public let tau0: Float
    /// Верхний порог GOP: выше → фонема правильная. В диапазоне [τ₀, τ₁] → искажение.
    public let tau1: Float
    /// Доля кадров с blank-доминантой, выше которой — пропуск фонемы.
    public let blankOmissionThreshold: Float
    /// Минимальная средняя апостериорная вероятность, ниже которой — неопределённость.
    public let minPosteriorForDecision: Float

    public init(
        tau0: Float = -1.5,
        tau1: Float = 0.5,
        blankOmissionThreshold: Float = 0.6,
        minPosteriorForDecision: Float = 0.03
    ) {
        self.tau0 = tau0
        self.tau1 = tau1
        self.blankOmissionThreshold = blankOmissionThreshold
        self.minPosteriorForDecision = minPosteriorForDecision
    }

    /// Пороги для конкретной логопедической группы звуков.
    ///
    /// Заднеязычные (К/Г/Х) имеют меньший датасет → менее надёжные абсолютные GOP →
    /// расширенная «серая зона» искажения.
    public static func forGroup(_ group: String) -> DefectThresholds {
        switch group {
        case "свистящие":
            return .init(tau0: -1.2, tau1: 0.4, blankOmissionThreshold: 0.6)
        case "шипящие":
            return .init(tau0: -1.2, tau1: 0.4, blankOmissionThreshold: 0.6)
        case "соноры":
            // Р/Л — наиболее склонны к заменам, τ₀ снижен
            return .init(tau0: -1.8, tau1: 0.5, blankOmissionThreshold: 0.65)
        case "заднеязычные":
            // Меньший датасет → расширенная серая зона
            return .init(tau0: -2.0, tau1: 0.6, blankOmissionThreshold: 0.65)
        default:
            return .init()
        }
    }
}

// MARK: - PhonemeDefectClassifier

/// Классификатор типов дефектов произношения на основе GOP и таблицы детских замен.
///
/// Правила классификации (в порядке приоритета):
///
/// 0. **Sentinel:** `avgPosterior == 0` И `competitorId == nil` (нескорируемая фонема /
///    пустой спан / `<unk>`) → `.uncertain` (нет данных для любого решения).
/// 1. **Пропуск:** blank-доминанта в ≥τ_blank кадрах спана → `.omission`.
/// 2. **Неопределённость:** `maxConfidentPosterior < minPosterior`, где
///    `maxConfidentPosterior = max(avgPosterior, competitorPosterior ?? 0)`.
///    Замена — уверенный сигнал (конкурент явно победил): его posterior высокий
///    даже когда target-posterior низкий. Uncertain означает, что НИ target,
///    НИ конкурент не уверены (диффузный/тихий спан).
/// 3. **Правильно:** GOP > τ₁ → `.correct`.
/// 4. **Конкурент побеждает** (GOP < τ₀):
///    - конкурент не идентифицирован → `.uncertain` (замена без конкурента неинтерпретируема);
///    - пара (target, competitor) ∈ ``ChildSpeechScoringPolicy.developmentalSubstitutions``
///      → `.developmentalSubstitution`;
///    - иначе → `.unexpectedSubstitution`.
/// 5. **Серая зона** (τ₀ ≤ GOP ≤ τ₁): целевая фонема выходит победителем нестабильно
///    → `.distortion`.
///
/// Использует таблицу ``ChildSpeechScoringPolicy.developmentalSubstitutions`` (IPA)
/// для различения возрастных и нетипичных замен.
///
/// ## Честные границы
/// Классификатор работает корректно при использовании ОТНОСИТЕЛЬНЫХ GOP
/// (self-baseline ребёнка). Абсолютные GOP на новых дикторах могут быть смещены.
/// Является педагогической эвристикой, не клинической диагностикой.
public enum PhonemeDefectClassifier {

    // MARK: - Public API

    /// Классифицирует дефект для одной фонемы по результатам GOP-скоринга.
    ///
    /// - Parameters:
    ///   - gop: ``PhonemeGOP`` из ``GOPScorer/score(logProbs:spans:)``.
    ///   - logProbs: матрица T×C log-вероятностей (нужна для blank-анализа спана).
    ///   - thresholds: пороги (по умолчанию общие). Для per-группы — ``DefectThresholds/forGroup(_:)``.
    /// - Returns: ``PhonemeDefectResult`` с типом дефекта и метаданными.
    public static func classify(
        gop: PhonemeGOP,
        logProbs: [[Float]],
        thresholds: DefectThresholds = .init()
    ) -> PhonemeDefectResult {
        let blankId = Wav2Vec2Vocabulary.blankIndex
        let timeSteps = logProbs.count

        // Правило 0: Sentinel — нескорируемая фонема (пустой спан / <unk> / ъ/ь).
        // GOPScorer возвращает avgPosterior=0, competitorId=nil для таких случаев.
        // Проверяем до blank-анализа: для нескорируемых фонем нет смысла считать blank-долю.
        if gop.avgPosterior == 0, gop.competitorId == nil {
            return PhonemeDefectResult(
                phoneme: gop.phoneme,
                defect: .uncertain,
                gop: gop.gop,
                avgPosterior: gop.avgPosterior,
                competitorIPA: nil,
                blankDominanceFraction: 0,
                rationale: "нескорируемая фонема (пустой спан или вне словаря) — нет данных для классификации"
            )
        }

        // MARK: Blank-доминанта
        let startFrame = max(0, gop.span.startFrame)
        let endFrame = min(gop.span.endFrame, timeSteps - 1)
        let frameCount = endFrame >= startFrame ? endFrame - startFrame + 1 : 0

        var blankDominantFrames = 0
        if frameCount > 0 {
            for t in startFrame ... endFrame {
                let row = logProbs[t]
                guard !row.isEmpty else { continue }
                var maxIdx = 0
                var maxVal = row[0]
                for i in 1 ..< row.count where row[i] > maxVal {
                    maxVal = row[i]
                    maxIdx = i
                }
                if maxIdx == blankId { blankDominantFrames += 1 }
            }
        }

        let blankFraction: Float = frameCount > 0
            ? Float(blankDominantFrames) / Float(frameCount)
            : 1.0

        // Правило 1: Пропуск
        if blankFraction >= thresholds.blankOmissionThreshold {
            return PhonemeDefectResult(
                phoneme: gop.phoneme,
                defect: .omission,
                gop: gop.gop,
                avgPosterior: gop.avgPosterior,
                competitorIPA: gop.competitorIPA,
                blankDominanceFraction: blankFraction,
                rationale: "blank-доминанта \(Int(blankFraction * 100))% ≥ порог \(Int(thresholds.blankOmissionThreshold * 100))%"
            )
        }

        // Правило 2: Неопределённость — ни target, ни конкурент не уверены.
        // Проверяем максимальный постериор среди победителей спана, а не только target.
        // Замена — уверенный сигнал: конкурент победил явно → его posterior высокий,
        // даже когда target-posterior низкий. Uncertain — когда ВЕСЬ спан диффузный.
        let maxConfidentPosterior = max(gop.avgPosterior, gop.competitorPosterior ?? 0)
        if maxConfidentPosterior < thresholds.minPosteriorForDecision {
            return PhonemeDefectResult(
                phoneme: gop.phoneme,
                defect: .uncertain,
                gop: gop.gop,
                avgPosterior: gop.avgPosterior,
                competitorIPA: gop.competitorIPA,
                blankDominanceFraction: blankFraction,
                rationale: "maxConfidentPosterior \(String(format: "%.3f", maxConfidentPosterior)) "
                    + "< порог \(String(format: "%.3f", thresholds.minPosteriorForDecision)) — диффузный спан"
            )
        }

        // Правило 3: Правильно
        if gop.gop > thresholds.tau1 {
            return PhonemeDefectResult(
                phoneme: gop.phoneme,
                defect: .correct,
                gop: gop.gop,
                avgPosterior: gop.avgPosterior,
                competitorIPA: gop.competitorIPA,
                blankDominanceFraction: blankFraction,
                rationale: "GOP \(String(format: "%.2f", gop.gop)) > τ₁ \(String(format: "%.2f", thresholds.tau1))"
            )
        }

        // Правило 4: Конкурент побеждает (GOP < τ₀)
        if gop.gop < thresholds.tau0 {
            guard let competitorIPA = gop.competitorIPA else {
                // Конкурент не идентифицирован — замена без конкурента неинтерпретируема.
                return PhonemeDefectResult(
                    phoneme: gop.phoneme,
                    defect: .uncertain,
                    gop: gop.gop,
                    avgPosterior: gop.avgPosterior,
                    competitorIPA: nil,
                    blankDominanceFraction: blankFraction,
                    rationale: "GOP \(String(format: "%.2f", gop.gop)) < τ₀, но конкурент не определён — недостаточно данных"
                )
            }
            let isDevelopmental = ChildSpeechScoringPolicy.isDevelopmentalSubstitution(
                target: gop.phoneme,
                produced: competitorIPA
            )
            if isDevelopmental {
                return PhonemeDefectResult(
                    phoneme: gop.phoneme,
                    defect: .developmentalSubstitution,
                    gop: gop.gop,
                    avgPosterior: gop.avgPosterior,
                    competitorIPA: competitorIPA,
                    blankDominanceFraction: blankFraction,
                    rationale: "GOP \(String(format: "%.2f", gop.gop)) < τ₀; конкурент '\(competitorIPA)' — возрастная замена для '\(gop.phoneme)'"
                )
            } else {
                return PhonemeDefectResult(
                    phoneme: gop.phoneme,
                    defect: .unexpectedSubstitution,
                    gop: gop.gop,
                    avgPosterior: gop.avgPosterior,
                    competitorIPA: competitorIPA,
                    blankDominanceFraction: blankFraction,
                    rationale: "GOP \(String(format: "%.2f", gop.gop)) < τ₀; конкурент '\(competitorIPA)' — нетипичная замена для '\(gop.phoneme)'"
                )
            }
        }

        // Правило 5: Серая зона (искажение)
        return PhonemeDefectResult(
            phoneme: gop.phoneme,
            defect: .distortion,
            gop: gop.gop,
            avgPosterior: gop.avgPosterior,
            competitorIPA: gop.competitorIPA,
            blankDominanceFraction: blankFraction,
            rationale: "GOP \(String(format: "%.2f", gop.gop)) ∈ "
                + "[τ₀=\(String(format: "%.2f", thresholds.tau0)), "
                + "τ₁=\(String(format: "%.2f", thresholds.tau1))] — зона искажения"
        )
    }

    /// Классифицирует дефекты для всего набора GOP-результатов одного слова.
    ///
    /// Пороги подбираются автоматически по логопедической группе первой фонемы из набора.
    /// Для смешанных слов (разные группы) — передавать явный `thresholds`.
    ///
    /// - Parameters:
    ///   - gops: результаты ``GOPScorer/score(logProbs:spans:)``.
    ///   - logProbs: матрица T×C log-вероятностей.
    ///   - groupOverride: явное имя группы для выбора порогов; если nil — определяется
    ///     по первой фонеме через ``IPADictionary/info(for:)``.
    /// - Returns: массив ``PhonemeDefectResult`` в порядке фонем.
    public static func classifyAll(
        gops: [PhonemeGOP],
        logProbs: [[Float]],
        groupOverride: String? = nil
    ) -> [PhonemeDefectResult] {
        let group = groupOverride
            ?? (gops.first.flatMap { IPADictionary.info(for: $0.phoneme)?.logopedicGroup })
            ?? ""
        let thresholds = DefectThresholds.forGroup(group)
        return gops.map { classify(gop: $0, logProbs: logProbs, thresholds: thresholds) }
    }
}
