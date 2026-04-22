import SwiftUI

// MARK: - WorldMapView

/// Visual world map — child sees their speech journey as a path through stages.
struct WorldMapView: View {
    @Environment(AppContainer.self) private var container
    let childId: String
    let targetSound: String
    @State private var currentStageIndex: Int = 2
    @State private var appeared: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                mapBackground
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(CorrectionStage.allCases.enumerated()), id: \.offset) { idx, stage in
                            WorldMapNode(
                                stage: stage,
                                stageIndex: idx,
                                currentIndex: currentStageIndex,
                                sound: targetSound
                            )
                            .offset(x: idx % 2 == 0 ? -40 : 40)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(MotionTokens.page.delay(Double(idx) * 0.05), value: appeared)
                        }
                    }
                    .padding(.vertical, SpacingTokens.xLarge)
                }
            }
            .navigationTitle("Карта звука \(targetSound)")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { appeared = true }
    }

    private var mapBackground: some View {
        LinearGradient(
            colors: [ColorTokens.Brand.primary.opacity(0.05), ColorTokens.Kid.bg],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - WorldMapNode

struct WorldMapNode: View {
    let stage: CorrectionStage
    let stageIndex: Int
    let currentIndex: Int
    let sound: String

    private var status: NodeStatus {
        if stageIndex < currentIndex { return .completed }
        if stageIndex == currentIndex { return .current }
        return .locked
    }

    var body: some View {
        HStack {
            if stageIndex % 2 != 0 { Spacer() }
            VStack(spacing: SpacingTokens.tiny) {
                ZStack {
                    Circle()
                        .fill(status.backgroundColor)
                        .frame(width: 64, height: 64)
                        .overlay(Circle().stroke(status.borderColor, lineWidth: 2))
                    Image(systemName: status.icon)
                        .font(.title2)
                        .foregroundStyle(status.iconColor)
                }
                Text(stage.displayName)
                    .font(TypographyTokens.caption())
                    .foregroundStyle(status == .locked ? .secondary : .primary)
                    .bold(status == .current)
            }
            if stageIndex % 2 == 0 { Spacer() }
        }
        .padding(.horizontal, SpacingTokens.xLarge)
        .padding(.vertical, SpacingTokens.small)
    }
}

// MARK: - NodeStatus

enum NodeStatus {
    case completed, current, locked

    var backgroundColor: Color {
        switch self {
        case .completed: return .green.opacity(0.2)
        case .current:   return ColorTokens.Brand.primary.opacity(0.2)
        case .locked:    return Color(.systemFill)
        }
    }

    var borderColor: Color {
        switch self {
        case .completed: return .green
        case .current:   return ColorTokens.Brand.primary
        case .locked:    return .secondary.opacity(0.3)
        }
    }

    var icon: String {
        switch self {
        case .completed: return "checkmark"
        case .current:   return "play.fill"
        case .locked:    return "lock.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .completed: return .green
        case .current:   return ColorTokens.Brand.primary
        case .locked:    return .secondary
        }
    }
}
