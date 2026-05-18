import OSLog
import SwiftUI

// MARK: - RetellingViewModelHolder

@MainActor
@Observable
final class RetellingViewModelHolder: RetellingDisplayLogic {

    var startVM: RetellingModels.Start.ViewModel?
    var coveredFrameIds: Set<String> = []
    var coverageLabel: String = ""
    var coverageFraction: Double = 0
    var finishVM: RetellingModels.Finish.ViewModel?
    var phase: Phase = .loading

    enum Phase: Equatable {
        case loading
        case listen
        case retell
        case finished
    }

    func displayStart(viewModel: RetellingModels.Start.ViewModel) async {
        self.startVM = viewModel
        self.coveredFrameIds = []
        self.coverageLabel = ""
        self.coverageFraction = 0
        self.finishVM = nil
        self.phase = .listen
    }

    func displayToggle(viewModel: RetellingModels.ToggleLink.ViewModel) async {
        self.coveredFrameIds = viewModel.coveredFrameIds
        self.coverageLabel = viewModel.coverageLabel
        self.coverageFraction = viewModel.coverageFraction
    }

    func displayFinish(viewModel: RetellingModels.Finish.ViewModel) async {
        self.finishVM = viewModel
        self.phase = .finished
    }
}

// MARK: - RetellingView (Clean Swift: View)
//
// v29 Фаза 8, Функция 2 «Расскажи по-настоящему».
//
// Детская игра пересказа: ребёнок слушает короткую историю, затем
// пересказывает своими словами, отмечая озвученные смысловые звенья;
// итог показывает покрытие и наводящие вопросы по пропущенному.
//
// Accessibility:
//   • Kid circuit: кнопки и кадры ≥ 56pt
//   • VoiceOver: кадры и кнопки — описательные labels
//   • Dynamic Type: minimumScaleFactor
//   • Reduced Motion: переходы фаз гейтятся reduceMotion
//   • Light + Dark: ColorTokens.Kid адаптируются

struct RetellingView: View {

    let childId: String

    @State private var holder = RetellingViewModelHolder()
    @State private var interactor: RetellingInteractor?
    @State private var presenter: RetellingPresenter?
    @State private var router: RetellingRouter?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "Retelling.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()

