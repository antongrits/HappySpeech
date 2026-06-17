import Foundation
import OSLog

// MARK: - StoryPicturesPresentationLogic

@MainActor
protocol StoryPicturesPresentationLogic: AnyObject {
    func presentStart(_ response: StoryPicturesModels.Start.Response)
    func presentPlaceFrame(_ response: StoryPicturesModels.PlaceFrame.Response, series: PictureSeries)
    func presentConfirmOrder(_ response: StoryPicturesModels.ConfirmOrder.Response)
    func presentTellFrame(_ response: StoryPicturesModels.LoadTellFrame.Response)
    func presentRecordingState(_ response: StoryPicturesModels.Recording.StateResponse)
    func presentTranscribe(_ response: StoryPicturesModels.Transcribe.Response, frame: PictureFrame)
    func presentMovie(_ response: StoryPicturesModels.BuildMovie.Response)
    func presentPlaying(_ isPlaying: Bool)
}

// MARK: - StoryPicturesPresenter
//
// Конвертирует Response → ViewModel. Бизнес-логика (упорядочивание, ASR-матчинг
// смысловых звеньев, арка полноты) — в Interactor/Builder. Здесь — форматирование
// и локализация. Никаких оценок «правильно/неправильно» в речи: связная речь
// оценивается ПОЛНОТОЙ (Глухов), подача мягкая, как у Ляли.

@MainActor
final class StoryPicturesPresenter: StoryPicturesPresentationLogic {

    weak var display: (any StoryPicturesDisplayLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "StoryPicturesPresenter")

    // MARK: - Start

    func presentStart(_ response: StoryPicturesModels.Start.Response) {
        let series = response.series
        let byId = Dictionary(uniqueKeysWithValues: series.frames.map { ($0.id, $0) })
        let tray: [StoryPicturesModels.FrameViewModel] = response.shuffledFrameIds.compactMap { id in
            guard let f = byId[id] else { return nil }
            return Self.frameVM(f, isTold: false)
        }
        let vm = StoryPicturesModels.Start.ViewModel(
            seriesTitle: series.title,
            frameCount: series.frames.count,
            trayFrames: tray,
            slotCount: series.frames.count
        )
        logger.info("presentStart series=\(series.id, privacy: .public) frames=\(series.frames.count, privacy: .public)")
        display?.displayStart(vm)
    }

    // MARK: - PlaceFrame

    func presentPlaceFrame(_ response: StoryPicturesModels.PlaceFrame.Response, series: PictureSeries) {
        let byId = Dictionary(uniqueKeysWithValues: series.frames.map { ($0.id, $0) })

        let slots: [StoryPicturesModels.SlotViewModel] = response.placedFrameIds.enumerated().map { idx, fid in
            let frameVM = fid.flatMap { byId[$0] }.map { Self.frameVM($0, isTold: false) }
            // Кадр верен, если его order совпадает с позицией.
            let isCorrect: Bool = {
                guard let fid, let f = byId[fid] else { return false }
                return f.order == idx + 1
            }()
            return StoryPicturesModels.SlotViewModel(
                id: idx,
                number: idx + 1,
                frame: frameVM,
                isNext: response.nextSlotIndex == idx,
                isCorrect: response.isFilled && isCorrect
            )
        }

        let tray = response.trayFrameIds.compactMap { id in
            byId[id].map { Self.frameVM($0, isTold: false) }
        }

        let hint: String
        let mascot: String
        if response.isFilled && response.isOrderCorrect {
            hint = String(localized: "storyPictures.order.done.hint",
                          defaultValue: "Всё по порядку! С чего началось — и чем закончилось.")
            mascot = String(localized: "storyPictures.order.done.mascot",
                            defaultValue: "Картинки по порядку! Теперь самое интересное — расскажи эту историю своими словами.")
        } else if response.isFilled {
            hint = String(localized: "storyPictures.order.recheck.hint",
                          defaultValue: "Кажется, что-то перепуталось. Подумай: что было раньше?")
            mascot = String(localized: "storyPictures.order.recheck.mascot",
                            defaultValue: "Давай ещё раз посмотрим: что случилось сначала, а что потом?")
        } else {
            let nextNumber = (response.nextSlotIndex ?? 0) + 1
            hint = String(localized: "storyPictures.order.continue.hint",
                          defaultValue: "Что было сначала? Перетащи следующую картинку.")
            mascot = String(
                format: String(localized: "storyPictures.order.continue.mascot %lld",
                               defaultValue: "А что было потом? Поставь картинку в клетку №%lld."),
                nextNumber
            )
        }

        let vm = StoryPicturesModels.PlaceFrame.ViewModel(
            slots: slots,
            trayFrames: tray,
            isFilled: response.isFilled,
            isOrderCorrect: response.isOrderCorrect,
            nextSlotIndex: response.nextSlotIndex,
            hintText: hint,
            mascotText: mascot,
            ctaEnabled: response.isFilled && response.isOrderCorrect
        )
        logger.info("presentPlaceFrame filled=\(response.isFilled, privacy: .public) correct=\(response.isOrderCorrect, privacy: .public)")
        display?.displayPlaceFrame(vm)
    }

