import Foundation
import OSLog

// MARK: - VoicingSoftnessCorpus
//
// «Карта звонкости и мягкости» — корпус оппозиционных пар и слов-ловушек.
// Загружается из `pack_voicing_softness.json` один раз. Разметка отражает
// акустический признак (звонкий/глухой, твёрдый/мягкий) по методике Каше,
// Филичёвой-Чиркиной. Все `imageAsset` слов-ловушек проверены по
// `word_manifest.json` и существуют как imageset. Полностью offline / on-device.

enum VoicingSoftnessCorpus {

    /// Раундов в одной сессии (антифатиговое правило).
    static var roundsPerSession: Int { VoicingSoftnessPackLoader.shared.roundsPerSession }

    /// Токены-звуки для режимов сортировки (voicing / softness).
    static func sortItems(
        for mode: VoicingSoftnessMode,
        targetSounds: [String]
    ) -> [VoicingSoftnessItem] {
        let pool: [VoicingSoftnessItem]
        switch mode {
        case .voicing:   pool = VoicingSoftnessPackLoader.shared.voicingItems
        case .softness:  pool = VoicingSoftnessPackLoader.shared.softnessItems
        case .trapWords: return []
        }
        guard !targetSounds.isEmpty else { return pool }
        let normalized = Set(targetSounds.map { $0.uppercased() })
        let preferred = pool.filter { normalized.contains($0.baseSound.uppercased()) }
        let rest = pool.filter { !normalized.contains($0.baseSound.uppercased()) }
        // Целевые звуки идут первыми, остальные добивают сессию.
        return preferred + rest
    }

    /// Раунды слов-ловушек.
    static func trapRounds(targetSounds: [String]) -> [VoicingSoftnessTrapRound] {
        let pool = VoicingSoftnessPackLoader.shared.trapRounds
        guard !targetSounds.isEmpty else { return pool }
        let normalized = Set(targetSounds.map { $0.uppercased() })
        let preferred = pool.filter { normalized.contains($0.baseSound.uppercased()) }
        let rest = pool.filter { !normalized.contains($0.baseSound.uppercased()) }
        return preferred + rest
    }
}

// MARK: - VoicingSoftnessPackLoader

struct VoicingSoftnessPackLoader {

    static let shared = VoicingSoftnessPackLoader()

