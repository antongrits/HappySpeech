import Foundation

// MARK: - ListenYourself VIP Models
//
// «Послушай себя» — слуховой самоконтроль (Л. С. Волкова, Р. Е. Левина):
// этап формирования обратной слуховой связи. Ребёнок:
//   1. записывает СВОЁ слово дважды (два дубля);
//   2. слушает оба и САМ выбирает лучший (тренируется суждение ребёнка,
//      а НЕ оценка приложения — числовых баллов на детском экране нет);
//   3. сравнивает выбранный дубль с эталоном Ляли (A/B);
//   4. сам оценивает похожесть из 3 тёплых вариантов (эмодзи, без цифр);
//   5. опционально открывает «секретный совет» (ASR-скоринг) — подсказку,
//      а не оценку, показывается ТОЛЬКО ПОСЛЕ выбора ребёнка.
//
// Аудио дублей хранится временно, локально, без выгрузки (COPPA).

enum ListenYourselfModels {

    // MARK: - Take (один дубль ребёнка)

    /// Один записанный дубль ребёнка: реальный файл записи + длительность.
    /// Никакой оценки приложения — только материал для собственного суждения.
    struct Take: Identifiable, Equatable, Sendable {
        /// Порядковый номер дубля (1 или 2) — он же стабильный id.
        let id: Int
        /// URL реальной записи (16 kHz mono WAV из `AudioService`).
        let url: URL
        /// Длительность записи в секундах (для подписи «0:02»).
        let durationSec: Double
    }

    // MARK: - Phase (state machine)

    /// Фазы экрана 1 «Два дубля».
    ///
    ///   loading → intro(нет дублей) → recording(дубль 1)
    ///           → recording(дубль 2) → choosing(оба дубля)
    ///           → compare(переход на экран 2)
    enum Phase: Equatable, Sendable {
        case loading
        /// Готовы записывать; показывает слово дня и кнопку «Записать».
        case intro
        /// Идёт запись очередного дубля (1 или 2).
        case recording(takeNumber: Int)
        /// Оба дубля записаны — ребёнок слушает и выбирает лучший.
        case choosing
        /// Переход к экрану «Сравни с Лялей».
        case comparing
    }

    // MARK: - Self-judgement (самооценка, без цифр)

    /// Три тёплых варианта самооценки на экране 2. Принципиально БЕЗ числового
    /// балла — ребёнок оценивает сам, машина не выставляет оценку.
    enum SelfJudgement: String, CaseIterable, Identifiable, Sendable {
        /// «Чуть-чуть не хватило».
        case almost
        /// «Уже похоже!».
        case close
        /// «Прямо как Ляля».
        case like

        var id: String { rawValue }

        /// Эмодзи-иконка варианта (детский язык, без баллов).
        var emoji: String {
            switch self {
            case .almost: return "🤏"
            case .close:  return "😊"
            case .like:   return "🌟"
            }
        }

        /// Двухстрочная тёплая подпись варианта.
        var title: String {
            switch self {
            case .almost: return String(localized: "listenYourself.judge.almost")
            case .close:  return String(localized: "listenYourself.judge.close")
            case .like:   return String(localized: "listenYourself.judge.like")
            }
        }
    }

    // MARK: - Articulation cue (опора-картинка)

    /// Одна опора-картинка артикуляции для целевого звука («язычок наверху» и т.п.).
    struct ArticulationCue: Identifiable, Equatable, Sendable {
        let id: String
        /// Эмодзи-иллюстрация опоры (без сторонних ассетов — kid-safe эмодзи).
        let emoji: String
        /// Короткая подпись (две строки).
        let label: String
    }

    // MARK: - LoadWord

    enum LoadWord {
        struct Request: Sendable {
            let childId: String
        }
        struct Response: Sendable {
            let word: String
            let targetSound: String
            /// Имя имейджсета `word_*` или SF-символ-фолбэк.
            let illustrationSymbol: String
            /// Буква-подсветка в слове (целевой звук в верхнем регистре).
            let highlightLetter: String
        }
        struct ViewModel: Sendable {
            let word: String
            let targetSound: String
            let illustrationSymbol: String
            let highlightLetter: String
            /// Опоры артикуляции для целевого звука.
            let cues: [ArticulationCue]
        }
    }

    // MARK: - RecordTake

    enum RecordTake {
        /// Интент «начать запись очередного дубля».
        struct Request: Sendable {}
        /// Результат сохранённого дубля.
        struct Response: Sendable {
            let take: Take
            let takeNumber: Int
            /// Записаны ли уже оба дубля.
            let bothTakesReady: Bool
        }
    }

    // MARK: - ChooseTake (выбор лучшего дубля ребёнком)

    enum ChooseTake {
        struct Request: Sendable {
            /// Номер выбранного дубля (1 или 2).
            let takeNumber: Int
        }
        struct Response: Sendable {
            let chosenTakeNumber: Int
        }
    }

    // MARK: - Judge (самооценка ребёнка)

    enum Judge {
        struct Request: Sendable {
            let judgement: SelfJudgement
        }
        struct Response: Sendable {
            let judgement: SelfJudgement
            /// Тёплое сообщение Ляли — хвалит за сам факт рефлексии.
            let mascotMessage: String
        }
    }