    // MARK: - ConfirmOrder

    func presentConfirmOrder(_ response: StoryPicturesModels.ConfirmOrder.Response) {
        let total = response.orderedFrames.count
        let firstVM = response.orderedFrames.first.map { tellFrameVM($0, index: 0, total: total, covered: []) }
        let frames = response.orderedFrames.map { Self.frameVM($0, isTold: false) }
        let vm = StoryPicturesModels.ConfirmOrder.ViewModel(
            title: String(localized: "storyPictures.tell.title", defaultValue: "Расскажи историю"),
            firstFrame: firstVM,
            orderedFrames: frames
        )
        display?.displayConfirmOrder(vm)
    }

    // MARK: - LoadTellFrame

    func presentTellFrame(_ response: StoryPicturesModels.LoadTellFrame.Response) {
        let vm = StoryPicturesModels.LoadTellFrame.ViewModel(
            tellFrame: tellFrameVM(
                response.frame,
                index: response.frameIndex,
                total: response.totalFrames,
                covered: response.coveredLinkIds
            ),
            toldFrameIds: response.toldFrameIds
        )
        display?.displayTellFrame(vm)
    }

    // MARK: - Recording state

    func presentRecordingState(_ response: StoryPicturesModels.Recording.StateResponse) {
        let vm = StoryPicturesModels.Recording.StateViewModel(
            isRecording: response.isRecording,
            timeLabel: Self.timeLabel(response.elapsedSeconds),
            amplitude: response.amplitude
        )
        display?.displayRecordingState(vm)
    }

    // MARK: - Transcribe (смысловые звенья)

    func presentTranscribe(_ response: StoryPicturesModels.Transcribe.Response, frame: PictureFrame) {
        let supports = frame.links.map { link in
            StoryPicturesModels.SupportViewModel(
                id: link.id,
                question: link.question,
                answerHint: link.answerHint,
                isNamed: response.coveredLinkIds.contains(link.id)
            )
        }
        let namedCount = supports.filter { $0.isNamed }.count
        let allNamed = !supports.isEmpty && namedCount == supports.count

        let mascot: String
        if allNamed {
            mascot = String(localized: "storyPictures.tell.allNamed.mascot",
                            defaultValue: "Молодец! Ты назвал и кто, и что делает. Едем дальше!")
        } else if namedCount > 0 {
            let missing = supports.first { !$0.isNamed }?.question ?? ""
            mascot = String(
                format: String(localized: "storyPictures.tell.partial.mascot %@",
                               defaultValue: "Здорово! А ещё расскажи: %@ Доскажи — и поедем дальше."),
                missing
            )
        } else {
            mascot = String(localized: "storyPictures.tell.empty.mascot",
                            defaultValue: "Посмотри на картинку и расскажи: кто здесь и что он делает?")
        }

        let vm = StoryPicturesModels.Transcribe.ViewModel(
            supports: supports,
            mascotText: mascot,
            allFrameLinksNamed: allNamed
        )
        logger.info("presentTranscribe frame=\(response.frameId, privacy: .public) named=\(namedCount, privacy: .public)/\(supports.count, privacy: .public)")
        display?.displayTranscribe(vm)
    }

    // MARK: - BuildMovie (радар полноты)

