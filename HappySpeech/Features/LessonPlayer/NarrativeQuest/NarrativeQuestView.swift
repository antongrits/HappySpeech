import SwiftUI

// MARK: - NarrativeQuestView

struct NarrativeQuestView: View {

    var body: some View {
        Text("NarrativeQuest")
            .font(TypographyTokens.title())
            .foregroundStyle(ColorTokens.Kid.ink)
    }
}

#Preview {
    NarrativeQuestView()
}