    // MARK: - SecretTip (опциональный ASR-совет, ПОСЛЕ выбора ребёнка)

    enum SecretTip {
        struct Request: Sendable {}
        struct Response: Sendable {
            /// Текст совета (артикуляционная подсказка, не оценка). nil — анализ
            /// не дал материала (нет записи/звук вне групп) → плашку не показываем.
            let tip: String?
        }
    }
}

// MARK: - ListenYourselfWordProvider

/// Поставщик «слова дня» для самоконтроля. Детерминированный ротатор слов по
/// дню года: ребёнок тренирует одно слово целиком (запись → выбор → сравнение).
/// Слова берутся с целевым звуком в сильной позиции; иллюстрация — реальный
/// `word_*` ассет из манифеста, иначе SF-символ-фолбэк.
enum ListenYourselfWordProvider {

    /// Карта слова: текст + целевой кириллический звук + фолбэк-символ.
    struct WordCard: Equatable, Sendable {
        let word: String
        let targetSound: String
        let illustrationSymbol: String

        /// Реальный ассет слова (`word_*`) из манифеста, если есть.
        var illustrationAsset: String? {
            LessonContentMap.asset(for: word)
        }

        /// Имя для `HSContentSymbol`: реальный ассет, иначе SF-символ-фолбэк.
        var displaySymbol: String {
            illustrationAsset ?? illustrationSymbol
        }
    }

    /// Пул слов (по одному из каждой основной группы + соноры для «Р»/«Л» —
    /// самые востребованные на этапе самоконтроля). Целевой звук — сильная позиция.
    private static let pool: [WordCard] = [
        WordCard(word: "Рыба", targetSound: "Р", illustrationSymbol: "fish.fill"),
        WordCard(word: "Луна", targetSound: "Л", illustrationSymbol: "moon.fill"),
        WordCard(word: "Шуба", targetSound: "Ш", illustrationSymbol: "tshirt.fill"),
        WordCard(word: "Сова", targetSound: "С", illustrationSymbol: "bird.fill"),
        WordCard(word: "Жук", targetSound: "Ж", illustrationSymbol: "ladybug.fill"),
        WordCard(word: "Замок", targetSound: "З", illustrationSymbol: "lock.fill"),
        WordCard(word: "Щётка", targetSound: "Щ", illustrationSymbol: "paintbrush.fill")
    ]

    /// Слово дня — детерминированно по дню года.
    static func wordForToday(now: Date = Date()) -> WordCard {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: now) ?? 1
        return pool[day % pool.count]
    }

    /// Все слова пула (для тестов/детерминизма).
    static var allWords: [WordCard] { pool }

    // MARK: - Articulation cues

    /// Три опоры-картинки артикуляции для группы целевого звука. Эмодзи —
    /// kid-safe, без сторонних ассетов. Подписи — двухстрочные, на русском.
    static func cues(forSound sound: String) -> [ListenYourselfModels.ArticulationCue] {
        let family = SoundFamily.allCases.first { $0.sounds.contains(sound) }
        switch family {
        case .sonorant: // Р, Л — язычок наверху, желобок
            return [
                .init(id: "tongue-up", emoji: "👅", label: String(localized: "listenYourself.cue.tongueUp")),
                .init(id: "hill", emoji: "⛰️", label: String(localized: "listenYourself.cue.hill")),
                .init(id: "groove", emoji: "〰️", label: String(localized: "listenYourself.cue.groove"))
            ]
        case .hissing: // Ш, Ж, Ч, Щ — чашечка, тёплый ветерок, губы трубочкой
            return [
                .init(id: "cup", emoji: "🥣", label: String(localized: "listenYourself.cue.cup")),
                .init(id: "warm-air", emoji: "♨️", label: String(localized: "listenYourself.cue.warmAir")),
                .init(id: "round-lips", emoji: "👄", label: String(localized: "listenYourself.cue.roundLips"))
            ]
        case .velar: // К, Г, Х — язычок назад, спинка вверх
            return [
                .init(id: "tongue-back", emoji: "👅", label: String(localized: "listenYourself.cue.tongueBack")),
                .init(id: "back-hill", emoji: "⛰️", label: String(localized: "listenYourself.cue.backHill")),
                .init(id: "soft-air", emoji: "💨", label: String(localized: "listenYourself.cue.softAir"))
            ]
        default: // свистящие С, З, Ц — улыбка, язык внизу, холодный ветерок
            return [
                .init(id: "smile", emoji: "😁", label: String(localized: "listenYourself.cue.smile")),
                .init(id: "tongue-down", emoji: "👅", label: String(localized: "listenYourself.cue.tongueDown")),
                .init(id: "cold-air", emoji: "❄️", label: String(localized: "listenYourself.cue.coldAir"))
            ]
        }
    }
}

// MARK: - ListenYourself errors (русские user-facing)

/// Доменные ошибки модуля. Все сообщения — тёплые, на русском (kid circuit).
enum ListenYourselfError: LocalizedError, Sendable {
    case recordingUnavailable
    case recordingFailed

    var errorDescription: String? {
        switch self {
        case .recordingUnavailable:
            return String(localized: "listenYourself.error.recordingUnavailable")
        case .recordingFailed:
            return String(localized: "listenYourself.error.recordingFailed")
        }
    }
}
