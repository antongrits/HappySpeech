import Foundation

// MARK: - HelpCenterModels (Clean Swift: Models)
//
// Block AE v21 — экран справки с FAQ-аккордеоном, видеоуроками и
// единым CTA «Связаться с логопедом».
//
// Persistence: статический корпус (FAQ + 5 видео-туториалов в Resources).
// COPPA: всё on-device, no networking.

// MARK: - FAQEntry

/// Один FAQ-айтем. `questionKey` / `answerKey` — ключи Localizable.xcstrings.
public struct FAQEntry: Identifiable, Sendable, Equatable {
    public let id: String
    public let questionKey: String
    public let answerKey: String
    public let category: FAQCategory

    public init(
        id: String,
        questionKey: String,
        answerKey: String,
        category: FAQCategory
    ) {
        self.id = id
        self.questionKey = questionKey
        self.answerKey = answerKey
        self.category = category
    }
}

// MARK: - FAQCategory

public enum FAQCategory: String, CaseIterable, Sendable {
    case gettingStarted   // первые шаги
    case voiceRecognition // микрофон / распознавание
    case progress         // отслеживание прогресса
    case parentControl    // родительский контроль
    case privacy          // приватность и COPPA

    public var titleKey: String {
        switch self {
        case .gettingStarted:   return "helpCenter.category.gettingStarted"
        case .voiceRecognition: return "helpCenter.category.voiceRecognition"
        case .progress:         return "helpCenter.category.progress"
        case .parentControl:    return "helpCenter.category.parentControl"
        case .privacy:          return "helpCenter.category.privacy"
        }
    }

    public var symbolName: String {
        switch self {
        case .gettingStarted:   return "sparkles"
        case .voiceRecognition: return "mic.fill"
        case .progress:         return "chart.line.uptrend.xyaxis"
        case .parentControl:    return "person.2.fill"
        case .privacy:          return "lock.shield.fill"
        }
    }
}

// MARK: - TutorialVideo

public struct TutorialVideo: Identifiable, Sendable, Equatable {
    public let id: String
    public let titleKey: String
    public let descriptionKey: String
    public let resourceName: String   // без .mp4
    public let durationSeconds: Int
    public let symbolName: String

    public init(
        id: String,
        titleKey: String,
        descriptionKey: String,
        resourceName: String,
        durationSeconds: Int,
        symbolName: String
    ) {
        self.id = id
        self.titleKey = titleKey
        self.descriptionKey = descriptionKey
        self.resourceName = resourceName
        self.durationSeconds = durationSeconds
        self.symbolName = symbolName
    }
}

// MARK: - HelpCenterModels namespace

enum HelpCenterModels {

    // MARK: Load

    enum Load {
        struct Request: Sendable {}

        struct Response: Sendable {
            let categories: [FAQCategory]
            let entries: [FAQEntry]
            let videos: [TutorialVideo]
            let cinema: [TutorialVideo]
        }

        struct ViewModel: Sendable {
            let categories: [CategoryViewModel]
            let videoSection: VideoSectionViewModel
            let cinemaSection: VideoSectionViewModel
            let contactCta: String
            let contactDescription: String
        }

        struct CategoryViewModel: Identifiable, Sendable {
            let id: String                 // FAQCategory.rawValue
            let title: String
            let symbolName: String
            let entries: [FAQEntryViewModel]
        }

        struct FAQEntryViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let question: String
            let answer: String
            let categoryTitle: String
        }

        struct VideoSectionViewModel: Sendable {
            let title: String
            let subtitle: String
            let videos: [VideoCellViewModel]
        }

        struct VideoCellViewModel: Identifiable, Sendable {
            let id: String
            let title: String
            let description: String
            let resourceName: String
            let durationLabel: String       // «1:25»
            let symbolName: String
            let accessibilityLabel: String
        }
    }

    // MARK: ToggleFAQ

    enum ToggleFAQ {
        struct Request: Sendable {
            let entryId: String
        }

        struct Response: Sendable {
            let entryId: String
            let expanded: Bool
        }

        struct ViewModel: Sendable {
            let entryId: String
            let expanded: Bool
        }
    }

    // MARK: SelectVideo

    enum SelectVideo {
        struct Request: Sendable {
            let videoId: String
        }

        struct Response: Sendable {
            let video: TutorialVideo
        }

        struct ViewModel: Sendable {
            let videoTitle: String
            let videoDescription: String
            let resourceName: String
            let durationLabel: String
        }
    }

    // MARK: ContactSupport

    enum ContactSupport {
        struct Request: Sendable {}

        struct Response: Sendable {
            let success: Bool
        }

        struct ViewModel: Sendable {
            let toastMessage: String
        }
    }
}

// MARK: - HelpCenterCorpus

/// Статический корпус FAQ-айтемов + 5 видеоуроков.
public enum HelpCenterCorpus {

