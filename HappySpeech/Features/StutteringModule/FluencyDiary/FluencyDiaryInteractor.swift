import Foundation
import OSLog

// MARK: - FluencyDiaryInteractor
//
// Управляет дневником плавности речи (Fluency Diary) в модуле заикания.
//
// Функциональность:
//   1. CRUD дневниковых записей: создание сессии, сохранение в Realm через storageWorker.
//   2. Запись голосового memo: AVAudioRecorder (16 kHz, M4A) + файл сохраняется при >3 сек.
//   3. Анализ плавности: WhisperKit (primary) → FluencyAnalyzerWorker → DysfluencyAnalysis.
//   4. Chart data: расчёт % дисфлюенций по дням для родительского отчёта.
//   5. PDF export: ReportsDocumentFormatter → SpecialistExportService.
//   6. Adaptive reminder: если 3 дня нет записей — показываем reminder Presenter.
//
// Алгоритм дисфлюенций:
//   dysfluencyRate = (repetitions + prolongations + pauses) / totalSyllables * 100
//   норма < 3%, лёгкое заикание 3–8%, умеренное 8–15%, тяжёлое > 15%.

@MainActor
final class FluencyDiaryInteractor {

    // MARK: - Display state

    @Observable
    final class Display {
        var currentText: String = ""
        var waveformLevels: [Float] = []
        var isRecording: Bool = false
        var showComplete: Bool = false
        var isAnalyzing: Bool = false
        var errorMessage: String? = nil
        /// true если последний анализ был выполнен без WhisperKit (stub-путь)
        var isStubAnalysis: Bool = true
        var chartData: [FluencyChartPoint] = []
        var averageDysfluencyRate: Double = 0
        var severityLabel: String = ""
        var showReminderBanner: Bool = false
        var recordingDuration: TimeInterval = 0
        var lastSessionDate: Date? = nil
        var totalSessions: Int = 0
    }

    let display = Display()

    // MARK: - Dependencies

    private let audioWorker: any BreathingAudioWorkerProtocol
    private let analyzerWorker: any FluencyAnalyzerWorkerProtocol
    private let storageWorker: any DiaryStorageWorkerProtocol
    private let whisperWorker: WhisperTranscriptionWorker
    private let hapticService: any HapticService
    private let fileRecorder: any AudioFileRecording
    private let logger = HSLogger.audio

    // MARK: - Session state

    private var textIndex: Int = 0
    private var recordedFileURL: URL?
    private var recordingStartTime: Date?

    /// Хэндл фоновой задачи анализа — позволяет детерминированно дождаться
    /// завершения `analyzeAndSave()` (используется тестами вместо фиксированного sleep).
    private var analysisTask: Task<Void, Never>?

    // MARK: - Chart & analytics state

    /// Кеш последних 14 дней для chart.
    private var recentSessions: [FluencySessionData] = []

    /// Минимальная длительность записи для полноценного анализа (секунды).
    private let minRecordingDurationForAnalysis: TimeInterval = 3.0

    // MARK: - Init

    init(
        audioWorker: any BreathingAudioWorkerProtocol = BreathingAudioWorker(),
        analyzerWorker: any FluencyAnalyzerWorkerProtocol = FluencyAnalyzerWorker(),
        storageWorker: any DiaryStorageWorkerProtocol,
        whisperWorker: WhisperTranscriptionWorker = WhisperTranscriptionWorker(),
        hapticService: any HapticService = LiveHapticService(),
        fileRecorder: any AudioFileRecording = LiveAudioFileRecorder()
    ) {
        self.audioWorker = audioWorker
        self.analyzerWorker = analyzerWorker
        self.storageWorker = storageWorker
        self.whisperWorker = whisperWorker
        self.hapticService = hapticService
        self.fileRecorder = fileRecorder
    }

    // MARK: - Public API

    func startSession() {
        textIndex = Int.random(in: 0..<FluencyDiaryTexts.texts.count)
        display.currentText = FluencyDiaryTexts.text(at: textIndex)
        display.showComplete = false
        display.errorMessage = nil
        display.waveformLevels = []
        display.isStubAnalysis = true
        display.recordingDuration = 0
        logger.info("FluencyDiary: session started textIndex=\(self.textIndex, privacy: .public)")
    }

