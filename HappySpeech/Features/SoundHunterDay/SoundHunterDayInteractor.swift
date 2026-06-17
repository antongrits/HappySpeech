import Foundation
import OSLog

// MARK: - SoundHunterDayBusinessLogic

@MainActor
protocol SoundHunterDayBusinessLogic: AnyObject {
    func start(_ request: SoundHunterDayModels.Start.Request) async
    func catchWord(_ request: SoundHunterDayModels.CatchWord.Request) async
    func toggleTask(_ request: SoundHunterDayModels.ToggleTask.Request) async
    func toggleHint()
    func parentCheckIn(_ request: SoundHunterDayModels.ParentCheckIn.Request) async
    func startVoiceNote() async
    func stopVoiceNote() async
    func cancel()
    func saveAndClose() async
}

// MARK: - SoundHunterDayInteractor
//
// Бизнес-логика «Звукового охотника дня» — переноса звука в спонтанную речь.
//
//   • start         — резолвит звук дня по профилю ребёнка (наименее освоенный
//                     целевой звук), грузит миссию из пака, поднимает/создаёт
//                     дневной CarryoverLog, считает серию дней охоты.
//   • catchWord     — ребёнок «поймал слово»: добавляет слово в сачок (idempotent
//                     до netGoal), персистит лог; при первом слове дня —
//                     планирует завтрашнюю утреннюю миссию (NotificationService).
//   • toggleTask    — отмечает задание-охоту выполненным/снимает отметку.
//   • parentCheckIn — родительская градация переноса. Питает AdaptivePlanner:
//                     clean → quality .perfect + продвижение CorrectionStage;
//                     sometimes → quality .hardCorrect (удержание этапа);
//                     notyet → quality .wrong + откат к этапу автоматизации.
//   • start/stopVoiceNote — родительская заметка-перл (локальный .m4a).
//   • saveAndClose  — фиксирует лог и закрывает экран.
//
// Никаких фабрикаций: «пойманные» слова и чек-ин — реальные записи Realm;
// сигнал переноса реально двигает SM-2 и стадию коррекции.

@MainActor
final class SoundHunterDayInteractor: SoundHunterDayBusinessLogic {

    // MARK: - VIP

    var presenter: (any SoundHunterDayPresentationLogic)?

    // MARK: - Deps

    private let childId: String
    private let childRepository: any ChildRepository
    private let carryoverRepository: any CarryoverLogRepository
    private let missionLoader: CarryoverMissionLoader
    private let adaptivePlanner: (any AdaptivePlannerService)?
    private let stageProgressStore: (any StageProgressStoring)?
    private let notificationService: (any NotificationService)?
    private let voiceNoteWorker: (any CarryoverVoiceNoteWorking)?
    private let calendar: Calendar
    private let now: () -> Date

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SoundHunterDayInteractor")

    // MARK: - State

    private var circuit: SoundHunterDayModels.Circuit = .kid
    private var mission: CarryoverMission?
    private var log: CarryoverLogDTO?
    private var childName: String = ""
    private var childAge: Int = 6
    private var noteTimerTask: Task<Void, Never>?

    // MARK: - Init

    init(
        childId: String,
        childRepository: any ChildRepository,
        carryoverRepository: any CarryoverLogRepository,
        missionLoader: CarryoverMissionLoader,
        adaptivePlanner: (any AdaptivePlannerService)? = nil,
        stageProgressStore: (any StageProgressStoring)? = nil,
        notificationService: (any NotificationService)? = nil,
        voiceNoteWorker: (any CarryoverVoiceNoteWorking)? = nil,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.childId = childId
        self.childRepository = childRepository
        self.carryoverRepository = carryoverRepository
        self.missionLoader = missionLoader
        self.adaptivePlanner = adaptivePlanner
        self.stageProgressStore = stageProgressStore
        self.notificationService = notificationService
        self.voiceNoteWorker = voiceNoteWorker
        self.calendar = calendar
        self.now = now
    }

    deinit {
        noteTimerTask?.cancel()
    }

    // MARK: - start

