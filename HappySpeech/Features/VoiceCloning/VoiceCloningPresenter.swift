import Foundation
import OSLog

// MARK: - VoiceCloningPresenter
//
// Преобразует Response из Interactor в ViewModel-структуры, готовые для отрисовки.
// Группирует записи по неделям, форматирует даты на русском, формирует CTA.

@MainActor
final class VoiceCloningPresenter {

    weak var viewModel: VoiceCloningViewModel?

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "d MMMM, HH:mm"
        return df
    }()

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday
        return cal
    }()

    // MARK: - Load

    func presentLoad(_ response: VoiceCloning.LoadResponse) {
        let rows = response.samples.map(makeRow)
        let sections = groupBySection(rows: rows, allSamples: response.samples)

        viewModel?.archiveSections = sections
        viewModel?.suggestedWord = response.suggestedWord
        viewModel?.targetSound = response.targetSound
        viewModel?.totalSamplesCount = response.samples.count
        viewModel?.state = response.samples.isEmpty ? .empty : .ready
        viewModel?.errorMessage = nil
    }

    // MARK: - Recording state

    func presentRecordingState(_ response: VoiceCloning.RecordingStateResponse) {
        viewModel?.isRecording = response.isRecording
        viewModel?.recordingProgress = min(1.0, response.elapsedSeconds / 5.0)
        viewModel?.recordingAmplitude = response.amplitude
        viewModel?.recordingElapsedText = formatDuration(response.elapsedSeconds)
    }

    // MARK: - Recording result

    func presentRecordingResult(_ response: VoiceCloning.RecordingResultResponse) {
        viewModel?.isRecording = false
        viewModel?.recordingProgress = 0
        viewModel?.recordingAmplitude = 0

        if response.success {
            viewModel?.lastSavedSampleId = response.savedSampleId
            viewModel?.toastMessage = String(localized: "voice_cloning.toast.saved")
        } else {
            viewModel?.errorMessage = response.errorMessage
                ?? String(localized: "voice_cloning.error.generic")
            viewModel?.toastMessage = nil
        }
    }

    // MARK: - Playback

    func presentPlayback(_ response: VoiceCloning.PlaybackResponse) {
        viewModel?.isPlaying = response.isPlaying
        viewModel?.currentlyPlayingSampleId = response.currentSampleId
    }

    // MARK: - Delete

    func presentDelete(_ response: VoiceCloning.DeleteResponse) {
        guard response.success else { return }
        viewModel?.archiveSections = viewModel?.archiveSections.compactMap { section in
            let filtered = section.rows.filter { $0.id != response.deletedSampleId }
            if filtered.isEmpty { return nil }
            return VoiceCloning.ArchiveSection(title: section.title, rows: filtered)
        } ?? []
        viewModel?.totalSamplesCount = max(0, (viewModel?.totalSamplesCount ?? 0) - 1)
        viewModel?.toastMessage = String(localized: "voice_cloning.toast.deleted")
    }

    // MARK: - Error

    func presentError(_ message: String) {
        viewModel?.state = .error(message)
        viewModel?.errorMessage = message
    }

    // MARK: - Private builders

    private func makeRow(from data: VoiceSampleData) -> VoiceCloning.ArchiveRow {
        VoiceCloning.ArchiveRow(
            id: data.id,
            title: data.word,
            targetSound: data.targetSound,
            dateText: dateFormatter.string(from: data.recordedAt),
            durationText: formatDuration(data.durationSeconds),
            audioFilePath: data.audioFilePath
        )
    }

    private func groupBySection(
        rows: [VoiceCloning.ArchiveRow],
        allSamples: [VoiceSampleData]
    ) -> [VoiceCloning.ArchiveSection] {
        guard !rows.isEmpty else { return [] }

        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let monthAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now

        var thisWeek: [VoiceCloning.ArchiveRow] = []
        var lastWeek: [VoiceCloning.ArchiveRow] = []
        var earlier: [VoiceCloning.ArchiveRow] = []

        for (index, row) in rows.enumerated() {
            // Используем индекс в allSamples — порядок совпадает с rows.
            let date = allSamples.indices.contains(index)
                ? allSamples[index].recordedAt
                : now
            if date >= weekAgo {
                thisWeek.append(row)
            } else if date >= monthAgo {
                lastWeek.append(row)
            } else {
                earlier.append(row)
            }
        }

        var result: [VoiceCloning.ArchiveSection] = []
        if !thisWeek.isEmpty {
            result.append(VoiceCloning.ArchiveSection(
                title: String(localized: "voice_cloning.section.this_week"),
                rows: thisWeek
            ))
        }
        if !lastWeek.isEmpty {
            result.append(VoiceCloning.ArchiveSection(
                title: String(localized: "voice_cloning.section.recent"),
                rows: lastWeek
            ))
        }
        if !earlier.isEmpty {
            result.append(VoiceCloning.ArchiveSection(
                title: String(localized: "voice_cloning.section.earlier"),
                rows: earlier
            ))
        }
        return result
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - VoiceCloningViewModel

@Observable
@MainActor
final class VoiceCloningViewModel {
    var state: VoiceCloning.ScreenState = .loading
    var archiveSections: [VoiceCloning.ArchiveSection] = []
    var totalSamplesCount: Int = 0
    var suggestedWord: String = ""
    var targetSound: String = "С"

    var isRecording: Bool = false
    var recordingProgress: Double = 0
    var recordingAmplitude: Float = 0
    var recordingElapsedText: String = "0:00"

    var isPlaying: Bool = false
    var currentlyPlayingSampleId: String?

    var lastSavedSampleId: String?
    var errorMessage: String?
    var toastMessage: String?
}