    /// Загружает историю сессий и строит chart data.
    ///
    /// При сбое чтения хранилища выставляет `display.errorMessage` — UI должен
    /// показать состояние ошибки, а не пустое «Записей ещё нет», которое
    /// маскировало бы реальный сбой Realm.
    func loadHistory() async {
        let sessions: [FluencySessionData]
        do {
            sessions = try await storageWorker.fetchSessions(limit: 14)
        } catch {
            logger.error("FluencyDiary: loadHistory failed \(error.localizedDescription, privacy: .public)")
            display.errorMessage = String(localized: "fluency_diary.error.load_failed")
            return
        }
        display.errorMessage = nil
        recentSessions = sessions
        display.totalSessions = sessions.count
        display.lastSessionDate = sessions.first?.date
        updateChartData(from: sessions)
        checkReminderBanner(sessions: sessions)
        logger.info("FluencyDiary: loaded \(sessions.count, privacy: .public) sessions")
    }

    func startRecording() async {
        guard !display.isRecording else { return }

        let granted = await audioWorker.requestPermission()
        guard granted else {
            display.errorMessage = String(localized: "stuttering.error.mic_permission")
            return
        }

        display.isRecording = true
        display.recordingDuration = 0
        recordingStartTime = Date()
        Task { await hapticService.play(pattern: .buttonTap) }

        startFileRecording()

        do {
            try await audioWorker.start(
                onAmplitude: { [weak self] amp in
                    Task { @MainActor [weak self] in self?.handleAmplitude(amp) }
                },
                onInterrupt: { [weak self] in
                    Task { @MainActor [weak self] in self?.stopRecording() }
                }
            )
        } catch {
            logger.error("FluencyDiary: audio start error \(error.localizedDescription, privacy: .public)")
            display.isRecording = false
            stopFileRecording()
        }
    }

    func stopRecording() {
        guard display.isRecording else { return }
        audioWorker.stop()
        stopFileRecording()
        display.isRecording = false

        // Обновляем финальную длительность
        if let start = recordingStartTime {
            display.recordingDuration = Date().timeIntervalSince(start)
        }
        recordingStartTime = nil

        Task { await hapticService.play(pattern: .buttonTap) }
        analyzeAndSave()
        logger.info(
            "FluencyDiary: recording stopped duration=\(self.display.recordingDuration, privacy: .public)s"
        )
    }

    // MARK: - Amplitude

    private func handleAmplitude(_ amplitude: Float) {
        var levels = display.waveformLevels
        levels.append(amplitude)
        if levels.count > 40 { levels.removeFirst(levels.count - 40) }
        display.waveformLevels = levels

        // Обновляем таймер
        if let start = recordingStartTime {
            display.recordingDuration = Date().timeIntervalSince(start)
        }
    }

    // MARK: - File recording

