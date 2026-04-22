import SwiftUI

// MARK: - BingoView

struct BingoView: View {

    var body: some View {
        Text("Bingo")
            .font(TypographyTokens.title())
            .foregroundStyle(ColorTokens.Kid.ink)
    }
}

#Preview {
    BingoView()
}
