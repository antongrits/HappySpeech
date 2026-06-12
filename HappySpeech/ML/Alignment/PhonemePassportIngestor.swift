import Foundation
import OSLog

// MARK: - PhonemePassportIngesting

/// Фоновый «приёмник наблюдений» для «Фонемного паспорта».
///
/// Собирает один пайплайн анализа произнесённого ребёнком слова и записывает
/// пофонемные наблюдения в ``PhonemeProfileServiceProtocol``:
///
/// ```
/// слово ──G2P──▶ [IPA] ──vocabIds──▶ refIds
/// audio ──Wav2Vec2.logits──▶ T×37 ──log-softmax──▶ logProbs
/// CTCForcedAligner.align(logProbs, refIds) ──▶ spans
/// GOPScorer.score(logProbs, spans)         ──▶ gops
/// PhonemeDefectClassifier.classifyAll      ──▶ defects
/// для каждой целевой фонемы ──▶ phonemeProfileService.record(...)
/// ```
///
/// ## Где вызывается
/// Только из РОДИТЕЛЬСКОГО / семейного контура (parent-tier, за ParentalGate) —
/// напр. из `FamilyVoiceScoringWorker`. Паспорт — аналитика для специалиста /
/// родителя, НЕ для kid-UI и НЕ влияет на оценку, которую видит ребёнок.
///
/// ## Гейтинг (важно)
/// - **RAM-gate.** Wav2Vec2RuChild ≈ 302 MB. Ingest запускается, только если
///   физической памяти устройства ≥ ``minPhysicalMemoryBytes`` (по умолчанию 4 GB).
///   На слабых устройствах ingest тихо пропускается — это НЕ ошибка.
/// - **Tier-gate.** Гарантируется местом вызова (parent-контур). Вызывающий не
///   должен запускать ingest из детского игрового пути.
///
/// ## Поведение
/// - Полностью fire-and-forget: вызывающий запускает `Task.detached(priority:.utility)`
///   ПОСЛЕ выдачи ребёнку оценки, чтобы не влиять на латентность.
/// - Все ошибки логируются в OSLog и НЕ пробрасываются в UI.
/// - COPPA-safe: хранятся только числа/IPA (через `PhonemeProfileService`),
///   никакого аудио и PII.
///
/// ## Честные границы
/// Wav2Vec2RuChild обучена на синтетике и не валидирована на детях. Записанные
/// GOP — относительные метрики для self-baseline динамики, не клинический диагноз
/// (project guide §11).
public protocol PhonemePassportIngesting: Sendable {

    /// Проанализировать одну попытку и записать пофонемные наблюдения.
    ///
    /// - Parameters:
    ///   - audio: сырое PCM аудио (Float32, 16 kHz mono) — см. ``Wav2Vec2Service``.
    ///   - word: эталонное русское слово (кириллица), которое произносил ребёнок.
    ///   - childId: идентификатор активного ребёнка (без PII). Пустой → пропуск.
    ///   - wordId: стабильный идентификатор слова (не PII). Используется для
    ///     группировки наблюдений.
    /// - Returns: число записанных наблюдений (0 — если гейт не пройден / нет
    ///   целевых фонем / ошибка).
    @discardableResult
    func ingest(
        audio: Data,
        word: String,
        childId: String,
        wordId: String
    ) async -> Int
}

// MARK: - LivePhonemePassportIngestor

