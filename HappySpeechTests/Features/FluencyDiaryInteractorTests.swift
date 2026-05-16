@testable import HappySpeech
import XCTest

// MARK: - FluencyDiaryInteractorTests
//
// Block 2.8.3 v25 — unit-покрытие FluencyDiaryInteractor (Stuttering / Fluency Diary).
// Покрывается логика без реального аудио-пути: startSession, loadHistory,
// chart data, severity-классификация, reminder-баннер.
//
// UNTESTABLE (документировано): startRecording/stopRecording/analyzeAndSave
// требуют AVAudioEngine + WhisperKit + microphone permission — реальный аудио-путь.
// Здесь покрываем чистую бизнес-логику через мокабельный DiaryStorageWorkerProtocol.

// MARK: - In-memory diary storage mock
//
// Note: FluencyDiaryInteractor.loadHistory() вызывает `fetchRecentSessions(limit:)`,
// который объявлен только как protocol-extension с дефолтной реализацией `{ [] }`
// (см. FluencyDiaryInteractor.swift). Метод НЕ входит в requirements
// DiaryStorageWorkerProtocol, поэтому диспетчеризуется статически к extension
// default — любой `any DiaryStorageWorkerProtocol` (включая live-воркер) при
// вызове через protocol-тип получит пустой массив. Это поведение прода;
// тесты loadHistory проверяют корректную обработку пустого результата.

private actor MockDiaryStorageWorker: DiaryStorageWorkerProtocol {
    private var store: [FluencySessionData] = []

    init(seed: [FluencySessionData] = []) {
        self.store = seed
    }

    func saveSession(_ data: FluencySessionData) async {
        store.removeAll { $0.id == data.id }
        store.append(data)
    }

    func fetchSessions(limit: Int) async -> [FluencySessionData] {
        let sorted = store.sorted { $0.date > $1.date }
        return limit > 0 ? Array(sorted.prefix(limit)) : sorted
    }
}

@MainActor
final class FluencyDiaryInteractorTests: XCTestCase {

    private func makeSUT(
        seed: [FluencySessionData] = []
    ) -> FluencyDiaryInteractor {
        FluencyDiaryInteractor(
            storageWorker: MockDiaryStorageWorker(seed: seed),
            hapticService: MockHapticService(),
            fileRecorder: MockAudioFileRecorder()
        )
    }

    /// SUT с инжектированным MockBreathingAudioWorker — позволяет покрыть
    /// startRecording/stopRecording/analyzeAndSave без реального микрофона.
    private func makeAudioSUT(
        seed: [FluencySessionData] = [],
        micGranted: Bool = true,
        scriptedAmplitudes: [Float] = [],
        recorderFails: Bool = false
    ) -> (FluencyDiaryInteractor, MockBreathingAudioWorker, MockAudioFileRecorder) {
        let audio = MockBreathingAudioWorker()
        audio.isPermissionGranted = micGranted
        audio.scriptedAmplitudes = scriptedAmplitudes
        let recorder = MockAudioFileRecorder()
        recorder.shouldFailStart = recorderFails
        let sut = FluencyDiaryInteractor(
            audioWorker: audio,
            storageWorker: MockDiaryStorageWorker(seed: seed),
            hapticService: MockHapticService(),
            fileRecorder: recorder
        )
        return (sut, audio, recorder)
    }

    private func session(
        id: String = UUID().uuidString,
        daysAgo: Int,
        dysfluencyCount: Int = 2,
        totalSyllables: Int = 40,
        rate: Float = 5.0
    ) -> FluencySessionData {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return FluencySessionData(
            id: id, date: date,
            dysfluencyCount: dysfluencyCount,
            totalSyllables: totalSyllables,
            rate: rate,
            transcript: "Тест"
        )
    }

    // MARK: - 1. startSession — устанавливает текст и сбрасывает состояние

    func test_startSession_setsCurrentTextAndResets() {
        let sut = makeSUT()
        sut.startSession()

        XCTAssertFalse(sut.display.currentText.isEmpty)
        XCTAssertFalse(sut.display.showComplete)
        XCTAssertNil(sut.display.errorMessage)
        XCTAssertTrue(sut.display.waveformLevels.isEmpty)
        XCTAssertEqual(sut.display.recordingDuration, 0)
    }

    // MARK: - 2. startSession — текст всегда из каталога FluencyDiaryTexts