    func start(_ request: SoundHunterDayModels.Start.Request) async {
        circuit = request.circuit
        guard !childId.isEmpty else {
            logger.error("start with empty childId")
            presenter?.presentUnavailable()
            return
        }

        // Профиль ребёнка → звук дня + имя/возраст.
        let targetSounds: [String]
        let progress: [String: Double]
        do {
            let profile = try await childRepository.fetch(id: childId)
            childName = profile.name
            childAge = max(5, min(profile.age, 8))
            targetSounds = profile.targetSounds
            progress = profile.progressSummary
        } catch {
            logger.warning("child profile fetch failed: \(error.localizedDescription, privacy: .public)")
            childName = ""
            childAge = 6
            targetSounds = []
            progress = [:]
        }

        let today = calendar.startOfDay(for: now())
        let sound = CarryoverMissionLoader.pickSound(
            targetSounds: targetSounds,
            progressSummary: progress,
            day: today,
            calendar: calendar
        )

        let missions = missionLoader.loadMissions()
        let resolvedMission = missionLoader.mission(for: sound, in: missions)
        mission = resolvedMission

        // Поднимаем/создаём дневной лог.
        var dayLog: CarryoverLogDTO
        do {
            if let existing = try await carryoverRepository.fetch(childId: childId, sound: sound, day: today) {
                dayLog = existing
            } else {
                dayLog = CarryoverLogDTO(
                    id: CarryoverLogDTO.makeId(childId: childId, sound: sound, day: today),
                    childId: childId,
                    sound: sound,
                    day: today,
                    netGoal: resolvedMission.netGoal
                )
                try await carryoverRepository.upsert(dayLog)
            }
        } catch {
            logger.warning("carryover log fetch/create failed: \(error.localizedDescription, privacy: .public)")
            dayLog = CarryoverLogDTO(
                id: CarryoverLogDTO.makeId(childId: childId, sound: sound, day: today),
                childId: childId,
                sound: sound,
                day: today,
                netGoal: resolvedMission.netGoal
            )
        }
        log = dayLog

        let streak = await computeStreak(referenceDay: today)
        let dots = makeWeekDots(referenceDay: today, streak: streak)

        presenter?.presentStart(SoundHunterDayModels.Start.Response(
            mission: resolvedMission,
            log: dayLog,
            childName: childName,
            childAge: childAge,
            streakDays: streak,
            weekDots: dots,
            circuit: circuit
        ))
    }

    // MARK: - catchWord

    func catchWord(_ request: SoundHunterDayModels.CatchWord.Request) async {
        guard let mission, var current = log else { return }
        guard current.caughtWords.count < current.netGoal else {
            // Сачок полон — больше не добавляем (защита от переполнения).
            presenter?.presentCatchWord(SoundHunterDayModels.CatchWord.Response(
                log: current, mission: mission, isNetFull: true, justStarted: false
            ))
            return
        }

        let justStarted = current.caughtWords.isEmpty
        let word = request.word?.trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
            ?? CarryoverMissionLoader.nextExample(mission: mission, caught: current.caughtWords)

        // Не дублируем уже пойманное слово.
        if !current.caughtWords.contains(where: { $0.caseInsensitiveCompare(word) == .orderedSame }) {
            current.caughtWords.append(word)
        }
        current = touch(current)
        log = current
        await persist(current)

        let isFull = current.caughtWords.count >= current.netGoal

        // При первом пойманном слове дня — планируем завтрашнюю утреннюю миссию.
        if justStarted {
            await scheduleMorningReminder()
        }

        // Каждое пойманное слово — успешная попытка переноса в интервальном
        // планировщике (звук закрепляется в спонтанной речи).
        await adaptivePlanner?.recordItemOutcome(
            childId: childId,
            itemId: "carryover_\(current.sound)_\(current.caughtWords.count)",
            sound: current.sound,
            correct: true
        )

        logger.info("caught word — net \(current.caughtWords.count, privacy: .public)/\(current.netGoal, privacy: .public)")
        presenter?.presentCatchWord(SoundHunterDayModels.CatchWord.Response(
            log: current, mission: mission, isNetFull: isFull, justStarted: justStarted
        ))
    }

    // MARK: - toggleTask