/// Боевой ингестор паспорта поверх Wav2Vec2 forced alignment.
public actor LivePhonemePassportIngestor: PhonemePassportIngesting {

    // MARK: Constants

    /// Порог физической памяти устройства, ниже которого ingest пропускается.
    /// Wav2Vec2RuChild ≈ 302 MB → запускаем только на устройствах ≥ 4 GB RAM.
    public static let defaultMinPhysicalMemoryBytes: UInt64 = 4 * 1024 * 1024 * 1024

    // MARK: Dependencies

    private let wav2Vec2: any Wav2Vec2Service
    private let profileService: any PhonemeProfileServiceProtocol
    private let g2p: RussianG2P
    /// Доступная физическая память устройства (байты). Инъектируется для тестов.
    private let physicalMemoryBytes: @Sendable () -> UInt64
    /// Минимально-необходимая физическая память для запуска тяжёлой модели.
    private let minPhysicalMemoryBytes: UInt64

    private let logger = Logger(subsystem: "ru.happyspeech", category: "PhonemePassportIngestor")

    // MARK: Init

    public init(
        wav2Vec2: any Wav2Vec2Service,
        profileService: any PhonemeProfileServiceProtocol,
        minPhysicalMemoryBytes: UInt64 = LivePhonemePassportIngestor.defaultMinPhysicalMemoryBytes,
        physicalMemoryBytes: @escaping @Sendable () -> UInt64 = { ProcessInfo.processInfo.physicalMemory }
    ) {
        self.wav2Vec2 = wav2Vec2
        self.profileService = profileService
        self.g2p = RussianG2P()
        self.minPhysicalMemoryBytes = minPhysicalMemoryBytes
        self.physicalMemoryBytes = physicalMemoryBytes
    }

    // MARK: PhonemePassportIngesting

    @discardableResult
    public func ingest(
        audio: Data,
        word: String,
        childId: String,
        wordId: String
    ) async -> Int {
        guard !childId.isEmpty else { return 0 }

        // RAM-gate: тяжёлую модель (~302 MB) запускаем только при достаточной памяти.
        let available = physicalMemoryBytes()
        guard available >= minPhysicalMemoryBytes else {
            logger.debug(
                "Passport ingest пропущен: RAM \(available) < порог \(self.minPhysicalMemoryBytes)"
            )
            return 0
        }

        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return 0 }

        // 1. G2P: слово → IPA.
        let ipa = g2p.transcribe(trimmed)
        guard !ipa.isEmpty else {
            logger.debug("Passport ingest: пустая IPA-транскрипция для слова")
            return 0
        }

        // 2. IPA → vocab-id (пропуская неподдерживаемые символы).
        let refIds = AlignmentVocabMap.vocabIds(for: ipa)
        guard !refIds.isEmpty else {
            logger.debug("Passport ingest: нет поддерживаемых фонем для alignment")
            return 0
        }

        // 3. Wav2Vec2: сырые логиты T×37 → log-softmax.
        let rawLogits: [[Float]]
        do {
            rawLogits = try await wav2Vec2.logits(audio: audio)
        } catch {
            logger.warning("Passport ingest: Wav2Vec2 logits недоступны (\(error.localizedDescription))")
            return 0
        }
        guard !rawLogits.isEmpty else { return 0 }
        let logProbs = CTCForcedAligner.applyLogSoftmax(rawLogits, vocabSize: Wav2Vec2Vocabulary.size)

        // 4. Forced alignment.
        let spans: [PhonemeSpan]
        do {
            spans = try CTCForcedAligner.align(logProbs: logProbs, refIds: refIds)
        } catch {
            logger.warning("Passport ingest: forced alignment не выполнен (\(error.localizedDescription))")
            return 0
        }
        guard spans.count == refIds.count else {
            logger.warning("Passport ingest: spans.count != refIds.count — пропуск")
            return 0
        }

        // 5. GOP-скоринг + классификация дефектов.
        let gops = GOPScorer.score(logProbs: logProbs, spans: spans)
        let defects = PhonemeDefectClassifier.classifyAll(gops: gops, logProbs: logProbs)

        // 6. Запись наблюдений только для ЦЕЛЕВЫХ (логопедически значимых) фонем.
        var recorded = 0
        for (index, gop) in gops.enumerated() {
            guard index < defects.count else { break }
            let defectResult = defects[index]
            let canonicalIPA = gop.phoneme

            // Целевые группы: свистящие / шипящие / соноры / заднеязычные.
            guard Self.isTargetPhoneme(canonicalIPA) else { continue }

            // Неинтерпретируемый исход (диффузный/тихий спан) в паспорт не пишем —
            // это «нет данных», а не дефект; иначе исказили бы матрицу состояний.
            guard defectResult.defect != .uncertain else { continue }

            let position = Self.position(forPhonemeIndex: index, totalPhonemes: refIds.count)
            let competitor = Self.competitorIPA(for: defectResult, gop: gop)

            do {
                try await profileService.record(
                    childId: childId,
                    phoneme: canonicalIPA,
                    wordId: wordId,
                    position: position,
                    gop: Double(gop.gop),
                    posterior: Double(gop.avgPosterior),
                    defect: Self.defectKey(defectResult.defect),
                    competitor: competitor
                )
                recorded += 1
            } catch {
                logger.warning("Passport ingest: запись наблюдения не удалась (\(error.localizedDescription))")
            }
        }

        logger.debug("Passport ingest: записано \(recorded) наблюдений (phonemes=\(refIds.count))")
        return recorded
    }

    // MARK: - Helpers

    /// Логопедически значимая фонема (целевая для коррекции): свистящие, шипящие,
    /// соноры, заднеязычные. Прочие (гласные, губные, знаки) в паспорт не пишутся —
    /// они не являются мишенью коррекционной работы.
    static func isTargetPhoneme(_ ipa: String) -> Bool {
        guard let group = IPADictionary.info(for: ipa)?.logopedicGroup else { return false }
        return targetGroups.contains(group)
    }

    static let targetGroups: Set<String> = ["свистящие", "шипящие", "соноры", "заднеязычные"]

    /// Позиция фонемы в слове по её индексу среди всех целевых-фонем.
    /// Первая → initial, последняя → final, прочие → medial.
    static func position(forPhonemeIndex index: Int, totalPhonemes: Int) -> PhonemeWordPosition {
        guard totalPhonemes > 1 else { return .initial }
        if index == 0 { return .initial }
        if index == totalPhonemes - 1 { return .final }
        return .medial
    }

    /// IPA-конкурента сохраняем только для исходов-замен (для матрицы confusion).
    static func competitorIPA(for result: PhonemeDefectResult, gop: PhonemeGOP) -> String? {
        switch result.defect {
        case .developmentalSubstitution, .unexpectedSubstitution:
            return result.competitorIPA ?? gop.competitorIPA
        case .correct, .distortion, .omission, .uncertain:
            return nil
        }
    }

    /// Строковый ключ исхода, совместимый с ``PhonemeProfileMath/state(fromDefect:)``.
    static func defectKey(_ defect: PhonemeDefect) -> String {
        switch defect {
        case .correct:                    return "ok"
        case .distortion:                 return "distortion"
        case .developmentalSubstitution:  return "age_substitution"
        case .unexpectedSubstitution:     return "substitution"
        case .omission:                   return "omission"
        case .uncertain:                  return "distortion"
        }
    }
}