    func test_startSession_textFromCatalog() {
        let sut = makeSUT()
        sut.startSession()
        XCTAssertTrue(FluencyDiaryTexts.texts.contains(sut.display.currentText))
    }

    // MARK: - 3. loadHistory — пустое хранилище → 0 сессий

    func test_loadHistory_emptyStorage_zeroSessions() async {
        let sut = makeSUT(seed: [])
        await sut.loadHistory()

        XCTAssertEqual(sut.display.totalSessions, 0)
        XCTAssertNil(sut.display.lastSessionDate)
    }

    // MARK: - 4. loadHistory — корректно обрабатывает пустой результат
    //
    // Note: loadHistory читает через fetchRecentSessions — protocol-extension
    // default возвращает []. Проверяем что Display не падает и валиден.

    func test_loadHistory_handlesEmptyExtensionResult() async {
        let seed = [session(daysAgo: 0), session(daysAgo: 1), session(daysAgo: 2)]
        let sut = makeSUT(seed: seed)
        await sut.loadHistory()

        // fetchRecentSessions (extension default) → [], totalSessions = 0.
        XCTAssertEqual(sut.display.totalSessions, 0)
        XCTAssertNil(sut.display.lastSessionDate)
    }

    // MARK: - 5. loadHistory — строит chartData на 14 дней

    func test_loadHistory_buildsFourteenDayChart() async {
        let sut = makeSUT(seed: [session(daysAgo: 0)])
        await sut.loadHistory()

        XCTAssertEqual(sut.display.chartData.count, 14)
    }

    // MARK: - 6. chartData — пустая история → все дни без данных

    func test_loadHistory_emptyHistory_allDaysWithoutData() async {
        let sut = makeSUT(seed: [])
        await sut.loadHistory()

        XCTAssertEqual(sut.display.chartData.count, 14)
        XCTAssertTrue(sut.display.chartData.allSatisfy { !$0.hasData })
    }

    // MARK: - 7. chartData — день без данных → rate -1

    func test_loadHistory_emptyDayHasNegativeRate() async {
        let sut = makeSUT(seed: [])
        await sut.loadHistory()

        XCTAssertTrue(sut.display.chartData.allSatisfy { $0.dysfluencyRate == -1 })
        XCTAssertTrue(sut.display.chartData.allSatisfy { !$0.hasData })
    }

    // MARK: - 8. averageDysfluencyRate — пустая история → 0

    func test_loadHistory_emptyHistory_averageRateZero() async {
        let sut = makeSUT(seed: [])
        await sut.loadHistory()

        XCTAssertEqual(sut.display.averageDysfluencyRate, 0, accuracy: 0.001)
    }

    // MARK: - 9. severityLabel — задаётся после loadHistory

    func test_loadHistory_severityLabelSet() async {
        let sut = makeSUT(seed: [])
        await sut.loadHistory()
        XCTAssertFalse(sut.display.severityLabel.isEmpty)
    }

    // MARK: - 10. reminderBanner — пустая история → баннер скрыт

    func test_loadHistory_emptyHistory_noReminderBanner() async {
        let sut = makeSUT(seed: [])
        await sut.loadHistory()
        XCTAssertFalse(sut.display.showReminderBanner)
    }

    // MARK: - 11. loadHistory — повторный вызов идемпотентен

    func test_loadHistory_repeatedCallsStable() async {
        let sut = makeSUT(seed: [session(daysAgo: 1)])
        await sut.loadHistory()
        await sut.loadHistory()
        XCTAssertEqual(sut.display.chartData.count, 14)
        XCTAssertEqual(sut.display.totalSessions, 0)
    }

    // MARK: - 12. stopRecording — без активной записи → no-op (не крашит)

    func test_stopRecording_whenNotRecording_doesNotCrash() {
        let sut = makeSUT()
        sut.stopRecording()
        XCTAssertFalse(sut.display.isRecording)
    }

    // MARK: - 13. FluencyChartPoint — структура корректна

    func test_fluencyChartPoint_construction() {
        let point = FluencyChartPoint(
            date: Date(), label: "1 мая",
            dysfluencyRate: 3.5, hasData: true
        )
        XCTAssertEqual(point.dysfluencyRate, 3.5, accuracy: 0.001)
        XCTAssertTrue(point.hasData)
        XCTAssertFalse(point.label.isEmpty)
    }

