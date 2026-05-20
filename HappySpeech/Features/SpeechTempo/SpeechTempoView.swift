import OSLog
import SwiftUI

// MARK: - SpeechTempoViewModelHolder

@MainActor
@Observable
final class SpeechTempoViewModelHolder: SpeechTempoDisplayLogic {

    var startVM: SpeechTempoModels.Start.ViewModel?
    var currentRhyme: SpeechTempoModels.Start.RhymeViewModel?
    var lastRatingText: String?
    var lastRating: TempoRating?
    var summary: SpeechTempoModels.Finish.SummaryViewModel?
    var isFinished: Bool = false
    /// Сколько слогов уже отбито в текущей чистоговорке.
    var tappedSyllables: Int = 0

    func displayStart(viewModel: SpeechTempoModels.Start.ViewModel) async {
        self.startVM = viewModel
        self.currentRhyme = viewModel.firstRhyme
        self.isFinished = false
        self.summary = nil
        self.lastRatingText = nil
        self.lastRating = nil
        self.tappedSyllables = 0
    }

    func displayFinish(viewModel: SpeechTempoModels.Finish.ViewModel) async {
        self.isFinished = viewModel.isFinished
        self.summary = viewModel.summary
        self.tappedSyllables = 0
        if let next = viewModel.nextRhyme {
            // Новая чистоговорка — стираем оценку предыдущей, чтобы баннер
            // не висел на следующей.
            self.currentRhyme = next
            self.lastRatingText = nil
            self.lastRating = nil
        } else {
            self.lastRatingText = viewModel.ratingText
            self.lastRating = viewModel.rating
        }
    }
}

// MARK: - SpeechTempoView (Clean Swift: View)
//
// v29 Фаза 8, Функция 6 «Темп-дорожка».
//
// Ребёнок «ведёт машинку Ляли»: проговаривает чистоговорку послогово и
// отбивает каждый слог большой кнопкой. Машинка едет по дорожке. По
// завершении — качественная оценка ровности темпа (без чисел и таймеров).
//
// Accessibility:
//   • Kid circuit: кнопка-«газ» крупная (≥ 56pt, фактически ~160pt)
//   • VoiceOver: чистоговорка и кнопка — описательные labels
//   • Dynamic Type: VStack + minimumScaleFactor
//   • Reduced Motion: движение машинки гейтится reduceMotion
//   • Light + Dark: ColorTokens.Kid адаптируются

struct SpeechTempoView: View {

    let childId: String

    @State private var holder = SpeechTempoViewModelHolder()
    @State private var interactor: SpeechTempoInteractor?
    @State private var presenter: SpeechTempoPresenter?
    @State private var router: SpeechTempoRouter?
    @State private var attemptStart: Date?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpeechTempo.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()