    let roundsPerSession: Int
    let voicingItems: [VoicingSoftnessItem]
    let softnessItems: [VoicingSoftnessItem]
    let trapRounds: [VoicingSoftnessTrapRound]

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "VoicingSoftness.PackLoader"
    )

    // MARK: DTOs

    private struct Pack: Decodable {
        let roundsPerSession: Int
        let voicingPairs: [VoicingPairDTO]
        let softnessPairs: [SoftnessPairDTO]
        let trapWords: [TrapDTO]
    }

    private struct VoicingPairDTO: Decodable {
        let id: String
        let voiced: String
        let voiceless: String
        let soundFamily: String
    }

    private struct SoftnessPairDTO: Decodable {
        let id: String
        let hard: String
        let soft: String
        let soundFamily: String
        let hardSyllables: [String]
        let softSyllables: [String]
    }

    private struct TrapDTO: Decodable {
        let id: String
        let contrast: String
        let a: TrapOptionDTO
        let b: TrapOptionDTO
        let difficulty: Int
    }

    private struct TrapOptionDTO: Decodable {
        let word: String
        let asset: String
        let diffIndex: Int
        let feature: String
    }

    // MARK: Init

    private init() {
        guard let url = Bundle.main.url(
            forResource: "pack_voicing_softness", withExtension: "json"
        ) else {
            Self.logger.error("pack_voicing_softness.json not found — using fallback")
            roundsPerSession = 10
            voicingItems = Self.fallbackVoicing
            softnessItems = Self.fallbackSoftness
            trapRounds = Self.fallbackTraps
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(Pack.self, from: data)
            roundsPerSession = max(6, pack.roundsPerSession)

            let voicing = Self.makeVoicingItems(pack.voicingPairs)
            let softness = Self.makeSoftnessItems(pack.softnessPairs)
            let traps = pack.trapWords.compactMap(Self.makeTrap)

            voicingItems = voicing.isEmpty ? Self.fallbackVoicing : voicing
            softnessItems = softness.isEmpty ? Self.fallbackSoftness : softness
            trapRounds = traps.isEmpty ? Self.fallbackTraps : traps
        } catch {
            Self.logger.error(
                "pack_voicing_softness.json decode error: \(error.localizedDescription, privacy: .public)"
            )
            roundsPerSession = 10
            voicingItems = Self.fallbackVoicing
            softnessItems = Self.fallbackSoftness
            trapRounds = Self.fallbackTraps
        }
    }

    // MARK: Builders

    /// Из каждой пары делаем два токена: звонкий → зона voiced, глухой → voiceless.
    private static func makeVoicingItems(_ pairs: [VoicingPairDTO]) -> [VoicingSoftnessItem] {
        pairs.flatMap { pair -> [VoicingSoftnessItem] in
            [
                VoicingSoftnessItem(
                    id: "\(pair.id)-v", token: pair.voiced, correctZone: .voiced,
                    soundFamily: pair.soundFamily, baseSound: pair.voiced,
                    audioId: "phoneme_\(pair.voiced)"
                ),
                VoicingSoftnessItem(
                    id: "\(pair.id)-vl", token: pair.voiceless, correctZone: .voiceless,
                    soundFamily: pair.soundFamily, baseSound: pair.voiceless,
                    audioId: "phoneme_\(pair.voiceless)"
                )
            ]
        }
    }

    /// Из каждой пары делаем слоговые токены: твёрдые слоги → hard, мягкие → soft.
    /// Берём по 2 слога каждого вида, чтобы корпус был достаточно разнообразным.
    private static func makeSoftnessItems(_ pairs: [SoftnessPairDTO]) -> [VoicingSoftnessItem] {
        pairs.flatMap { pair -> [VoicingSoftnessItem] in
            let hard = pair.hardSyllables.prefix(2).enumerated().map { index, syll in
                VoicingSoftnessItem(
                    id: "\(pair.id)-h\(index)", token: syll, correctZone: .hard,
                    soundFamily: pair.soundFamily, baseSound: pair.hard,
                    audioId: "syllable_\(syll)"
                )
            }
            let soft = pair.softSyllables.prefix(2).enumerated().map { index, syll in
                VoicingSoftnessItem(
                    id: "\(pair.id)-s\(index)", token: syll, correctZone: .soft,
                    soundFamily: pair.soundFamily, baseSound: pair.hard,
                    audioId: "syllable_\(syll)"
                )
            }
            return hard + soft
        }
    }

    private static func makeTrap(_ dto: TrapDTO) -> VoicingSoftnessTrapRound? {
        guard let contrast = VoicingSoftnessContrast(rawValue: dto.contrast) else {
            logger.error("Unknown contrast: \(dto.contrast, privacy: .public)")
            return nil
        }
        // Целевое слово — то, что несёт звонкий/мягкий признак (a в паке).
        let target = dto.a
        let distractor = dto.b
        let targetIsVoicedOrSoft = (target.feature == "voiced" || target.feature == "soft")

        let options = [
            VoicingSoftnessTrapOption(
                id: "\(dto.id)-a", word: target.word, imageAsset: target.asset,
                diffIndex: target.diffIndex, isTarget: true
            ),
            VoicingSoftnessTrapOption(
                id: "\(dto.id)-b", word: distractor.word, imageAsset: distractor.asset,
                diffIndex: distractor.diffIndex, isTarget: false
            )
        ]
        let diffLetter = Self.letter(in: target.word, at: target.diffIndex)
        let baseSound = diffLetter.uppercased()
        return VoicingSoftnessTrapRound(
            id: dto.id, contrast: contrast, targetWord: target.word,
            diffLetter: diffLetter, targetIsVoicedOrSoft: targetIsVoicedOrSoft,
            options: options, baseSound: baseSound
        )
    }

    /// Безопасно достаёт букву слова по индексу (для подсветки различия).
    static func letter(in word: String, at index: Int) -> String {
        let chars = Array(word)
        guard index >= 0, index < chars.count else { return "" }
        return String(chars[index])
    }

    // MARK: Fallback (минимальный методически верный набор)

    private static let fallbackVoicing: [VoicingSoftnessItem] = [
        .init(id: "fb-b", token: "Б", correctZone: .voiced, soundFamily: "губно-губные", baseSound: "Б", audioId: "phoneme_Б"),
        .init(id: "fb-p", token: "П", correctZone: .voiceless, soundFamily: "губно-губные", baseSound: "П", audioId: "phoneme_П"),
        .init(id: "fb-z", token: "З", correctZone: .voiced, soundFamily: "свистящие", baseSound: "З", audioId: "phoneme_З"),
        .init(id: "fb-s", token: "С", correctZone: .voiceless, soundFamily: "свистящие", baseSound: "С", audioId: "phoneme_С"),
        .init(id: "fb-zh", token: "Ж", correctZone: .voiced, soundFamily: "шипящие", baseSound: "Ж", audioId: "phoneme_Ж"),
        .init(id: "fb-sh", token: "Ш", correctZone: .voiceless, soundFamily: "шипящие", baseSound: "Ш", audioId: "phoneme_Ш"),
        .init(id: "fb-g", token: "Г", correctZone: .voiced, soundFamily: "заднеязычные", baseSound: "Г", audioId: "phoneme_Г"),
        .init(id: "fb-k", token: "К", correctZone: .voiceless, soundFamily: "заднеязычные", baseSound: "К", audioId: "phoneme_К")
    ]

    private static let fallbackSoftness: [VoicingSoftnessItem] = [
        .init(id: "fb-la", token: "ЛА", correctZone: .hard, soundFamily: "соноры", baseSound: "Л", audioId: "syllable_ЛА"),
        .init(id: "fb-li", token: "ЛИ", correctZone: .soft, soundFamily: "соноры", baseSound: "Л", audioId: "syllable_ЛИ"),
        .init(id: "fb-lu", token: "ЛУ", correctZone: .hard, soundFamily: "соноры", baseSound: "Л", audioId: "syllable_ЛУ"),
        .init(id: "fb-lyu", token: "ЛЮ", correctZone: .soft, soundFamily: "соноры", baseSound: "Л", audioId: "syllable_ЛЮ"),
        .init(id: "fb-ra", token: "РА", correctZone: .hard, soundFamily: "соноры", baseSound: "Р", audioId: "syllable_РА"),
        .init(id: "fb-ri", token: "РИ", correctZone: .soft, soundFamily: "соноры", baseSound: "Р", audioId: "syllable_РИ"),
        .init(id: "fb-sa", token: "СА", correctZone: .hard, soundFamily: "свистящие", baseSound: "С", audioId: "syllable_СА"),
        .init(id: "fb-si", token: "СИ", correctZone: .soft, soundFamily: "свистящие", baseSound: "С", audioId: "syllable_СИ")
    ]

    private static let fallbackTraps: [VoicingSoftnessTrapRound] = [
        .init(
            id: "fb-koza-kosa", contrast: .voicing, targetWord: "коза",
            diffLetter: "з", targetIsVoicedOrSoft: true,
            options: [
                .init(id: "fb-koza-kosa-a", word: "коза", imageAsset: "word_goat", diffIndex: 2, isTarget: true),
                .init(id: "fb-koza-kosa-b", word: "коса", imageAsset: "word_kosa", diffIndex: 2, isTarget: false)
            ],
            baseSound: "З"
        ),
        .init(
            id: "fb-zhar-shar", contrast: .voicing, targetWord: "жар",
            diffLetter: "ж", targetIsVoicedOrSoft: true,
            options: [
                .init(id: "fb-zhar-shar-a", word: "жар", imageAsset: "word_zhar", diffIndex: 0, isTarget: true),
                .init(id: "fb-zhar-shar-b", word: "шар", imageAsset: "word_shar", diffIndex: 0, isTarget: false)
            ],
            baseSound: "Ж"
        )
    ]
}
