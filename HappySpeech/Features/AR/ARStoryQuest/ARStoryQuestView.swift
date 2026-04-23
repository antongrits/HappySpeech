import SwiftUI

// MARK: - ARStoryQuestView
//
// Minimal-playable stub for the "AR Story Quest" game — a narrative where
// Lyalya tells a mini-story and asks the child to pronounce a target word
// at each decision point. Full VIP stack will land in M6 deepening; this
// stub keeps the ARZone switch exhaustive and compilation green.

struct ARStoryQuestView: View {

    @State private var step: Int = 0
    private let steps = [
        String(localized: "Жила-была Рыбка. Она плыла в реке. Скажи «Рыба»!"),
        String(localized: "Рыбка встретила Крабика. Скажи «Крабик»!"),
        String(localized: "Они построили дом. Скажи «Дом»!"),
        String(localized: "И жили они долго и счастливо!"),
    ]

    var body: some View {
        VStack(spacing: SpacingTokens.large) {
            Text(String(localized: "AR История"))
                .font(TypographyTokens.title())
                .foregroundStyle(ColorTokens.Kid.ink)

            Text(steps[min(step, steps.count - 1)])
                .font(TypographyTokens.body(18))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.screenEdge)
                .frame(maxWidth: .infinity, alignment: .center)

            HSButton(
                step < steps.count - 1
                 ? String(localized: "Дальше")
                 : String(localized: "Ещё раз"),
                style: .primary
            ) {
                if step < steps.count - 1 { step += 1 } else { step = 0 }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .padding(.vertical, SpacingTokens.xxLarge)
        .accessibilityElement(children: .contain)
    }
}

#Preview { ARStoryQuestView() }
