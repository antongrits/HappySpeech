import Foundation

// MARK: - CoPlayModels (Clean Swift: Models)
//
// v29 Фаза 8, Функция 8 «Занятие вместе» — совместная игра со взрослым.
//
// Для 5–6 лет и ЗРР совместная речевая игра эффективнее одиночной (вызов
// речи через диалог, имитация). Взрослый — образец речи; ходы чередуются.
//
// VIP-модуль; контент — `CoPlayCorpus` (offline / on-device).

// MARK: - CoPlayRole

/// Чей ход в раунде.
public enum CoPlayRole: String, Sendable, CaseIterable {
    /// Говорит взрослый — образец речи.
    case adult
    /// Повторяет / отвечает ребёнок.
    case child
}

// MARK: - CoPlayTurn

/// Один ход совместной игры.
public struct CoPlayTurn: Identifiable, Sendable, Equatable {
    public let id: String
    public let role: CoPlayRole
    /// Что произносит говорящий (реплика-образец или фраза ребёнка).
    public let line: String
    /// Инструкция говорящему («Скажи как кошка», «Повтори за мамой»).
    public let instruction: String

    public init(id: String, role: CoPlayRole, line: String, instruction: String) {
        self.id = id
        self.role = role
        self.line = line
        self.instruction = instruction
    }
}

// MARK: - CoPlayActivity

/// Сценарий совместной игры — последовательность чередующихся ходов.
public struct CoPlayActivity: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    /// SF Symbol активности.
    public let symbolName: String
    /// Ходы в порядке выполнения.
    public let turns: [CoPlayTurn]
    /// Инструктаж взрослому перед началом.
    public let adultBriefing: String

    public init(
        id: String,
        title: String,
        symbolName: String,
        turns: [CoPlayTurn],
        adultBriefing: String
    ) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
        self.turns = turns
        self.adultBriefing = adultBriefing
    }
}

// MARK: - CoPlayModels namespace

enum CoPlayModels {

    // MARK: Start

    enum Start {
        struct Request: Sendable {
            let childId: String
        }

        struct Response: Sendable {
            let activity: CoPlayActivity
        }

        struct ViewModel: Sendable {
            let title: String
            let activityTitle: String
            let symbolName: String
            let adultBriefing: String
            let totalTurns: Int
            let firstTurn: TurnViewModel
        }

        struct TurnViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let role: CoPlayRole
            let line: String
            let instruction: String
            /// Подпись роли для подсветки («Ход мамы», «Ход малыша»).
            let roleLabel: String
            let progressLabel: String
            let progressFraction: Double
            let accessibilityLabel: String
        }
    }

    // MARK: NextTurn

    enum NextTurn {
        struct Request: Sendable {
            let voiceConfirmed: Bool
        }

        struct Response: Sendable {
            let isFinished: Bool
            let nextTurn: CoPlayTurn?
            let nextTurnIndex: Int?
            let totalTurns: Int
        }

        struct ViewModel: Sendable {
            let isFinished: Bool
            let nextTurn: Start.TurnViewModel?
            let summary: SummaryViewModel?
        }

        struct SummaryViewModel: Sendable {
            let title: String
            let turnsLabel: String
            let adultTip: String
        }
    }
}
