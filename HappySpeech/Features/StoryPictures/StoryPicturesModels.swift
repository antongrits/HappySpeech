import Foundation
import SwiftUI

// MARK: - StoryPictures VIP Models
//
// «Рассказ по серии картинок» — связная речь по сюжетной серии (Глухов / Ткаченко).
// Главный вид работы по связной речи при ОНР: установление последовательности
// событий и причинно-следственных связей, затем озвучивание рассказа.
//
// 3 экрана (см. open-design kid-story-pictures-1/2/3.html):
//   1. order  — drag-сетка перемешанных кадров серии → правильный порядок.
//   2. tell   — активный кадр + опора-вопросы (Кто?/Что делает?/Чем закончилось?),
//               запись AudioService; ASRService + смысловые теги (галочки).
//   3. movie  — плеер «мультика» (точки-кадры) + радар-арка полноты
//               завязка→действие→развязка; «Показать маме» через parental gate.
//
// Контент: pack_picture_series.json. Персонажи — COPPA-safe животные, без людей.

enum StoryPicturesModels {

    // MARK: - Start

    enum Start {
        struct Request {
            let childId: String
        }
        struct Response {
            let series: PictureSeries
            /// Перемешанный порядок кадров для экрана упорядочивания.
            let shuffledFrameIds: [String]
        }
        struct ViewModel {
            let seriesTitle: String
            let frameCount: Int
            /// Кадры в перемешанном порядке (для подноса).
            let trayFrames: [FrameViewModel]
            /// Пустые слоты ленты (по числу кадров).
            let slotCount: Int
        }
    }

    // MARK: - PlaceFrame (drag-упорядочивание)
    //
    // Ребёнок поставил кадр `frameId` в слот `slotIndex` (0-based). Интерактор
    // проверяет, верный ли это кадр для позиции, и сообщает, заполнена ли лента.

    enum PlaceFrame {
        struct Request {
            let frameId: String
            let slotIndex: Int
        }
        struct Response {
            /// Текущее содержимое слотов (frameId или nil).
            let placedFrameIds: [String?]
            /// Кадры, оставшиеся в подносе.
            let trayFrameIds: [String]
            /// Все слоты заполнены.
            let isFilled: Bool
            /// Порядок полностью верный (для подсветки success).
            let isOrderCorrect: Bool
            /// Индекс следующего ожидаемого слота (для подсветки «next»).
            let nextSlotIndex: Int?
        }
        struct ViewModel {
            let slots: [SlotViewModel]
            let trayFrames: [FrameViewModel]
            let isFilled: Bool
            let isOrderCorrect: Bool
            let nextSlotIndex: Int?
            let hintText: String
            let mascotText: String
            let ctaEnabled: Bool
        }
    }

    // MARK: - ConfirmOrder (порядок собран → шаг 2)

    enum ConfirmOrder {
        struct Request {}
        struct Response {
            /// Кадры в правильном порядке (для шага рассказа).
            let orderedFrames: [PictureFrame]
        }
        struct ViewModel {
            let title: String
            let firstFrame: TellFrameViewModel?
            /// Кадры серии в правильном порядке (для плёнки).
            let orderedFrames: [FrameViewModel]
        }
    }

    // MARK: - LoadTellFrame (показать кадр N для рассказа)

    enum LoadTellFrame {
        struct Request {
            let frameIndex: Int
        }
        struct Response {
            let frame: PictureFrame
            let frameIndex: Int
            let totalFrames: Int
            let toldFrameIds: Set<String>
            let coveredLinkIds: Set<String>
        }
        struct ViewModel {
            let tellFrame: TellFrameViewModel
            /// Идентификаторы кадров, по которым уже был рассказ (для плёнки).
            let toldFrameIds: Set<String>
        }
    }

    // MARK: - Recording (запись по текущему кадру)

    enum Recording {
        struct StateResponse {
            let isRecording: Bool
            let elapsedSeconds: Int
            let amplitude: Float
        }
        struct StateViewModel {
            let isRecording: Bool
            let timeLabel: String
            let amplitude: Float
        }
    }

    // MARK: - Transcribe (ASR + смысловые звенья)
    //
    // По остановке записи интерактор транскрибирует аудио и отмечает, какие
    // смысловые звенья (опора-вопросы) названы в речи ребёнка.

