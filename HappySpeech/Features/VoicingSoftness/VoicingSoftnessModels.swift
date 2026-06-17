import Foundation

// MARK: - VoicingSoftnessModels (Clean Swift: Models)
//
// «Карта звонкости и мягкости» — дифференциация оппозиционных фонем по
// акустическим признакам. Системный тренажёр различения звонких/глухих
// (П-Б, Т-Д, К-Г, С-З, Ш-Ж, Ф-В) и твёрдых/мягких звуков с акустической и
// тактильной (вибро-гортань через HapticService) опорой.
//
// Методика: Г. А. Каше, Т. Б. Филичёва, Г. В. Чиркина, Л. С. Волкова —
// дифференциация оппозиционных фонем по акустико-артикуляционным признакам;
// опора на «работу голоса» (рука на горле чувствует вибрацию у звонких).
// Прямой инструмент против дисграфических замен по звонкости.
//
// Сквозные методические правила (как во всех kid-играх):
//   • «Светофор оценки» (FeedbackTier hit/almost/retry), НИКОГДА «неправильно».
//   • Подсказка после 2 промахов подряд (errorless fading) + «потрогай горлышко».
//   • Без таймеров/соревнований (антифатиговое правило).
//   • Звонкий звук → реальная виброотдача (метафора голоса).

// MARK: - VoicingSoftnessMode

/// Режим тренажёра — три последовательные ступени методики.
public enum VoicingSoftnessMode: String, Sendable, CaseIterable, Equatable {
    /// Звонкость/глухость: «моторчик гудит» (звонкий) / «молчит» (глухой).
    case voicing
    /// Твёрдость/мягкость: «сердитый брат» (твёрдый) / «ласковый братик» (мягкий).
    case softness
    /// Слова-ловушки: выбрать картинку минимальной пары по услышанному слову.
    case trapWords

    /// Минимальный возраст для режима (возрастной гейт, методика):
    /// 5–6 — звонкость на ярких парах, 6–7 — твёрдость-мягкость, 7–8 — слова.
    public var minAge: Int {
        switch self {
        case .voicing:   return 5
        case .softness:  return 6
        case .trapWords: return 7
        }
    }

    /// Следующая ступень (для естественного перехода между режимами).
    public var next: VoicingSoftnessMode? {
        switch self {
        case .voicing:   return .softness
        case .softness:  return .trapWords
        case .trapWords: return nil
        }
    }
}

// MARK: - VoicingZone

/// Зона-домик, куда ребёнок относит звук.
public enum VoicingZone: String, Sendable, CaseIterable, Equatable {
    /// Звонкий — горлышко дрожит, моторчик гудит.
    case voiced
    /// Глухой — горлышко спокойно, моторчик молчит.
    case voiceless
    /// Твёрдый — «сердитый брат».
    case hard
    /// Мягкий — «ласковый братик».
    case soft

    /// Зоны, релевантные для режима (две на экран).
    static func zones(for mode: VoicingSoftnessMode) -> [VoicingZone] {
        switch mode {
        case .voicing:   return [.voiced, .voiceless]
        case .softness:  return [.hard, .soft]
        case .trapWords: return []
        }
    }
}

// MARK: - VoicingSoftnessItem (zone-sorting раунд)

/// Звук/слог для раунда сортировки по зонам (режимы voicing / softness).
public struct VoicingSoftnessItem: Identifiable, Sendable, Equatable {
    public let id: String
    /// Текст токена-звука («Б», «Ль», «ЛА»).
    public let token: String
    /// Верная зона для этого токена.
    public let correctZone: VoicingZone
    /// Группа звуков (для подбора по рабочему звуку ребёнка).
    public let soundFamily: String
    /// Базовый звук пары (для записи прогресса: «Б», «Л», «С»).
    public let baseSound: String
    /// id озвучки токена (для кнопки «Послушать ещё раз»).
    public let audioId: String

    public init(
        id: String,
        token: String,
        correctZone: VoicingZone,
        soundFamily: String,
        baseSound: String,
        audioId: String
    ) {
        self.id = id
        self.token = token
        self.correctZone = correctZone
        self.soundFamily = soundFamily
        self.baseSound = baseSound
        self.audioId = audioId
    }

    /// Звонкий ли токен (для виброотдачи-метафоры голоса).
    public var isVoiced: Bool { correctZone == .voiced }
}

// MARK: - VoicingSoftnessTrap (минимальная пара слов)

/// Слово минимальной пары для режима «слова-ловушки».
public struct VoicingSoftnessTrapOption: Identifiable, Sendable, Equatable {
    public let id: String
    public let word: String
    public let imageAsset: String
    /// Индекс различающейся буквы (для подсветки коралловым).
    public let diffIndex: Int
    /// Является ли это слово целевым (которое произнесено).
    public let isTarget: Bool

    public init(id: String, word: String, imageAsset: String, diffIndex: Int, isTarget: Bool) {
        self.id = id
        self.word = word
        self.imageAsset = imageAsset
        self.diffIndex = diffIndex
        self.isTarget = isTarget
    }
}

/// Раунд «слов-ловушек»: целевое слово + две картинки минимальной пары.
public struct VoicingSoftnessTrapRound: Identifiable, Sendable, Equatable {
    public let id: String
    /// Признак различения: звонкость или твёрдость-мягкость.
    public let contrast: VoicingSoftnessContrast
    /// Что произнесено (целевое слово).
    public let targetWord: String
    /// Различающаяся буква целевого слова (для подсказки «звонкий Б»).
    public let diffLetter: String
    /// true, если целевое слово — со звонким/мягким признаком (для реплики).
    public let targetIsVoicedOrSoft: Bool
    /// Два варианта-картинки (целевой + дистрактор минимальной пары).
    public let options: [VoicingSoftnessTrapOption]
    /// Базовый звук (для записи прогресса).
    public let baseSound: String

