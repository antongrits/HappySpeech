import Foundation
import OSLog

// MARK: - SoundOfTheDayInteractor
//
// VIP-Interactor для «Звук дня».
//
// Поток:
//   1. `loadToday(_:)` — берёт звук дня из AdaptivePlannerService
//      (первый шаг daily route), стрик из ChildRepository, имя ребёнка
//      и формирует список 3 активностей. Если planner упал — fallback на «Р».
//   2. `selectActivity(_:)` — Router → LessonPlayer.

@MainActor
final class SoundOfTheDayInteractor {

    // MARK: - Dependencies

    private let presenter: SoundOfTheDayPresenter
    private let router: SoundOfTheDayRouter
    private let adaptivePlannerService: any AdaptivePlannerService
    private let childRepository: any ChildRepository
    private let childId: String

    /// P0-2: звук дня, выбранный планировщиком/профилем в `loadToday`. Передаётся
    /// в LessonPlayer, чтобы активность тренировала именно его, а не хардкод.
    private var resolvedTargetSound: String = ""

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundOfTheDay.Interactor"
    )

    // MARK: - Init

    init(
        presenter: SoundOfTheDayPresenter,
        router: SoundOfTheDayRouter,
        adaptivePlannerService: any AdaptivePlannerService,
        childRepository: any ChildRepository,
        childId: String
    ) {
        self.presenter = presenter
        self.router = router
        self.adaptivePlannerService = adaptivePlannerService
        self.childRepository = childRepository
        self.childId = childId
    }

    // MARK: - Load

    func loadToday(_ request: SoundOfTheDayModels.LoadToday.Request) async {
        let childName = await fetchChildName(childId: request.childId)
        let streakDays = await fetchStreakDays(childId: request.childId)
        let targetSound = await fetchTargetSound(childId: request.childId)
        resolvedTargetSound = targetSound
        let response = SoundOfTheDayModels.LoadToday.Response(
            childName: childName,
            targetSound: targetSound,
            weekdayDateText: Self.weekdayDateString(),
            reasonText: Self.reasonText(for: streakDays),
            streakDays: streakDays,
            activities: ActivityCard.all
        )
        await presenter.presentLoadToday(response: response)
    }

    // MARK: - Select Activity

    func selectActivity(_ request: SoundOfTheDayModels.SelectActivity.Request) {
        Self.logger.info(
            "Звук дня: выбрана активность \(request.activity.id, privacy: .public)"
        )
        router.routeToActivity(request.activity, childId: childId, targetSound: resolvedTargetSound)
    }

    /// Удобный метод для CTA «Начать день» — берёт первую активность.
    func startDay() {
        let first = ActivityCard.all.first ?? ActivityCard.play
        router.routeToActivity(first, childId: childId, targetSound: resolvedTargetSound)
    }

    // MARK: - Private

    private func fetchChildName(childId: String) async -> String {
        do {
            let profile = try await childRepository.fetch(id: childId)
            return profile.name
        } catch {
            Self.logger.error(
                "fetchChildName error: \(error.localizedDescription, privacy: .public)"
            )
            return ""
        }
    }

    private func fetchStreakDays(childId: String) async -> Int {
        do {
            let profile = try await childRepository.fetch(id: childId)
            return profile.currentStreak
        } catch {
            return 0
        }
    }

    private func fetchTargetSound(childId: String) async -> String {
        do {
            let route = try await adaptivePlannerService.buildDailyRoute(for: childId)
            if let first = route.steps.first?.targetSound, !first.isEmpty {
                return first
            }
        } catch {
            Self.logger.warning(
                "buildDailyRoute упал, fallback Р: \(error.localizedDescription, privacy: .public)"
            )
        }
        return "Р"
    }

    /// Кэшируем форматтер — пересоздаётся редко (раз в init).
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "EEEE, d MMMM"
        return f
    }()

    private static func weekdayDateString(now: Date = Date()) -> String {
        dateFormatter.string(from: now)
    }

    private static func reasonText(for streakDays: Int) -> String {
        switch streakDays {
        case 0:
            return String(localized: "sotd.reason.fresh")
        case 1...2:
            return String(localized: "sotd.reason.warmup")
        case 3...6:
            return String(localized: "sotd.reason.building")
        default:
            return String(localized: "sotd.reason.streak.strong")
        }
    }
}
