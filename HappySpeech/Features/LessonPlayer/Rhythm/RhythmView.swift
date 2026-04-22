import SwiftUI

// MARK: - RhythmView

struct RhythmView: View {

    var body: some View {
        Text("Rhythm")
            .font(TypographyTokens.title())
            .foregroundStyle(ColorTokens.Kid.ink)
    }
}

#Preview {
    RhythmView()
}
