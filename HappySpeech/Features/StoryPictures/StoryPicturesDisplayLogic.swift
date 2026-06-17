import Foundation

// MARK: - StoryPicturesDisplayLogic
//
// Контракт между `StoryPicturesPresenter` и SwiftUI-слоем
// (`StoryPicturesDisplay`). Все методы — только на @MainActor.

@MainActor
protocol StoryPicturesDisplayLogic: AnyObject {
    func displayStart(_ viewModel: StoryPicturesModels.Start.ViewModel)
    func displayPlaceFrame(_ viewModel: StoryPicturesModels.PlaceFrame.ViewModel)
    func displayConfirmOrder(_ viewModel: StoryPicturesModels.ConfirmOrder.ViewModel)
    func displayTellFrame(_ viewModel: StoryPicturesModels.LoadTellFrame.ViewModel)
    func displayRecordingState(_ viewModel: StoryPicturesModels.Recording.StateViewModel)
    func displayTranscribe(_ viewModel: StoryPicturesModels.Transcribe.ViewModel)
    func displayMovie(_ viewModel: StoryPicturesModels.BuildMovie.ViewModel)
    func displayPlaying(_ isPlaying: Bool)
}

// MARK: - StoryPicturesDisplay conformance

extension StoryPicturesDisplay: StoryPicturesDisplayLogic {

    func displayStart(_ viewModel: StoryPicturesModels.Start.ViewModel) {
        seriesTitle = viewModel.seriesTitle
        frameCount = viewModel.frameCount
        trayFrames = viewModel.trayFrames
        slots = (0..<viewModel.slotCount).map { idx in
            StoryPicturesModels.SlotViewModel(
                id: idx,
                number: idx + 1,
                frame: nil,
                isNext: idx == 0,
                isCorrect: false
            )
        }
        isFilled = false
        isOrderCorrect = false
        nextSlotIndex = 0
        orderHintText = String(
            localized: "storyPictures.order.hint",
            defaultValue: "Что было сначала? Поставь картинки по порядку — с чего всё началось и чем закончилось."
        )
        mascotText = String(
            localized: "storyPictures.order.mascot",
            defaultValue: "Картинки перепутались! Помоги мне расставить их по порядку."
        )
        phase = .order
    }

    func displayPlaceFrame(_ viewModel: StoryPicturesModels.PlaceFrame.ViewModel) {
        slots = viewModel.slots
        trayFrames = viewModel.trayFrames
        isFilled = viewModel.isFilled
        isOrderCorrect = viewModel.isOrderCorrect
        nextSlotIndex = viewModel.nextSlotIndex
        orderHintText = viewModel.hintText
        mascotText = viewModel.mascotText
        if phase != .order { phase = .order }
    }

    func displayConfirmOrder(_ viewModel: StoryPicturesModels.ConfirmOrder.ViewModel) {
        orderedFrames = viewModel.orderedFrames
        toldFrameIds = []
        if let first = viewModel.firstFrame {
            applyTellFrame(first)
        }
        phase = .tell
    }

    func displayTellFrame(_ viewModel: StoryPicturesModels.LoadTellFrame.ViewModel) {
        toldFrameIds = viewModel.toldFrameIds
        applyTellFrame(viewModel.tellFrame)
        if phase != .tell { phase = .tell }
    }

    func displayRecordingState(_ viewModel: StoryPicturesModels.Recording.StateViewModel) {
        isRecording = viewModel.isRecording
        recordTimeLabel = viewModel.timeLabel
        amplitude = viewModel.amplitude
    }

    func displayTranscribe(_ viewModel: StoryPicturesModels.Transcribe.ViewModel) {
        supports = viewModel.supports
        mascotText = viewModel.mascotText
        allFrameLinksNamed = viewModel.allFrameLinksNamed
        if let tf = tellFrame { toldFrameIds.insert(tf.frameId) }
        if var tf = tellFrame {
            tf = StoryPicturesModels.TellFrameViewModel(
                frameId: tf.frameId,
                scene: tf.scene,
                imageAsset: tf.imageAsset,
                badge: tf.badge,
                frameIndex: tf.frameIndex,
                totalFrames: tf.totalFrames,
                supports: viewModel.supports,
                mascotText: viewModel.mascotText
            )
            tellFrame = tf
        }
    }

    func displayMovie(_ viewModel: StoryPicturesModels.BuildMovie.ViewModel) {
        movieTitle = viewModel.title
        seriesTitle = viewModel.seriesTitle
        playerFrames = viewModel.playerFrames
        durationLabel = viewModel.durationLabel
        arc = viewModel.arc
        pills = viewModel.pills
        mascotText = viewModel.mascotText
        isStoryComplete = viewModel.isComplete
        missingRole = viewModel.missingRole
        isPlaying = false
        phase = .movie
    }

    func displayPlaying(_ isPlaying: Bool) {
        self.isPlaying = isPlaying
    }

    // MARK: - Helpers

    private func applyTellFrame(_ frame: StoryPicturesModels.TellFrameViewModel) {
        tellFrame = frame
        tellFrameIndex = frame.frameIndex
        supports = frame.supports
        mascotText = frame.mascotText
        allFrameLinksNamed = frame.supports.allSatisfy { $0.isNamed }
        isRecording = false
        recordTimeLabel = "0:00"
        amplitude = 0
    }
}
