import Foundation
import SwiftUI

// MARK: - SoundHunterDayPhase

/// Фаза экрана «Звуковой охотник дня».
enum SoundHunterDayPhase: Sendable, Equatable {
    case loading
    /// Контент готов — показываем миссию/копилку (kid) или чек-ин (parent).
    case ready
    /// Ошибка загрузки (нет активного ребёнка и т. п.) — мягкий empty-state.
    case unavailable
}

// MARK: - SoundHunterDayDisplay (View state)

@MainActor
@Observable
final class SoundHunterDayDisplay {

    // Контур
    var circuit: SoundHunterDayModels.Circuit = .kid

    // Фаза
    var phase: SoundHunterDayPhase = .loading

    // Звук дня и тексты миссии
    var sound: String = ""
    var soundball: String = "🎯"
    var missionTitle: String = ""
    var missionSubtitle: String = ""
    var missionHint: String = ""

    // Задания-охоты
    var tasks: [CarryoverTask] = []
    var completedTaskIds: Set<String> = []

    // Сачок
    var caughtWords: [String] = []
    var netGoal: Int = 5
    /// Прогресс сачка 0…1 — для нижней полоски (butter→gold).
    var netProgress: Double = 0
    var isNetFull: Bool = false

    // Серия дней охоты (kid-копилка)
    var streakDays: Int = 0
    var weekDots: [SoundHunterDayModels.DayDot] = []

    // Родитель
    var childName: String = ""
    var childAge: Int = 6
    var parentGrade: CarryoverGrade?
    var isRecordingNote: Bool = false
    var noteDurationSec: Double = 0
    var hasVoiceNote: Bool = false

    // Подсказки «где искать» (kid)
    var showHint: Bool = false

    // Навигация / выход
    var pendingExit: Bool = false
}

// MARK: - SoundHunterDayDisplayLogic

/// Контракт между `SoundHunterDayPresenter` и SwiftUI-слоем. Только @MainActor.
@MainActor
protocol SoundHunterDayDisplayLogic: AnyObject {
    func displayStart(_ viewModel: SoundHunterDayPresenter.StartViewModel)
    func displayCatchWord(_ viewModel: SoundHunterDayPresenter.NetViewModel)
    func displayToggleTask(_ viewModel: SoundHunterDayPresenter.TasksViewModel)
    func displayParentCheckIn(_ grade: CarryoverGrade)
    func displayRecordingState(isRecording: Bool, durationSec: Double)
    func displayVoiceNoteSaved(durationSec: Double)
    func displayUnavailable()
    func displaySaved()
}

// MARK: - SoundHunterDayDisplay conformance

extension SoundHunterDayDisplay: SoundHunterDayDisplayLogic {

    func displayStart(_ viewModel: SoundHunterDayPresenter.StartViewModel) {
        circuit = viewModel.circuit
        sound = viewModel.sound
        soundball = viewModel.soundball
        missionTitle = viewModel.missionTitle
        missionSubtitle = viewModel.missionSubtitle
        missionHint = viewModel.missionHint
        tasks = viewModel.tasks
        completedTaskIds = viewModel.completedTaskIds
        caughtWords = viewModel.caughtWords
        netGoal = viewModel.netGoal
        netProgress = viewModel.netProgress
        isNetFull = viewModel.isNetFull
        streakDays = viewModel.streakDays
        weekDots = viewModel.weekDots
        childName = viewModel.childName
        childAge = viewModel.childAge
        parentGrade = viewModel.parentGrade
        hasVoiceNote = viewModel.hasVoiceNote
        noteDurationSec = viewModel.noteDurationSec
        phase = .ready
    }

    func displayCatchWord(_ viewModel: SoundHunterDayPresenter.NetViewModel) {
        caughtWords = viewModel.caughtWords
        netProgress = viewModel.netProgress
        isNetFull = viewModel.isNetFull
        netGoal = viewModel.netGoal
    }

    func displayToggleTask(_ viewModel: SoundHunterDayPresenter.TasksViewModel) {
        completedTaskIds = viewModel.completedTaskIds
    }

    func displayParentCheckIn(_ grade: CarryoverGrade) {
        parentGrade = grade
    }

    func displayRecordingState(isRecording: Bool, durationSec: Double) {
        isRecordingNote = isRecording
        noteDurationSec = durationSec
    }

    func displayVoiceNoteSaved(durationSec: Double) {
        hasVoiceNote = true
        isRecordingNote = false
        noteDurationSec = durationSec
    }

    func displayUnavailable() {
        phase = .unavailable
    }

    func displaySaved() {
        pendingExit = true
    }
}