                if holder.isFinished, let summary = holder.summary {
                    summarySection(summary)
                } else if let startVM = holder.startVM,
                          let rhyme = holder.currentRhyme {
                    gameSection(startVM: startVM, rhyme: rhyme)
                } else {
                    loadingSection
                }
            }
            .navigationTitle(Text("speechTempo.title"))
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
                    .accessibilityLabel(Text("speechTempo.close.a11y"))
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
        startVM: SpeechTempoModels.Start.ViewModel,
        rhyme: SpeechTempoModels.Start.RhymeViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp5) {
            VStack(spacing: SpacingTokens.sp2) {
                Text(rhyme.progressLabel)
                    .font(TypographyTokens.caption(12).monospacedDigit())
                    .foregroundStyle(ColorTokens.Kid.inkMuted)

                Text(startVM.instruction)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp4)

            // Road with the car
            roadView(rhyme: rhyme)

            // Rhyme syllables
            rhymeCard(rhyme)
                .id(rhyme.id)
                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))

            if let ratingText = holder.lastRatingText, let rating = holder.lastRating {
                ratingBanner(text: ratingText, rating: rating)
            }

            Spacer()

            // Drive (beat) button + finish
            VStack(spacing: SpacingTokens.sp3) {
                driveButton(rhyme: rhyme)

                Button {
                    Task { await finishRhyme() }
                } label: {
                    Text("speechTempo.finish")
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .strokeBorder(ColorTokens.Brand.primary, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
                .disabled(holder.tappedSyllables == 0)
                .opacity(holder.tappedSyllables == 0 ? 0.5 : 1)
                .accessibilityHint(Text("speechTempo.finish.hint"))
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp6)
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: rhyme.id)
    }

    private func roadView(rhyme: SpeechTempoModels.Start.RhymeViewModel) -> some View {
        let total = max(rhyme.syllables.count, 1)
        let fraction = min(1, Double(holder.tappedSyllables) / Double(total))
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(ColorTokens.Kid.surfaceAlt)
                Image(systemName: "car.side.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(ColorTokens.Brand.rose)
                    .offset(x: max(0, (geo.size.width - 44) * fraction))
                    .animation(
                        reduceMotion ? nil : .spring(duration: 0.3),
                        value: holder.tappedSyllables
                    )
            }
        }
        .frame(height: 48)
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityLabel(Text("speechTempo.road.a11y"))
    }

    private func rhymeCard(_ rhyme: SpeechTempoModels.Start.RhymeViewModel) -> some View {
        Text(rhyme.text)
            .font(TypographyTokens.title(28))
            .foregroundStyle(ColorTokens.Kid.ink)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, SpacingTokens.sp5)
            .padding(.vertical, SpacingTokens.sp5)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .strokeBorder(ColorTokens.Kid.line, lineWidth: 2)
            )
            .depthShadow(ShadowTokens.kidDepth)
            .padding(.horizontal, SpacingTokens.screenEdge)
            .accessibilityLabel(Text(rhyme.accessibilityLabel))
            .accessibilityAddTraits(.isStaticText)
    }

    private func driveButton(rhyme: SpeechTempoModels.Start.RhymeViewModel) -> some View {
        let done = holder.tappedSyllables
        let total = rhyme.syllables.count
        let label = done < total
            ? rhyme.syllables[done]
            : String(localized: "speechTempo.drive.ready")
        return Button {
            Task { await recordBeat() }
        } label: {
            VStack(spacing: SpacingTokens.sp1) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 32))
                Text(label)
                    .font(TypographyTokens.title(26))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .frame(maxWidth: .infinity, minHeight: 110)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Brand.rose)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("speechTempo.drive.a11y"))
        .accessibilityHint(Text("speechTempo.drive.hint"))
        .accessibilityValue(Text(label))
    }

    private func ratingBanner(text: String, rating: TempoRating) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            Image(systemName: rating == .smooth
                ? "checkmark.circle.fill"
                : "arrow.triangle.2.circlepath")
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
            Capsule().fill(rating == .smooth
                ? ColorTokens.Brand.mint
                : ColorTokens.Brand.butter)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(text))
    }

    // MARK: - Summary

    private func summarySection(
        _ summary: SpeechTempoModels.Finish.SummaryViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp5) {
            Spacer()

            Image(systemName: "flag.checkered.2.crossed")
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
                    Text("speechTempo.summary.again")
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(ColorTokens.Brand.primary)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("speechTempo.summary.again.hint"))

                Button {
                    dismiss()
                } label: {
                    Text("speechTempo.summary.done")
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
            Text("speechTempo.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Wiring

    private func setupAndStart(forceRestart: Bool = false) async {
        if interactor == nil {
            let presenter = SpeechTempoPresenter(displayLogic: holder)
            let worker = SpeechTempoWorker(childRepository: container.childRepository)
            let interactor = SpeechTempoInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = SpeechTempoRouter(dismissAction: { dismiss() })
        }
        _ = forceRestart
        attemptStart = nil
        await interactor?.start(request: .init(childId: childId))
    }

    private func recordBeat() async {
        let now = Date()
        if attemptStart == nil { attemptStart = now }
        let elapsed = now.timeIntervalSince(attemptStart ?? now)
        holder.tappedSyllables += 1
        await interactor?.recordBeat(request: .init(timestamp: elapsed))
    }

    private func finishRhyme() async {
        attemptStart = nil
        await interactor?.finishRhyme(request: .init())
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SpeechTempo / game") {
    SpeechTempoView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
