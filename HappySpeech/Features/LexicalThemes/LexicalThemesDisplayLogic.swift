import Foundation

// MARK: - LexicalThemesDisplayLogic
//
// v29 Фаза 8, Функция 7 — Clean Swift: контракт View ← Presenter.

@MainActor
protocol LexicalThemesDisplayLogic: AnyObject {
    func displayThemes(viewModel: LexicalThemesModels.LoadThemes.ViewModel) async
    func displayThemeStart(viewModel: LexicalThemesModels.StartTheme.ViewModel) async
    func displayAnswer(viewModel: LexicalThemesModels.Answer.ViewModel) async
}