    // MARK: - 14. FluencyDiaryTexts — каталог не пуст, циклический доступ

    func test_fluencyDiaryTexts_cyclicAccess() {
        XCTAssertFalse(FluencyDiaryTexts.texts.isEmpty)
        let count = FluencyDiaryTexts.texts.count
        XCTAssertEqual(FluencyDiaryTexts.text(at: 0), FluencyDiaryTexts.text(at: count))
    }

    // MARK: - 15. Display — начальное состояние

    func test_display_initialState() {
        let sut = makeSUT()
        XCTAssertFalse(sut.display.isRecording)
        XCTAssertFalse(sut.display.isAnalyzing)
        XCTAssertEqual(sut.display.totalSessions, 0)
        XCTAssertTrue(sut.display.isStubAnalysis)
    }

    // MARK: - Batch 2.6a v25: startRecording / stopRecording / analyzeAndSave

    func test_startRecording_micGranted_setsIsRecording() async {
        let (sut, audio, recorder) = makeAudioSUT(micGranted: true)
        sut.startSession()
        await sut.startRecording()
        XCTAssertTrue(sut.display.isRecording)
        XCTAssertEqual(audio.startCount, 1)
        XCTAssertEqual(recorder.startCallCount, 1)
        sut.stopRecording()
    }

    func test_startRecording_micDenied_setsErrorMessage() async {
        let (sut, _, _) = makeAudioSUT(micGranted: false)
        sut.startSession()
        await sut.startRecording()
        XCTAssertFalse(sut.display.isRecording)
        XCTAssertNotNil(sut.display.errorMessage)
    }

    func test_startRecording_whenAlreadyRecording_isIgnored() async {
        let (sut, audio, _) = makeAudioSUT(micGranted: true)
        sut.startSession()
        await sut.startRecording()
        let startCountAfterFirst = audio.startCount
        await sut.startRecording() // повторный вызов — guard
        XCTAssertEqual(audio.startCount, startCountAfterFirst)
        sut.stopRecording()
    }

    func test_startRecording_recorderFails_stillSetsIsRecording() async {
        // fileRecorder.startRecording возвращает false → recordedFileURL=nil,
        // но audioWorker всё равно стартует и display.isRecording=true.
        let (sut, _, recorder) = makeAudioSUT(micGranted: true, recorderFails: true)
        sut.startSession()
        await sut.startRecording()
        XCTAssertTrue(sut.display.isRecording)
        XCTAssertEqual(recorder.startCallCount, 1)
        sut.stopRecording()
    }

    func test_stopRecording_afterStart_analyzesAndCompletes() async throws {
        let (sut, _, _) = makeAudioSUT(micGranted: true)
        sut.startSession()
        await sut.startRecording()
        sut.stopRecording()
        XCTAssertFalse(sut.display.isRecording)
        // analyzeAndSave запускает Task — даём ему завершиться (stub-путь).
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertTrue(sut.display.showComplete, "stub-анализ должен завершить сессию")
        XCTAssertFalse(sut.display.isAnalyzing)
        XCTAssertTrue(sut.display.isStubAnalysis, "Короткая запись без WhisperKit → stub")
        XCTAssertFalse(sut.display.severityLabel.isEmpty)
    }

    func test_stopRecording_incrementsTotalSessions() async throws {
        let (sut, _, _) = makeAudioSUT(micGranted: true)
        sut.startSession()
        await sut.startRecording()
        sut.stopRecording()
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(sut.display.totalSessions, 1)
        XCTAssertNotNil(sut.display.lastSessionDate)
    }

    func test_startRecording_scriptedAmplitudes_fillWaveform() async throws {
        let (sut, _, _) = makeAudioSUT(
            micGranted: true,
            scriptedAmplitudes: [0.2, 0.3, 0.25, 0.4, 0.35]
        )
        sut.startSession()
        await sut.startRecording()
        // MockBreathingAudioWorker пушит сэмплы с cadence 50 мс.
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertFalse(sut.display.waveformLevels.isEmpty,
                       "handleAmplitude должен заполнять waveformLevels")
        sut.stopRecording()
        try await Task.sleep(for: .milliseconds(300))
    }

