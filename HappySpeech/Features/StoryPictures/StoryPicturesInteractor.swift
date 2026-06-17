import Foundation
import OSLog

// MARK: - StoryPicturesBusinessLogic

@MainActor
protocol StoryPicturesBusinessLogic: AnyObject {
    func start(_ request: StoryPicturesModels.Start.Request) async
    func placeFrame(_ request: StoryPicturesModels.PlaceFrame.Request)
    func removeFrame(slotIndex: Int)
    func confirmOrder()
    func loadTellFrame(_ request: StoryPicturesModels.LoadTellFrame.Request)
    func toggleRecording() async
    func nextTellFrame() async
    func buildMovie() async
    func cancel()
}

// MARK: - StoryPicturesInteractor
//
// Бизнес-логика «Рассказа по серии картинок».
//   • start        — подбирает серию по возрасту, перемешивает кадры.
//   • placeFrame   — ставит кадр в слот, проверяет порядок (Builder).
//   • confirmOrder — порядок собран → шаг рассказа.
//   • toggleRecording — старт/стоп записи (AudioService); по стопу транскрибирует
//                       (ASRService) и отмечает названные смысловые звенья кадра
//                       (Builder.coveredLinks) — устойчиво к словоформам.
//   • nextTellFrame   — следующий кадр серии.
//   • buildMovie      — арка полноты (завязка/действие/развязка) + результат
//                       сохраняется в `AdaptivePlannerService` (пословный outcome
//                       по кадрам + SM-2 по сессии).
//
// Методически (Глухов/Ткаченко): связная речь оценивается ПОЛНОТОЙ высказывания,
// без «правильно/неправильно». Названо звено — галочка; не названо — мягкая
// наводка Ляли, а не ошибка.

@MainActor
final class StoryPicturesInteractor: StoryPicturesBusinessLogic {

    // MARK: - VIP

    var presenter: (any StoryPicturesPresentationLogic)?

    // MARK: - Deps

