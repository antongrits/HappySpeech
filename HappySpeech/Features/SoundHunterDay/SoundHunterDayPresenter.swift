import Foundation
import OSLog

// MARK: - SoundHunterDayPresentationLogic

@MainActor
protocol SoundHunterDayPresentationLogic: AnyObject {
    func presentStart(_ response: SoundHunterDayModels.Start.Response)
    func presentCatchWord(_ response: SoundHunterDayModels.CatchWord.Response)
    func presentToggleTask(_ response: SoundHunterDayModels.ToggleTask.Response)
    func presentToggleHint()
    func presentParentCheckIn(_ response: SoundHunterDayModels.ParentCheckIn.Response)
    func presentRecording(isRecording: Bool, durationSec: Double)
    func presentVoiceNoteSaved(durationSec: Double)
    func presentUnavailable()
    func presentSaved()
}

// MARK: - SoundHunterDayPresenter
//
// Конвертирует Response → ViewModel: прогресс сачка, серия дней, локализация,
// форматирование чек-ина. Бизнес-логика (лог, планировщик, стадия) — в Interactor.

@MainActor
final class SoundHunterDayPresenter: SoundHunterDayPresentationLogic {

    weak var display: (any SoundHunterDayDisplayLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SoundHunterDayPresenter")

    // MARK: - View models

    struct StartViewModel {
        let circuit: SoundHunterDayModels.Circuit
        let sound: String
        let soundball: String
        let missionTitle: String
        let missionSubtitle: String
        let missionHint: String
        let tasks: [CarryoverTask]
        let completedTaskIds: Set<String>
        let caughtWords: [String]
        let netGoal: Int
        let netProgress: Double
        let isNetFull: Bool
        let streakDays: Int
        let weekDots: [SoundHunterDayModels.DayDot]
        let childName: String
        let childAge: Int
        let parentGrade: CarryoverGrade?
        let hasVoiceNote: Bool
        let noteDurationSec: Double
    }

    struct NetViewModel {
        let caughtWords: [String]
        let netGoal: Int
        let netProgress: Double
        let isNetFull: Bool
    }

    struct TasksViewModel {
        let completedTaskIds: Set<String>
    }

    // MARK: - Start

    func presentStart(_ response: SoundHunterDayModels.Start.Response) {
        let log = response.log
        let goal = max(1, log.netGoal)
        let vm = StartViewModel(
            circuit: response.circuit,
            sound: response.mission.sound,
            soundball: response.mission.soundball,
            missionTitle: response.mission.title,
            missionSubtitle: response.mission.subtitle,
            missionHint: response.mission.hint,
            tasks: response.mission.tasks,
            completedTaskIds: Set(log.completedTaskIds),
            caughtWords: log.caughtWords,
            netGoal: goal,
            netProgress: Self.progress(caught: log.caughtWords.count, goal: goal),
            isNetFull: log.caughtWords.count >= goal,
            streakDays: response.streakDays,
            weekDots: response.weekDots,
            childName: response.childName,
            childAge: response.childAge,
            parentGrade: CarryoverGrade(storage: log.parentCheckIn),
            hasVoiceNote: log.parentVoiceNotePath != nil,
            noteDurationSec: log.parentVoiceNoteDurationSec
        )
        logger.info("presentStart sound=\(response.mission.sound, privacy: .public) caught=\(log.caughtWords.count, privacy: .public)")
        display?.displayStart(vm)
    }

    // MARK: - CatchWord

    func presentCatchWord(_ response: SoundHunterDayModels.CatchWord.Response) {
        let goal = max(1, response.log.netGoal)
        display?.displayCatchWord(NetViewModel(
            caughtWords: response.log.caughtWords,
            netGoal: goal,
            netProgress: Self.progress(caught: response.log.caughtWords.count, goal: goal),
            isNetFull: response.isNetFull
        ))
    }

    // MARK: - ToggleTask

    func presentToggleTask(_ response: SoundHunterDayModels.ToggleTask.Response) {
        display?.displayToggleTask(TasksViewModel(
            completedTaskIds: Set(response.log.completedTaskIds)
        ))
    }

    // MARK: - ToggleHint

    func presentToggleHint() {
        // Состояние подсказки — простой тумблер во View; презентер только
        // ретранслирует событие (нет форматирования).
    }

    // MARK: - ParentCheckIn

    func presentParentCheckIn(_ response: SoundHunterDayModels.ParentCheckIn.Response) {
        display?.displayParentCheckIn(response.grade)
    }

    // MARK: - Recording

    func presentRecording(isRecording: Bool, durationSec: Double) {
        display?.displayRecordingState(isRecording: isRecording, durationSec: durationSec)
    }

    func presentVoiceNoteSaved(durationSec: Double) {
        display?.displayVoiceNoteSaved(durationSec: durationSec)
    }

    // MARK: - Unavailable / Saved

    func presentUnavailable() {
        display?.displayUnavailable()
    }

    func presentSaved() {
        display?.displaySaved()
    }

    // MARK: - Pure helpers

    /// Прогресс сачка в [0, 1].
    static func progress(caught: Int, goal: Int) -> Double {
        guard goal > 0 else { return 0 }
        return min(max(Double(caught) / Double(goal), 0), 1)
    }
}
