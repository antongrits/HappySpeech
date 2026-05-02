import Foundation

// MARK: - SpecialistDisplayLogic

@MainActor
protocol SpecialistDisplayLogic: AnyObject {
    func displayFetch(_ viewModel: SpecialistModels.Fetch.ViewModel)
    func displayUpdate(_ viewModel: SpecialistModels.Update.ViewModel)
    func displayChildDashboard(_ viewModel: SpecialistModels.FetchChildDashboard.ViewModel)
    func displaySaveNote(_ viewModel: SpecialistModels.SaveNote.ViewModel)
    func displayFetchNotes(_ viewModel: SpecialistModels.FetchNotes.ViewModel)
    func displayExport(_ viewModel: SpecialistModels.RequestExport.ViewModel)
    func displaySendMessage(_ viewModel: SpecialistModels.SendParentMessage.ViewModel)
    func displayDeleteNote(_ viewModel: SpecialistModels.DeleteNote.ViewModel)
    func displayError(_ message: String)
}
