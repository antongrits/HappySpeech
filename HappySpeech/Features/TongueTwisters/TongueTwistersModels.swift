import Foundation
import SwiftUI

// MARK: - TongueTwisters VIP Models
//
// «Чистоговорки-конструктор» — автоматизация целевого звука во фразе с ритмом.
// Методика: В. В. Коноваленко, С. В. Коноваленко «Автоматизация звуков у детей»
// (чистоговорка — ступень автоматизации между словом и связной речью;
// ритмизация облегчает удержание звука).
//
// Две стадии внутри каждой чистоговорки (см. open-design
// kid-game-tongue-twisters-1/2.html):
//   1. rhyme   — «Собери чистоговорку»: слоговая разминка с ритм-долями +
//      строка с пропуском-рифмой (3 варианта-ответа, один рифмующийся).
//   2. say      — «Скажи целиком»: рифма выбрана, ребёнок проговаривает всю
//      чистоговорку под мягкий ритм; запись (AudioService) + мягкая ASR-проверка
//      наличия целевого звука (ASRService) — подсказка, не штраф.
//   3. train    — «Наращивание строки»: ступени слог→ряд→короткая фраза→полная,
//      оформленные как вагончики поезда (done=mint, now=коралл, locked).
//
// Метроном опционален и замедляем — для заикающихся можно выключить совсем
// (без таймера/соревнования). Контент — pack_tongue_phrases.json.

enum TongueTwistersModels {

    // MARK: - Start

    enum Start {
        struct Request {
            let childId: String
        }
        struct Response {
            let phrases: [TonguePhrase]
        }
        struct ViewModel {
            let totalPhrases: Int
            let first: PhraseViewModel?
        }
    }

    // MARK: - LoadPhrase

    enum LoadPhrase {
        struct Response {
            let phrase: TonguePhrase
            let phraseIndex: Int
            let totalPhrases: Int
        }
    }

    // MARK: - ChooseRhyme
    //
    // Ребёнок выбрал картинку-рифму. Верный вариант (рифмующийся) → вписывается
    // в пропуск, переходим к стадии «скажи целиком». Неверный → мягкая подсказка
    // (errorless: без слова «неправильно»), повтор образца.

    enum ChooseRhyme {
        struct Request {
            /// id выбранного варианта-ответа.
            let answerId: String
        }
        struct Response {
            let isCorrect: Bool
            let chosenWord: String
            let correctWord: String
        }
        struct ViewModel {
            let isCorrect: Bool
            let selectedAnswerId: String?
            let filledWord: String?
            let feedbackText: String
            let advanceToSay: Bool
        }
    }

    // MARK: - CheckRecording
    //
    // Ребёнок проговорил чистоговорку — записали (AudioService) и мягко проверили
    // наличие целевого звука (ASRService). Это поддержка, а не оценка: «слышу
    // звук С — отлично!» либо «давай ещё разок, погромче» (без штрафа).

    enum CheckRecording {
        struct Response {
            let soundHeard: Bool
            let targetSound: String
            /// true — ASR недоступен/тих, статус-чип скрыт (первично — старание).
            let inconclusive: Bool
        }
        struct ViewModel {
            /// Текст статус-пилла «слышу звук С — отлично!» (пусто → пилл скрыт).
            let statusText: String
            let soundHeard: Bool
            let showStatus: Bool
        }
    }

    // MARK: - SpeakWagon
    //
    // Ребёнок проговорил текущий «вагон» (ступень наращивания). Подтверждаем,
    // открываем следующий. Когда все вагоны пройдены — поезд собран (награда).

    enum SpeakWagon {
        struct Response {
            let completedIndex: Int
            let nextIndex: Int?
            let allDone: Bool
        }
        struct ViewModel {
            let wagonStates: [WagonState]
            let currentIndex: Int?
            let allDone: Bool
        }
    }

    // MARK: - Complete

    enum Complete {
        struct Response {
            let phrasesCompleted: Int
            let totalPhrases: Int
            let cleanFraction: Float
        }
        struct ViewModel {
            let starsEarned: Int
            let scoreLabel: String
            let completionMessage: String
            let finalScore: Float
        }
    }

    // MARK: - View-side phrase model

    struct PhraseViewModel: Equatable {
        let targetSound: String
        let warmupSyllable: String
        let warmupBeats: Int
    }
}

