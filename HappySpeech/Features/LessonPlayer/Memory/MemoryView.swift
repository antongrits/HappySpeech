import SwiftUI

// MARK: - MemoryView

struct MemoryView: View {

    var body: some View {
        Text("Memory")
            .font(TypographyTokens.title())
            .foregroundStyle(ColorTokens.Kid.ink)
    }
}

#Preview {
    MemoryView()
}
