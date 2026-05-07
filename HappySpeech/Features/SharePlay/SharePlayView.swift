import GroupActivities
import OSLog
import SwiftUI

// MARK: - SharePlayView
//
// Root View модуля SharePlay.
// Родительский контур (parent circuit).
//
// Отображает:
//   - Список доступных уроков для совместной игры
//   - Кнопку «Играть вдвоём» → BiometricGate → GroupActivity.activate()
//   - Fallback-hint если FaceTime недоступен (симулятор / нет звонка)
//   - Активную сессию через SharePlaySessionView (overlay)
//
// Clean Swift: View → Interactor → Presenter → ViewModel (@Observable)

struct SharePlayView: View {

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - VIP

    @State private var viewModel = SharePlayViewModel()
    @State private var interactor: SharePlayInteractor?
    @State private var presenter: SharePlayPresenter?
    @State private var router: SharePlayRouter?
    @State private var controller: FamilyShareplayController?

    // MARK: - Local state

    @State private var selectedLesson: SharePlayLessonItem?
    @State private var isLoading = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SpacingTokens.sectionGap) {
                    headerSection
                    lessonsSection
                    if viewModel.showFallbackHint {
                        fallbackHintSection
                    }
                    if viewModel.biometricHintVisible {
                        biometricHintSection
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp8)
            }
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle(String(localized: "shareplay.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .alert(
                String(localized: "shareplay.alert.title"),
                isPresented: Binding(
                    get: { viewModel.showAlert },
                    set: { viewModel.showAlert = $0 }
                )
            ) {
                Button(String(localized: "common.ok"), role: .cancel) {}
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
        }
        .overlay(alignment: .top) {
            if viewModel.isSessionActive, let ctrl = controller {
                SharePlaySessionBannerView(
                    controller: ctrl,
                    participantCountLabel: viewModel.participantCountLabel,
                    onEnd: {
                        Task { await interactor?.endSession(SharePlay.EndSession.Request()) }
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(
                    reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8),
                    value: viewModel.isSessionActive
                )
            }
        }
        .task { await bootstrap() }
        .onChange(of: controller?.isActive) { _, newValue in
            guard let newValue, let ctrl = controller else { return }
            let response = SharePlay.SessionStateChange.Response(
                isActive: newValue,
                participantCount: ctrl.participants.count
            )
            presenter?.presentSessionStateChange(response)
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(alignment: .top, spacing: SpacingTokens.sp3) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                Text(
                    String(
                        format: String(localized: "shareplay.subtitle"),
                        viewModel.childName
                    )
                )
                .font(TypographyTokens.body(17))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .padding(.top, SpacingTokens.sp2)

                Text(String(localized: "shareplay.instruction"))
                    .font(TypographyTokens.caption(14))
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            LyalyaMascotView(state: .happy, size: 72)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    private var lessonsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            Text(String(localized: "shareplay.lessons.title"))
                .font(TypographyTokens.headline(17))
                .foregroundStyle(ColorTokens.Parent.ink)
                .accessibilityAddTraits(.isHeader)

            ForEach(viewModel.availableLessons) { lesson in
                SharePlayLessonCard(
                    lesson: lesson,
                    isSelected: selectedLesson?.id == lesson.id,
                    isSessionActive: viewModel.isSessionActive
                ) {
                    selectedLesson = lesson
                    Task { await startSession(lesson: lesson) }
                }
            }
        }
    }

    private var fallbackHintSection: some View {
        HSLiquidGlassCard(style: .primary) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                HStack(spacing: SpacingTokens.sp2) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(ColorTokens.Parent.accent)
                        .accessibilityHidden(true)
                    Text(String(localized: "shareplay.fallback.title"))
                        .font(TypographyTokens.headline(15))
                        .foregroundStyle(ColorTokens.Parent.ink)
                }
                Text(String(localized: "shareplay.fallback.instruction"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "shareplay.fallback.title") + ". " +
            String(localized: "shareplay.fallback.instruction")
        )
    }

    private var biometricHintSection: some View {
        HStack(spacing: SpacingTokens.sp2) {
            Image(systemName: "faceid")
                .foregroundStyle(ColorTokens.Parent.inkSoft)
                .accessibilityHidden(true)
            Text(String(localized: "shareplay.biometric.hint"))
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Parent.inkSoft)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "shareplay.biometric.hint"))
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
            }
            .accessibilityLabel(String(localized: "common.close"))
        }
    }

    // MARK: - Actions

    private func startSession(lesson: SharePlayLessonItem) async {
        isLoading = true
        defer { isLoading = false }
        await interactor?.startSession(SharePlay.StartSession.Request(lesson: lesson))
    }

    // MARK: - Bootstrap

    private func bootstrap() async {
        guard interactor == nil else { return }

        let ctrl = FamilyShareplayController()
        let presenter = SharePlayPresenter()
        let interactor = SharePlayInteractor(
            biometric: container.biometricGateService,
            childRepository: container.childRepository,
            controller: ctrl
        )
        let router = SharePlayRouter(coordinator: coordinator)

        presenter.viewModel = viewModel
        interactor.presenter = presenter

        self.controller = ctrl
        self.presenter = presenter
        self.interactor = interactor
        self.router = router

        // Начинаем слушать входящие SharePlay-сессии
        ctrl.observeSessions()

        // Слушаем сообщения от других участников
        Task { [weak ctrl, weak presenter] in
            guard let ctrl, let presenter else { return }
            for await message in ctrl.incomingMessages() {
                presenter.presentRemoteMessage(
                    SharePlay.RemoteMessage.Response(message: message)
                )
            }
        }

        await interactor.load(
            SharePlay.Load.Request(childId: container.currentChildId)
        )
    }
}

