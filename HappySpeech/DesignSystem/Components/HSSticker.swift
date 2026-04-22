import SwiftUI

// MARK: - HSSticker

/// Reward sticker component. Renders a named sticker or placeholder.
/// Locked stickers show grayscale overlay.
public struct HSSticker: View {

    public enum StickerType: String, CaseIterable {
        // Animals
        case butterfly = "butterfly"
        case bunny     = "bunny"
        case bear      = "bear"
        case fox       = "fox"
        case owl       = "owl"
        case penguin   = "penguin"
        // Stars & Rewards
        case goldStar  = "goldStar"
        case silverStar = "silverStar"
        case crown     = "crown"
        case trophy    = "trophy"
        case medal     = "medal"
        case rocket    = "rocket"
    }

    private let type: StickerType
    private let size: CGFloat
    private let isLocked: Bool
    private let isNew: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    public init(
        type: StickerType,
        size: CGFloat = 80,
        isLocked: Bool = false,
        isNew: Bool = false
    ) {
        self.type = type
        self.size = size
        self.isLocked = isLocked
        self.isNew = isNew
    }

    public var body: some View {
        ZStack {
            // Sticker background circle
            Circle()
                .fill(isLocked ? AnyShapeStyle(Color.secondary.opacity(0.15)) : AnyShapeStyle(stickerGradient))
                .frame(width: size, height: size)

            // Sticker content (SF Symbol as placeholder)
            Image(systemName: symbolName)
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.52, height: size * 0.52)
                .foregroundStyle(isLocked ? Color.secondary : stickerIconColor)

            // Lock overlay
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: size * 0.25))
                    .foregroundStyle(Color.secondary)
                    .offset(y: size * 0.18)
            }

            // "New" badge
            if isNew && !isLocked {
                Text(String(localized: "Новый!"))
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(ColorTokens.Brand.primary))
                    .offset(y: -(size / 2 + 8))
            }
        }
        .scaleEffect(appeared ? 1.0 : 0.3)
        .opacity(appeared ? 1.0 : 0.0)
        .onAppear {
            if !reduceMotion {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.55).delay(0.05)) {
                    appeared = true
                }
            } else {
                appeared = true
            }
        }
        .accessibilityLabel("\(isLocked ? "Закрытая" : "") наклейка «\(type.displayName)»")
    }

    private var symbolName: String {
        switch type {
        case .butterfly:  return "butterfly.fill"
        case .bunny:      return "hare.fill"
        case .bear:       return "pawprint.fill"
        case .fox:        return "fox.fill"
        case .owl:        return "bird.fill"
        case .penguin:    return "bird.fill"
        case .goldStar:   return "star.fill"
        case .silverStar: return "star.fill"
        case .crown:      return "crown.fill"
        case .trophy:     return "trophy.fill"
        case .medal:      return "medal.fill"
        case .rocket:     return "rocket.fill"
        }
    }

    private var stickerGradient: LinearGradient {
        LinearGradient(
            colors: [stickerBaseColor.adjustingBrightness(by: 0.1), stickerBaseColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var stickerBaseColor: Color {
        switch type {
        case .butterfly:  return ColorTokens.Brand.primary.opacity(0.25)
        case .bunny:      return ColorTokens.Brand.rose.opacity(0.25)
        case .bear:       return ColorTokens.Brand.butter.opacity(0.35)
        case .fox:        return Color.orange.opacity(0.25)
        case .owl:        return ColorTokens.Brand.lilac.opacity(0.25)
        case .penguin:    return ColorTokens.Brand.sky.opacity(0.25)
        case .goldStar:   return ColorTokens.Brand.butter.opacity(0.4)
        case .silverStar: return Color.gray.opacity(0.2)
        case .crown:      return ColorTokens.Brand.butter.opacity(0.4)
        case .trophy:     return Color.orange.opacity(0.25)
        case .medal:      return ColorTokens.Brand.mint.opacity(0.3)
        case .rocket:     return ColorTokens.Brand.sky.opacity(0.25)
        }
    }

    private var stickerIconColor: Color {
        switch type {
        case .goldStar, .crown, .trophy: return Color(hex: "#E5A000")
        case .silverStar:                return Color(hex: "#8899AA")
        case .butterfly:                 return ColorTokens.Brand.primary
        default:                         return Color.secondary
        }
    }
}

extension HSSticker.StickerType {
    var displayName: String {
        switch self {
        case .butterfly:  return "бабочка"
        case .bunny:      return "зайчик"
        case .bear:       return "мишка"
        case .fox:        return "лисичка"
        case .owl:        return "совушка"
        case .penguin:    return "пингвинчик"
        case .goldStar:   return "золотая звезда"
        case .silverStar: return "серебряная звезда"
        case .crown:      return "корона"
        case .trophy:     return "кубок"
        case .medal:      return "медаль"
        case .rocket:     return "ракета"
        }
    }
}

// MARK: - Preview

#Preview("Stickers") {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
        ForEach(HSSticker.StickerType.allCases, id: \.rawValue) { type in
            HSSticker(type: type, size: 72, isNew: type == .goldStar)
        }
        HSSticker(type: .butterfly, size: 72, isLocked: true)
    }
    .padding()
}
