import CoreVideo
import OSLog
import Vision

// MARK: - SoundHunterMapping (pure, testable mapping core)
//
// Чистая (без Vision, без I/O) логика маппинга Vision-лейблов в русские слова и
// фильтрации по целевому звуку. Вынесена отдельно, чтобы покрывать unit-тестами
// без реального `VNClassifyImageRequest` (его observations нельзя инстанцировать
// вручную, а ANE-контекст недоступен на CI).
//
// Источник маппинга — общий `russian_object_mapping.json` (166 бытовых предметов
// «ImageNet label → русское слово + ключевые звуки»), который уже лежит в
// `Resources/` и переиспользуется `ObjectDetectionWorker`.

struct SoundHunterMapping: Sendable {

    /// Один распознанный предмет, сматченный со словарём.
    struct Match: Sendable, Equatable {
        /// ImageNet-метка (английская), как её вернул Vision. Пример: "umbrella".
        let visionLabel: String
        /// Русское слово. Пример: "зонт".
        let word: String
        /// Уверенность Vision 0…1.
        let confidence: Float
        /// Ключевые звуки русского слова (строчные). Пример: ["з", "т"].
        let sounds: [String]
    }

    /// Карточка сетки фоллбэк-режима: предмет + признак «целевой ли он»
    /// (содержит целевой звук). Дистрактор — `isTarget == false`.
    struct GridCard: Sendable, Equatable {
        let match: Match
        let isTarget: Bool
    }

    /// Словарь `ImageNet label → (русское слово, звуки)`.
    private let entries: [String: ObjectMapping]

    init(entries: [String: ObjectMapping]) {
        self.entries = entries
    }

    /// Загружает словарь из `russian_object_mapping.json` (Bundle.main).
    /// - Throws: `SoundHunterError.mappingNotFound` если ресурс отсутствует.
    static func loadFromBundle() throws -> SoundHunterMapping {
        guard let url = Bundle.main.url(forResource: "russian_object_mapping",
                                        withExtension: "json") else {
            throw SoundHunterError.mappingNotFound
        }
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode([String: ObjectMapping].self, from: data)
        return SoundHunterMapping(entries: decoded)
    }

    // MARK: - Mapping a single Vision label

    /// Сопоставляет один Vision-лейбл с записью словаря (точное → частичное совпадение).
    /// ImageNet-лейблы иногда приходят с суффиксами через запятую
    /// ("scarf, muffler") — пробуем первую компоненту.
    func entry(forVisionLabel label: String) -> ObjectMapping? {
        if let exact = entries[label] { return exact }
        let shortKey = label
            .components(separatedBy: ",")
            .first?
            .trimmingCharacters(in: .whitespaces) ?? label
        return entries[shortKey]
    }

    // MARK: - Filtering classifications by target sound

