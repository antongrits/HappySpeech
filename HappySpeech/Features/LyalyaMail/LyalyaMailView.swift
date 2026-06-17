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
            .navigationTitle(Text("lyalya.mail.nav.title"))
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
                    VStack(spacing: SpacingTokens.sp3) {
                        mascotHero(vm)
                        sectionHeader(vm)
                        VStack(spacing: SpacingTokens.sp2) {
                            ForEach(Array(vm.rows.enumerated()), id: \.element.id) { index, row in
                                letterCard(row)
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
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.top, SpacingTokens.sp3)
                    .padding(.bottom, SpacingTokens.sp4)
                }
                .scrollBounceBehavior(.basedOnSize)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text(vm.accessibilitySummary))
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    // MARK: - Mascot hero «Ляля говорит»

    private func mascotHero(_ vm: LyalyaMailModels.LoadMail.ViewModel) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.sp3) {
            LyalyaMascotView(state: .happy, size: 64)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("lyalya.mail.hero.kicker")
                    .font(TypographyTokens.caption(12).weight(.bold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                Text(vm.unreadCount > 0
                     ? String(localized: "lyalya.mail.hero.unread")
                     : String(localized: "lyalya.mail.hero.allRead"))
                    .font(TypographyTokens.body(14).weight(.semibold))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(SpacingTokens.sp3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
            )
        }
        .padding(SpacingTokens.sp3)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [ColorTokens.Kid.surface, ColorTokens.Brand.primaryLo.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Section header

    private func sectionHeader(_ vm: LyalyaMailModels.LoadMail.ViewModel) -> some View {
        HStack {
            Text("lyalya.mail.section.title")
                .font(TypographyTokens.caption(13).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .textCase(.uppercase)
            Spacer()
            if vm.unreadCount > 0 {
                Text(String(format: String(localized: "lyalya.mail.section.count"), vm.unreadCount))
                    .font(TypographyTokens.caption(12).weight(.semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(ColorTokens.Brand.primaryLo.opacity(0.5)))
            }
        }
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Letter card

    private func letterCard(_ row: LyalyaLetterRowViewModel) -> some View {
        Button {
            openLetter(row.id)
        } label: {
            letterCardLabel(row)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                Task { await deleteLetter(row.id) }
            } label: {
                Label(String(localized: "action.delete"), systemImage: "trash")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(row.accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }

    private func letterCardLabel(_ row: LyalyaLetterRowViewModel) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.sp3) {
            // Конверт-аватар: цвет зависит от прочитанности.
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(row.isRead
                          ? ColorTokens.Brand.lilac.opacity(0.16)
                          : ColorTokens.Brand.primaryLo.opacity(0.45))
                    .frame(width: 46, height: 46)
                Image(systemName: row.isRead ? "envelope.open.fill" : "envelope.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(row.isRead ? ColorTokens.Brand.lilac : ColorTokens.Brand.primary)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: SpacingTokens.sp1) {
                    Text(row.title)
                        .font(TypographyTokens.headline(15))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: SpacingTokens.sp1)
                    Text(row.dateLabel)
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Kid.inkSoft)
                        .lineLimit(1)
                }
                Text(row.preview)
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !row.isRead {
                Circle()
                    .fill(ColorTokens.Brand.primary)
                    .frame(width: 10, height: 10)
                    .padding(.top, 6)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(ColorTokens.Brand.mint)
                    .padding(.top, 5)
                    .accessibilityHidden(true)
            }
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(row.isRead
                      ? AnyShapeStyle(ColorTokens.Kid.surface)
                      : AnyShapeStyle(LinearGradient(
                          colors: [ColorTokens.Kid.surface, ColorTokens.Brand.primaryLo.opacity(0.22)],
                          startPoint: .top,
                          endPoint: .bottom
                        )))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    row.isRead ? ColorTokens.Kid.line : ColorTokens.Brand.primaryLo,
                    lineWidth: row.isRead ? 1 : 1.5
                )
        )
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sp3) {
            LyalyaMascotView(state: .thinking, size: 120)
                .accessibilityHidden(true)
            Text("lyalya.mail.empty.title")
                .font(TypographyTokens.headline(17))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
            Text("lyalya.mail.empty.subtitle")
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
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
                            .fixedSize(horizontal: false, vertical: true)
                        Text(vm.dateLabel)
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                            Text(vm.body)
                                .font(TypographyTokens.body(15))
                                .foregroundStyle(ColorTokens.Kid.ink)
                                .multilineTextAlignment(.leading)
                                .lineLimit(nil)
                                .minimumScaleFactor(0.9)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            HStack(spacing: SpacingTokens.sp2) {
                                Spacer()
                                LyalyaMascotView(state: .happy, size: 34)
                                    .accessibilityHidden(true)
                                Text("lyalya.mail.signature")
                                    .font(TypographyTokens.headline(15))
                                    .foregroundStyle(ColorTokens.Brand.primary)
                            }
                        }
                        .padding(SpacingTokens.sp4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            ColorTokens.Kid.surface,
                                            ColorTokens.Brand.butter.opacity(0.18)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
                        )
                        if vm.hasAudio, let audioFile = vm.audioFileName {
                            HSButton(
                                String(localized: "lyalya.mail.play"),
                                style: .primary,
                                size: .medium,
                                icon: "play.circle.fill"
                            ) {
                                playLetterAudio(fileName: audioFile, body: vm.body)
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
                        .accessibilityLabel(Text("action.close"))
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
            .accessibilityLabel(Text("action.close"))
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

    /// Проигрывает озвучку письма голосом Ляли. Если у письма есть bundled-аудио
    /// (`audioFileName`) — играет его; иначе пытается озвучить текст письма через
    /// общий voice-worker (семейная запись / phrase-mapping). Реальное аудио, а
    /// не один лишь хаптик.
    private func playLetterAudio(fileName: String, body: String) {
        hapticService.impact(.light)
        Task {
            await LessonVoiceWorker.shared.speakAsset(
                fileName,
                fallbackText: body,
                lessonType: "lyalya_mail"
            )
        }
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