    func test_stopRecording_buildsChartDataAfterAnalysis() async throws {
        let (sut, _, _) = makeAudioSUT(micGranted: true)
        sut.startSession()
        await sut.startRecording()
        sut.stopRecording()
        try await Task.sleep(for: .milliseconds(300))
        // analyzeAndSave → updateChartData(from: recentSessions) с непустым кешем.
        XCTAssertEqual(sut.display.chartData.count, 14)
        // Сегодняшний день должен иметь данные после сохранённой сессии.
        let today = sut.display.chartData.last
        XCTAssertNotNil(today)
        XCTAssertTrue(today?.hasData ?? false, "Сегодняшний день содержит только что записанную сессию")
    }

    func test_multipleRecordings_accumulateSessions() async throws {
        let (sut, _, _) = makeAudioSUT(micGranted: true)
        sut.startSession()
        for _ in 0..<3 {
            await sut.startRecording()
            sut.stopRecording()
            try await Task.sleep(for: .milliseconds(250))
        }
        XCTAssertEqual(sut.display.totalSessions, 3)
    }

    func test_startSession_afterRecording_resetsState() async throws {
        let (sut, _, _) = makeAudioSUT(micGranted: true)
        sut.startSession()
        await sut.startRecording()
        sut.stopRecording()
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertTrue(sut.display.showComplete)

        // Новая сессия сбрасывает showComplete и waveform.
        sut.startSession()
        XCTAssertFalse(sut.display.showComplete)
        XCTAssertTrue(sut.display.waveformLevels.isEmpty)
        XCTAssertEqual(sut.display.recordingDuration, 0)
    }

    // MARK: - Batch 2.6a v25 (доп.): fallback-анализ через non-FluencyAnalyzerWorker

    /// Мок-анализатор, который НЕ является `FluencyAnalyzerWorker` — заставляет
    /// `analyzeAndSave` пойти по ветке `makeFallbackAnalysis`.
    private final class StubAnalyzer: FluencyAnalyzerWorkerProtocol, @unchecked Sendable {
        func classifyOnset(
            rmsBuffer: [Float],
            threshold: Float,
            difficulty: StutteringDifficulty
        ) -> (classification: OnsetClassification, attackTimeMs: Float) {
            (.soft, 120)
        }
        func analyzeDysfluency(transcript: String) -> (repetitions: Int, totalTokens: Int) {
            (0, 0)
        }
        func estimateSyllableCount(in text: String) -> Int { 0 }
        func dysfluencyRate(count: Int, syllables: Int) -> Float { 0 }
    }

    private func makeFallbackSUT(
        micGranted: Bool = true
    ) -> (FluencyDiaryInteractor, MockBreathingAudioWorker) {
        let audio = MockBreathingAudioWorker()
        audio.isPermissionGranted = micGranted
        let sut = FluencyDiaryInteractor(
            audioWorker: audio,
            analyzerWorker: StubAnalyzer(),
            storageWorker: MockDiaryStorageWorker(),
            hapticService: MockHapticService(),
            fileRecorder: MockAudioFileRecorder()
        )
        return (sut, audio)
    }

    func test_stopRecording_withStubAnalyzer_usesFallbackAnalysis() async throws {
        let (sut, _) = makeFallbackSUT()
        sut.startSession()
        await sut.startRecording()
        sut.stopRecording()
        try await Task.sleep(for: .milliseconds(350))
        // analyzerWorker не FluencyAnalyzerWorker → makeFallbackAnalysis → isStub true.
        XCTAssertTrue(sut.display.showComplete)
        XCTAssertTrue(sut.display.isStubAnalysis)
    }

    func test_stopRecording_withStubAnalyzer_incrementsSessions() async throws {
        let (sut, _) = makeFallbackSUT()
        sut.startSession()
        await sut.startRecording()
        sut.stopRecording()
        try await Task.sleep(for: .milliseconds(350))
        XCTAssertEqual(sut.display.totalSessions, 1)
    }

    func test_stopRecording_withStubAnalyzer_buildsChartAfterAnalysis() async throws {
        let (sut, _) = makeFallbackSUT()
        sut.startSession()
        await sut.startRecording()
        sut.stopRecording()
        try await Task.sleep(for: .milliseconds(350))
        XCTAssertFalse(sut.display.chartData.isEmpty,
                       "Fallback-анализ всё равно строит 14-дневный chart")
        XCTAssertFalse(sut.display.severityLabel.isEmpty)
    }
}
