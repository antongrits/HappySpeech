import SwiftUI

// MARK: - HSProgressRing

public struct HSProgressRing: View {
    let value: Double       // 0.0 – 1.0
    let size: CGFloat
    let lineWidth: CGFloat
    var color: Color = ColorTokens.Brand.primary
    var backgroundColor: Color = Color(.systemFill)
    var label: String? = nil

    public init(value: Double, size: CGFloat = 80, lineWidth: CGFloat = 8, color: Color = ColorTokens.Brand.primary, label: String? = nil) {
        self.value = value
        self.size = size
        self.lineWidth = lineWidth
        self.color = color
        self.label = label
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, value)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(MotionTokens.spring, value: value)
            if let label {
                Text(label)
                    .font(TypographyTokens.caption())
                    .bold()
                    .foregroundStyle(.primary)
            } else {
                Text("\(Int(value * 100))%")
                    .font(TypographyTokens.caption())
                    .bold()
            }
        }
        .frame(width: size, height: size)
    }
}
