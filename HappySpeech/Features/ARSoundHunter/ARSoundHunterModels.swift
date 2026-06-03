import Foundation

// MARK: - ARSoundHunter VIP Models
//
// Игра «Звуковой охотник по комнате»: камера показывает комнату → Apple Vision
// классифицирует предмет в кадре → ребёнку предлагают найти и назвать предмет
// с целевым звуком → запись через AudioService → on-device скоринг (Pronunciation
// + ASR) → награда.
//
// COPPA: всё on-device, кадры не покидают устройство (см. VisionObjectClassifierWorker).

enum ARSoundHunterModels {

    // MARK: - Phase

    /// Фаза экрана игры.
    enum Phase: Sendable, Equatable {
        /// Камера ищет предмет с целевым звуком.
        case hunting
        /// Подходящий предмет найден — ребёнку предлагается назвать его.
        case prompting
        /// Идёт запись голоса ребёнка.
        case recording
        /// Идёт on-device оценка записи.
        case scoring
        /// Раунд завершён (с наградой или мягким повтором).
        case roundComplete
    }

    /// Режим работы экрана.
    enum Mode: Sendable, Equatable {
        /// Полноценный AR-режим: задняя камера + Vision-классификация.
        case camera
        /// Фоллбэк: фото-карточки (камеры нет / iOS < 18 / нет доступа).
        case photoCards
    }

    // MARK: - StartGame

    enum StartGame {
        struct Request {
            /// Идентификатор ребёнка — для возраста и целевых звуков.
            let childId: String
            /// Переопределение целевого звука (например из планировщика). nil → авто.
            let targetSoundOverride: String?
            /// Доступна ли камера + Vision-классификация на этом устройстве.
            let cameraAvailable: Bool

            init(childId: String, targetSoundOverride: String? = nil, cameraAvailable: Bool) {
                self.childId = childId
                self.targetSoundOverride = targetSoundOverride
                self.cameraAvailable = cameraAvailable
            }
        }
        struct Response {
            let targetSound: String
            let mode: Mode
            /// Сетка фото-карточек для фоллбэк-режима: целевые (со звуком) +
            /// дистракторы (без звука). Пусто в camera-режиме.
            let gridCards: [SoundHunterMapping.GridCard]
            let childAge: Int
        }
        struct ViewModel {
            let targetSound: String
            /// «Найди и назови предмет со звуком «С»»
            let prompt: String
            let mode: Mode
            /// Карточки фоллбэка (пусто в camera-режиме).
            let cards: [Card]
            let mascotState: LyalyaAnimation
        }
    }

    // MARK: - FrameClassified
    //
    // Кадр распознан Worker'ом — Interactor решает, нашли ли мы предмет с
    // целевым звуком и достаточно ли он уверенно держится в кадре.

    enum FrameClassified {
        struct Request {
            let matches: [SoundHunterMapping.Match]
        }
        struct Response {
            /// Найденный устойчивый предмет (nil — ещё ищем).
            let foundObject: SoundHunterMapping.Match?
            /// Прогресс «удержания» предмета в кадре 0…1 (для индикатора).
            let lockProgress: Float
        }
        struct ViewModel {
            let foundWord: String?
            let lockProgress: Float
            let shouldPrompt: Bool
        }
    }

    // MARK: - SelectCard (фоллбэк)
    //
    // Ребёнок выбрал фото-карточку предмета. Целевая (со звуком) → переходим к
    // называнию. Дистрактор (без звука) → мягкий фидбэк без звезды/штрафа, можно
    // продолжить выбирать.

    enum SelectCard {
        struct Request { let cardId: String }
        struct Response {
            let word: String
            /// Содержит ли выбранное слово целевой звук.
            let isTarget: Bool
            /// Целевой звук — для текста фидбэка дистрактора.
            let targetSound: String
        }
        struct ViewModel {
            /// Целевая карточка → промпт «Назови предмет: …»; nil для дистрактора.
            let word: String?
            let prompt: String?
            /// Дистрактор → мягкий фидбэк «В этом слове нет звука Х»; nil для цели.
            let distractorFeedback: String?
            /// Какую карточку подсветить как «не подходит» (id == word).
            let distractorCardId: String?
        }
    }

    // MARK: - ScoreNaming
    //
    // Запись названа и оценена on-device. Interactor агрегирует результат
    // ASR-распознавания и оценки произношения в звёзды.

    enum ScoreNaming {
        struct Request {
            let word: String
            let transcript: String
            let asrConfidence: Double
            let pronunciationScore: PronunciationScore
        }
        struct Response {
            let stars: Int
            let matchedWord: Bool
            let foundWord: String
        }
        struct ViewModel {
            let stars: Int
            let feedback: String
            let foundWord: String
            let isSuccess: Bool
        }
    }

    // MARK: - NextRound

    enum NextRound {
        struct Request {}
        struct Response { let totalFound: Int }
        struct ViewModel { let totalFoundText: String }
    }

    // MARK: - Card (view-ready, фоллбэк)

    /// Карточка предмета для фоллбэк-режима фото-карточек.
    struct Card: Sendable, Identifiable, Hashable {
        let id: String
        let word: String
        /// Имя имейджсета (`word_*`) если есть в каталоге контента, иначе nil →
        /// View рендерит SF Symbol-плейсхолдер.
        let assetName: String?
        /// Содержит ли слово целевой звук. View сам по себе НЕ выдаёт это
        /// визуально (иначе задание тривиально) — флаг используется Interactor'ом
        /// при выборе. По умолчанию `false`, чтобы не раскрывать ответ.
        let isTarget: Bool
    }
}

// MARK: - SoundHunterError

/// Ошибки слоя «Звукового охотника».
enum SoundHunterError: LocalizedError, Sendable {
    case mappingNotFound
    case visionRequestFailed(String)

    var errorDescription: String? {
        switch self {
        case .mappingNotFound:
            return String(localized: "Словарь предметов недоступен")
        case .visionRequestFailed(let reason):
            return String(localized: "Не получилось распознать предмет: \(reason)")
        }
    }
}