    /// Превращает сырые `(label, confidence)` пары в `Match`, отфильтрованные по
    /// целевому звуку и порогу уверенности. Отсортированы по убыванию confidence.
    ///
    /// - Parameters:
    ///   - classifications: пары «Vision-лейбл → confidence».
    ///   - targetSound: целевой русский звук (строка); `nil` — без фильтра.
    ///   - minimumConfidence: минимальная уверенность Vision.
    func matches(
        from classifications: [(label: String, confidence: Float)],
        targetSound: String?,
        minimumConfidence: Float
    ) -> [Match] {
        let normalizedTarget = SoundHunterMapping.normalize(sound: targetSound)
        return classifications
            .filter { $0.confidence >= minimumConfidence }
            .compactMap { item -> Match? in
                guard let entry = entry(forVisionLabel: item.label) else { return nil }
                if let target = normalizedTarget {
                    let hasSound = entry.sounds.contains { $0.lowercased() == target }
                    guard hasSound else { return nil }
                }
                return Match(
                    visionLabel: item.label,
                    word: entry.ru,
                    confidence: item.confidence,
                    sounds: entry.sounds
                )
            }
            .sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Huntable words (fallback photo-card mode)

    /// Все слова из словаря, содержащие целевой звук — источник для фоллбэк-режима
    /// (фото-карточки), когда камеры нет или iOS < 18. Детерминированно
    /// отсортированы по слову.
    func huntableWords(forSound sound: String) -> [Match] {
        guard let target = SoundHunterMapping.normalize(sound: sound) else { return [] }
        return entries
            .filter { entry in entry.value.sounds.contains { $0.lowercased() == target } }
            .map {
                Match(visionLabel: $0.key, word: $0.value.ru, confidence: 1, sounds: $0.value.sounds)
            }
            .sorted { $0.word < $1.word }
    }

    /// Слова БЕЗ целевого звука — дистракторы для сетки фото-карточек.
    /// Детерминированно отсортированы по слову.
    func distractorWords(forSound sound: String) -> [Match] {
        guard let target = SoundHunterMapping.normalize(sound: sound) else { return [] }
        return entries
            .filter { entry in !entry.value.sounds.contains { $0.lowercased() == target } }
            .map {
                Match(visionLabel: $0.key, word: $0.value.ru, confidence: 1, sounds: $0.value.sounds)
            }
            .sorted { $0.word < $1.word }
    }

    // MARK: - Huntable grid (fallback photo-card mode, with distractors)

    /// Формирует сетку фото-карточек для фоллбэк-режима как смесь **целевых**
    /// (слово содержит целевой звук) и **дистракторов** (слово БЕЗ целевого
    /// звука) — иначе задание «найди предмет со звуком Х» теряет смысл (все
    /// карточки «правильные»).
    ///
    /// Гарантии: всегда хотя бы один целевой и хотя бы два дистрактора; если в
    /// словаре не набирается запрошенное количество — берётся максимум доступного,
    /// но не нарушая минимумы (целевые при острой нехватке дополняются повтором
    /// доступных целевых нельзя — просто меньше дистракторов). Источники
    /// перемешиваются, итоговый порядок карточек также перемешивается, чтобы
    /// правильные позиции были непредсказуемы.
    ///
    /// - Parameters:
    ///   - sound: целевой русский звук.
    ///   - targetCount: желаемое число целевых карточек.
    ///   - distractorCount: желаемое число дистракторов.
    /// - Returns: карточки `GridCard` в перемешанном порядке.
    func huntableGrid(
        forSound sound: String,
        targetCount: Int,
        distractorCount: Int
    ) -> [GridCard] {
        let availableTargets = huntableWords(forSound: sound).shuffled()
        let availableDistractors = distractorWords(forSound: sound).shuffled()

        // Минимумы: ≥1 целевой, ≥2 дистрактора (если их хватает в словаре).
        let wantTargets = max(1, targetCount)
        let wantDistractors = max(2, distractorCount)

        let chosenTargets = Array(availableTargets.prefix(wantTargets))
        let chosenDistractors = Array(availableDistractors.prefix(wantDistractors))

        var grid = chosenTargets.map { GridCard(match: $0, isTarget: true) }
        grid += chosenDistractors.map { GridCard(match: $0, isTarget: false) }
        return grid.shuffled()
    }

    // MARK: - Helpers

    /// Нормализует целевой звук: приводит к нижнему регистру, обрезает пробелы;
    /// мягкие звуки («Сь», «Рь») сводятся к базовой согласной (в словаре звуки
    /// записаны без мягкого знака).
    static func normalize(sound: String?) -> String? {
        guard let sound else { return nil }
        let trimmed = sound.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        if trimmed.count == 2, trimmed.hasSuffix("ь") {
            return String(trimmed.dropLast())
        }
        return trimmed
    }
}

// MARK: - VisionObjectClassifierWorkerProtocol

/// Протокол классификатора предметов в видеокадре для «Звукового охотника».
/// Actor-изолирован — безопасен для вызова из любого Swift 6 контекста.
protocol VisionObjectClassifierWorkerProtocol: Actor {

