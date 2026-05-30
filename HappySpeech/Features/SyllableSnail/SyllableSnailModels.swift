import Foundation

// MARK: - SyllableSnailModels (Clean Swift: Models)
//
// F2-003 «Слоговая улитка» (Wave 2).
//
// Слоговая структура слова — воспроизведение количества, последовательности и
// наполнения слогов. По А.К. Марковой («Преодоление ОНР у дошкольников») — 13
// классов слоговой структуры по нарастающей сложности. Это отдельный речевой
// навык, не сводимый к звукопроизношению ([[speech-methodology]],
// [[correction-stages]] — этап `syllable`).
//
// Игровое ядро: Улитка (питомец Ляли) ползёт по «тропинке слогов»; на каждый
// слог — «шаг». Три режима поверх единого движка слога:
//   • A «прохлопай» — ритмико-слоговой анализ (число тапов ≈ число слогов);
//   • B «выложи»    — синтез (собрать слово из слогов, как SyllableConstructor);
//   • C «почини»    — коррекция перестановок/пропусков (ЯДРО ценности; прямая
//                     работа с типовыми НСС-ошибками: парафазии и элизии).
//
// Переиспользует `SyllableWord`, `SyllableTile`, `SyllableTier`,
// `FeedbackTier` из существующих модулей (SyllableConstructor / SoundDetective)
// — НЕ дублирует их. Контент — `SyllableSnailCorpus`
// (`pack_syllable_snail.json`, offline / on-device).
//
// Сквозные методические правила (ОБЯЗАТЕЛЬНЫ):
//   • «Светофор оценки» (FeedbackTier hit/almost/retry), НИКОГДА «неправильно».
//   • Подсказка после 2 промахов подряд (errorless fading).
//   • Без таймеров/соревнований (антифатиговое правило; критично при заикании).
//   • Ретро-старт: первые 2 раунда — на лёгком уровне.
//   • По-слоговая озвучка с замедлением в retry.

// MARK: - SnailMode

/// Режим «Слоговой улитки». Один движок слога — три механики.
public enum SnailMode: String, Sendable, CaseIterable, Equatable {
    /// A — «Прохлопай слово»: ритмико-слоговой анализ (счёт тапов).
    case clap
    /// B — «Выложи слово»: синтез из перемешанных слогов.
    case build
    /// C — «Почини слово»: переставить/добавить слог (коррекция НСС).
    case fix

    /// Следующий режим в методическом порядке A → B → C.
    public var next: SnailMode {
        switch self {
        case .clap:  return .build
        case .build: return .fix
        case .fix:   return .clap
        }
    }
}

// MARK: - SnailRound

/// Один раунд «улитки»: целевое слово + режим + материал для режима.
public struct SnailRound: Identifiable, Sendable, Equatable {
    public let id: String
    public let word: SnailWord
    public let mode: SnailMode
    /// Перемешанные плитки слогов (для build / fix). Для clap — пусто.
    public let tiles: [SyllableTile]

    public init(id: String, word: SnailWord, mode: SnailMode, tiles: [SyllableTile]) {
        self.id = id
        self.word = word
        self.mode = mode
        self.tiles = tiles
    }
}

// MARK: - SnailWord

/// Слово корпуса «улитки»: слоговая запись + картинка + класс Марковой +
/// по-слоговая озвучка + преднабор перестановки. Расширяет `SyllableWord`
/// (переиспользуется как ядро), не дублируя его поля.
public struct SnailWord: Sendable, Equatable, Identifiable {

    /// Базовая слоговая запись (id / word / syllables / tier) — общая модель.
    public let base: SyllableWord
    /// Asset картинки (из word_manifest.json).
    public let imageAsset: String
    /// Класс слоговой структуры по А.К. Марковой (1–13).
    public let markovaClass: Int
    /// По-слоговая романизация (для TTS-проговаривания режима A с паузами).
    public let audioSyllables: [String]
    /// Преднабор перестановки для режима C (типовая НСС-ошибка). Если пуст —
    /// перестановку генерирует worker.
    public let scrambledHints: [String]

    public var id: String { base.id }
    public var word: String { base.word }
    public var syllables: [String] { base.syllables }
    public var tier: SyllableTier { base.tier }

    public init(
        base: SyllableWord,
        imageAsset: String,
        markovaClass: Int,
        audioSyllables: [String],
        scrambledHints: [String]
    ) {
        self.base = base
        self.imageAsset = imageAsset
        self.markovaClass = markovaClass
        self.audioSyllables = audioSyllables
        self.scrambledHints = scrambledHints
    }
}

// MARK: - SyllableSnailModels namespace

enum SyllableSnailModels {

    // MARK: Start

    enum Start {
        struct Request: Sendable {
            let childId: String
            /// Если задан — форсирует режим (иначе подбирается ротацией).
            let mode: SnailMode?
            /// Если задан — форсирует уровень (иначе по возрасту / истории).
            let preferredTier: SyllableTier?
        }