    private let childId: String
    private let childAge: Int
    private let builder: StoryPicturesBuilder
    private let audioService: any AudioService
    private let asrService: any ASRService
    private let adaptivePlanner: (any AdaptivePlannerService)?
    /// Тестовый seam: фиксированная серия + seed перемешивания (детерминизм).
    private let seededSeries: PictureSeries?
    private let shuffleSeed: UInt64?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "StoryPicturesInteractor")

    // MARK: - State

    private var series: PictureSeries?
    /// Слоты ленты: frameId или nil.
    private var placedFrameIds: [String?] = []
    /// Кадры в подносе (ещё не поставленные).
    private var trayFrameIds: [String] = []

    private var tellIndex: Int = 0
    /// Кадры в правильном порядке (для рассказа).
    private var orderedFrames: [PictureFrame] = []
    /// Все распознанные смысловые звенья по всем кадрам.
    private var coveredLinkIds: Set<String> = []
    /// Кадры, по которым была хотя бы одна запись.
    private var toldFrameIds: Set<String> = []
    /// Накопленные транскрипты по кадрам (для подсчёта слов мультика).
    private var transcripts: [String: String] = [:]
    /// Суммарная длительность записей (сек).
    private var totalDuration: Double = 0

    private var isRecording: Bool = false
    private var recordingStartedAt: Date?
    private var recordTimerTask: Task<Void, Never>?
    private var isFinished: Bool = false

    // MARK: - Init

    init(
        childId: String,
        childAge: Int,
        builder: StoryPicturesBuilder,
        audioService: any AudioService,
        asrService: any ASRService,
        adaptivePlanner: (any AdaptivePlannerService)? = nil,
        seededSeries: PictureSeries? = nil,
        shuffleSeed: UInt64? = nil
    ) {
        self.childId = childId
        self.childAge = max(5, min(childAge, 8))
        self.builder = builder
        self.audioService = audioService
        self.asrService = asrService
        self.adaptivePlanner = adaptivePlanner
        self.seededSeries = seededSeries
        self.shuffleSeed = shuffleSeed
    }

    deinit {
        recordTimerTask?.cancel()
    }

    // MARK: - start

    func start(_ request: StoryPicturesModels.Start.Request) async {
        let picked: PictureSeries?
        if let seededSeries {
            picked = seededSeries
        } else {
            let all = builder.loadSeries()
            picked = builder.pickSeries(from: all, age: childAge)
        }
        guard let picked else {
            logger.error("No series available for child=\(self.childId, privacy: .public)")
            return
        }
        series = picked
        placedFrameIds = Array(repeating: nil, count: picked.frames.count)
        let shuffled = builder.shuffledFrameIds(for: picked, seed: shuffleSeed)
        trayFrameIds = shuffled
        orderedFrames = picked.orderedFrames
        coveredLinkIds = []
        toldFrameIds = []
        transcripts = [:]
        totalDuration = 0
        tellIndex = 0
        isFinished = false

        logger.info("start child=\(self.childId, privacy: .public) series=\(picked.id, privacy: .public) frames=\(picked.frames.count, privacy: .public)")
        presenter?.presentStart(.init(series: picked, shuffledFrameIds: shuffled))
    }

    // MARK: - placeFrame (drag в слот)

    func placeFrame(_ request: StoryPicturesModels.PlaceFrame.Request) {
        guard let series else { return }
        guard placedFrameIds.indices.contains(request.slotIndex) else { return }
        // Кадр должен быть в подносе.
        guard let trayIdx = trayFrameIds.firstIndex(of: request.frameId) else { return }
        // Если слот занят — вернём прежний кадр в поднос.
        if let existing = placedFrameIds[request.slotIndex] {
            trayFrameIds.append(existing)
        }
        placedFrameIds[request.slotIndex] = request.frameId
        trayFrameIds.remove(at: trayIdx)
        emitPlacement(series: series)
    }

    // MARK: - removeFrame (снять кадр обратно в поднос)

    func removeFrame(slotIndex: Int) {
        guard let series else { return }
        guard placedFrameIds.indices.contains(slotIndex),
              let fid = placedFrameIds[slotIndex] else { return }
        placedFrameIds[slotIndex] = nil
        if !trayFrameIds.contains(fid) { trayFrameIds.append(fid) }
        emitPlacement(series: series)
    }

    private func emitPlacement(series: PictureSeries) {
        let isFilled = placedFrameIds.allSatisfy { $0 != nil }
        let isCorrect = builder.isOrderCorrect(placedFrameIds: placedFrameIds, series: series)
        let next = builder.nextEmptySlot(in: placedFrameIds)
        presenter?.presentPlaceFrame(
            .init(
                placedFrameIds: placedFrameIds,
                trayFrameIds: trayFrameIds,
                isFilled: isFilled,
                isOrderCorrect: isFilled && isCorrect,
                nextSlotIndex: next
            ),
            series: series
        )
    }

    // MARK: - confirmOrder (шаг 1 → шаг 2)

    func confirmOrder() {
        guard let series,
              builder.isOrderCorrect(placedFrameIds: placedFrameIds, series: series) else { return }
        // Порядок собран верно — собираем кадры по слотам (он же правильный).
        orderedFrames = placedFrameIds.compactMap { fid in
            fid.flatMap { id in series.frames.first(where: { $0.id == id }) }
        }
        tellIndex = 0
        presenter?.presentConfirmOrder(.init(orderedFrames: orderedFrames))
    }

    // MARK: - loadTellFrame

    func loadTellFrame(_ request: StoryPicturesModels.LoadTellFrame.Request) {
        guard orderedFrames.indices.contains(request.frameIndex) else { return }
        tellIndex = request.frameIndex
        let frame = orderedFrames[request.frameIndex]
        presenter?.presentTellFrame(.init(
            frame: frame,
            frameIndex: request.frameIndex,
            totalFrames: orderedFrames.count,
            toldFrameIds: toldFrameIds,
            coveredLinkIds: coveredLinkIds
        ))
    }

    // MARK: - toggleRecording (старт/стоп записи по текущему кадру)

    func toggleRecording() async {
        if isRecording {
            await stopRecordingAndTranscribe()
        } else {
            await startRecording()
        }
    }

    private func startRecording() async {
        guard !isRecording, !isFinished else { return }
        do {
            try await audioService.startRecording()
            isRecording = true
            recordingStartedAt = Date()
            startRecordTimer()
            logger.info("recording started frame=\(self.tellIndex, privacy: .public)")
        } catch {
            isRecording = false
            logger.error("recording start failed: \(error.localizedDescription, privacy: .public)")
            presenter?.presentRecordingState(.init(isRecording: false, elapsedSeconds: 0, amplitude: 0))
        }
    }

    private func stopRecordingAndTranscribe() async {
        guard isRecording else { return }
        isRecording = false
        recordTimerTask?.cancel()
        recordTimerTask = nil
        let started = recordingStartedAt ?? Date()
        let duration = Date().timeIntervalSince(started)
        totalDuration += max(0, duration)
        presenter?.presentRecordingState(.init(isRecording: false, elapsedSeconds: Int(duration), amplitude: 0))

        guard orderedFrames.indices.contains(tellIndex) else { return }
        let frame = orderedFrames[tellIndex]
        do {
            let url = try await audioService.stopRecording()
            let result = try await asrService.transcribe(url: url, expectedWord: nil, childAge: childAge)
            await applyTranscript(result.transcript, for: frame)
        } catch {
            logger.error("stop+ASR failed: \(error.localizedDescription, privacy: .public)")
            // Запись была — кадр считаем «рассказанным», но без новых звеньев.
            await applyTranscript("", for: frame)
        }
    }

    /// Применяет транскрипт: матчит смысловые звенья кадра, обновляет покрытие,
    /// сохраняет пословный outcome в планировщик. Public для тестов (без микрофона).
    func applyTranscript(_ transcript: String, for frame: PictureFrame) async {
        toldFrameIds.insert(frame.id)
        transcripts[frame.id] = transcript
        let newlyCovered = builder.coveredLinks(in: transcript, links: frame.links)
        coveredLinkIds.formUnion(newlyCovered)

        let frameLinkIds = Set(frame.links.map { $0.id })
        let frameCovered = !frameLinkIds.isEmpty && frameLinkIds.isSubset(of: coveredLinkIds)

        // Кадр «успешен», если названо хотя бы одно смысловое звено.
        await recordFrameOutcome(frame: frame, correct: !newlyCovered.isEmpty)

        presenter?.presentTranscribe(
            .init(
                frameId: frame.id,
                links: frame.links,
                coveredLinkIds: coveredLinkIds.intersection(frameLinkIds),
                frameCovered: frameCovered,
                transcript: transcript
            ),
            frame: frame
        )
    }

    private func startRecordTimer() {
        recordTimerTask?.cancel()
        recordTimerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, self.isRecording else { return }
                let elapsed = Int(Date().timeIntervalSince(self.recordingStartedAt ?? Date()))
                self.presenter?.presentRecordingState(.init(
                    isRecording: true,
                    elapsedSeconds: elapsed,
                    amplitude: self.audioService.amplitude
                ))
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    // MARK: - nextTellFrame

    func nextTellFrame() async {
        // Если идёт запись — корректно завершаем её.
        if isRecording { await stopRecordingAndTranscribe() }
        let next = tellIndex + 1
        if next >= orderedFrames.count {
            await buildMovie()
            return
        }
        loadTellFrame(.init(frameIndex: next))
    }

    // MARK: - buildMovie (экран 3 + сохранение)

    func buildMovie() async {
        if isRecording { await stopRecordingAndTranscribe() }
        guard let series else { return }
        let arc = builder.computeArc(series: series, coveredLinkIds: coveredLinkIds)
        let totalWords = transcripts.values.reduce(0) { acc, t in
            acc + t.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        }
        logger.info("buildMovie completeness=\(arc.completeness, privacy: .public) words=\(totalWords, privacy: .public)")
        await recordSession(arc: arc)
        presenter?.presentMovie(.init(
            series: series,
            frames: orderedFrames,
            arc: arc,
            totalWords: totalWords,
            toldFrameCount: toldFrameIds.count,
            totalDurationSeconds: totalDuration
        ))
    }

    // MARK: - cancel

    func cancel() {
        isFinished = true
        recordTimerTask?.cancel()
        recordTimerTask = nil
        if isRecording {
            isRecording = false
            Task { _ = try? await audioService.stopRecording() }
        }
        logger.info("StoryPictures cancelled")
    }

    // MARK: - Persistence

    private func recordFrameOutcome(frame: PictureFrame, correct: Bool) async {
        guard let planner = adaptivePlanner else { return }
        await planner.recordItemOutcome(
            childId: childId,
            itemId: frame.id,
            sound: "связная-речь",
            correct: correct
        )
    }

    private func recordSession(arc: StoryArc) async {
        guard let planner = adaptivePlanner else { return }
        let quality = SM2Quality.fromSuccessRate(arc.completeness)
        do {
            try await planner.recordSessionResult(
                childId: childId,
                soundTarget: "связная-речь",
                qualityScore: quality
            )
        } catch {
            logger.error("recordSessionResult failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Test seams

    /// Доля полноты рассказа (для тестов).
    var completeness: Double {
        guard let series else { return 0 }
        return builder.computeArc(series: series, coveredLinkIds: coveredLinkIds).completeness
    }

    /// Текущее множество названных звеньев (для тестов).
    var coveredLinks: Set<String> { coveredLinkIds }

    /// Текущая раскладка слотов (для тестов).
    var currentPlacement: [String?] { placedFrameIds }
}