    public static let faqs: [FAQEntry] = [
        // Getting started
        .init(id: "faq-gs-1",
              questionKey: "helpCenter.faq.gs1.question",
              answerKey: "helpCenter.faq.gs1.answer",
              category: .gettingStarted),
        .init(id: "faq-gs-2",
              questionKey: "helpCenter.faq.gs2.question",
              answerKey: "helpCenter.faq.gs2.answer",
              category: .gettingStarted),
        .init(id: "faq-gs-3",
              questionKey: "helpCenter.faq.gs3.question",
              answerKey: "helpCenter.faq.gs3.answer",
              category: .gettingStarted),

        // Voice recognition
        .init(id: "faq-vr-1",
              questionKey: "helpCenter.faq.vr1.question",
              answerKey: "helpCenter.faq.vr1.answer",
              category: .voiceRecognition),
        .init(id: "faq-vr-2",
              questionKey: "helpCenter.faq.vr2.question",
              answerKey: "helpCenter.faq.vr2.answer",
              category: .voiceRecognition),
        .init(id: "faq-vr-3",
              questionKey: "helpCenter.faq.vr3.question",
              answerKey: "helpCenter.faq.vr3.answer",
              category: .voiceRecognition),

        // Progress
        .init(id: "faq-pr-1",
              questionKey: "helpCenter.faq.pr1.question",
              answerKey: "helpCenter.faq.pr1.answer",
              category: .progress),
        .init(id: "faq-pr-2",
              questionKey: "helpCenter.faq.pr2.question",
              answerKey: "helpCenter.faq.pr2.answer",
              category: .progress),

        // Parent control
        .init(id: "faq-pc-1",
              questionKey: "helpCenter.faq.pc1.question",
              answerKey: "helpCenter.faq.pc1.answer",
              category: .parentControl),
        .init(id: "faq-pc-2",
              questionKey: "helpCenter.faq.pc2.question",
              answerKey: "helpCenter.faq.pc2.answer",
              category: .parentControl),

        // Privacy
        .init(id: "faq-pv-1",
              questionKey: "helpCenter.faq.pv1.question",
              answerKey: "helpCenter.faq.pv1.answer",
              category: .privacy),
        .init(id: "faq-pv-2",
              questionKey: "helpCenter.faq.pv2.question",
              answerKey: "helpCenter.faq.pv2.answer",
              category: .privacy)
    ]

    /// 5 туториальных видео в `Resources/Videos/tutorials/*.mp4`.
    public static let videos: [TutorialVideo] = [
        .init(id: "tut-how-to-play",
              titleKey: "helpCenter.video.howToPlay.title",
              descriptionKey: "helpCenter.video.howToPlay.description",
              resourceName: "tutorial_how_to_play",
              durationSeconds: 95,
              symbolName: "play.rectangle.fill"),
        .init(id: "tut-articulation",
              titleKey: "helpCenter.video.articulation.title",
              descriptionKey: "helpCenter.video.articulation.description",
              resourceName: "tutorial_articulation",
              durationSeconds: 120,
              symbolName: "mouth.fill"),
        .init(id: "tut-breathing",
              titleKey: "helpCenter.video.breathing.title",
              descriptionKey: "helpCenter.video.breathing.description",
              resourceName: "tutorial_breathing",
              durationSeconds: 65,
              symbolName: "wind"),
        .init(id: "tut-ar-setup",
              titleKey: "helpCenter.video.arSetup.title",
              descriptionKey: "helpCenter.video.arSetup.description",
              resourceName: "tutorial_ar_setup",
              durationSeconds: 110,
              symbolName: "camera.fill"),
        .init(id: "tut-progress",
              titleKey: "helpCenter.video.progressTracking.title",
              descriptionKey: "helpCenter.video.progressTracking.description",
              resourceName: "tutorial_progress_tracking",
              durationSeconds: 85,
              symbolName: "chart.line.uptrend.xyaxis"),

        // Обучающие видео-мультики (Veo): звук ↔ образ. Файлы в Videos/lessons/edu/.
        .init(id: "edu-s", titleKey: "helpCenter.video.edu_s.title",
              descriptionKey: "helpCenter.video.edu_s.description",
              resourceName: "demo_sound_s", durationSeconds: 8, symbolName: "speaker.wave.2.fill"),
        .init(id: "edu-r", titleKey: "helpCenter.video.edu_r.title",
              descriptionKey: "helpCenter.video.edu_r.description",
              resourceName: "demo_sound_r", durationSeconds: 8, symbolName: "car.fill"),
        .init(id: "edu-l", titleKey: "helpCenter.video.edu_l.title",
              descriptionKey: "helpCenter.video.edu_l.description",
              resourceName: "demo_sound_l", durationSeconds: 8, symbolName: "ferry.fill"),
        .init(id: "edu-sh", titleKey: "helpCenter.video.edu_sh.title",
              descriptionKey: "helpCenter.video.edu_sh.description",
              resourceName: "demo_sound_sh", durationSeconds: 8, symbolName: "wind"),
        .init(id: "edu-zh", titleKey: "helpCenter.video.edu_zh.title",
              descriptionKey: "helpCenter.video.edu_zh.description",
              resourceName: "demo_sound_zh", durationSeconds: 8, symbolName: "ant.fill"),
        .init(id: "edu-k", titleKey: "helpCenter.video.edu_k.title",
              descriptionKey: "helpCenter.video.edu_k.description",
              resourceName: "demo_sound_k", durationSeconds: 8, symbolName: "arrowtriangle.down.fill"),
        .init(id: "edu-breath", titleKey: "helpCenter.video.edu_breath.title",
              descriptionKey: "helpCenter.video.edu_breath.description",
              resourceName: "demo_breath_dandelion", durationSeconds: 8, symbolName: "wind"),
        .init(id: "edu-story-s", titleKey: "helpCenter.video.edu_story_s.title",
              descriptionKey: "helpCenter.video.edu_story_s.description",
              resourceName: "story_sad_na_s", durationSeconds: 8, symbolName: "leaf.fill"),
        .init(id: "edu-story-sh", titleKey: "helpCenter.video.edu_story_sh.title",
              descriptionKey: "helpCenter.video.edu_story_sh.description",
              resourceName: "story_lesnaya_shishka", durationSeconds: 8, symbolName: "tree.fill"),
        .init(id: "edu-story-r", titleKey: "helpCenter.video.edu_story_r.title",
              descriptionKey: "helpCenter.video.edu_story_r.description",
              resourceName: "story_raduga_r", durationSeconds: 8, symbolName: "cloud.rain.fill"),
        .init(id: "edu-story-l", titleKey: "helpCenter.video.edu_story_l.title",
              descriptionKey: "helpCenter.video.edu_story_l.description",
              resourceName: "story_luzhayka_l", durationSeconds: 8, symbolName: "sun.max.fill"),
        .init(id: "edu-story-z", titleKey: "helpCenter.video.edu_story_z.title",
              descriptionKey: "helpCenter.video.edu_story_z.description",
              resourceName: "story_zimnyaya_z", durationSeconds: 8, symbolName: "snowflake"),

        // Длинные обучающие мультики (Veo 3.1, склейка нескольких сцен + озвучка Ляли).
        // Файлы в Videos/lessons/edu/. 1–5 минут, связный сюжет по методике.
        .init(id: "movie-r", titleKey: "helpCenter.video.movie_r.title",
              descriptionKey: "helpCenter.video.movie_r.description",
              resourceName: "story_journey_r", durationSeconds: 48, symbolName: "map.fill"),
        .init(id: "movie-hisses", titleKey: "helpCenter.video.movie_hisses.title",
              descriptionKey: "helpCenter.video.movie_hisses.description",
              resourceName: "story_day_hisses", durationSeconds: 56, symbolName: "house.fill"),
        .init(id: "movie-l", titleKey: "helpCenter.video.movie_l.title",
              descriptionKey: "helpCenter.video.movie_l.description",
              resourceName: "story_tale_l", durationSeconds: 48, symbolName: "book.fill"),
        .init(id: "movie-gym", titleKey: "helpCenter.video.movie_gym.title",
              descriptionKey: "helpCenter.video.movie_gym.description",
              resourceName: "story_tongue_gym", durationSeconds: 48, symbolName: "figure.flexibility")
    ]