    enum Transcribe {
        struct Response {
            let frameId: String
            /// Все звенья текущего кадра.
            let links: [StoryLink]
            /// Идентификаторы звеньев, распознанных в речи (новые + ранее).
            let coveredLinkIds: Set<String>
            /// Звенья именно этого кадра, что названы.
            let frameCovered: Bool
            let transcript: String
        }
        struct ViewModel {
            let supports: [SupportViewModel]
            let mascotText: String
            let allFrameLinksNamed: Bool
        }
    }

    // MARK: - BuildMovie (экран 3: склейка + радар полноты)

    enum BuildMovie {
        struct Request {}
        struct Response {
            let series: PictureSeries
            let frames: [PictureFrame]
            /// Покрытие по ролям арки (завязка/действие/развязка) 0…1.
            let arc: StoryArc
            let totalWords: Int
            let toldFrameCount: Int
            let totalDurationSeconds: Double
        }
        struct ViewModel {
            let title: String
            let seriesTitle: String
            let playerFrames: [FrameViewModel]
            let durationLabel: String
            let arc: ArcViewModel
            let pills: [PillViewModel]
            let mascotText: String
            let isComplete: Bool
            /// Роль, которой не хватает (для CTA «дорассказать»), nil если полно.
            let missingRole: StoryLinkRole?
        }
    }

    // MARK: - View-side frame models

    /// Лёгкая модель кадра для подноса / ленты / плеера.
    struct FrameViewModel: Equatable, Identifiable {
        let id: String
        let scene: StoryPictureScene
        let imageAsset: String?
        let order: Int
        let isTold: Bool
    }

    /// Слот ленты событий.
    struct SlotViewModel: Equatable, Identifiable {
        let id: Int          // = slotIndex
        let number: Int      // 1-based для подписи
        let frame: FrameViewModel?
        let isNext: Bool
        let isCorrect: Bool
    }

    /// Модель кадра на экране рассказа.
    struct TellFrameViewModel: Equatable {
        let frameId: String
        let scene: StoryPictureScene
        let imageAsset: String?
        let badge: String
        let frameIndex: Int
        let totalFrames: Int
        let supports: [SupportViewModel]
        let mascotText: String
    }

    /// Опора-вопрос под картинкой.
    struct SupportViewModel: Equatable, Identifiable {
        let id: String
        let question: String
        let answerHint: String
        let isNamed: Bool
    }

    /// Сегмент радар-арки полноты.
    struct ArcViewModel: Equatable {
        let segments: [Segment]
        let percentLabel: String
        let isComplete: Bool

        struct Segment: Equatable, Identifiable {
            let id: String      // role.rawValue
            let role: StoryLinkRole
            let title: String
            let summary: String
            /// 0…1 заполнение.
            let fill: Double
            /// Сегмент полный (для mint vs gold-акцента).
            let isComplete: Bool
        }
    }

    struct PillViewModel: Equatable, Identifiable {
        let id: String
        let text: String
        let isGold: Bool
    }
}

// MARK: - Domain types

/// Роль смыслового звена в структуре рассказа (story grammar).
enum StoryLinkRole: String, Sendable, Equatable, Codable, CaseIterable {
    case setup       // завязка
    case action      // действие / середина
    case resolution  // развязка / конец

    var displayName: String {
        switch self {
        case .setup:      return String(localized: "storyPictures.role.setup", defaultValue: "Завязка")
        case .action:     return String(localized: "storyPictures.role.action", defaultValue: "Действие")
        case .resolution: return String(localized: "storyPictures.role.resolution", defaultValue: "Развязка")
        }
    }
}

/// Одно смысловое звено кадра — опора-вопрос с ключевыми словами для ASR-матчинга.
struct StoryLink: Sendable, Equatable, Identifiable, Codable {
    let id: String
    let role: StoryLinkRole
    /// Опора-вопрос («Кто?», «Что делает?», «Чем закончилось?»).
    let question: String
    /// Краткая подсказка-ответ (для подписи опоры).
    let answerHint: String
    /// Корни-ключи для нечёткого матчинга в транскрипте (lowercased).
    let keywords: [String]
}

