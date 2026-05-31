import Foundation
import OSLog

// MARK: - WordFormationCorpus
//
// F2-007 «Назови ласково / Один-много-нет» (Wave 2).
//
// Корпус заданий словообразования/словоизменения. Загружается из
// `pack_word_formation.json` (своя схема, как `pack_fourth_extra.json`). Каждый
// раунд — основа (картинка из word_manifest.json) + ровно одна нормативная
// форма среди опций + дистракторы (намеренно типичные детские ошибки).
// Полностью offline / on-device.

enum WordFormationCorpus {

    /// Сколько раундов в одной сессии (8–12, антифатиговое правило).
    static var roundsPerSession: Int { WordFormationPackLoader.shared.roundsPerSession }

    /// Все раунды корпуса.
    static var allRounds: [FormationRound] { WordFormationPackLoader.shared.rounds }

    /// Раунды заданного под-типа.
    static func rounds(for subtask: FormationSubtask) -> [FormationRound] {
        allRounds.filter { $0.subtask == subtask }
    }

    /// Раунды под-типа, не превышающие возрастной гейт (minAge ≤ age).
    static func rounds(for subtask: FormationSubtask, maxAge age: Int) -> [FormationRound] {
        rounds(for: subtask).filter { $0.minAge <= age }
    }

    /// Все раунды, доступные ребёнку по возрасту (любой под-тип, minAge ≤ age).
    static func rounds(maxAge age: Int) -> [FormationRound] {
        allRounds.filter { $0.minAge <= age }
    }

    /// «Лёгкие» раунды (difficulty == 1) для ретро-старта.
    static func easyRounds(maxAge age: Int) -> [FormationRound] {
        let pool = rounds(maxAge: age)
        let easy = pool.filter { $0.difficulty <= 1 }
        return easy.isEmpty ? pool : easy
    }
}

// MARK: - WordFormationPackLoader
//
// Разбирает `pack_word_formation.json` один раз. Отбрасывает раунды без ровно
// одной нормативной формы (валидация корпуса). При отказе бандла возвращает
// безопасный минимальный набор, чтобы модуль оставался рабочим.

struct WordFormationPackLoader {

    static let shared = WordFormationPackLoader()

