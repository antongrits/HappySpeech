@testable import HappySpeech
import XCTest

// MARK: - SoundHunterDayInteractorTests
//
// Бизнес-логика «Звукового охотника дня» (перенос звука в спонтанную речь).
// Покрываем реальные ветки интерактора:
//   • start          — резолв звука дня, поднятие/создание дневного CarryoverLog,
//                       серия дней охоты + недельные точки, empty-childId guard;
//   • catchWord      — «поймал слово»: дедуп (без регистра), потолок netGoal,
//                       justStarted-флаг + планирование утреннего напоминания,
//                       пословный outcome в планировщике, персист;
//   • toggleTask     — отметить/снять задание-охоту, персист;
//   • parentCheckIn  — 3 градации → SM-2 quality + сдвиг CorrectionStage
//                       (clean ×2 → продвижение; notyet → откат к автоматизации);
//   • voice note     — запись/сохранение через worker; без worker — no-op;
//   • saveAndClose   — финальный персист + presentSaved.
//
// Все зависимости мокаются (репозитории/планировщик/нотификации/voice-worker);
// время и календарь зафиксированы → детерминированные серии/точки недели.

@MainActor
final class SoundHunterDayInteractorTests: XCTestCase {

    // MARK: - Spy presenter

    private final class SpyPresenter: SoundHunterDayPresentationLogic {
        var starts: [SoundHunterDayModels.Start.Response] = []
        var catches: [SoundHunterDayModels.CatchWord.Response] = []
        var toggles: [SoundHunterDayModels.ToggleTask.Response] = []
        var hintToggles = 0
        var checkIns: [SoundHunterDayModels.ParentCheckIn.Response] = []
        var recordings: [(isRecording: Bool, durationSec: Double)] = []
        var savedNotes: [Double] = []
        var unavailableCount = 0
        var savedCount = 0

        func presentStart(_ response: SoundHunterDayModels.Start.Response) { starts.append(response) }
        func presentCatchWord(_ response: SoundHunterDayModels.CatchWord.Response) { catches.append(response) }
        func presentToggleTask(_ response: SoundHunterDayModels.ToggleTask.Response) { toggles.append(response) }
        func presentToggleHint() { hintToggles += 1 }
        func presentParentCheckIn(_ response: SoundHunterDayModels.ParentCheckIn.Response) { checkIns.append(response) }
        func presentRecording(isRecording: Bool, durationSec: Double) {
            recordings.append((isRecording, durationSec))
        }
        func presentVoiceNoteSaved(durationSec: Double) { savedNotes.append(durationSec) }
        func presentUnavailable() { unavailableCount += 1 }
        func presentSaved() { savedCount += 1 }
    }

    // MARK: - Controllable voice-note worker

    private final class StubVoiceNoteWorker: CarryoverVoiceNoteWorking, @unchecked Sendable {
        var isRecording = false
        var currentDurationSec: Double = 0
        var maxDurationSec: Double = 30
        /// Результат finishAndPersist (nil → «записи не было»).
        var persistResult: (relativePath: String, durationSec: Double)? = ("CarryoverNotes/note.m4a", 4.0)
        var startShouldThrow = false
        private(set) var startCount = 0
        private(set) var cancelCount = 0

        func requestPermission() async -> Bool { true }
        func startRecording() async throws {
            startCount += 1
            if startShouldThrow { throw AppError.audioPermissionDenied }
            isRecording = true
        }
        func finishAndPersist(childId: String) -> (relativePath: String, durationSec: Double)? {
            isRecording = false
            return persistResult
        }
        func cancel() { cancelCount += 1; isRecording = false }
    }

    // MARK: - Fixtures