    /// Анализирует один `CVPixelBuffer` и возвращает предметы, чьё русское слово
    /// содержит `targetSound`.
    /// - Parameters:
    ///   - pixelBuffer: кадр с задней камеры (комната) или ARFrame.
    ///   - targetSound: целевой русский звук; `nil` → все распознанные предметы.
    /// - Returns: совпадения, отсортированные по убыванию уверенности.
    func classify(in pixelBuffer: sending CVPixelBuffer, targetSound: String?) async throws -> [SoundHunterMapping.Match]

    /// Слова из словаря с целевым звуком — для фоллбэк-режима фото-карточек.
    func huntableWords(forSound sound: String) async -> [SoundHunterMapping.Match]

    /// Сетка фото-карточек: целевые (со звуком) + дистракторы (без звука).
    /// Для фоллбэк-режима, чтобы задание «найди предмет со звуком Х» имело смысл.
    func huntableGrid(
        forSound sound: String,
        targetCount: Int,
        distractorCount: Int
    ) async -> [SoundHunterMapping.GridCard]
}

// MARK: - VisionObjectClassifierWorker

/// Классификатор бытовых предметов через Apple Vision.
///
/// Использует `ClassifyImageRequest` (iOS 18+) с автоматическим откатом на
/// `VNClassifyImageRequest` для iOS 17. Полностью on-device, без сторонних
/// моделей, без сети — COPPA-safe (кадры не покидают устройство).
///
/// Поток:
/// 1. Vision возвращает топ-классы изображения с уверенностью.
/// 2. `SoundHunterMapping` маппит английские лейблы → русские слова + звуки.
/// 3. Фильтрация по целевому звуку (если задан).
actor VisionObjectClassifierWorker: VisionObjectClassifierWorkerProtocol {

    private let mapping: SoundHunterMapping
    private let minimumConfidence: Float
    private let maxResults: Int
    private let logger = Logger(subsystem: "ru.happyspeech", category: "ARSoundHunter.Vision")

    /// - Parameters:
    ///   - mapping: словарь предметов (по умолчанию — из bundle).
    ///   - minimumConfidence: порог уверенности Vision (по умолчанию 0.25 —
    ///     детям нужен мягкий порог, предметы в комнате далеко/под углом).
    ///   - maxResults: сколько топ-классов рассматривать.
    /// - Throws: `SoundHunterError.mappingNotFound` если ресурс недоступен.
    init(
        mapping: SoundHunterMapping? = nil,
        minimumConfidence: Float = 0.25,
        maxResults: Int = 8
    ) throws {
        self.mapping = try mapping ?? SoundHunterMapping.loadFromBundle()
        self.minimumConfidence = minimumConfidence
        self.maxResults = maxResults
    }

    func classify(
        in pixelBuffer: sending CVPixelBuffer,
        targetSound: String?
    ) async throws -> [SoundHunterMapping.Match] {
        let raw = try await classifications(in: pixelBuffer)
        let matches = mapping.matches(
            from: raw,
            targetSound: targetSound,
            minimumConfidence: minimumConfidence
        )
        logger.debug("classify: raw=\(raw.count) matched=\(matches.count) sound=\(targetSound ?? "all")")
        return matches
    }

    func huntableWords(forSound sound: String) async -> [SoundHunterMapping.Match] {
        mapping.huntableWords(forSound: sound)
    }

    func huntableGrid(
        forSound sound: String,
        targetCount: Int,
        distractorCount: Int
    ) async -> [SoundHunterMapping.GridCard] {
        mapping.huntableGrid(
            forSound: sound,
            targetCount: targetCount,
            distractorCount: distractorCount
        )
    }

    // MARK: - Vision invocation

    /// Возвращает топ-классы изображения как `(label, confidence)`, используя
    /// новый `ClassifyImageRequest` на iOS 18+ и `VNClassifyImageRequest` иначе.
    private func classifications(
        in pixelBuffer: sending CVPixelBuffer
    ) async throws -> [(label: String, confidence: Float)] {
        if #available(iOS 18.0, *) {
            return try await modernClassifications(in: pixelBuffer)
        } else {
            return try legacyClassifications(in: pixelBuffer)
        }
    }