    public init(
        id: String,
        contrast: VoicingSoftnessContrast,
        targetWord: String,
        diffLetter: String,
        targetIsVoicedOrSoft: Bool,
        options: [VoicingSoftnessTrapOption],
        baseSound: String
    ) {
        self.id = id
        self.contrast = contrast
        self.targetWord = targetWord
        self.diffLetter = diffLetter
        self.targetIsVoicedOrSoft = targetIsVoicedOrSoft
        self.options = options
        self.baseSound = baseSound
    }
}

/// Признак различения слов-ловушек.
public enum VoicingSoftnessContrast: String, Sendable, Equatable {
    case voicing
    case softness
}

// MARK: - VoicingSoftnessModels namespace

enum VoicingSoftnessModels {

    // MARK: Start

    enum Start {
        struct Request: Sendable {
            let childId: String
            /// Если задан — форсирует режим (иначе подбирается по возрасту).
            let preferredMode: VoicingSoftnessMode?
        }

        struct Response: Sendable {
            let mode: VoicingSoftnessMode
            /// Раунды сортировки (для voicing / softness). Пусто для trapWords.
            let sortRounds: [VoicingSoftnessItem]
            /// Раунды слов-ловушек. Пусто для voicing / softness.
            let trapRounds: [VoicingSoftnessTrapRound]
            let targetSound: String
        }

        struct ViewModel: Sendable {
            let mode: VoicingSoftnessMode
            let title: String
            let subtitle: String
            let totalRounds: Int
            /// Первый раунд (один из двух типов — по режиму).
            let firstSort: SortRoundViewModel?
            let firstTrap: TrapRoundViewModel?
        }

        /// Готовый к показу раунд сортировки.
        struct SortRoundViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let token: String
            /// Реплика Ляли (вопрос).
            let promptLyalya: String
            let zones: [ZoneViewModel]
            let audioId: String
            let progressLabel: String
            let progressFraction: Double
            /// Звонкий токен — нужна виброотдача при озвучке/попадании.
            let isVoiced: Bool
            let tokenAccessibilityLabel: String
        }

        /// Зона-домик.
        struct ZoneViewModel: Identifiable, Sendable, Equatable {
            let id: VoicingZone
            let title: String
            let desc: String
            let emoji: String
            let accessibilityLabel: String
        }

        /// Готовый к показу раунд слов-ловушек.
        struct TrapRoundViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let promptLyalya: String
            let targetWord: String
            let options: [TrapOptionViewModel]
            let progressLabel: String
            let progressFraction: Double
        }

        /// Картинка-вариант минимальной пары.
        struct TrapOptionViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let word: String
            let imageAsset: String
            /// Различающаяся буква (для подсветки коралловым).
            let diffLetter: String
            let diffIndex: Int
            let accessibilityLabel: String
        }
    }

    // MARK: Answer

    enum Answer {
        struct Request: Sendable {
            /// Выбранная зона (для sort-режимов) или nil (для trapWords).
            let chosenZone: VoicingZone?
            /// id выбранной картинки (для trapWords) или nil.
            let chosenOptionId: String?
            /// Номер попытки в текущем раунде.
            let attemptInRound: Int
        }

        struct Response: Sendable {
            let feedback: FeedbackTier
            /// Верная зона (sort-режимы) — для раскрытия.
            let correctZone: VoicingZone?
            /// id верной картинки (trapWords).
            let correctOptionId: String?
            /// Показать подсказку «потрогай горлышко» (после 2 промахов или ошибки).
            let showThroatHint: Bool
            /// Дать виброотдачу (звонкий звук попал верно — метафора голоса).
            let triggerVoicedHaptic: Bool
            let replayWithEmphasis: Bool
            let advancedToNextRound: Bool
            let isFinished: Bool
            /// Следующий раунд (один из двух типов — по режиму).
            let nextSort: VoicingSoftnessItem?
            let nextTrap: VoicingSoftnessTrapRound?
            let nextRoundIndex: Int?
            let mode: VoicingSoftnessMode
            /// Различающаяся буква текущего trap-раунда (для подсказки).
            let trapDiffLetter: String?
            /// Звонкий/мягкий ли целевой признак trap-раунда (для реплики).
            let trapTargetIsVoicedOrSoft: Bool
            let correctCount: Int
            let totalRounds: Int
        }

        struct ViewModel: Sendable {
            let feedback: FeedbackTier
            /// Тёплая реплика Ляли (без «неправильно»).
            let lyalyaLine: String
            let correctZone: VoicingZone?
            let correctOptionId: String?
            /// Подсказка «потрогай горлышко» (мягкая коррекция).
            let throatHint: String?
            let triggerVoicedHaptic: Bool
            let replayWithEmphasis: Bool
            let isFinished: Bool
            let nextSort: Start.SortRoundViewModel?
            let nextTrap: Start.TrapRoundViewModel?
            let summary: SummaryViewModel?
        }

        struct SummaryViewModel: Sendable {
            let title: String
            let scoreText: String
            let correctCount: Int
            let totalRounds: Int
            let accuracyFraction: Double
            let encouragement: String
            /// ≥ 0.8 — показать праздник.
            let showCelebration: Bool
        }
    }
}