    func presentMovie(_ response: StoryPicturesModels.BuildMovie.Response) {
        let series = response.series
        let frames = response.frames.map { Self.frameVM($0, isTold: true) }

        let segments: [StoryPicturesModels.ArcViewModel.Segment] = StoryLinkRole.allCases.compactMap { role in
            guard let fill = response.arc.coverageByRole[role] else { return nil }
            return StoryPicturesModels.ArcViewModel.Segment(
                id: role.rawValue,
                role: role,
                title: role.displayName,
                summary: arcSummary(for: role, in: series, covered: response.arc),
                fill: fill,
                isComplete: fill >= 0.999
            )
        }
        let completeness = response.arc.completeness
        let isComplete = completeness >= 0.999
        let percentLabel = isComplete
            ? String(localized: "storyPictures.arc.excellent", defaultValue: "отлично!")
            : String(localized: "storyPictures.arc.almost", defaultValue: "почти!")

        let arcVM = StoryPicturesModels.ArcViewModel(
            segments: segments,
            percentLabel: percentLabel,
            isComplete: isComplete
        )

        var pills: [StoryPicturesModels.PillViewModel] = [
            StoryPicturesModels.PillViewModel(
                id: "frames",
                text: String(
                    format: String(localized: "storyPictures.pill.frames %lld", defaultValue: "%lld картинки"),
                    response.toldFrameCount
                ),
                isGold: false
            ),
            StoryPicturesModels.PillViewModel(
                id: "words",
                text: String(
                    format: String(localized: "storyPictures.pill.words %lld", defaultValue: "%lld слов"),
                    response.totalWords
                ),
                isGold: false
            )
        ]
        let missingRole = response.arc.firstIncompleteRole
        if isComplete {
            pills.append(StoryPicturesModels.PillViewModel(
                id: "structure",
                text: String(localized: "storyPictures.pill.structure", defaultValue: "Начало, середина, конец"),
                isGold: true
            ))
        } else if let missingRole {
            pills.append(StoryPicturesModels.PillViewModel(
                id: "missing",
                text: String(
                    format: String(localized: "storyPictures.pill.addPart %@", defaultValue: "Добавь: %@"),
                    missingRole.displayName.lowercased()
                ),
                isGold: true
            ))
        }

        let mascot: String
        if isComplete {
            mascot = String(localized: "storyPictures.movie.complete.mascot",
                            defaultValue: "Ты рассказал с начала до конца — настоящий рассказчик! Хочешь показать мультик маме?")
        } else if let missingRole {
            mascot = String(
                format: String(localized: "storyPictures.movie.incomplete.mascot %@",
                               defaultValue: "Здорово получилось! Не хватило только одной части: %@. Доскажи — и мультик станет целым."),
                missingRole.displayName.lowercased()
            )
        } else {
            mascot = String(localized: "storyPictures.movie.empty.mascot",
                            defaultValue: "Давай расскажем историю по картинкам — получится твой мультик!")
        }

        let vm = StoryPicturesModels.BuildMovie.ViewModel(
            title: isComplete
                ? String(localized: "storyPictures.movie.title.ready", defaultValue: "Твой мультик готов!")
                : String(localized: "storyPictures.movie.title.almost", defaultValue: "Почти готово!"),
            seriesTitle: series.title,
            playerFrames: frames,
            durationLabel: Self.timeLabel(Int(response.totalDurationSeconds.rounded())),
            arc: arcVM,
            pills: pills,
            mascotText: mascot,
            isComplete: isComplete,
            missingRole: isComplete ? nil : missingRole
        )
        logger.info("presentMovie completeness=\(completeness, privacy: .public) complete=\(isComplete, privacy: .public)")
        display?.displayMovie(vm)
    }

    // MARK: - Playing

    func presentPlaying(_ isPlaying: Bool) {
        display?.displayPlaying(isPlaying)
    }

    // MARK: - Helpers

    private static func frameVM(_ frame: PictureFrame, isTold: Bool) -> StoryPicturesModels.FrameViewModel {
        StoryPicturesModels.FrameViewModel(
            id: frame.id,
            scene: frame.scene,
            imageAsset: frame.imageAsset,
            order: frame.order,
            isTold: isTold
        )
    }

    private func tellFrameVM(
        _ frame: PictureFrame,
        index: Int,
        total: Int,
        covered: Set<String>
    ) -> StoryPicturesModels.TellFrameViewModel {
        let supports = frame.links.map { link in
            StoryPicturesModels.SupportViewModel(
                id: link.id,
                question: link.question,
                answerHint: link.answerHint,
                isNamed: covered.contains(link.id)
            )
        }
        let badge = String(
            format: String(localized: "storyPictures.tell.badge %lld %@", defaultValue: "№%lld · %@"),
            frame.order, frame.caption
        )
        let mascot = String(
            format: String(localized: "storyPictures.tell.frame.mascot %@",
                           defaultValue: "Расскажи, что здесь происходит. Опоры внизу помогут: %@"),
            frame.links.map { $0.question }.joined(separator: " ")
        )
        return StoryPicturesModels.TellFrameViewModel(
            frameId: frame.id,
            scene: frame.scene,
            imageAsset: frame.imageAsset,
            badge: badge,
            frameIndex: index,
            totalFrames: total,
            supports: supports,
            mascotText: mascot
        )
    }

    private func arcSummary(for role: StoryLinkRole, in series: PictureSeries, covered: StoryArc) -> String {
        // Сводка ответов-подсказок по роли (что названо / что доспросить).
        let hints = series.frames
            .flatMap { $0.links }
            .filter { $0.role == role }
            .map { $0.answerHint }
        var seen = Set<String>()
        let unique = hints.filter { seen.insert($0).inserted }
        if covered.fill(for: role) >= 0.999 {
            return unique.prefix(2).joined(separator: ", ")
        }
        return String(localized: "storyPictures.arc.whatHappened", defaultValue: "чем закончилось?")
    }

    static func timeLabel(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
