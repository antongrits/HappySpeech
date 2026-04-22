import SwiftUI

// MARK: - BreathingView

struct BreathingView: View {

    var body: some View {
        Text("Breathing")
            .font(TypographyTokens.title())
            .foregroundStyle(ColorTokens.Kid.ink)
    }
}

#Preview {
    BreathingView()
}