    /// Зафиксированный «сегодня» — среда 2026-06-17 12:00, gregorian, UTC-нейтрально.
    private var fixedNow: Date {
        var c = DateComponents()
        c.year = 2026; c.month = 6; c.day = 17; c.hour = 12
        return calendar.date(from: c)!
    }

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Minsk") ?? .current
        return cal
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = 12
        return calendar.date(from: c)!
    }

    private func rMission() -> CarryoverMission {
        CarryoverMission(
            sound: "Р",
            soundball: "🎯",
            title: "Ловим звук Р!",
            subtitle: "Слушай себя.",
            hint: "Ищи слова с Р.",
            examples: ["рыба", "ковёр", "корова"],
            tasks: [
                CarryoverTask(id: "home-objects", icon: "🏠", title: "Назови 3 предмета", subtitle: ""),
                CarryoverTask(id: "tell-about", icon: "💬", title: "Расскажи историю", subtitle: "")
            ],
            netGoal: 3
        )
    }

    private func makeProfile(
        id: String = "kid-1",
        targetSounds: [String] = ["Р"],
        progress: [String: Double] = ["Р": 0.4]
    ) -> ChildProfileDTO {
        ChildProfileDTO(
            id: id, name: "Миша", age: 6, targetSounds: targetSounds,
            parentId: "local-parent", progressSummary: progress
        )
    }

    private struct SUT {
        let interactor: SoundHunterDayInteractor
        let presenter: SpyPresenter
        let childRepo: MockChildRepository
        let carryoverRepo: MockCarryoverLogRepository
        let planner: MockAdaptivePlannerService
        let stageStore: UserDefaultsStageProgressStore
        let notifications: SpyNotificationService
        let voiceWorker: StubVoiceNoteWorker
        let suiteName: String
    }

    private func makeSUT(
        childId: String = "kid-1",
        profile: ChildProfileDTO? = nil,
        seedLogs: [CarryoverLogDTO] = [],
        mission: CarryoverMission? = nil,
        voiceWorker: StubVoiceNoteWorker? = StubVoiceNoteWorker(),
        now: Date? = nil
    ) -> SUT {
        let presenter = SpyPresenter()
        let resolvedProfile = profile ?? makeProfile(id: childId)
        let childRepo = MockChildRepository(children: [resolvedProfile])
        let carryoverRepo = MockCarryoverLogRepository(logs: seedLogs)
        let planner = MockAdaptivePlannerService()
        let suiteName = "soundHunterTests.\(UUID().uuidString)"
        let stageStore = UserDefaultsStageProgressStore(suiteName: suiteName)
        let notifications = SpyNotificationService()
        let worker = voiceWorker
        let loader = CarryoverMissionLoader(seededMissions: [mission ?? rMission()])
        let fixed = now ?? fixedNow
        let interactor = SoundHunterDayInteractor(
            childId: childId,
            childRepository: childRepo,
            carryoverRepository: carryoverRepo,
            missionLoader: loader,
            adaptivePlanner: planner,
            stageProgressStore: stageStore,
            notificationService: notifications,
            voiceNoteWorker: worker,
            calendar: calendar,
            now: { fixed }
        )
        interactor.presenter = presenter
        return SUT(
            interactor: interactor, presenter: presenter, childRepo: childRepo,
            carryoverRepo: carryoverRepo, planner: planner, stageStore: stageStore,
            notifications: notifications, voiceWorker: worker ?? StubVoiceNoteWorker(),
            suiteName: suiteName
        )
    }

    override func tearDown() {
        // Изолированные suite'ы за собой не оставляем.
        super.tearDown()
    }

    // MARK: - start

    func test_start_resolvesMissionAndCreatesDailyLog() async {
        let sut = makeSUT()
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))

        XCTAssertEqual(sut.presenter.starts.count, 1)
        let resp = sut.presenter.starts.first
        XCTAssertEqual(resp?.mission.sound, "Р")
        XCTAssertEqual(resp?.mission.netGoal, 3)
        XCTAssertEqual(resp?.childName, "Миша")
        XCTAssertEqual(resp?.childAge, 6)
        XCTAssertEqual(resp?.circuit, .kid)
        // Новый дневной лог создан и сохранён в репозитории.
        XCTAssertEqual(sut.carryoverRepo.logs.count, 1)
        XCTAssertEqual(sut.carryoverRepo.logs.first?.sound, "Р")
        XCTAssertEqual(sut.carryoverRepo.logs.first?.netGoal, 3)
        XCTAssertTrue(sut.carryoverRepo.logs.first?.caughtWords.isEmpty ?? false)
    }

    func test_start_emptyChildId_presentsUnavailable() async {
        let sut = makeSUT(childId: "")
        await sut.interactor.start(.init(childId: "", circuit: .kid))

        XCTAssertEqual(sut.presenter.unavailableCount, 1)
        XCTAssertTrue(sut.presenter.starts.isEmpty)
        XCTAssertTrue(sut.carryoverRepo.logs.isEmpty)
    }

    func test_start_reusesExistingDayLog() async {
        let today = calendar.startOfDay(for: fixedNow)
        let existing = CarryoverLogDTO(
            id: CarryoverLogDTO.makeId(childId: "kid-1", sound: "Р", day: today),
            childId: "kid-1", sound: "Р", day: today,
            caughtWords: ["рыба"], netGoal: 3
        )
        let sut = makeSUT(seedLogs: [existing])
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))

        // Существующий лог поднят, а не перезаписан пустым.
        XCTAssertEqual(sut.presenter.starts.first?.log.caughtWords, ["рыба"])
        XCTAssertEqual(sut.carryoverRepo.logs.count, 1)
        XCTAssertEqual(sut.carryoverRepo.logs.first?.caughtWords, ["рыба"])
    }

    func test_start_profileFetchFails_fallsBackToDefaultSound() async {
        let sut = makeSUT()
        // Профиля для этого childId нет → fetch(id:) бросает entityNotFound
        // (реальный отказ загрузки; флаг shouldFail у мока влияет только на
        // fetchAll, поэтому опустошаем выборку — это и есть «профиль не загрузился»).
        sut.childRepo.children = []
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))

        // Профиль не загрузился → пустые цели → дефолтный звук «Р» (pickSound).
        XCTAssertEqual(sut.presenter.starts.count, 1)
        XCTAssertEqual(sut.presenter.starts.first?.mission.sound, "Р")
        XCTAssertEqual(sut.presenter.starts.first?.childName, "")
        XCTAssertEqual(sut.presenter.starts.first?.childAge, 6)
    }

    func test_start_streak_countsConsecutiveActiveDaysIncludingToday() async {
        // Активность сегодня, вчера, позавчера → серия 3. Разрыв 4 дня назад.
        let logs = [
            activeLog(day: day(2026, 6, 17), words: ["рыба"]),  // сегодня
            activeLog(day: day(2026, 6, 16), words: ["рак"]),   // вчера
            activeLog(day: day(2026, 6, 15), words: ["рот"]),   // позавчера
            activeLog(day: day(2026, 6, 13), words: ["рука"])   // разрыв (14-го нет)
        ]
        let sut = makeSUT(seedLogs: logs)
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))

        XCTAssertEqual(sut.presenter.starts.first?.streakDays, 3)
        XCTAssertEqual(sut.presenter.starts.first?.weekDots.count, 7)
    }

    func test_start_streak_noActivityToday_countsFromYesterday() async {
        // Сегодня пусто, но вчера и позавчера активны → серия 2 (отсчёт со вчера).
        let logs = [
            activeLog(day: day(2026, 6, 16), words: ["рак"]),
            activeLog(day: day(2026, 6, 15), words: ["рот"])
        ]
        let sut = makeSUT(seedLogs: logs)
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))

        XCTAssertEqual(sut.presenter.starts.first?.streakDays, 2)
    }

    func test_start_streak_emptyHistory_isZero() async {
        let sut = makeSUT()
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))
        XCTAssertEqual(sut.presenter.starts.first?.streakDays, 0)
    }

    func test_start_weekDots_todayFlaggedAndNotOn() async {
        // 2026-06-17 — среда → индекс Пн=0 даёт mondayIndex = 2.
        let sut = makeSUT()
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))
        let dots = sut.presenter.starts.first?.weekDots ?? []
        XCTAssertEqual(dots.count, 7)
        XCTAssertEqual(dots[2].weekdayLabel, "Ср")
        XCTAssertTrue(dots[2].isToday, "Среда должна быть сегодня")
        XCTAssertFalse(dots[2].isOn, "Сегодняшний столбец не закрашивается как прошлый")
    }

    private func activeLog(day: Date, words: [String]) -> CarryoverLogDTO {
        CarryoverLogDTO(
            id: CarryoverLogDTO.makeId(childId: "kid-1", sound: "Р", day: day),
            childId: "kid-1", sound: "Р", day: calendar.startOfDay(for: day),
            caughtWords: words, netGoal: 3
        )
    }

    // MARK: - catchWord

    func test_catchWord_explicitWord_appendsAndPersists() async {
        let sut = makeSUT()
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))
        await sut.interactor.catchWord(.init(word: "корова"))

        XCTAssertEqual(sut.presenter.catches.count, 1)
        XCTAssertEqual(sut.presenter.catches.first?.log.caughtWords, ["корова"])
        XCTAssertTrue(sut.presenter.catches.first?.justStarted ?? false)
        // Персист в репозитории.
        XCTAssertEqual(sut.carryoverRepo.logs.first?.caughtWords, ["корова"])
    }

    func test_catchWord_nilWord_usesNextMissionExample() async {
        let sut = makeSUT()
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))
        await sut.interactor.catchWord(.init(word: nil))

        // Первый непойманный пример миссии — «рыба».
        XCTAssertEqual(sut.presenter.catches.first?.log.caughtWords, ["рыба"])
    }

    func test_catchWord_duplicateCaseInsensitive_notAddedTwice() async {
        let sut = makeSUT()
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))
        await sut.interactor.catchWord(.init(word: "Рыба"))
        await sut.interactor.catchWord(.init(word: "рыба"))

        XCTAssertEqual(sut.presenter.catches.last?.log.caughtWords, ["Рыба"],
                       "Повтор того же слова в другом регистре не должен дублироваться")
    }

    func test_catchWord_firstWord_schedulesMorningReminderOnce() async {
        let sut = makeSUT()
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))
        await sut.interactor.catchWord(.init(word: "рыба"))
        await sut.interactor.catchWord(.init(word: "ковёр"))

        XCTAssertEqual(sut.notifications.kidReminderNames, ["Миша"],
                       "Напоминание планируется только при ПЕРВОМ слове дня")
    }

    func test_catchWord_recordsItemOutcomeCorrect() async {
        let sut = makeSUT()
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))
        await sut.interactor.catchWord(.init(word: "рыба"))

        XCTAssertEqual(sut.planner.recordedItemOutcomes.count, 1)
        let outcome = sut.planner.recordedItemOutcomes.first
        XCTAssertEqual(outcome?.sound, "Р")
        XCTAssertTrue(outcome?.correct ?? false)
        XCTAssertEqual(outcome?.childId, "kid-1")
    }

    func test_catchWord_respectsNetGoalCap() async {
        let sut = makeSUT() // netGoal = 3
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))
        await sut.interactor.catchWord(.init(word: "рыба"))
        await sut.interactor.catchWord(.init(word: "ковёр"))
        await sut.interactor.catchWord(.init(word: "корова"))   // net = 3 → full
        await sut.interactor.catchWord(.init(word: "рак"))      // отклонено (full)

        XCTAssertEqual(sut.presenter.catches.last?.log.caughtWords.count, 3)
        XCTAssertTrue(sut.presenter.catches.last?.isNetFull ?? false)
        XCTAssertEqual(sut.carryoverRepo.logs.first?.caughtWords.count, 3,
                       "Сачок полон — четвёртое слово не сохраняется")
        // Пятый вызов на полном сачке тоже не уходит в outcome (только 3).
        XCTAssertEqual(sut.planner.recordedItemOutcomes.count, 3)
    }

    func test_catchWord_isNetFull_trueWhenReachingGoal() async {
        let sut = makeSUT()
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))
        await sut.interactor.catchWord(.init(word: "рыба"))
        XCTAssertFalse(sut.presenter.catches.last?.isNetFull ?? true)
        await sut.interactor.catchWord(.init(word: "ковёр"))
        XCTAssertFalse(sut.presenter.catches.last?.isNetFull ?? true)
        await sut.interactor.catchWord(.init(word: "корова"))
        XCTAssertTrue(sut.presenter.catches.last?.isNetFull ?? false)
    }

    // MARK: - toggleTask

    func test_toggleTask_addsThenRemoves() async {
        let sut = makeSUT()
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))

        await sut.interactor.toggleTask(.init(taskId: "home-objects"))
        XCTAssertEqual(sut.presenter.toggles.last?.log.completedTaskIds, ["home-objects"])
        XCTAssertEqual(sut.carryoverRepo.logs.first?.completedTaskIds, ["home-objects"])

        await sut.interactor.toggleTask(.init(taskId: "home-objects"))
        XCTAssertTrue(sut.presenter.toggles.last?.log.completedTaskIds.isEmpty ?? false)
        XCTAssertTrue(sut.carryoverRepo.logs.first?.completedTaskIds.isEmpty ?? false)
    }

    func test_toggleTask_beforeStart_isNoOp() async {
        let sut = makeSUT()
        await sut.interactor.toggleTask(.init(taskId: "home-objects"))
        XCTAssertTrue(sut.presenter.toggles.isEmpty)
    }

    // MARK: - toggleHint

    func test_toggleHint_relaysToPresenter() async {
        let sut = makeSUT()
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))
        sut.interactor.toggleHint()
        XCTAssertEqual(sut.presenter.hintToggles, 1)
    }

    // MARK: - parentCheckIn (SM-2 + CorrectionStage)

    func test_parentCheckIn_clean_mapsToPerfectQuality() async {
        let sut = makeSUT()
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))
        await sut.interactor.parentCheckIn(.init(grade: .clean))

        XCTAssertEqual(sut.planner.recordedQualities.last?.quality, .perfect)
        XCTAssertEqual(sut.planner.recordedQualities.last?.soundTarget, "Р")
        XCTAssertEqual(sut.presenter.checkIns.last?.grade, .clean)
        // Чек-ин персистится в логе.
        XCTAssertEqual(sut.carryoverRepo.logs.first?.parentCheckIn, "clean")
    }

    func test_parentCheckIn_sometimes_mapsToHardCorrect() async {
        let sut = makeSUT()
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))
        await sut.interactor.parentCheckIn(.init(grade: .sometimes))
        XCTAssertEqual(sut.planner.recordedQualities.last?.quality, .hardCorrect)
        XCTAssertEqual(sut.carryoverRepo.logs.first?.parentCheckIn, "sometimes")
    }

    func test_parentCheckIn_notyet_mapsToWrong() async {
        let sut = makeSUT()
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))
        await sut.interactor.parentCheckIn(.init(grade: .notyet))
        XCTAssertEqual(sut.planner.recordedQualities.last?.quality, .wrong)
        XCTAssertEqual(sut.carryoverRepo.logs.first?.parentCheckIn, "notyet")
    }

    func test_parentCheckIn_cleanTwice_advancesCorrectionStage() async {
        // Старт стадии — phrase; два чистых чек-ина подряд → продвижение к sentence.
        let sut = makeSUT()
        sut.stageStore.save(StageProgress(stage: .phrase, consecutiveQualifyingSessions: 0),
                            childId: "kid-1", sound: "Р")
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))

        await sut.interactor.parentCheckIn(.init(grade: .clean))
        XCTAssertEqual(sut.stageStore.progress(childId: "kid-1", sound: "Р").stage, .phrase,
                       "Первый чистый чек-ин копит счётчик, но ещё не продвигает")
        XCTAssertEqual(sut.stageStore.progress(childId: "kid-1", sound: "Р").consecutiveQualifyingSessions, 1)

        await sut.interactor.parentCheckIn(.init(grade: .clean))
        XCTAssertEqual(sut.stageStore.progress(childId: "kid-1", sound: "Р").stage, .sentence,
                       "Два чистых подряд → продвижение на следующий этап")
        XCTAssertEqual(sut.stageStore.progress(childId: "kid-1", sound: "Р").consecutiveQualifyingSessions, 0)
    }

    func test_parentCheckIn_notyet_rollsBackTowardAutomationFloor() async {
        // Со стадии sentence провал переноса → откат на один этап (phrase).
        let sut = makeSUT()
        sut.stageStore.save(StageProgress(stage: .sentence, consecutiveQualifyingSessions: 1),
                            childId: "kid-1", sound: "Р")
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))

        await sut.interactor.parentCheckIn(.init(grade: .notyet))
        XCTAssertEqual(sut.stageStore.progress(childId: "kid-1", sound: "Р").stage, .phrase)
        XCTAssertEqual(sut.stageStore.progress(childId: "kid-1", sound: "Р").consecutiveQualifyingSessions, 0)
    }

    func test_parentCheckIn_notyet_doesNotRollBelowWordInitFloor() async {
        // На этапе автоматизации (wordInit) откат ниже не уходит (методический пол).
        let sut = makeSUT()
        sut.stageStore.save(StageProgress(stage: .wordInit, consecutiveQualifyingSessions: 0),
                            childId: "kid-1", sound: "Р")
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))

        await sut.interactor.parentCheckIn(.init(grade: .notyet))
        XCTAssertEqual(sut.stageStore.progress(childId: "kid-1", sound: "Р").stage, .wordInit,
                       "Откат не опускается ниже этапа автоматизации в словах")
    }

    func test_parentCheckIn_sometimes_holdsStage() async {
        let sut = makeSUT()
        sut.stageStore.save(StageProgress(stage: .phrase, consecutiveQualifyingSessions: 1),
                            childId: "kid-1", sound: "Р")
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))

        await sut.interactor.parentCheckIn(.init(grade: .sometimes))
        let progress = sut.stageStore.progress(childId: "kid-1", sound: "Р")
        XCTAssertEqual(progress.stage, .phrase, "Удержание этапа — стадия не меняется")
        XCTAssertEqual(progress.consecutiveQualifyingSessions, 0, "Счётчик обнуляется")
    }

    // MARK: - Voice note

    func test_startVoiceNote_emitsRecordingTrue() async {
        let sut = makeSUT()
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))
        await sut.interactor.startVoiceNote()

        XCTAssertEqual(sut.voiceWorker.startCount, 1)
        XCTAssertTrue(sut.presenter.recordings.contains { $0.isRecording })
    }

    func test_startVoiceNote_permissionDenied_emitsNotRecording() async {
        let worker = StubVoiceNoteWorker()
        worker.startShouldThrow = true
        let sut = makeSUT(voiceWorker: worker)
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))
        await sut.interactor.startVoiceNote()

        // Старт упал → последнее событие записи = false.
        XCTAssertEqual(sut.presenter.recordings.last?.isRecording, false)
    }

    func test_stopVoiceNote_persistsPathAndDuration() async {
        let worker = StubVoiceNoteWorker()
        worker.persistResult = ("CarryoverNotes/kid-1-abc.m4a", 6.5)
        let sut = makeSUT(voiceWorker: worker)
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))
        await sut.interactor.stopVoiceNote()

        XCTAssertEqual(sut.presenter.savedNotes.last, 6.5)
        XCTAssertEqual(sut.carryoverRepo.logs.first?.parentVoiceNotePath, "CarryoverNotes/kid-1-abc.m4a")
        XCTAssertEqual(sut.carryoverRepo.logs.first?.parentVoiceNoteDurationSec, 6.5)
    }

    func test_stopVoiceNote_noResult_emitsNotRecordingWithoutPersist() async {
        let worker = StubVoiceNoteWorker()
        worker.persistResult = nil
        let sut = makeSUT(voiceWorker: worker)
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))
        await sut.interactor.stopVoiceNote()

        XCTAssertTrue(sut.presenter.savedNotes.isEmpty)
        XCTAssertNil(sut.carryoverRepo.logs.first?.parentVoiceNotePath)
        XCTAssertEqual(sut.presenter.recordings.last?.isRecording, false)
    }

    func test_voiceNote_withoutWorker_isNoOp() async {
        let sut = makeSUT(voiceWorker: nil)
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))
        await sut.interactor.startVoiceNote()
        await sut.interactor.stopVoiceNote()

        // Нет worker'а → нет событий записи/сохранения и нет path в логе.
        XCTAssertTrue(sut.presenter.savedNotes.isEmpty)
        XCTAssertNil(sut.carryoverRepo.logs.first?.parentVoiceNotePath)
    }

    func test_cancel_cancelsVoiceWorker() async {
        let sut = makeSUT()
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))
        sut.interactor.cancel()
        XCTAssertEqual(sut.voiceWorker.cancelCount, 1)
    }

    // MARK: - saveAndClose

    func test_saveAndClose_persistsAndPresentsSaved() async {
        let sut = makeSUT()
        await sut.interactor.start(.init(childId: "kid-1", circuit: .kid))
        await sut.interactor.catchWord(.init(word: "рыба"))
        await sut.interactor.saveAndClose()

        XCTAssertEqual(sut.presenter.savedCount, 1)
        XCTAssertEqual(sut.carryoverRepo.logs.first?.caughtWords, ["рыба"])
    }
}

// MARK: - SpyNotificationService (shared в этом файле)

private final class SpyNotificationService: NotificationService, @unchecked Sendable {
    private(set) var kidReminderNames: [String] = []
    private(set) var cancelledKidNames: [String] = []

    func scheduleDailyReminder(at hour: Int, minute: Int) async throws {}
    func cancelAllReminders() async {}
    func requestPermission() async -> Bool { true }
    func scheduleDailyKidReminder(childName: String) async { kidReminderNames.append(childName) }
    func cancelDailyKidReminder(childName: String) async { cancelledKidNames.append(childName) }
    func scheduleWeeklyParentSummary(achievementsCount: Int, streakDays: Int) async {}
    func cancelWeeklyParentSummary() async {}
    @discardableResult
    func scheduleCalendarReminder(
        identifier: String,
        title: String,
        body: String,
        at dateComponents: DateComponents
    ) async throws -> String { identifier }
    func cancelCalendarReminder(identifier: String) async {}
}