        struct Response: Sendable {
            let mode: SnailMode
            let tier: SyllableTier
            let rounds: [SnailRound]
        }

        struct ViewModel: Sendable {
            let title: String
            let modeLabel: String
            let tierLabel: String
            let totalRounds: Int
            let firstRound: RoundViewModel
        }

        /// Готовый к показу раунд.
        struct RoundViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let mode: SnailMode
            let imageAsset: String
            let wordText: String
            /// Реплика Ляли (вопрос / приглашение, по режиму).
            let promptLyalya: String
            /// Кол-во «домиков» на тропинке (= число слогов).
            let pathSlotsCount: Int
            /// Плитки слогов (build / fix). Для clap — пусто.
            let tiles: [TileViewModel]
            /// По-слоговая озвучка (для кнопки «Ещё разок» и анимации шага).
            let audioSyllables: [String]
            let progressLabel: String
            let progressFraction: Double
            let accessibilityLabel: String
        }

        struct TileViewModel: Identifiable, Sendable, Equatable, Hashable {
            let id: String
            let text: String
            let accessibilityLabel: String
        }
    }

    // MARK: Tap (режим A — «Прохлопай»)

    enum Tap {
        struct Request: Sendable {
            /// Сколько раз ребёнок «хлопнул» (тапнул).
            let tapCount: Int
            let attemptInRound: Int
        }

        struct Response: Sendable {
            let feedback: FeedbackTier
            let expectedSyllables: Int
            let gotTaps: Int
            /// Переиграть слово по слогам (на almost/retry — с замедлением).
            let replayBySyllable: Bool
            /// Улитка дошла до домика (на hit).
            let snailReachedHome: Bool
            let showHint: Bool
            let advancedToNextRound: Bool
            let isFinished: Bool
            let nextRound: SnailRound?
            let nextRoundIndex: Int?
            let correctCount: Int
            let totalRounds: Int
        }

        struct ViewModel: Sendable {
            let feedback: FeedbackTier
            let lyalyaLine: String
            let expectedSyllables: Int
            let replayBySyllable: Bool
            let snailReachedHome: Bool
            /// Подсветить число слогов (подсказка после 2 промахов).
            let showHint: Bool
            let isFinished: Bool
            let nextRound: Start.RoundViewModel?
            let summary: SummaryViewModel?
        }
    }

    // MARK: Submit (режим B — «Выложи»)

    enum Submit {
        struct Request: Sendable {
            let tileIds: [String]
            let attemptInRound: Int
        }

        struct Response: Sendable {
            let feedback: FeedbackTier
            let assembled: String
            let expected: String
            let snailReachedHome: Bool
            let replayBySyllable: Bool
            /// Индекс первого неверного слота (подсказка) — nil если нет.
            let firstWrongSlotIndex: Int?
            let showHint: Bool
            let advancedToNextRound: Bool
            let isFinished: Bool
            let nextRound: SnailRound?
            let nextRoundIndex: Int?
            let correctCount: Int
            let totalRounds: Int
        }

        struct ViewModel: Sendable {
            let feedback: FeedbackTier
            let lyalyaLine: String
            let assembled: String
            let snailReachedHome: Bool
            let replayBySyllable: Bool
            let firstWrongSlotIndex: Int?
            let showHint: Bool
            let isFinished: Bool
            let nextRound: Start.RoundViewModel?
            let summary: SummaryViewModel?
        }
    }

    // MARK: Fix (режим C — «Почини», ядро ценности)

    enum Fix {
        struct Request: Sendable {
            /// Порядок плиток после перестановки/добавления.
            let orderedTileIds: [String]
            let attemptInRound: Int
        }

        struct Response: Sendable {
            let feedback: FeedbackTier
            let assembled: String
            let expected: String
            let snailReachedHome: Bool
            let replayBySyllable: Bool
            let firstWrongSlotIndex: Int?
            let showHint: Bool
            let advancedToNextRound: Bool
            let isFinished: Bool
            let nextRound: SnailRound?
            let nextRoundIndex: Int?
            let correctCount: Int
            let totalRounds: Int
        }

        struct ViewModel: Sendable {
            let feedback: FeedbackTier
            let lyalyaLine: String
            let assembled: String
            let snailReachedHome: Bool
            let replayBySyllable: Bool
            let firstWrongSlotIndex: Int?
            let showHint: Bool
            let isFinished: Bool
            let nextRound: Start.RoundViewModel?
            let summary: SummaryViewModel?
        }
    }

    // MARK: Summary (общая для всех режимов)

    struct SummaryViewModel: Sendable {
        let title: String
        let scoreText: String
        let correctCount: Int
        let totalRounds: Int
        let accuracyFraction: Double
        let encouragement: String
        /// ≥ 0.8 — показать праздник (confetti / static fallback).
        let showCelebration: Bool
    }
}
