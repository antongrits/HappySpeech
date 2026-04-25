import SwiftUI

// MARK: - AnimatedStoryPlayerView
//
// Полноэкранный плеер анимированной истории.
// Показывает 3 сцены последовательно с emoji-персонажами и SwiftUI-анимациями.
//
// Reduced Motion: все анимации сводятся к opacity-переходу.
// MotionTokens: все длительности и кривые берутся из MotionTokens.

@MainActor
struct AnimatedStoryPlayerView: View {

    // MARK: - API

    let story: AnimatedStory
    var onComplete: (() -> Void)?

    // MARK: - State

    @State private var currentSceneIndex: Int = 0
    @State private var characterOffset: CGFloat = 0
    @State private var characterScale: CGFloat = 1.0
    @State private var characterRotation: Double = 0
    @State private var characterOpacity: Double = 0
    @State private var sceneVisible: Bool = false
    @State private var buttonVisible: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Computed

    private var currentScene: AnimatedStoryScene {
        story.scenes[currentSceneIndex]
    }

    private var isLastScene: Bool {
        currentSceneIndex == story.scenes.count - 1
    }

    private var backgroundColors: [Color] {
        story.backgroundGradient.compactMap { Color(hex: $0) }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundLayer
            contentLayer
        }
        .ignoresSafeArea()
        .onAppear {
            showScene()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            String(localized: "story.player.accessibility_label \(story.title)")
        )
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        LinearGradient(
            colors: backgroundColors.isEmpty
                ? [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]
                : backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Content

    private var contentLayer: some View {
        VStack(spacing: 0) {
            progressDots
                .padding(.top, 56)
                .padding(.bottom, 12)

            backgroundEmojiRow

            Spacer(minLength: 16)

            characterView

            Spacer(minLength: 16)

            narrativeCard
                .padding(.horizontal, 20)

            Spacer(minLength: 24)

            actionButton
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
        }
    }

    // MARK: - Progress dots

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<story.scenes.count, id: \.self) { index in
                Circle()
                    .fill(index <= currentSceneIndex
                          ? Color.white
                          : Color.white.opacity(0.35))
                    .frame(width: index == currentSceneIndex ? 12 : 8,
                           height: index == currentSceneIndex ? 12 : 8)
                    .animation(
                        reduceMotion ? .none : MotionTokens.spring,
                        value: currentSceneIndex
                    )
            }
        }
        .accessibilityLabel(
            String(localized: "story.player.progress \(currentSceneIndex + 1) из \(story.scenes.count)")
        )
        .accessibilityHidden(true)
    }

    // MARK: - Emoji background row

    private var backgroundEmojiRow: some View {
        Text(currentScene.backgroundEmoji)
            .font(.system(size: 42))
            .opacity(sceneVisible ? 1 : 0)
            .animation(
                reduceMotion ? .none : MotionTokens.outQuick,
                value: sceneVisible
            )
    }

    // MARK: - Character

    private var characterView: some View {
        Text(currentScene.characterEmoji)
            .font(.system(size: 80))
            .scaleEffect(characterScale)
            .offset(x: characterOffset, y: 0)
            .rotationEffect(.degrees(characterRotation))
            .opacity(characterOpacity)
            .frame(height: 120)
            .accessibilityLabel(
                String(localized: "story.character.label \(currentScene.characterEmoji)")
            )
            .accessibilityHidden(true)
    }

    // MARK: - Narrative card

    private var narrativeCard: some View {
        VStack(spacing: 12) {
            narrativeText
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)

            HStack(spacing: 4) {
                Text(String(localized: "story.target_word.label"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))

                Text(currentScene.targetWord)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.25))
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.25))
        )
        .opacity(sceneVisible ? 1 : 0)
        .offset(y: sceneVisible ? 0 : 20)
        .animation(
            reduceMotion ? .none : MotionTokens.spring,
            value: sceneVisible
        )
    }

    // MARK: - Narrative text with bold targetWord

    private var narrativeText: some View {
        let text = currentScene.narrativeText
        let target = currentScene.targetWord

        if let range = text.range(of: target) {
            let before = String(text[text.startIndex..<range.lowerBound])
            let word = String(text[range])
            let after = String(text[range.upperBound...])

            return Text(before)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
            + Text(word)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            + Text(after)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
        } else {
            return Text(text)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
            + Text("")
            + Text("")
        }
    }

    // MARK: - Action button

    private var actionButton: some View {
        Button {
            handleButtonTap()
        } label: {
            HStack(spacing: 8) {
                Text(isLastScene
                     ? String(localized: "story.button.complete")
                     : String(localized: "story.button.next"))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Image(systemName: isLastScene ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.5), lineWidth: 1.5)
                    )
            )
        }
        .lineLimit(nil)
        .minimumScaleFactor(0.85)
        .scaleEffect(buttonVisible ? 1 : 0.88)
        .opacity(buttonVisible ? 1 : 0)
        .animation(
            reduceMotion ? .none : MotionTokens.bounce,
            value: buttonVisible
        )
        .accessibilityLabel(
            isLastScene
                ? String(localized: "story.button.complete.accessibility")
                : String(localized: "story.button.next.accessibility")
        )
    }

    // MARK: - Transitions

    private func showScene() {
        resetCharacter()
        sceneVisible = false
        buttonVisible = false
        characterOpacity = 0

        let entrance = reduceMotion ? Animation.linear(duration: MotionTokens.Duration.quick) : MotionTokens.spring
        withAnimation(entrance.delay(0.05)) {
            sceneVisible = true
            characterOpacity = 1
        }

        if !reduceMotion {
            playAnimation(for: currentScene.animationType)
        }

        withAnimation((reduceMotion ? Animation.linear(duration: 0.15) : MotionTokens.spring)
                        .delay(reduceMotion ? 0.1 : MotionTokens.Duration.moderate)) {
            buttonVisible = true
        }
    }

    private func handleButtonTap() {
        if isLastScene {
            onComplete?()
        } else {
            withAnimation(reduceMotion ? .none : MotionTokens.page) {
                currentSceneIndex += 1
            }
            DispatchQueue.main.asyncAfter(
                deadline: .now() + (reduceMotion ? 0 : MotionTokens.Duration.pageTransition)
            ) {
                showScene()
            }
        }
    }

    private func resetCharacter() {
        characterOffset = 0
        characterScale = 1.0
        characterRotation = 0
    }

    // MARK: - Animation dispatch

    private func playAnimation(for type: StoryAnimationType) {
        switch type {
        case .bounce:
            withAnimation(MotionTokens.bounce) {
                characterScale = 1.4
            }
            withAnimation(MotionTokens.bounce.delay(MotionTokens.Duration.standard)) {
                characterScale = 1.0
            }

        case .slide:
            characterOffset = currentScene.characterPosition == .right ? 200 : -200
            withAnimation(MotionTokens.spring) {
                characterOffset = 0
            }

        case .float:
            withAnimation(
                Animation.easeInOut(duration: MotionTokens.Duration.slow)
                    .repeatForever(autoreverses: true)
            ) {
                characterScale = 1.08
            }

        case .spin:
            withAnimation(
                Animation.easeInOut(duration: MotionTokens.Duration.moderate)
            ) {
                characterRotation = 360
            }

        case .grow:
            characterScale = 0.3
            withAnimation(MotionTokens.bounce) {
                characterScale = 1.0
            }

        case .shake:
            withAnimation(Animation.easeInOut(duration: MotionTokens.Duration.quick)) {
                characterOffset = -12
            }
            withAnimation(Animation.easeInOut(duration: MotionTokens.Duration.quick)
                .delay(MotionTokens.Duration.quick)) {
                characterOffset = 12
            }
            withAnimation(Animation.easeInOut(duration: MotionTokens.Duration.quick)
                .delay(MotionTokens.Duration.quick * 2)) {
                characterOffset = -8
            }
            withAnimation(MotionTokens.spring
                .delay(MotionTokens.Duration.quick * 3)) {
                characterOffset = 0
            }

        case .fadeIn:
            characterOpacity = 0
            withAnimation(Animation.easeIn(duration: MotionTokens.Duration.standard)) {
                characterOpacity = 1
            }

        case .flip:
            withAnimation(Animation.easeInOut(duration: MotionTokens.Duration.moderate)) {
                characterRotation = 180
            }
            withAnimation(Animation.easeInOut(duration: MotionTokens.Duration.moderate)
                .delay(MotionTokens.Duration.moderate)) {
                characterRotation = 0
            }
        }
    }
}

// MARK: - Preview

#Preview("Шипящая история") {
    AnimatedStoryPlayerView(
        story: StoryLibrary.shared.allStories[0],
        onComplete: { }
    )
}

#Preview("Сонорная история") {
    AnimatedStoryPlayerView(
        story: StoryLibrary.shared.stories(for: "Р").first!,
        onComplete: { }
    )
}