// MARK: - SharePlayLessonCard

private struct SharePlayLessonCard: View {

    let lesson: SharePlayLessonItem
    let isSelected: Bool
    let isSessionActive: Bool
    let onTap: () -> Void

    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            HSLiquidGlassCard(
                style: isSelected ? .tinted(ColorTokens.Brand.primary) : .primary
            ) {
                HStack(spacing: SpacingTokens.sp3) {
                    // Иконка звука
                    ZStack {
                        Circle()
                            .fill(ColorTokens.Brand.primary.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Text(lesson.soundId.uppercased())
                            .font(TypographyTokens.headline(20))
                            .foregroundStyle(ColorTokens.Brand.primary)
                    }

                    VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                        Text(lesson.title)
                            .font(TypographyTokens.headline(16))
                            .foregroundStyle(ColorTokens.Parent.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)

                        Text(templateLabel(lesson.templateKind))
                            .font(TypographyTokens.caption(13))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }

                    Spacer()

                    if isSelected && isSessionActive {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .scaleEffect(isPressed && !reduceMotion ? 0.97 : 1.0)
        .animation(
            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
            value: isPressed
        )
        .buttonStyle(.plain)
        .accessibilityLabel(lesson.title)
        .accessibilityHint(String(localized: "shareplay.lesson.card.hint"))
        .disabled(isSessionActive && !isSelected)
    }

    private func templateLabel(_ kind: String) -> String {
        switch kind {
        case "repeatAfterModel":
            return String(localized: "game.template.repeatAfterModel")
        case "listenAndChoose":
            return String(localized: "game.template.listenAndChoose")
        default:
            return kind
        }
    }
}

// MARK: - SharePlaySessionBannerView

/// Баннер активной SharePlay-сессии в верхней части экрана.
private struct SharePlaySessionBannerView: View {

    let controller: FamilyShareplayController
    let participantCountLabel: String
    let onEnd: () -> Void

    var body: some View {
        HStack(spacing: SpacingTokens.sp3) {
            // Иконка SharePlay
            Image(systemName: "shareplay")
                .foregroundStyle(.white)
                .font(TypographyTokens.body(16))
                .accessibilityHidden(true)

            Text(participantCountLabel)
                .font(TypographyTokens.body(14))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            Button(action: onEnd) {
                Text(String(localized: "shareplay.session.end"))
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, SpacingTokens.sp3)
                    .padding(.vertical, SpacingTokens.sp1)
                    .background(ColorTokens.Overlay.highlight, in: Capsule())
            }
            .accessibilityLabel(String(localized: "shareplay.session.end"))
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.vertical, SpacingTokens.sp3)
        .background(ColorTokens.Brand.primary.gradient)
        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.md))
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.sp2)
        .shadow(color: ColorTokens.Brand.primary.opacity(0.3), radius: 8, y: 4)
    }
}

// MARK: - Preview

#Preview("SharePlay — Launcher") {
    SharePlayView()
        .environment(AppContainer.preview())
        .environment(AppCoordinator())
}

#Preview("SharePlay — Dark") {
    SharePlayView()
        .environment(AppContainer.preview())
        .environment(AppCoordinator())
        .preferredColorScheme(.dark)
}