    private func startFileRecording() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("fluency_\(UUID().uuidString).m4a")
        if fileRecorder.startRecording(to: tempURL) {
            recordedFileURL = tempURL
            logger.info("FluencyDiary: file recorder started → \(tempURL.lastPathComponent, privacy: .public)")
        } else {
            logger.warning("FluencyDiary: file recorder failed to start")
            recordedFileURL = nil
        }
    }

    private func stopFileRecording() {
        fileRecorder.stopRecording()
    }

    // MARK: - Analysis & persistence

    private func analyzeAndSave() {
        display.isAnalyzing = true
        let capturedFileURL = recordedFileURL
        let fallbackText = display.currentText
        let duration = display.recordingDuration
        recordedFileURL = nil

        analysisTask = Task {
            let analysis: DysfluencyAnalysis

            // Анализируем только если запись достаточно длинная.
            let isLongEnough = duration >= minRecordingDurationForAnalysis

            if isLongEnough,
               let fileURL = capturedFileURL,
               FileManager.default.fileExists(atPath: fileURL.path),
               let realTranscript = await whisperWorker.transcribe(audioURL: fileURL) {
                analysis = (analyzerWorker as? FluencyAnalyzerWorker)?
                    .analyzeRealTranscript(realTranscript)
                    ?? makeFallbackAnalysis(text: realTranscript.fullText)
                logger.info("FluencyDiary: real WhisperKit analysis isStub=false")
            } else {
                if !isLongEnough {
                    logger.info(
                        "FluencyDiary: запись < \(self.minRecordingDurationForAnalysis, privacy: .public)s → stub"
                    )
                }
                analysis = (analyzerWorker as? FluencyAnalyzerWorker)?
                    .makeStubAnalysis(text: fallbackText)
                    ?? makeFallbackAnalysis(text: fallbackText)
                logger.info("FluencyDiary: stub analysis")
            }

            // Удаляем временный файл
            if let fileURL = capturedFileURL {
                try? FileManager.default.removeItem(at: fileURL)
            }

            let sessionData = FluencySessionData(
                id: UUID().uuidString,
                date: Date(),
                dysfluencyCount: analysis.repetitions + analysis.prolongations + analysis.insideWordPauses,
                totalSyllables: analysis.totalSyllables,
                rate: analysis.rate,
                transcript: analysis.isStub ? fallbackText : ""
            )

            await storageWorker.saveSession(sessionData)

            // Обновляем локальный кеш
            var updated = [sessionData] + recentSessions
            if updated.count > 14 { updated = Array(updated.prefix(14)) }
            recentSessions = updated

            await MainActor.run {
                self.display.isStubAnalysis = analysis.isStub
                self.display.isAnalyzing = false
                self.display.showComplete = true
                self.display.totalSessions += 1
                self.display.lastSessionDate = sessionData.date
                self.updateChartData(from: self.recentSessions)
                self.updateSeverityLabel(rate: Double(analysis.rate))
                Task { await self.hapticService.play(pattern: .celebration) }
            }
        }
    }

    /// Простой fallback-расчёт без доступа к FluencyAnalyzerWorker.
    private func makeFallbackAnalysis(text: String) -> DysfluencyAnalysis {
        let vowels: Set<Character> = ["а", "е", "ё", "и", "о", "у", "ы", "э", "ю", "я"]
        let syllables = text.lowercased().filter { vowels.contains($0) }.count
        return DysfluencyAnalysis(
            repetitions: 0,
            prolongations: 0,
            insideWordPauses: 0,
            totalSyllables: syllables,
            rate: 0,
            isStub: true
        )
    }

    // MARK: - Chart data

    /// Строит данные для линейного графика (14 дней × dysfluencyRate).
    private func updateChartData(from sessions: [FluencySessionData]) {
        let calendar = Calendar.current
        let now = Date()
        var points: [FluencyChartPoint] = []

        for dayOffset in (0..<14).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let dayStart = calendar.startOfDay(for: day)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            let daySessions = sessions.filter { $0.date >= dayStart && $0.date < dayEnd }

            let rate: Double
            if daySessions.isEmpty {
                rate = -1 // нет данных
            } else {
                let totalDys = daySessions.map { $0.dysfluencyCount }.reduce(0, +)
                let totalSyl = daySessions.map { $0.totalSyllables }.reduce(0, +)
                rate = totalSyl > 0 ? Double(totalDys) / Double(totalSyl) * 100 : 0
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            formatter.locale = Locale(identifier: "ru_RU")

            points.append(FluencyChartPoint(
                date: dayStart,
                label: formatter.string(from: dayStart),
                dysfluencyRate: rate,
                hasData: !daySessions.isEmpty
            ))
        }

        display.chartData = points

        // Средний процент по имеющимся данным
        let withData = points.filter { $0.hasData }
        display.averageDysfluencyRate = withData.isEmpty ? 0
            : withData.map { $0.dysfluencyRate }.reduce(0, +) / Double(withData.count)

        updateSeverityLabel(rate: display.averageDysfluencyRate)
    }

    /// Обновляет текстовую метку тяжести по среднему проценту дисфлюенций.
    private func updateSeverityLabel(rate: Double) {
        display.severityLabel = severityLabel(for: rate)
    }

    private func severityLabel(for rate: Double) -> String {
        switch rate {
        case ..<3:
            return String(localized: "fluency.severity.normal")
        case 3..<8:
            return String(localized: "fluency.severity.mild")
        case 8..<15:
            return String(localized: "fluency.severity.moderate")
        default:
            return String(localized: "fluency.severity.severe")
        }
    }

    // MARK: - Reminder logic

    /// Показываем reminder-баннер если последняя запись > 3 дней назад.
    private func checkReminderBanner(sessions: [FluencySessionData]) {
        guard let lastDate = sessions.first?.date else {
            // Истории ещё нет — нечего напоминать, баннер скрыт.
            // (Ветка достижима только при пустом `sessions`.)
            display.showReminderBanner = false
            return
        }
        let daysSinceLast = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        display.showReminderBanner = daysSinceLast >= 3
        if display.showReminderBanner {
            logger.info(
                "FluencyDiary: reminder banner shown (days since last = \(daysSinceLast, privacy: .public))"
            )
        }
    }

    // MARK: - Test seam

    #if DEBUG
    /// Детерминированно ожидает завершения фоновой задачи анализа,
    /// запущенной из `analyzeAndSave()`. Используется тестами вместо `Task.sleep`.
    func awaitAnalysisForTesting() async {
        await analysisTask?.value
    }
    #endif
}

// MARK: - FluencyChartPoint

/// Точка данных для линейного графика дневника.
struct FluencyChartPoint: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let label: String
    let dysfluencyRate: Double   // -1 означает «нет данных»
    let hasData: Bool
}