/// Тип векторной сцены кадра — рендерится `StoryScenePainter` (COPPA-safe
/// животные/предметы без людей; иллюстрации серий не зависят от фото-ассетов).
enum StoryPictureScene: String, Sendable, Equatable, Codable {
    case hedgehogSeesTree
    case hedgehogShakesTree
    case hedgehogRollsApple
    case hedgehogCarriesHome
    case kittenSeesMilk
    case kittenDrinks
    case kittenSleeps
    case squirrelFindsNut
    case squirrelClimbs
    case squirrelHidesNut
    case squirrelWinter
    case bunnyDigs
    case bunnyWaters
    case bunnyHarvest
    /// Фоллбэк для неизвестной строки сцены из пака.
    case generic
}

/// Один кадр сюжетной серии.
struct PictureFrame: Sendable, Equatable, Identifiable {
    let id: String
    /// Правильная позиция кадра в серии (1-based).
    let order: Int
    let scene: StoryPictureScene
    let caption: String
    /// Опциональный `word_*`-ассет (если кадр иллюстрирует один предмет).
    let imageAsset: String?
    let links: [StoryLink]
}

/// Сюжетная серия картинок.
struct PictureSeries: Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    let minAge: Int
    let maxAge: Int
    /// Базовая сцена-персонаж серии (для общего стиля).
    let scene: StoryPictureScene
    let frames: [PictureFrame]

    /// Кадры в правильном порядке (по полю `order`).
    var orderedFrames: [PictureFrame] {
        frames.sorted { $0.order < $1.order }
    }
}

/// Покрытие структуры рассказа по ролям арки.
struct StoryArc: Sendable, Equatable {
    /// role → доля названных звеньев этой роли (0…1).
    let coverageByRole: [StoryLinkRole: Double]

    func fill(for role: StoryLinkRole) -> Double {
        coverageByRole[role] ?? 0
    }

    /// Полнота рассказа — среднее покрытие присутствующих ролей.
    var completeness: Double {
        let present = StoryLinkRole.allCases.filter { coverageByRole[$0] != nil }
        guard !present.isEmpty else { return 0 }
        let sum = present.reduce(0.0) { $0 + (coverageByRole[$1] ?? 0) }
        return sum / Double(present.count)
    }

    /// Первая роль с неполным покрытием (для мягкой подсказки «дорассказать»).
    var firstIncompleteRole: StoryLinkRole? {
        StoryLinkRole.allCases.first { (coverageByRole[$0] ?? 1) < 0.999 && coverageByRole[$0] != nil }
    }
}

// MARK: - Phase

/// Экран фичи — управляет переключением подвью.
enum StoryPicturesPhase: Sendable, Equatable {
    case loading
    case order   // экран 1: разложи по порядку
    case tell    // экран 2: расскажи по картинкам
    case movie   // экран 3: готовый мультик
}

// MARK: - View display state

@MainActor
@Observable
final class StoryPicturesDisplay {

    // Серия
    var seriesTitle: String = ""
    var frameCount: Int = 0

    // Экран 1: упорядочивание
    var slots: [StoryPicturesModels.SlotViewModel] = []
    var trayFrames: [StoryPicturesModels.FrameViewModel] = []
    var isFilled: Bool = false
    var isOrderCorrect: Bool = false
    var nextSlotIndex: Int?
    var orderHintText: String = ""

    // Экран 2: рассказ
    var tellFrame: StoryPicturesModels.TellFrameViewModel?
    var tellFrameIndex: Int = 0
    /// Кадры в правильном порядке для плёнки (told-флаг обновляется по ходу).
    var orderedFrames: [StoryPicturesModels.FrameViewModel] = []
    var toldFrameIds: Set<String> = []
    var supports: [StoryPicturesModels.SupportViewModel] = []
    var isRecording: Bool = false
    var recordTimeLabel: String = "0:00"
    var amplitude: Float = 0
    var allFrameLinksNamed: Bool = false

    // Экран 3: мультик + радар
    var movieTitle: String = ""
    var playerFrames: [StoryPicturesModels.FrameViewModel] = []
    var durationLabel: String = "0:00"
    var arc: StoryPicturesModels.ArcViewModel?
    var pills: [StoryPicturesModels.PillViewModel] = []
    var isStoryComplete: Bool = false
    var missingRole: StoryLinkRole?

    // Общее
    var mascotText: String = ""
    var phase: StoryPicturesPhase = .loading
    var isPlaying: Bool = false
    var pendingExit: Bool = false
}
