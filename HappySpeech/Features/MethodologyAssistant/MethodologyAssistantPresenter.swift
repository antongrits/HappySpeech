import Foundation
import Observation

// MARK: - MethodologyAssistantPresentationLogic

@MainActor
protocol MethodologyAssistantPresentationLogic: AnyObject {
    func presentLoading(_ response: MethodologyAssistant.Response.Loading)
    func presentAnswer(_ response: MethodologyAssistant.Response.Answered)
    func presentFailure(_ response: MethodologyAssistant.Response.Failed)
    func presentCleared(_ response: MethodologyAssistant.Response.Cleared)
}

// MARK: - MethodologyAssistantPresenter

/// Презентер помощника по методике — формирует ``MethodologyAssistant/ViewModel``
/// из ответов интерактора. Является `@Observable` display-моделью для SwiftUI.
@MainActor
@Observable
final class MethodologyAssistantPresenter: MethodologyAssistantPresentationLogic {

    // MARK: - Display state

    /// ViewModel, который наблюдает View.
    private(set) var viewModel: MethodologyAssistant.ViewModel = .initial

    // MARK: - Loading

    func presentLoading(_ response: MethodologyAssistant.Response.Loading) {
        var turns = viewModel.turns
        turns.append(
            .init(kind: .question, text: response.pendingQuestion)
        )
        viewModel = MethodologyAssistant.ViewModel(
            turns: turns,
            isLoading: true,
            errorMessage: nil,
            suggestions: [],
            canSend: false
        )
    }

    // MARK: - Answer

    func presentAnswer(_ response: MethodologyAssistant.Response.Answered) {
        var turns = viewModel.turns
        turns.append(
            .init(
                kind: .answer,
                text: response.answer.answer,
                citations: response.answer.citations
            )
        )
        viewModel = MethodologyAssistant.ViewModel(
            turns: turns,
            isLoading: false,
            errorMessage: nil,
            suggestions: [],
            canSend: true
        )
    }

    // MARK: - Failure

    func presentFailure(_ response: MethodologyAssistant.Response.Failed) {
        // Если вопрос уже добавлен в ленту как .question (loading state),
        // оставляем его — пользователь видит, что именно он спросил.
        viewModel = MethodologyAssistant.ViewModel(
            turns: viewModel.turns,
            isLoading: false,
            errorMessage: response.message,
            suggestions: viewModel.turns.isEmpty ? MethodologyAssistant.ViewModel.initial.suggestions : [],
            canSend: true
        )
    }

    // MARK: - Cleared

    func presentCleared(_ response: MethodologyAssistant.Response.Cleared) {
        viewModel = .initial
    }
}