    /// «Кинозал» — раздел «Мультфильм о Ляле»: кат-сцены, доступные для
    /// пересмотра (read-only, parent-контур; `seen` НЕ проверяется).
    /// Источник — `CutsceneCatalog.movieReel`. Показываем ТОЛЬКО кат-сцены с
    /// готовым видео (`videoReady`), чтобы в кинозале не было пустых строк;
    /// дополнительная проверка наличия файла в бандле — в `FAQRepositoryWorker`.
    public static let cutsceneMovies: [TutorialVideo] = CutsceneCatalog.movieReel
        .filter { $0.videoReady }
        .map { cutscene in
            TutorialVideo(
                id: "cutscene-\(cutscene.id)",
                titleKey: "cutscene.helpcenter.\(cutscene.id).title",
                descriptionKey: cutscene.voiceoverKey,
                resourceName: cutscene.videoResourceName,
                durationSeconds: cutsceneDurationSeconds[cutscene.id] ?? 30,
                symbolName: "sparkles.tv.fill"
            )
        }

    /// Длительности кат-сцен (сек) — зеркало `cutscenes`-секции video-manifest.
    /// Значения измерены ffprobe из реальных mp4-файлов в бандле.
    private static let cutsceneDurationSeconds: [String: Int] = [
        "cs-prologue": 17,
        "cs-isl-whistling-in": 19, "cs-isl-whistling-out": 14,
        "cs-isl-hissing-in": 22, "cs-isl-hissing-out": 6,
        "cs-isl-affr-in": 11, "cs-isl-affr-out": 14,
        "cs-isl-sonor-in": 14, "cs-isl-sonor-out": 21,
        "cs-isl-velar-in": 22, "cs-isl-velar-out": 14,
        "cs-isl-grammar-in": 14, "cs-isl-grammar-out": 14,
        "cs-finale": 56, "cs-streak-7": 6, "cs-streak-30": 6
    ]

    public static func video(forId id: String) -> TutorialVideo? {
        videos.first { $0.id == id } ?? cutsceneMovies.first { $0.id == id }
    }

    public static func entry(forId id: String) -> FAQEntry? {
        faqs.first { $0.id == id }
    }
}
