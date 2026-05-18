import OSLog
import SwiftUI

// MARK: - CoPlayViewModelHolder

@MainActor
@Observable
final class CoPlayViewModelHolder: CoPlayDisplayLogic {

    var startVM: CoPlayModels.Start.ViewModel?
    var currentTurn: CoPlayModels.Start.TurnViewModel?
    var summary: CoPlayModels.NextTurn.SummaryViewModel?
    var showBriefing: Bool = true
    var isFinished: Bool = false

    func displayStart(viewModel: CoPlayModels.Start.ViewModel) async {
        self.startVM = viewModel
        self.currentTurn = viewModel.firstTurn
        self.showBriefing = true
        self.isFinished = false
        self.summary = nil
    }

    func displayNextTurn(viewModel: CoPlayModels.NextTurn.ViewModel) async {
        self.isFinished = viewModel.isFinished
        self.summary = viewModel.summary
        if let next = viewModel.nextTurn {
            self.currentTurn = next
        }
    }
}

// MARK: - CoPlayView (Clean Swift: View)
//
// v29 Фаза 8, Функция 8 «Занятие вместе».
//
// Совместная игра ребёнка и взрослого на одном экране: ходы чередуются,
// активная роль подсвечена. Взрослому даются крупные родительские
// инструкции, ребёнку — игровые.
//
// Accessibility:
//   • Touch targets ≥ 56pt (детский контур)
//   • VoiceOver: роль и реплика — описательные labels
//   • Dynamic Type: minimumScaleFactor
//   • Reduced Motion: переходы ходов гейтятся reduceMotion
//   • Light + Dark: ColorTokens.Kid адаптируются

struct CoPlayView: View {

    let childId: String

    @State private var holder = CoPlayViewModelHolder()
    @State private var interactor: CoPlayInteractor?
    @State private var presenter: CoPlayPresenter?
    @State private var router: CoPlayRouter?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "CoPlay.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()

                if holder.isFinished, let summary = holder.summary {
                    summarySection(summary)
                } else if let start = holder.startVM {
                    if holder.showBriefing {
                        briefingSection(start)
                    } else if let turn = holder.currentTurn {
                        turnSection(turn)
                    } else {
                        loadingSection
                    }
                } else {
                    loadingSection
                }
            }
            .navigationTitle(Text("coPlay.title"))
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
                    .accessibilityLabel(Text("coPlay.close.a11y"))
                }
            }
            .task {
                await setupAndStart()
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Briefing

    private func briefingSection(
        _ start: CoPlayModels.Start.ViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp5) {
            Spacer()

            Image(systemName: start.symbolName)
                .font(.system(size: 76))
                .foregroundStyle(ColorTokens.Brand.lilac)
                .accessibilityHidden(true)

            Text(start.activityTitle)
                .font(TypographyTokens.title(25))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                Label {
                    Text("coPlay.briefing.title")
                        .font(TypographyTokens.headline(15))
                } icon: {
                    Image(systemName: "person.fill.questionmark")
                }
                .foregroundStyle(ColorTokens.Kid.ink)

                Text(start.adultBriefing)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(nil)
            }
            .padding(SpacingTokens.sp4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Kid.surface)
            )
            .padding(.horizontal, SpacingTokens.screenEdge)
            .accessibilityElement(children: .combine)

            Spacer()

            Button {
                holder.showBriefing = false
            } label: {
                Text("coPlay.briefing.start")
                    .font(TypographyTokens.headline(18))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .fill(ColorTokens.Brand.primary)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("coPlay.briefing.start.hint"))
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp6)
        }
    }

    // MARK: - Turn

    private func turnSection(
        _ turn: CoPlayModels.Start.TurnViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp5) {
            VStack(spacing: SpacingTokens.sp2) {
                Text(turn.progressLabel)
                    .font(TypographyTokens.caption(12).monospacedDigit())
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(ColorTokens.Kid.surfaceAlt)
                        Capsule()
                            .fill(ColorTokens.Brand.primary)
                            .frame(width: max(0, geo.size.width * turn.progressFraction))
                    }
                }
                .frame(height: 10)
                .accessibilityHidden(true)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp4)

            Spacer()

            // Роль-баннер
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: turn.role == .adult
                    ? "person.fill"
                    : "figure.child")
                    .font(.title2)
                Text(turn.roleLabel)
                    .font(TypographyTokens.headline(18))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .padding(.horizontal, SpacingTokens.sp5)
            .padding(.vertical, SpacingTokens.sp2)
            .background(
                Capsule().fill(turn.role == .adult
                    ? ColorTokens.Brand.sky
                    : ColorTokens.Brand.mint)
            )
            .accessibilityLabel(Text(turn.roleLabel))

            // Реплика-карточка
            VStack(spacing: SpacingTokens.sp3) {
                Text(turn.line)
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .minimumScaleFactor(0.6)

                Text(turn.instruction)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            .padding(SpacingTokens.sp6)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .strokeBorder(
                        turn.role == .adult
                            ? ColorTokens.Brand.sky
                            : ColorTokens.Brand.mint,
                        lineWidth: 3
                    )
            )
            .padding(.horizontal, SpacingTokens.screenEdge)
            .id(turn.id)
            .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(turn.accessibilityLabel))

            Spacer()

            Button {
                Task { await advance() }
            } label: {
                HStack(spacing: SpacingTokens.sp2) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("coPlay.turn.done")
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
            .accessibilityHint(Text("coPlay.turn.done.hint"))
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp6)
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: turn.id)
    }

    // MARK: - Summary

    private func summarySection(
        _ summary: CoPlayModels.NextTurn.SummaryViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp5) {
            Spacer()

            Image(systemName: "hands.and.sparkles.fill")
                .font(.system(size: 80))
                .foregroundStyle(ColorTokens.Brand.butter)
                .accessibilityHidden(true)

            Text(summary.title)
                .font(TypographyTokens.title(26))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(summary.turnsLabel)
                .font(TypographyTokens.headline(18).monospacedDigit())
                .foregroundStyle(ColorTokens.Brand.primary)

            Text(summary.adultTip)
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .padding(.horizontal, SpacingTokens.sp6)

            Spacer()

            VStack(spacing: SpacingTokens.sp3) {
                Button {
                    Task { await setupAndStart(forceRestart: true) }
                } label: {
                    Text("coPlay.summary.again")
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(ColorTokens.Brand.primary)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("coPlay.summary.again.hint"))

                Button {
                    dismiss()
                } label: {
                    Text("coPlay.summary.done")
                        .font(TypographyTokens.body(16).weight(.medium))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp6)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ProgressView()
                .controlSize(.large)
            Text("coPlay.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Wiring

    private func setupAndStart(forceRestart: Bool = false) async {
        if interactor == nil {
            let presenter = CoPlayPresenter(displayLogic: holder)
            let worker = CoPlayWorker(childRepository: container.childRepository)
            let interactor = CoPlayInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = CoPlayRouter(dismissAction: { dismiss() })
        }
        _ = forceRestart
        await interactor?.start(request: .init(childId: childId))
    }

    private func advance() async {
        await interactor?.nextTurn(request: .init(voiceConfirmed: true))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("CoPlay / briefing") {
    CoPlayView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