    func toggleTask(_ request: SoundHunterDayModels.ToggleTask.Request) async {
        guard let mission, var current = log else { return }
        if let idx = current.completedTaskIds.firstIndex(of: request.taskId) {
            current.completedTaskIds.remove(at: idx)
        } else {
            current.completedTaskIds.append(request.taskId)
        }
        current = touch(current)
        log = current
        await persist(current)
        presenter?.presentToggleTask(SoundHunterDayModels.ToggleTask.Response(
            log: current, mission: mission
        ))
    }

    // MARK: - toggleHint

    func toggleHint() {
        presenter?.presentToggleHint()
    }

    // MARK: - parentCheckIn

    func parentCheckIn(_ request: SoundHunterDayModels.ParentCheckIn.Request) async {
        guard let mission, var current = log else { return }
        current.parentCheckIn = request.grade.storageValue
        current = touch(current)
        log = current
        await persist(current)

        await applyCarryoverSignal(grade: request.grade, sound: current.sound)

        logger.info("parent check-in grade=\(request.grade.rawValue, privacy: .public) sound=\(current.sound, privacy: .public)")
        presenter?.presentParentCheckIn(SoundHunterDayModels.ParentCheckIn.Response(
            log: current, grade: request.grade, mission: mission
        ))
    }

    // MARK: - Voice note