// MARK: - Domain types

/// Один вариант-ответ для строки-рифмы (картинка + слово).
struct RhymeAnswer: Sendable, Equatable, Identifiable {
    let id: String
    let word: String
    let imageAsset: String
    /// Рифмуется ли с пропуском (ровно один вариант — true).
    let isCorrect: Bool
}

/// Ступень наращивания строки («вагон» поезда).
struct WagonStep: Sendable, Equatable, Identifiable {
    let id: Int
    let text: String
    /// Слоговая ступень (Са / Са-са-са) vs. фразовая («вот летит оса»).
    let isSyllable: Bool
}

/// Состояние вагона для отрисовки.
enum WagonState: Sendable, Equatable {
    case done
    case now
    case locked
}

/// Одна чистоговорка: целевой звук, разминка, строка с пропуском, варианты,
/// ступени наращивания.
struct TonguePhrase: Sendable, Equatable, Identifiable {
    let id: String
    let targetSound: String
    let group: String
    let minAge: Int
    /// Слог разминки («Са»).
    let warmupSyllable: String
    /// Сколько ритм-пилюль показать в разминке.
    let warmupBeats: Int
    /// Начало строки до пропуска («Са-са-са —»).
    let linePrefix: String
    /// Часть строки между прологом и пропуском («вот летит»).
    let lineSuffix: String
    /// Слово-ответ, вписываемое в пропуск («оса»).
    let answerWord: String
    let answerAsset: String
    /// Варианты-ответы (включая верный), детерминированно перемешанные.
    let answers: [RhymeAnswer]
    /// Ступени наращивания строки.
    let wagons: [WagonStep]

    /// Полная строка чистоговорки (для озвучки образца и записи).
    var fullLine: String {
        "\(linePrefix) \(lineSuffix) \(answerWord)"
    }
}

// MARK: - Phase

/// Фаза экрана — переключает подвью.
enum TongueTwistersPhase: Sendable, Equatable {
    case loading
    case rhyme       // экран 1: разминка + выбор рифмы
    case say          // экран 1b: рифма выбрана, повтор вслух + запись/ASR
    case train        // экран 2: наращивание строки (вагончики)
    case completed    // финал со звёздами
}

// MARK: - View display state

@MainActor
@Observable
final class TongueTwistersDisplay {

    // Текущая чистоговорка
    var targetSound: String = ""
    var warmupSyllable: String = ""
    var warmupBeats: Int = 3
    var linePrefix: String = ""
    var lineSuffix: String = ""
    var answerWord: String = ""
    var answers: [RhymeAnswer] = []

    // Прогресс по чистоговоркам сессии
    var phraseIndex: Int = 0
    var totalPhrases: Int = 1

    // Выбор рифмы
    var selectedAnswerId: String?
    var filledWord: String?
    var rhymeCorrect: Bool = false

    // Запись + ASR-статус
    var isRecording: Bool = false
    var statusText: String = ""
    var showStatus: Bool = false
    var soundHeard: Bool = false

    // Наращивание (вагончики)
    var wagons: [WagonStep] = []
    var wagonStates: [WagonState] = []
    var currentWagonIndex: Int?

    // Метроном (опционален, замедляем)
    var metronomeOn: Bool = false
    var metronomeBPM: Int = 72
    /// Активная ритм-пилюля разминки (циклически 0…beats-1) — для пульса в такт.
    var activeBeat: Int = 0

    // Обратная связь
    var feedbackText: String = ""

    // Фаза / плеер
    var phase: TongueTwistersPhase = .loading
    var isPlaying: Bool = false

    // Финал
    var starsEarned: Int = 0
    var scoreLabel: String = ""
    var completionMessage: String = ""
    var lastScore: Float = 0
    var pendingExit: Bool = false

    /// Состояние одного вагона по индексу (безопасно вне диапазона → locked).
    func state(at index: Int) -> WagonState {
        wagonStates.indices.contains(index) ? wagonStates[index] : .locked
    }
}

// MARK: - Scoring

enum TongueTwistersScoring {
    /// Звёзды по доле «чистых» чистоговорок (рифма + услышан звук).
    static func stars(for score: Float) -> Int {
        switch score {
        case 0.9...:    return 3
        case 0.6..<0.9: return 2
        case 0.3..<0.6: return 1
        default:        return 0
        }
    }
}
