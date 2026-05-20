import OSLog
import SwiftUI

// MARK: - BilingualPracticeView
//
// Под-экран тренировки. Открывается из `BilingualModeView` как sheet.
// Логика:
//   - 10 раундов (берёт из `holder.practiceStartVM.rounds`);
//   - на каждом — русское слово + 3 опции на втором языке;
//   - tap → отправляем в Interactor → подсветка правильного / неправильного;
//   - через 0.8 сек переходим к следующему раунду;
//   - после последнего — finishPractice → result-карточка.

struct BilingualPracticeView: View {

    let interactor: BilingualModeInteractor
    let ttsWorker: BilingualTTSWorker
    let language: BilingualSecondLanguage
    @Bindable var holder: BilingualModeViewModelHolder
    let onClose: () -> Void

    @State private var roundIndex: Int = 0
    @State private var lastAnswerCorrect: Bool?
    @State private var lastSelectedOptionId: String?
    @State private var correctOptionIdForHighlight: String?
    @State private var isFinished: Bool = false
    @State private var isLocked: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "BilingualMode.Practice"
    )

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                VStack(spacing: SpacingTokens.sp3) {
                    if isFinished, let finish = holder.finishVM {
                        resultSection(finish)
                    } else if let rounds = holder.practiceStartVM?.rounds,
                              roundIndex < rounds.count {
                        let round = rounds[roundIndex]
                        progressBar(current: roundIndex, total: rounds.count)
                        roundCard(round, total: rounds.count)
                        optionsList(round)
                    } else {
                        ProgressView()
                    }
                }
                .padding(SpacingTokens.screenEdge)
            }
            .navigationTitle(Text("Угадай перевод"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Progress

    private func progressBar(current: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
            HStack {
                Text("Раунд \(current + 1) из \(total)")
                    .font(TypographyTokens.caption(13).monospacedDigit())
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                Spacer()
                Text(language.displayName)
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Brand.lilac)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(ColorTokens.Kid.surfaceAlt)
                    Capsule()
                        .fill(ColorTokens.Brand.lilac)
                        .frame(width: proxy.size.width * progress(current: current, total: total))
                }
            }
            .frame(height: 8)
            .accessibilityLabel(Text("Прогресс тренировки"))
            .accessibilityValue(Text("Раунд \(current + 1) из \(total)"))
        }
    }

    private func progress(current: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }

    // MARK: - Round card

    private func roundCard(_ round: BilingualPracticeRound, total: Int) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            Image(systemName: round.word.symbol)
                .font(.system(size: 72))
                .foregroundStyle(ColorTokens.Brand.lilac)
                .accessibilityHidden(true)
            Text(round.word.russian)
                .font(TypographyTokens.title(32))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text("Как это будет на \(language.displayName.lowercased())?")
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(SpacingTokens.sp4)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Kid.surface)
        )
    }

    // MARK: - Options

    private func optionsList(_ round: BilingualPracticeRound) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            ForEach(round.options) { option in
                optionButton(round: round, option: option)
            }
        }
    }

    private func optionButton(
        round: BilingualPracticeRound,
        option: BilingualPracticeOption
    ) -> some View {
        let style = optionStyle(for: option, round: round)
        return Button {
            Task { await tapOption(option: option, round: round) }
        } label: {
            HStack {
                Text(option.translation)
                    .font(TypographyTokens.headline(18))
                    .foregroundStyle(style.foreground)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Spacer()
                if let iconName = style.icon {
                    Image(systemName: iconName)
                        .foregroundStyle(style.foreground)
                        .accessibilityHidden(true)
                }
            }
            .padding(SpacingTokens.sp3)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(style.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .strokeBorder(style.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .accessibilityLabel(Text(option.translation))
        .accessibilityHint(Text("Нажми, чтобы выбрать этот вариант"))
        .scaleEffect(isHighlighted(option) && !reduceMotion ? 1.02 : 1.0)
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.15), value: lastSelectedOptionId)
    }

    private struct OptionStyle {
        let background: Color
        let border: Color
        let foreground: Color
        let icon: String?
    }

    private func optionStyle(
        for option: BilingualPracticeOption,
        round: BilingualPracticeRound
    ) -> OptionStyle {
        if let correctId = correctOptionIdForHighlight, option.id == correctId {
            return OptionStyle(
                background: ColorTokens.Semantic.successBg,
                border: ColorTokens.Semantic.success,
                foreground: ColorTokens.Semantic.success,
                icon: "checkmark.circle.fill"
            )
        }
        if let selected = lastSelectedOptionId,
           option.id == selected,
           lastAnswerCorrect == false {
            return OptionStyle(
                background: ColorTokens.Semantic.errorBg,
                border: ColorTokens.Semantic.error,
                foreground: ColorTokens.Semantic.error,
                icon: "xmark.circle.fill"
            )
        }
        return OptionStyle(
            background: ColorTokens.Kid.surface,
            border: ColorTokens.Kid.line,
            foreground: ColorTokens.Kid.ink,
            icon: nil
        )
    }

    private func isHighlighted(_ option: BilingualPracticeOption) -> Bool {
        option.id == lastSelectedOptionId
    }

    // MARK: - Result

    private func resultSection(
        _ finish: BilingualModeModels.FinishPractice.ViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp3) {
            Spacer()
            Image(systemName: finish.stars >= 2 ? "star.fill" : "sparkles")
                .font(.system(size: 64))
                .foregroundStyle(ColorTokens.Brand.gold)
                .accessibilityHidden(true)
            Text(finish.title)
                .font(TypographyTokens.title(28))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
            HStack(spacing: SpacingTokens.sp1) {
                ForEach(0..<3, id: \.self) { idx in
                    Image(systemName: idx < finish.stars ? "star.fill" : "star")
                        .font(.system(size: 36))
                        .foregroundStyle(idx < finish.stars
                                         ? ColorTokens.Brand.gold
                                         : ColorTokens.Kid.inkSoft)
                }
            }
            .accessibilityLabel(Text("\(finish.stars) из 3 звёзд"))
            Text(finish.body)
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, SpacingTokens.sp3)
            Spacer()
            HStack(spacing: SpacingTokens.sp2) {
                Button {
                    Task { await restartPractice() }
                } label: {
                    Text("Ещё раз")
                        .font(TypographyTokens.headline(16))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(ColorTokens.Kid.surfaceAlt)
                        )
                        .foregroundStyle(ColorTokens.Kid.ink)
                }
                .buttonStyle(.plain)
                Button {
                    onClose()
                } label: {
                    Text("Готово")
                        .font(TypographyTokens.headline(16))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(ColorTokens.Brand.lilac)
                        )
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(SpacingTokens.sp3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(finish.accessibilityLabel))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
            }
            .accessibilityLabel(Text("Закрыть"))
        }
    }

    // MARK: - Actions

    private func tapOption(
        option: BilingualPracticeOption,
        round: BilingualPracticeRound
    ) async {
        guard !isLocked else { return }
        isLocked = true
        lastSelectedOptionId = option.id
        correctOptionIdForHighlight = round.correctOptionId

        let isCorrect = await interactor.submitAnswer(
            roundIndex: roundIndex,
            selectedOptionId: option.id
        )
        lastAnswerCorrect = isCorrect

        // Озвучиваем правильный перевод (даёт ребёнку модель произношения).
        let correctText = round.options.first { $0.id == round.correctOptionId }?.translation
            ?? round.word.russian
        await ttsWorker.speak(correctText, language: language)

        try? await Task.sleep(nanoseconds: 800_000_000)
        await advanceRound()
    }

    private func advanceRound() async {
        let total = holder.practiceStartVM?.rounds.count ?? 0
        lastSelectedOptionId = nil
        correctOptionIdForHighlight = nil
        lastAnswerCorrect = nil
        isLocked = false

        if roundIndex + 1 >= total {
            await interactor.finishPractice()
            isFinished = true
        } else {
            roundIndex += 1
        }
    }

    private func restartPractice() async {
        roundIndex = 0
        isFinished = false
        lastAnswerCorrect = nil
        lastSelectedOptionId = nil
        correctOptionIdForHighlight = nil
        isLocked = false
        await interactor.startPractice()
    }
}