                switch holder.phase {
                case .loading:
                    loadingSection
                case .listen:
                    if let start = holder.startVM { listenSection(start) }
                case .retell:
                    if let start = holder.startVM { retellSection(start) }
                case .finished:
                    if let finish = holder.finishVM { summarySection(finish) }
                }
            }
            .navigationTitle(Text("retelling.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text("retelling.close.a11y"))
                }
            }
            .task {
                await setupAndStart()
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Listen phase

    private func listenSection(
        _ start: RetellingModels.Start.ViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp4) {
            ScrollView {
                VStack(spacing: SpacingTokens.sp4) {
                    Text(start.storyTitle)
                        .font(TypographyTokens.title(24))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .padding(.top, SpacingTokens.sp4)

                    Text(start.listenPrompt)
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .padding(.horizontal, SpacingTokens.sp4)

                    ForEach(start.frames) { frame in
                        frameCard(frame, isCovered: false, interactive: false)
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
            }

            Button {
                holder.phase = .retell
            } label: {
                Text("retelling.startRetell")
                    .font(TypographyTokens.headline(18))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .fill(ColorTokens.Brand.primary)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("retelling.startRetell.hint"))
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp5)
        }
    }

    // MARK: - Retell phase

    private func retellSection(
        _ start: RetellingModels.Start.ViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp4) {
            VStack(spacing: SpacingTokens.sp2) {
                Text("retelling.retell.prompt")
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, SpacingTokens.sp4)

                if !holder.coverageLabel.isEmpty {
                    Text(holder.coverageLabel)
                        .font(TypographyTokens.caption(13).monospacedDigit())
                        .foregroundStyle(ColorTokens.Brand.primary)
                }
            }
            .padding(.top, SpacingTokens.sp4)

            ScrollView {
                VStack(spacing: SpacingTokens.sp3) {
                    ForEach(start.frames) { frame in
                        frameCard(
                            frame,
                            isCovered: holder.coveredFrameIds.contains(frame.id),
                            interactive: true
                        )
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
            }

            Button {
                Task { await finish() }
            } label: {
                HStack(spacing: SpacingTokens.sp2) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("retelling.finishButton")
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(ColorTokens.Brand.primary)
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("retelling.finishButton.hint"))
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp5)
        }
    }

    private func frameCard(
        _ frame: RetellingModels.Start.FrameViewModel,
        isCovered: Bool,
        interactive: Bool
    ) -> some View {
        let content = HStack(spacing: SpacingTokens.sp3) {
            Image(systemName: frame.symbolName)
                .font(.system(size: 34))
                .foregroundStyle(isCovered ? ColorTokens.Brand.mint : ColorTokens.Brand.sky)
                .frame(width: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(frame.linkLabel)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .textCase(.uppercase)
                Text(frame.sentence)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            if interactive {
                Image(systemName: isCovered ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isCovered ? ColorTokens.Brand.mint : ColorTokens.Kid.inkSoft)
            }
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Kid.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .strokeBorder(
                    isCovered ? ColorTokens.Brand.mint : ColorTokens.Kid.line,
                    lineWidth: 2
                )
        )

        return Group {
            if interactive {
                Button {
                    Task { await toggle(frameId: frame.id) }
                } label: { content }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(frame.accessibilityLabel))
                .accessibilityHint(Text("retelling.frame.hint"))
                .accessibilityAddTraits(isCovered ? [.isButton, .isSelected] : .isButton)
            } else {
                content
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text(frame.accessibilityLabel))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isCovered)
    }

    // MARK: - Summary

    private func summarySection(
        _ finish: RetellingModels.Finish.ViewModel
    ) -> some View {
        ScrollView {
            VStack(spacing: SpacingTokens.sp4) {
                Image(systemName: finish.coverageFraction >= 0.75
                    ? "book.closed.fill"
                    : "hand.thumbsup.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(ColorTokens.Brand.butter)
                    .accessibilityHidden(true)
                    .padding(.top, SpacingTokens.sp5)

                Text(finish.title)
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(finish.scoreText)
                    .font(TypographyTokens.headline(19).monospacedDigit())
                    .foregroundStyle(ColorTokens.Brand.primary)

                Text(finish.encouragement)
                    .font(TypographyTokens.body(16))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, SpacingTokens.sp5)

                if !finish.hints.isEmpty {
                    VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                        Text("retelling.hints.title")
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Kid.ink)
                        ForEach(Array(finish.hints.enumerated()), id: \.offset) { _, hint in
                            HStack(alignment: .top, spacing: SpacingTokens.sp2) {
                                Image(systemName: "questionmark.circle.fill")
                                    .foregroundStyle(ColorTokens.Brand.lilac)
                                Text(hint)
                                    .font(TypographyTokens.body(14))
                                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                                    .lineLimit(nil)
                            }
                        }
                    }
                    .padding(SpacingTokens.sp4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .fill(ColorTokens.Kid.surface)
                    )
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .accessibilityElement(children: .contain)
                }

                VStack(spacing: SpacingTokens.sp3) {
                    Button {
                        Task { await setupAndStart(forceRestart: true) }
                    } label: {
                        Text("retelling.summary.again")
                            .font(TypographyTokens.headline(17))
                            .foregroundStyle(ColorTokens.Overlay.onAccent)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(
                                RoundedRectangle(cornerRadius: RadiusTokens.card)
                                    .fill(ColorTokens.Brand.primary)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("retelling.summary.again.hint"))

                    Button {
                        dismiss()
                    } label: {
                        Text("retelling.summary.done")
                            .font(TypographyTokens.body(16).weight(.medium))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp6)
            }
        }
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ProgressView()
                .controlSize(.large)
            Text("retelling.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Wiring

    private func setupAndStart(forceRestart: Bool = false) async {
        if interactor == nil {
            let presenter = RetellingPresenter(displayLogic: holder)
            let worker = RetellingWorker(childRepository: container.childRepository)
            let interactor = RetellingInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = RetellingRouter(dismissAction: { dismiss() })
        }
        _ = forceRestart
        holder.phase = .loading
        await interactor?.start(request: .init(childId: childId))
    }

    private func toggle(frameId: String) async {
        await interactor?.toggleLink(request: .init(frameId: frameId))
    }

    private func finish() async {
        await interactor?.finish(request: .init(voiceRecorded: true))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Retelling / listen") {
    RetellingView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
