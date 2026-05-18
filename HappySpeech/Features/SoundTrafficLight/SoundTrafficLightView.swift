import OSLog
import SwiftUI

// MARK: - SoundTrafficLightViewModelHolder

@MainActor
@Observable
final class SoundTrafficLightViewModelHolder: SoundTrafficLightDisplayLogic {

    var startVM: SoundTrafficLightModels.Start.ViewModel?
    var currentRound: SoundTrafficLightModels.Start.RoundViewModel?
    var lastFeedback: String?
    var lastWasCorrect: Bool?
    var summary: SoundTrafficLightModels.Sort.SummaryViewModel?
    var isFinished: Bool = false

    func displayStart(viewModel: SoundTrafficLightModels.Start.ViewModel) async {
        self.startVM = viewModel
        self.currentRound = viewModel.firstRound
        self.isFinished = false
        self.summary = nil
        self.lastFeedback = nil
        self.lastWasCorrect = nil
    }

    func displaySort(viewModel: SoundTrafficLightModels.Sort.ViewModel) async {
        self.isFinished = viewModel.isFinished
        self.summary = viewModel.summary
        if let next = viewModel.nextRound {
            // Новый раунд — стираем обратную связь предыдущего, чтобы
            // баннер не оставался висеть на следующем слове.
            self.currentRound = next
            self.lastFeedback = nil
            self.lastWasCorrect = nil
        } else {
            self.lastFeedback = viewModel.feedbackText
            self.lastWasCorrect = viewModel.wasCorrect
        }
    }
}

// MARK: - SoundTrafficLightView (Clean Swift: View)
//
// v29 Фаза 8, Функция 5 «Звуковой светофор».
//
// Детская игра дифференциации: ребёнок слышит/видит слово и отправляет его
// в один из двух «гаражей» по целевому звуку. По завершении — сводка.
//
// Accessibility:
//   • Kid circuit: touch targets гаражей ≥ 56pt (фактически крупные карточки)
//   • VoiceOver: раунд и гаражи — описательные labels
//   • Dynamic Type: VStack + minimumScaleFactor
//   • Reduced Motion: анимация смены слова гейтится reduceMotion
//   • Light + Dark: ColorTokens.Kid адаптируются

struct SoundTrafficLightView: View {

    let childId: String

    @State private var holder = SoundTrafficLightViewModelHolder()
    @State private var interactor: SoundTrafficLightInteractor?
    @State private var presenter: SoundTrafficLightPresenter?
    @State private var router: SoundTrafficLightRouter?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundTrafficLight.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()