    func startVoiceNote() async {
        guard let worker = voiceNoteWorker else { return }
        do {
            try await worker.startRecording()
            presenter?.presentRecording(isRecording: true, durationSec: 0)
            // Тикер длительности для волн-индикатора.
            noteTimerTask?.cancel()
            noteTimerTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    guard let self, let worker = self.voiceNoteWorker, worker.isRecording else { break }
                    self.presenter?.presentRecording(isRecording: true, durationSec: worker.currentDurationSec)
                    if worker.currentDurationSec >= worker.maxDurationSec {
                        await self.stopVoiceNote()
                        break
                    }
                    try? await Task.sleep(for: .milliseconds(200))
                }
            }
        } catch {
            logger.warning("voice note start failed: \(error.localizedDescription, privacy: .public)")
            presenter?.presentRecording(isRecording: false, durationSec: 0)
        }
    }

    func stopVoiceNote() async {
        noteTimerTask?.cancel()
        noteTimerTask = nil
        guard let worker = voiceNoteWorker, var current = log else { return }
        guard let result = worker.finishAndPersist(childId: childId) else {
            presenter?.presentRecording(isRecording: false, durationSec: 0)
            return
        }
        current.parentVoiceNotePath = result.relativePath
        current.parentVoiceNoteDurationSec = result.durationSec
        current = touch(current)
        log = current
        await persist(current)
        logger.info("voice note saved dur=\(result.durationSec, privacy: .public)")
        presenter?.presentVoiceNoteSaved(durationSec: result.durationSec)
    }

    // MARK: - cancel / save

    func cancel() {
        noteTimerTask?.cancel()
        noteTimerTask = nil
        voiceNoteWorker?.cancel()
    }

    func saveAndClose() async {
        if let current = log { await persist(current) }
        presenter?.presentSaved()
    }

    // MARK: - AdaptivePlanner carryover signal
    //
    // Главная методическая связка: сигнал переноса родителя двигает модель
    // освоения звука и стадию коррекции.
    private func applyCarryoverSignal(grade: CarryoverGrade, sound: String) async {
        let quality: SM2Quality
        switch grade {
        case .clean:     quality = .perfect      // свободная речь чистая → к завершению
        case .sometimes: quality = .hardCorrect  // нужен контроль → удержание этапа
        case .notyet:    quality = .wrong        // теряется → возврат автоматизации
        }
        do {
            try await adaptivePlanner?.recordSessionResult(
                childId: childId,
                soundTarget: sound,
                qualityScore: quality
            )
        } catch {
            logger.error("recordSessionResult failed: \(error.localizedDescription, privacy: .public)")
        }
        adjustCorrectionStage(grade: grade, sound: sound)
    }

    /// Двигает текущую стадию коррекции звука в зависимости от градации переноса.
    /// Чистый перенос на финальных этапах → к дифференциации/завершению; провал
    /// переноса → откат к этапу автоматизации в словах. Управляемый методический
    /// шаг, без наказания.
    private func adjustCorrectionStage(grade: CarryoverGrade, sound: String) {
        guard let store = stageProgressStore else { return }
        var progress = store.progress(childId: childId, sound: sound)
        let ordered = CorrectionStage.allCases
        guard let idx = ordered.firstIndex(of: progress.stage) else { return }

        switch grade {
        case .clean:
            // Засчитываем квалифицирующую сессию переноса; после двух подряд —
            // продвигаем на следующий этап (ближе к diff/завершению).
            progress.consecutiveQualifyingSessions += 1
            if progress.consecutiveQualifyingSessions >= 2, idx < ordered.count - 1 {
                progress.stage = ordered[idx + 1]
                progress.consecutiveQualifyingSessions = 0
            }
        case .sometimes:
            // Удержание этапа: счётчик не растёт, но и не падает.
            progress.consecutiveQualifyingSessions = 0
        case .notyet:
            // Откат к этапу автоматизации в словах, если ушли дальше.
            progress.consecutiveQualifyingSessions = 0
            let automationFloor = CorrectionStage.wordInit
            if let floorIdx = ordered.firstIndex(of: automationFloor), idx > floorIdx {
                progress.stage = ordered[idx - 1]
            }
        }
        store.save(progress, childId: childId, sound: sound)
    }

    // MARK: - Streak

    /// Серия дней охоты подряд: считаем кол-во последовательных дней (включая
    /// сегодня, если есть активность), в которые ребёнок поймал хотя бы 1 слово.
    private func computeStreak(referenceDay: Date) async -> Int {
        let all: [CarryoverLogDTO]
        do {
            all = try await carryoverRepository.fetchAll(childId: childId)
        } catch {
            return 0
        }
        // Дни с активностью (поймано >= 1 слово), нормализованные к началу дня.
        let activeDays = Set(
            all.filter { !$0.caughtWords.isEmpty }
                .map { calendar.startOfDay(for: $0.day) }
        )
        guard !activeDays.isEmpty else { return 0 }

        var streak = 0
        var cursor = referenceDay
        // Если сегодня ещё нет активности — серия отсчитывается со вчера.
        if !activeDays.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        while activeDays.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    /// 7 точек недели (Пн…Вс) текущей недели referenceDay: on — есть активность,
    /// today — сегодняшний столбец.
    private func makeWeekDots(referenceDay: Date, streak: Int) -> [SoundHunterDayModels.DayDot] {
        let symbols = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
        // weekday: 1=Sun … 7=Sat (gregorian). Переводим в индекс Пн=0.
        let weekday = calendar.component(.weekday, from: referenceDay)
        let mondayIndex = ((weekday + 5) % 7) // Mon=0 … Sun=6
        // Серия закрашивает дни до сегодня включительно (трейлинг-ран недели).
        var dots: [SoundHunterDayModels.DayDot] = []
        for i in 0..<7 {
            let isToday = i == mondayIndex
            // День «горит», если попадает в трейлинг-серию до сегодня.
            let withinStreak = i <= mondayIndex && (mondayIndex - i) < streak
            dots.append(SoundHunterDayModels.DayDot(
                weekdayLabel: symbols[i],
                isOn: withinStreak && !isToday,
                isToday: isToday
            ))
        }
        return dots
    }

    // MARK: - Notifications

    private func scheduleMorningReminder() async {
        guard let service = notificationService, !childName.isEmpty else { return }
        await service.scheduleDailyKidReminder(childName: childName)
    }

    // MARK: - Helpers

    private func touch(_ dto: CarryoverLogDTO) -> CarryoverLogDTO {
        CarryoverLogDTO(
            id: dto.id,
            childId: dto.childId,
            sound: dto.sound,
            day: dto.day,
            caughtWords: dto.caughtWords,
            netGoal: dto.netGoal,
            completedTaskIds: dto.completedTaskIds,
            parentCheckIn: dto.parentCheckIn,
            parentVoiceNotePath: dto.parentVoiceNotePath,
            parentVoiceNoteDurationSec: dto.parentVoiceNoteDurationSec,
            createdAt: dto.createdAt,
            updatedAt: now()
        )
    }

    private func persist(_ dto: CarryoverLogDTO) async {
        do {
            try await carryoverRepository.upsert(dto)
        } catch {
            logger.error("carryover upsert failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Test seams

    var currentLog: CarryoverLogDTO? { log }
    var currentMission: CarryoverMission? { mission }
}
