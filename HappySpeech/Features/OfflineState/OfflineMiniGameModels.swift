import Foundation

// MARK: - OfflineMiniGame VIP Models
//
// Расширенная VIP-модель для OfflineMiniGame (Block J v16):
//   - State machine: idle / loading / playing / paused / completed / failed
//   - Difficulty tiers: easy / medium / hard (адаптивная прогрессия)
//   - Achievement triggers: firstWin / fiveWins / tenWins / perfectGame
//   - Analytics events: started / paused / resumed / completed / failed
//   - Resume mid-game: persisted state в UserDefaults
//
// COPPA: нет PII, нет сетевых вызовов. Все события — локальные.

enum OfflineMiniGameModels {

    // MARK: - Game Type

    enum GameType: String, CaseIterable, Sendable, Codable {
        case tapLyalya
        case dragClouds
        case findPair
    }

    // MARK: - Difficulty (Block J)

    /// Уровень сложности — определяет длительность раунда и параметры игры.
    /// Прогрессия: easy → medium (после 3 побед) → hard (после 8 побед).
    enum Difficulty: String, CaseIterable, Sendable, Codable {
        case easy
        case medium
        case hard

        /// Множитель длительности раунда (easy=1.0, medium=0.8, hard=0.65).
        var durationMultiplier: Double {
            switch self {
            case .easy:   return 1.0
            case .medium: return 0.8
            case .hard:   return 0.65
            }
        }

        /// Порог «отличного» результата для текущей сложности.
        var greatScoreThreshold: Int {
            switch self {
            case .easy:   return 8
            case .medium: return 12
            case .hard:   return 16
            }
        }
    }

    // MARK: - State Machine (Block J)

    /// Состояние мини-игры. Используется Interactor'ом для гарантии корректных переходов.
    enum GameState: String, Sendable, Codable {
        case idle           // Не запущена, ожидание выбора игры
        case loading        // Загрузка контента из ContentEngine
        case playing        // Активная игра, таймер тикает
        case paused         // Пользователь нажал «Пауза», прогресс сохранён
        case completed      // Игра успешно завершена (timer expired или все цели поражены)
        case failed         // Игра прервана ошибкой (Realm недоступен и т.п.)
    }

    // MARK: - Achievement (Block J)

    /// Достижения, выдаваемые за прогресс в офлайн-играх.
    enum Achievement: String, CaseIterable, Sendable, Codable {
        case firstWin       // Первая победа в любой игре
        case fiveWins       // 5 побед суммарно
        case tenWins        // 10 побед суммарно
        case perfectGame    // Идеальная игра (greatScoreThreshold достигнут)

        /// Локализационный ключ для отображения пользователю.
        var titleKey: String {
            switch self {
            case .firstWin:    return "offline.minigame.achievement.firstWin"
            case .fiveWins:    return "offline.minigame.achievement.fiveWins"
            case .tenWins:     return "offline.minigame.achievement.tenWins"
            case .perfectGame: return "offline.minigame.achievement.perfectGame"
            }
        }
    }

    // MARK: - Analytics Event (Block J)

    /// Локальное событие аналитики (никаких внешних SDK, COPPA-safe).
    /// Записывается в UserDefaults в виде последних 50 событий.
    struct AnalyticsEvent: Sendable, Codable {
        let name: String                // game_started / game_paused / game_resumed / game_completed / game_failed
        let gameType: GameType
        let difficulty: Difficulty
        let timestamp: Date
        let metadata: [String: String]
    }

    // MARK: - Persisted State (Block J)

    /// Снимок состояния игры для resume mid-game.
    /// Сохраняется в UserDefaults при паузе или backgrounding приложения.
    struct PersistedState: Sendable, Codable {
        let gameType: GameType
        let difficulty: Difficulty
        let elapsedSeconds: Int
        let currentScore: Int
        let savedAt: Date
    }

    // MARK: - Persisted Stats (Block J)

    /// Накопленная статистика игр (суммарно по всем типам).
    /// Используется для achievement triggers и difficulty progression.
    struct PersistedStats: Sendable, Codable {
        var totalWins: Int = 0
        var perfectGames: Int = 0
        var unlockedAchievements: Set<String> = []

        /// Текущая сложность на основе накопленных побед.
        var currentDifficulty: Difficulty {
            switch totalWins {
            case 0..<3:   return .easy
            case 3..<8:   return .medium
            default:      return .hard
            }
        }
    }

    // MARK: - Errors (Block J)

    /// Ошибки, возникающие в Interactor'е.
    enum InteractorError: LocalizedError {
        case persistenceFailed(underlying: Error)
        case invalidStateTransition(from: GameState, to: GameState)
        case timerCancelled

        var errorDescription: String? {
            switch self {
            case .persistenceFailed:
                return String(localized: "offline.minigame.error.persistence")
            case .invalidStateTransition:
                return String(localized: "offline.minigame.error.state")
            case .timerCancelled:
                return String(localized: "offline.minigame.error.timer")
            }
        }
    }

    // MARK: - StartGame

    enum StartGame {
        struct Request {
            let gameType: GameType
            /// Block J: явная сложность (если nil — берётся из PersistedStats).
            var requestedDifficulty: Difficulty? = nil
            /// Block J: попытка resume из persisted state.
            var resumeFromPersisted: Bool = false
        }
        struct Response {
            let gameType: GameType
            let durationSeconds: Int
            let difficulty: Difficulty
            let resumedFromState: PersistedState?
        }
        struct ViewModel {
            let gameType: GameType
            let durationSeconds: Int
            let titleKey: String
            let instructionKey: String
            let difficultyLabel: String
            let resumeBannerVisible: Bool
        }
    }

    // MARK: - PauseGame (Block J)

    enum PauseGame {
        struct Request {
            let gameType: GameType
            let elapsedSeconds: Int
            let currentScore: Int
        }
        struct Response {
            let scheduleNotification: Bool
            let pausedAt: Date
        }
        struct ViewModel {
            let bannerKey: String
            let resumeCTAKey: String
        }
    }

    // MARK: - ResumeGame (Block J)

    enum ResumeGame {
        struct Request {
            let gameType: GameType
        }
        struct Response {
            let restoredState: PersistedState?
            let remainingSeconds: Int
        }
        struct ViewModel {
            let restoredScore: Int
            let remainingSeconds: Int
        }
    }

    // MARK: - FinishGame

    enum FinishGame {
        struct Request {
            let gameType: GameType
            let rawScore: Int
            /// Block J: завершилась ли игра успешно (true) или прервана (false).
            var didComplete: Bool = true
        }
        struct Response {
            let gameType: GameType
            let rawScore: Int
            let displayScore: String
            let unlockedAchievements: [Achievement]
            let nextDifficulty: Difficulty
            let didCompletePerfectly: Bool
        }
        struct ViewModel {
            let displayScore: String
            let congratsText: String
            let achievementBanners: [String]
            let nextDifficultyLabel: String
        }
    }
}