    @available(iOS 18.0, *)
    private func modernClassifications(
        in pixelBuffer: sending CVPixelBuffer
    ) async throws -> [(label: String, confidence: Float)] {
        // Новый value-type Vision API (WWDC24): perform — async throws.
        var request = ClassifyImageRequest()
        request.cropAndScaleAction = .scaleToFit
        do {
            let observations = try await request.perform(
                on: pixelBuffer,
                orientation: .up
            )
            return observations
                .prefix(maxResults)
                .map { (label: $0.identifier, confidence: Float($0.confidence)) }
        } catch {
            logger.error("ClassifyImageRequest failed — \(error.localizedDescription)")
            throw SoundHunterError.visionRequestFailed(error.localizedDescription)
        }
    }

    private func legacyClassifications(
        in pixelBuffer: sending CVPixelBuffer
    ) throws -> [(label: String, confidence: Float)] {
        let request = VNClassifyImageRequest()
        request.preferBackgroundProcessing = true
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            logger.error("VNClassifyImageRequest failed — \(error.localizedDescription)")
            throw SoundHunterError.visionRequestFailed(error.localizedDescription)
        }
        guard let observations = request.results else { return [] }
        return observations
            .prefix(maxResults)
            .map { (label: $0.identifier, confidence: $0.confidence) }
    }
}

// MARK: - MockVisionObjectClassifierWorker (Preview / Tests)

/// Mock без Vision: возвращает предсказуемый набор предметов, отфильтрованный по
/// звуку через тот же `SoundHunterMapping`-контракт.
actor MockVisionObjectClassifierWorker: VisionObjectClassifierWorkerProtocol {

    private let mapping: SoundHunterMapping
    private let fixedClassifications: [(label: String, confidence: Float)]

    init() {
        // Маленький детерминированный словарь — независим от bundle.
        // Для каждого звука есть и целевые (со звуком), и дистракторы (без звука),
        // чтобы фоллбэк-сетка фото-карточек собиралась осмысленно и в Preview.
        self.mapping = SoundHunterMapping(entries: [
            "scarf": ObjectMapping(ru: "шарф", sounds: ["ш", "р", "ф"]),
            "cup": ObjectMapping(ru: "чашка", sounds: ["ч", "ш", "к"]),
            "hat": ObjectMapping(ru: "шапка", sounds: ["ш", "п", "к"]),
            "sock": ObjectMapping(ru: "носок", sounds: ["с", "к"]),
            "spoon": ObjectMapping(ru: "ложка", sounds: ["л", "ж", "к"]),
            "book": ObjectMapping(ru: "книга", sounds: ["к", "н", "г"]),
            "umbrella": ObjectMapping(ru: "зонт", sounds: ["з", "н", "т"]),
            "ball": ObjectMapping(ru: "мяч", sounds: ["м", "ч"])
        ])
        self.fixedClassifications = [
            (label: "scarf", confidence: 0.88),
            (label: "sock", confidence: 0.61),
            (label: "cup", confidence: 0.55)
        ]
    }

    func classify(
        in pixelBuffer: sending CVPixelBuffer,
        targetSound: String?
    ) async throws -> [SoundHunterMapping.Match] {
        mapping.matches(from: fixedClassifications, targetSound: targetSound, minimumConfidence: 0.25)
    }

    func huntableWords(forSound sound: String) async -> [SoundHunterMapping.Match] {
        mapping.huntableWords(forSound: sound)
    }

    func huntableGrid(
        forSound sound: String,
        targetCount: Int,
        distractorCount: Int
    ) async -> [SoundHunterMapping.GridCard] {
        mapping.huntableGrid(
            forSound: sound,
            targetCount: targetCount,
            distractorCount: distractorCount
        )
    }
}
