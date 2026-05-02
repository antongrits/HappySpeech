import Foundation

// MARK: - ScreeningDisplayLogic

@MainActor
protocol ScreeningDisplayLogic: AnyObject {
    func displayStartScreening(_ viewModel: ScreeningModels.StartScreening.ViewModel)
    func displayPrepareStage(_ viewModel: ScreeningModels.PrepareStage.ViewModel)
    func displayStartRecording(_ viewModel: ScreeningModels.StartRecording.ViewModel)
    func displaySubmitAnswer(_ viewModel: ScreeningModels.SubmitAnswer.ViewModel)
    func displayFinishScreening(_ viewModel: ScreeningModels.FinishScreening.ViewModel)
    func displayRecordingError(_ error: ScreeningModels.RecordingError)
    func displayMicrophonePermission(_ viewModel: ScreeningModels.MicrophonePermission.ViewModel)
    func displayRescreeningCheck(_ viewModel: ScreeningModels.CheckRescreening.ViewModel)
}
