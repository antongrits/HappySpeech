import OSLog
import SwiftUI

// MARK: - LyalyaMailDisplayLogic

@MainActor
protocol LyalyaMailDisplayLogic: AnyObject {
    func displayLetters(viewModel: LyalyaMailModels.LoadMail.ViewModel) async
    func displayOpenedLetter(viewModel: LyalyaMailModels.OpenLetter.ViewModel) async
    func displayDeleted(removedId: UUID) async
}

// MARK: - Holder

@MainActor
@Observable
final class LyalyaMailViewModelHolder: LyalyaMailDisplayLogic {

    var loadVM: LyalyaMailModels.LoadMail.ViewModel?
    var openVM: LyalyaMailModels.OpenLetter.ViewModel?
    var lastRemovedId: UUID?

    func displayLetters(viewModel: LyalyaMailModels.LoadMail.ViewModel) async {
        self.loadVM = viewModel
    }

    func displayOpenedLetter(viewModel: LyalyaMailModels.OpenLetter.ViewModel) async {
        self.openVM = viewModel
    }

    func displayDeleted(removedId: UUID) async {
        self.lastRemovedId = removedId
    }
}

// MARK: - LyalyaMailView

struct LyalyaMailView: View {

    let childId: String

    @State private var holder = LyalyaMailViewModelHolder()
    @State private var interactor: LyalyaMailInteractor?
    @State private var presenter: LyalyaMailPresenter?
    @State private var router: LyalyaMailRouter?
    @State private var didBootstrap = false
    @State private var showDetail = false

    @Environment(\.exitGame) private var exitGame
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.hapticService) private var hapticService

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "LyalyaMail.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                HSMeshGradientBackground(palette: .kidWarm, animated: !reduceMotion)
                    .ignoresSafeArea()
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                content
            }
            .navigationTitle(Text("Письма от Ляли"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await bootstrap() }
            .sheet(isPresented: $showDetail) {
                detailSheet
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let vm = holder.loadVM {
            if vm.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: SpacingTokens.sp2) {
                        header(vm)
                        ForEach(Array(vm.rows.enumerated()), id: \.element.id) { index, row in
                            letterCard(row)
                                .onTapGesture { openLetter(row.id) }
                                .scrollTransition(
                                    .animated(
                                        reduceMotion
                                            ? .linear(duration: 0)
                                            : .spring(response: 0.5, dampingFraction: 0.85)
                                    )
                                ) { content, phase in
                                    content
                                        .opacity(phase.isIdentity ? 1 : 0)
                                        .scaleEffect(phase.isIdentity ? 1 : 0.95)
                                }
                                .hsParallaxTile(factor: 0.18)
                                .zIndex(Double(vm.rows.count - index))
                        }
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.top, SpacingTokens.sp3)
                    .padding(.bottom, SpacingTokens.sp4)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text(vm.accessibilitySummary))
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    // MARK: - Header

    private func header(_ vm: LyalyaMailModels.LoadMail.ViewModel) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            LyalyaMascotView(state: .happy, size: 60)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Привет!")
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Text(vm.unreadCount > 0
                     ? "Новых писем: \(vm.unreadCount)"
                     : "Все письма прочитаны")
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            Spacer()
        }
        .padding(.bottom, SpacingTokens.sp1)
    }

    // MARK: - Letter card

    private func letterCard(_ row: LyalyaLetterRowViewModel) -> some View {
        HSLiquidGlassCard(style: row.isRead ? .primary : .elevated) {
            HStack(alignment: .top, spacing: SpacingTokens.sp2) {
                LyalyaMascotView(state: row.mascotState, size: 40)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(row.title)
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Spacer()
                        if !row.isRead {
                            newBadge
                        }
                    }
                    Text(row.preview)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(row.dateLabel)
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Kid.inkSoft)
                }
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                Task { await deleteLetter(row.id) }
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(row.accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }

    private var newBadge: some View {
        Text("NEW")
            .font(TypographyTokens.caption(10).weight(.bold))
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(ColorTokens.Brand.primary)
            )
            .accessibilityHidden(true)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sp3) {
            LyalyaMascotView(state: .thinking, size: 120)
                .accessibilityHidden(true)
            Text("Ляля скоро напишет тебе!")
                .font(TypographyTokens.headline(17))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Text("Загляни сюда позже — здесь появятся тёплые сообщения.")
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Detail sheet

    @ViewBuilder
    private var detailSheet: some View {
        if let vm = holder.openVM {
            NavigationStack {
                ScrollView {
                    VStack(spacing: SpacingTokens.sp3) {
                        LyalyaMascotView(state: vm.mascotState, size: 100)
                            .padding(.top, SpacingTokens.sp3)
                            .accessibilityHidden(true)
                        Text(vm.title)
                            .font(TypographyTokens.title(22))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)
                        Text(vm.dateLabel)
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                        HSCard(style: .tinted(ColorTokens.Brand.butter.opacity(0.14))) {
                            Text(vm.body)
                                .font(TypographyTokens.body(15))
                                .foregroundStyle(ColorTokens.Kid.ink)
                                .multilineTextAlignment(.leading)
                                .lineLimit(nil)
                                .minimumScaleFactor(0.9)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if vm.hasAudio {
                            HSButton(
                                String(localized: "lyalya.mail.play"),
                                style: .primary,
                                size: .medium,
                                icon: "play.circle.fill"
                            ) {
                                hapticService.impact(.light)
                            }
                        }
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.bottom, SpacingTokens.sp4)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showDetail = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(ColorTokens.Kid.inkSoft)
                        }
                        .accessibilityLabel(Text("Закрыть"))
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                exitGame()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
            }
            .accessibilityLabel(Text("Закрыть"))
        }
    }

    // MARK: - Lifecycle

    private func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        let presenter = LyalyaMailPresenter(displayLogic: holder)
        let interactor = LyalyaMailInteractor(
            childId: childId,
            realmActor: container.realmActor,
            childRepository: container.childRepository,
            sessionRepository: container.sessionRepository
        )
        interactor.presenter = presenter
        let router = LyalyaMailRouter()
        router.coordinator = coordinator
        self.presenter = presenter
        self.interactor = interactor
        self.router = router
        await interactor.loadMail(.init(childId: childId))
    }

    private func openLetter(_ id: UUID) {
        hapticService.impact(.light)
        Task {
            await interactor?.openLetter(.init(letterId: id))
            showDetail = true
        }
    }

    private func deleteLetter(_ id: UUID) async {
        await interactor?.delete(.init(letterId: id))
        hapticService.notification(.success)
    }
}

// MARK: - Preview

#Preview("LyalyaMail — Light") {
    LyalyaMailView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("LyalyaMail — Dark") {
    LyalyaMailView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
