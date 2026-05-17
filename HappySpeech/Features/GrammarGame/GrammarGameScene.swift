import Observation
import SwiftUI

// MARK: - GrammarGameStackHolder

/// Удерживает VIP-стек GrammarGame на время жизни сцены.
/// Нужен, потому что `GrammarGamePresenter.display` — `weak`-ссылка,
/// а сам стек зависит от Environment и не может быть собран в `init` View.
@MainActor
@Observable
final class GrammarGameStackHolder {

    private(set) var interactor: GrammarGameInteractor?
    private var presenter: GrammarGamePresenter?
    private var router: GrammarGameRouter?
    private var displayHost: GrammarGameDisplayHost?

    /// Собирает стек один раз. Повторные вызовы игнорируются.
    func build(
        childId: String,
        hapticService: any HapticService,
        coordinator: AppCoordinator
    ) {
        guard interactor == nil else { return }

        let presenter = GrammarGamePresenter()
        let interactor = GrammarGameInteractor(
            contentLoader: GrammarContentLoaderWorker(),
            scoring: GrammarScoringWorker(),
            feedback: GrammarFeedbackWorker(hapticService: hapticService)
        )
        interactor.presenter = presenter

        let router = GrammarGameRouter()
        router.onDismiss = { [weak coordinator] in
            coordinator?.navigate(to: .childHome(childId: childId))
        }
        router.onSessionComplete = { [weak coordinator] _, _ in
            coordinator?.navigate(to: .sessionComplete)
        }

        self.presenter = presenter
        self.interactor = interactor
        self.router = router
    }

    /// Связывает `DisplayHost` (создаётся внутри `.task` View) с презентером.
    func attach(displayHost: GrammarGameDisplayHost) {
        self.displayHost = displayHost
        presenter?.display = displayHost
    }

    var grammarRouter: GrammarGameRouter? { router }
}

// MARK: - GrammarGameScene

/// Достижимая обёртка GrammarGame для подключения в навигацию (`AppRoute.grammarGame`).
///
/// `GrammarGameView` принимает уже собранный VIP-стек через инициализатор. Связывание
/// `Presenter.display` требует `GrammarGameDisplayHost`, привязанного к актуальным
/// `@State` экземпляра View в иерархии — поэтому host создаётся внутри `.task`
/// самого View и возвращается через `onBootstrap`.
struct GrammarGameScene: View {

    let childId: String
    let mode: GrammarGameMode
    let difficulty: GrammarDifficulty

    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator

    @State private var holder = GrammarGameStackHolder()

    init(
        childId: String,
        mode: GrammarGameMode = .oneMany,
        difficulty: GrammarDifficulty = .medium
    ) {
        self.childId = childId
        self.mode = mode
        self.difficulty = difficulty
    }

    var body: some View {
        Group {
            if let interactor = holder.interactor, let router = holder.grammarRouter {
                GrammarGameView(
                    mode: mode,
                    difficulty: difficulty,
                    childId: childId,
                    interactor: interactor,
                    router: router,
                    onBootstrap: { host in
                        holder.attach(displayHost: host)
                        Task {
                            await interactor.loadGame(
                                .init(mode: mode, difficulty: difficulty, childId: childId)
                            )
                        }
                    }
                )
            } else {
                ColorTokens.Kid.bg
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            holder.build(
                childId: childId,
                hapticService: container.hapticService,
                coordinator: coordinator
            )
        }
    }
}

#Preview {
    GrammarGameScene(childId: "preview-child")
        .environment(AppContainer.preview())
        .environment(AppCoordinator())
}
