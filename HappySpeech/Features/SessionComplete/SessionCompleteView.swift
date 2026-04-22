import SwiftUI

// MARK: - SessionCompleteView

struct SessionCompleteView: View {
    let result: SessionResult
    let onContinue: () -> Void
    let onReplay: () -> Void

    @State private var appeared: Bool = false

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()

            VStack(spacing: SpacingTokens.xLarge) {
                Spacer()
                successAnimation
                scoreSection
                wordBreakdown
                Spacer()
                actionButtons
            }
            .padding(SpacingTokens.large)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 40)
        }
        .onAppear {
            withAnimation(MotionTokens.page.delay(0.1)) { appeared = true }
        }
        .navigationBarBackButtonHidden()
    }

    private var successAnimation: some View {
        ZStack {
            Circle()
                .fill(scoreColor.opacity(0.15))
                .frame(width: 140, height: 140)
            Image(systemName: scoreIcon)
                .font(.system(size: 64))
                .foregroundStyle(scoreColor)
        }
    }

    private var scoreSection: some View {
        VStack(spacing: SpacingTokens.small) {
            Text("Занятие завершено!")
                .font(TypographyTokens.title())
                .bold()
            Text("\(Int(result.successRate * 100))% правильно")
                .font(TypographyTokens.headline())
                .foregroundStyle(scoreColor)
            Text("\(result.attemptCount) слов за \(result.durationSec / 60) мин")
                .font(TypographyTokens.body())
                .foregroundStyle(.secondary)
        }
    }

    private var wordBreakdown: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Text("Результаты по словам")
                .font(TypographyTokens.headline())
                .padding(.bottom, SpacingTokens.tiny)
            ForEach(result.wordResults, id: \.word) { item in
                HStack {
                    Image(systemName: item.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(item.isCorrect ? .green : .red)
                    Text(item.word)
                        .font(TypographyTokens.body())
                    Spacer()
                    Text("\(Int(item.score * 100))%")
                        .font(TypographyTokens.caption())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(SpacingTokens.medium)
        .hsCard()
    }

    private var actionButtons: some View {
        VStack(spacing: SpacingTokens.medium) {
            HSButton("Продолжить", style: .primary) { onContinue() }
            HSButton("Повторить", style: .secondary) { onReplay() }
        }
    }

    private var scoreColor: Color {
        switch result.successRate {
        case 0.8...:    return .green
        case 0.5..<0.8: return .orange
        default:        return .red
        }
    }

    private var scoreIcon: String {
        switch result.successRate {
        case 0.8...:    return "star.fill"
        case 0.5..<0.8: return "hand.thumbsup.fill"
        default:        return "heart.fill"
        }
    }
}

// MARK: - SessionResult

struct SessionResult {
    let successRate: Double
    let attemptCount: Int
    let durationSec: Int
    let targetSound: String
    let wordResults: [WordResult]

    struct WordResult {
        let word: String
        let isCorrect: Bool
        let score: Double
    }

    static let sample = SessionResult(
        successRate: 0.75,
        attemptCount: 12,
        durationSec: 540,
        targetSound: "Р",
        wordResults: [
            WordResult(word: "рыба", isCorrect: true, score: 0.92),
            WordResult(word: "рука", isCorrect: true, score: 0.85),
            WordResult(word: "дерево", isCorrect: false, score: 0.41),
        ]
    )
}

// MARK: - Preview

#Preview("Session Complete") {
    SessionCompleteView(
        result: .sample,
        onContinue: {},
        onReplay: {}
    )
}
