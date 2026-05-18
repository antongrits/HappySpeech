import Foundation

// MARK: - StorytellingDisplayLogic
//
// v29 Фаза 8, Функция 11 — Clean Swift: контракт View ← Presenter.

@MainActor
protocol StorytellingDisplayLogic: AnyObject {
    func displayTopics(viewModel: StorytellingModels.LoadTopics.ViewModel) async
    func displayTopicStart(viewModel: StorytellingModels.StartTopic.ViewModel) async
    func displayToggle(viewModel: StorytellingModels.ToggleStep.ViewModel) async
    func displayFinish(viewModel: StorytellingModels.Finish.ViewModel) async
}