                if holder.isFinished, let summary = holder.summary {
                    summarySection(summary)
                } else if let startVM = holder.startVM,
                          let round = holder.currentRound {
                    gameSection(startVM: startVM, round: round)
                } else {
                    loadingSection
                }
            }
            .navigationTitle(Text("soundTrafficLight.title"))
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
                    .accessibilityLabel(Text("soundTrafficLight.close.a11y"))
                }
            }
            .task {
                await setupAndStart()
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Game

    private func gameSection(
        startVM: SoundTrafficLightModels.Start.ViewModel,
        round: SoundTrafficLightModels.Start.RoundViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp5) {
            // Progress + instruction
            VStack(spacing: SpacingTokens.sp2) {
                Text(round.progressLabel)
                    .font(TypographyTokens.caption(12).monospacedDigit())
                    .foregroundStyle(ColorTokens.Kid.inkMuted)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(ColorTokens.Kid.surfaceAlt)
                        Capsule()
                            .fill(ColorTokens.Brand.primary)
                            .frame(width: max(0, geo.size.width * round.progressFraction))
                    }
                }
                .frame(height: 10)
                .accessibilityHidden(true)

                Text(startVM.instruction)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp4)

            Spacer()

            // Word card
            wordCard(round.word)
                .id(round.id)
                .transition(reduceMotion
                    ? .opacity
                    : .scale.combined(with: .opacity))

            // Feedback
            if let feedback = holder.lastFeedback,
               let wasCorrect = holder.lastWasCorrect {
                feedbackBanner(text: feedback, isCorrect: wasCorrect)
            }

            Spacer()

            // Two garages
            HStack(spacing: SpacingTokens.sp3) {
                garageButton(
                    label: startVM.garageALabel,
                    tint: ColorTokens.Brand.sky,
                    symbol: "car.fill"
                ) {
                    Task { await sort(pickedGarageA: true) }
                }
                garageButton(
                    label: startVM.garageBLabel,
                    tint: ColorTokens.Brand.mint,
                    symbol: "car.fill"
                ) {
                    Task { await sort(pickedGarageA: false) }
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp6)
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: round.id)
    }

    private func wordCard(_ word: String) -> some View {
        Text(word)
            .font(TypographyTokens.title(40))
            .foregroundStyle(ColorTokens.Kid.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, SpacingTokens.sp6)
            .padding(.vertical, SpacingTokens.sp8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .strokeBorder(ColorTokens.Kid.line, lineWidth: 2)
            )
            .padding(.horizontal, SpacingTokens.screenEdge)
            .accessibilityLabel(Text(verbatim: word))
            .accessibilityAddTraits(.isStaticText)
    }

    private func garageButton(
        label: String,
        tint: Color,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: SpacingTokens.sp2) {
                Image(systemName: symbol)
                    .font(.system(size: 34))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                Text(label)
                    .font(TypographyTokens.headline(18))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .padding(SpacingTokens.sp4)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(tint)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityHint(Text("soundTrafficLight.garage.hint"))
        .accessibilityAddTraits(.isButton)
    }

    private func feedbackBanner(text: String, isCorrect: Bool) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill")
                .font(.title3)
            Text(text)
                .font(TypographyTokens.body(15).weight(.medium))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(ColorTokens.Overlay.onAccent)
        .padding(.horizontal, SpacingTokens.sp4)
        .padding(.vertical, SpacingTokens.sp2)
        .background(
            Capsule().fill(isCorrect ? ColorTokens.Brand.mint : ColorTokens.Brand.butter)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(text))
    }

    // MARK: - Summary

    private func summarySection(
        _ summary: SoundTrafficLightModels.Sort.SummaryViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp5) {
            Spacer()

            Image(systemName: summary.accuracyFraction >= 0.8
                ? "star.circle.fill"
                : "hand.thumbsup.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(ColorTokens.Brand.butter)
                .accessibilityHidden(true)

            Text(summary.title)
                .font(TypographyTokens.title(26))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(summary.scoreText)
                .font(TypographyTokens.headline(20).monospacedDigit())
                .foregroundStyle(ColorTokens.Brand.primary)

            Text(summary.encouragement)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .padding(.horizontal, SpacingTokens.sp6)

            Spacer()

            VStack(spacing: SpacingTokens.sp3) {
                Button {
                    Task { await setupAndStart(forceRestart: true) }
                } label: {
                    Text("soundTrafficLight.summary.again")
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(ColorTokens.Brand.primary)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("soundTrafficLight.summary.again.hint"))

                Button {
                    dismiss()
                } label: {
                    Text("soundTrafficLight.summary.done")
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
            Text("soundTrafficLight.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Wiring

    private func setupAndStart(forceRestart: Bool = false) async {
        if interactor == nil {
            let presenter = SoundTrafficLightPresenter(displayLogic: holder)
            let worker = SoundTrafficLightWorker(childRepository: container.childRepository)
            let interactor = SoundTrafficLightInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = SoundTrafficLightRouter(dismissAction: { dismiss() })
        }
        _ = forceRestart
        await interactor?.start(request: .init(childId: childId))
    }

    private func sort(pickedGarageA: Bool) async {
        await interactor?.sort(request: .init(pickedGarageA: pickedGarageA))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SoundTrafficLight / game") {
    SoundTrafficLightView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
