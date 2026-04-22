import SwiftUI
import Lottie

// MARK: - RewardsView

struct RewardsView: View {
    @Environment(AppContainer.self) private var container
    let childId: String
    @State private var rewards: [RewardItem] = RewardItem.allRewards
    @State private var showingBurst: Bool = false
    @State private var burstReward: RewardItem?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.medium), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: SpacingTokens.medium) {
                    ForEach(rewards) { reward in
                        RewardCell(reward: reward)
                            .onTapGesture {
                                if reward.isEarned {
                                    burstReward = reward
                                    showingBurst = true
                                }
                            }
                    }
                }
                .padding(SpacingTokens.medium)
            }
            .navigationTitle("Мои награды")
            .overlay {
                if showingBurst, let reward = burstReward {
                    RewardBurstOverlay(reward: reward, onDismiss: {
                        showingBurst = false
                        burstReward = nil
                    })
                }
            }
        }
    }
}

// MARK: - RewardItem

struct RewardItem: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    var isEarned: Bool

    static let allRewards: [RewardItem] = [
        RewardItem(id: "star1", name: "Первый звук", icon: "star.fill", color: .yellow, isEarned: true),
        RewardItem(id: "streak3", name: "3 дня подряд", icon: "flame.fill", color: .orange, isEarned: true),
        RewardItem(id: "perfect", name: "Идеально!", icon: "checkmark.seal.fill", color: .green, isEarned: false),
        RewardItem(id: "explorer", name: "Исследователь", icon: "map.fill", color: .blue, isEarned: false),
        RewardItem(id: "speed", name: "Быстрый", icon: "bolt.fill", color: .purple, isEarned: true),
        RewardItem(id: "week", name: "Неделя", icon: "calendar", color: .teal, isEarned: false),
    ]
}

// MARK: - RewardCell

struct RewardCell: View {
    let reward: RewardItem

    var body: some View {
        VStack(spacing: SpacingTokens.small) {
            ZStack {
                Circle()
                    .fill(reward.isEarned ? reward.color.opacity(0.2) : Color(.systemFill))
                    .frame(width: 64, height: 64)
                Image(systemName: reward.icon)
                    .font(.title)
                    .foregroundStyle(reward.isEarned ? reward.color : .secondary)
                    .opacity(reward.isEarned ? 1.0 : 0.3)
            }
            Text(reward.name)
                .font(TypographyTokens.caption())
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(reward.isEarned ? .primary : .secondary)
        }
        .padding(SpacingTokens.small)
        .hsCard()
    }
}

// MARK: - RewardBurstOverlay

struct RewardBurstOverlay: View {
    let reward: RewardItem
    let onDismiss: () -> Void
    @State private var scale: CGFloat = 0.1
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: SpacingTokens.large) {
                ZStack {
                    ForEach(0..<8) { i in
                        Circle()
                            .fill(reward.color)
                            .frame(width: 12, height: 12)
                            .offset(x: cos(Double(i) * .pi / 4) * 80,
                                    y: sin(Double(i) * .pi / 4) * 80)
                            .opacity(opacity)
                    }
                    Circle()
                        .fill(reward.color.opacity(0.2))
                        .frame(width: 120, height: 120)
                    Image(systemName: reward.icon)
                        .font(.system(size: 56))
                        .foregroundStyle(reward.color)
                }

                Text(reward.name)
                    .font(TypographyTokens.title())
                    .bold()
                Text("Поздравляем!")
                    .font(TypographyTokens.body())
                    .foregroundStyle(.secondary)

                HSButton("Отлично!", style: .primary) { onDismiss() }
                    .padding(.horizontal, SpacingTokens.xLarge)
            }
            .padding(SpacingTokens.xLarge)
            .hsCard()
            .padding(SpacingTokens.xLarge)
            .scaleEffect(scale)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}