    let roundsPerSession: Int
    let rounds: [FormationRound]

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WordFormation.PackLoader"
    )

    private struct Pack: Decodable {
        let roundsPerSession: Int
        let items: [ItemDTO]
    }

    private struct ItemDTO: Decodable {
        let id: String
        let subtask: String
        let baseWord: String
        let baseImage: String
        let prompt: String
        let difficulty: Int
        let minAge: Int
        let options: [OptionDTO]
        let spokenForm: String
    }

    private struct OptionDTO: Decodable {
        let id: String
        let text: String
        let isCorrect: Bool
        /// Близкая (типичная) ошибка. Опционально (по умолчанию false).
        let isNearMiss: Bool?
    }

    private init() {
        guard let url = Bundle.main.url(
            forResource: "pack_word_formation", withExtension: "json"
        ) else {
            Self.logger.error("pack_word_formation.json not found in bundle — using fallback")
            roundsPerSession = 10
            rounds = WordFormationPackLoader.fallbackRounds
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(Pack.self, from: data)
            roundsPerSession = max(6, pack.roundsPerSession)
            let decoded = pack.items.compactMap(Self.makeRound)
            rounds = decoded.isEmpty ? WordFormationPackLoader.fallbackRounds : decoded
        } catch {
            Self.logger.error(
                "pack_word_formation.json decode error: \(error.localizedDescription, privacy: .public)"
            )
            roundsPerSession = 10
            rounds = WordFormationPackLoader.fallbackRounds
        }
    }

    private static func makeRound(_ dto: ItemDTO) -> FormationRound? {
        guard let subtask = FormationSubtask(rawValue: dto.subtask) else {
            logger.error("Unknown subtask: \(dto.subtask, privacy: .public)")
            return nil
        }
        let options = dto.options.map { opt in
            FormationOption(
                id: opt.id,
                text: opt.text,
                isCorrect: opt.isCorrect,
                isNearMiss: opt.isNearMiss ?? false
            )
        }
        // Валидация: 2–4 варианта и ровно одна нормативная форма.
        guard (2...4).contains(options.count),
              options.filter(\.isCorrect).count == 1 else {
            logger.error("Invalid round (option/correct count): \(dto.id, privacy: .public)")
            return nil
        }
        return FormationRound(
            id: dto.id,
            subtask: subtask,
            baseWord: dto.baseWord,
            baseImage: dto.baseImage,
            prompt: dto.prompt,
            options: options,
            spokenForm: dto.spokenForm,
            difficulty: dto.difficulty,
            minAge: dto.minAge
        )
    }

    // MARK: Fallback (минимальный рабочий набор)

    private static let fallbackRounds: [FormationRound] = [
        FormationRound(
            id: "wf-fb-dim-stol", subtask: .diminutive,
            baseWord: "стол", baseImage: "word_stol", prompt: "Назови ласково",
            options: [
                .init(id: "wf-fb-dim-stol-0", text: "столик", isCorrect: true),
                .init(id: "wf-fb-dim-stol-1", text: "столёнок", isCorrect: false)
            ],
            spokenForm: "Столик.", difficulty: 1, minAge: 5
        ),
        FormationRound(
            id: "wf-fb-dim-grib", subtask: .diminutive,
            baseWord: "гриб", baseImage: "word_grib", prompt: "Назови ласково",
            options: [
                .init(id: "wf-fb-dim-grib-0", text: "грибок", isCorrect: true),
                .init(id: "wf-fb-dim-grib-1", text: "грибик", isCorrect: false)
            ],
            spokenForm: "Грибок.", difficulty: 1, minAge: 5
        ),
        FormationRound(
            id: "wf-fb-many-stul", subtask: .oneMany,
            baseWord: "стул", baseImage: "word_stul", prompt: "Один стул — а если много?",
            options: [
                .init(id: "wf-fb-many-stul-0", text: "стулья", isCorrect: true),
                .init(id: "wf-fb-many-stul-1", text: "стулы", isCorrect: false, isNearMiss: true)
            ],
            spokenForm: "Стулья.", difficulty: 2, minAge: 5
        ),
        FormationRound(
            id: "wf-fb-manyof-stul", subtask: .manyOf,
            baseWord: "стул", baseImage: "word_stul", prompt: "Чего много?",
            options: [
                .init(id: "wf-fb-manyof-stul-0", text: "много стульев", isCorrect: true),
                .init(id: "wf-fb-manyof-stul-1", text: "много стулов", isCorrect: false, isNearMiss: true),
                .init(id: "wf-fb-manyof-stul-2", text: "много стулья", isCorrect: false)
            ],
            spokenForm: "Много стульев.", difficulty: 3, minAge: 6
        ),
        FormationRound(
            id: "wf-fb-manyof-okno", subtask: .manyOf,
            baseWord: "окно", baseImage: "word_window", prompt: "Чего нет?",
            options: [
                .init(id: "wf-fb-manyof-okno-0", text: "нет окон", isCorrect: true),
                .init(id: "wf-fb-manyof-okno-1", text: "нет окнов", isCorrect: false, isNearMiss: true),
                .init(id: "wf-fb-manyof-okno-2", text: "нет окны", isCorrect: false)
            ],
            spokenForm: "Нет окон.", difficulty: 3, minAge: 7
        ),
        FormationRound(
            id: "wf-fb-dim-dom", subtask: .diminutive,
            baseWord: "дом", baseImage: "word_house", prompt: "Назови ласково",
            options: [
                .init(id: "wf-fb-dim-dom-0", text: "домик", isCorrect: true),
                .init(id: "wf-fb-dim-dom-1", text: "домок", isCorrect: false)
            ],
            spokenForm: "Домик.", difficulty: 1, minAge: 5
        )
    ]
}
