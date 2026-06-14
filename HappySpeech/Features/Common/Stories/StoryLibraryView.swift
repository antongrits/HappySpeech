import SwiftUI

// MARK: - StoryLibraryView
//
// Детский каталог анимированных историй («Сказки Ляли»).
//
// Сетка из 20 историй (`StoryLibrary.shared.allStories`): у каждой —
// градиентная обложка из `backgroundGradient`, название, бейдж целевого
// звука и иконка-героя. Тап по карточке открывает `AnimatedStoryPlayerView`
// в полноэкранном cover'е (внутри проигрывается MP4 из `Videos/stories/<id>.mp4`).
//
// Контур: детский (kid). Запускается через `AppCoordinator.navigate(to:)`,
// поэтому выход — через `@Environment(\.exitGame)`.
//
// Accessibility:
//   • карточки крупные (тап-таргет ≥ 110pt по высоте), описательные
//     VoiceOver-labels (название + целевой звук)
//   • Dynamic Type: `.minimumScaleFactor(0.85)`, `.lineLimit(nil)` на CTA/тексте,
//     `.fixedSize` для переноса длинных названий
//   • Light + Dark: `ColorTokens.Kid` адаптируются; mesh-палитра выбирается по
//     `colorScheme`, фон статичный (без «волновой» анимации — `animated: false`)
//
// Дизайн: тёплая палитра-токены, маскот Ляля в шапке, симметричные `screenEdge`
// отступы слева=справа, сетка из 2 равных колонок (`.flexible`) — на SE375
// колонки сужаются, текст не обрезается.

struct StoryLibraryView: View {

    // MARK: - API

    let childId: String

    // MARK: - State

    @State private var selectedStory: AnimatedStory?

    @Environment(\.exitGame) private var exitGame
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Data

    private var stories: [AnimatedStory] {
        StoryLibrary.shared.allStories
    }

    // MARK: - Grid columns (адаптив: 1 колонка на узких SE, 2 на широких)

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: SpacingTokens.sp4),
            GridItem(.flexible(), spacing: SpacingTokens.sp4)
        ]
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()

            HSMeshGradientBackground(
                palette: colorScheme == .dark ? .kidWarmDark : .kidWarm,
                animated: false
            )
            .ignoresSafeArea()
            .opacity(colorScheme == .dark ? 0.22 : 0.32)
            .blendMode(.softLight)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            scrollContent
        }
        .fullScreenCover(item: $selectedStory) { story in
            AnimatedStoryPlayerView(
                story: story,
                onComplete: { selectedStory = nil }
            )
            .environment(\.circuitContext, .kid)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Scroll content

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.sp5) {
                header

                LazyVGrid(columns: columns, spacing: SpacingTokens.sp4) {
                    ForEach(stories) { story in
                        StoryCoverCard(story: story) {
                            selectedStory = story
                        }
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
            }
            .padding(.top, SpacingTokens.sp4)
            // Нижний отступ держит последний ряд карточек выше home-indicator.
            .padding(.bottom, SpacingTokens.sp10)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Header (маскот + заголовок + кнопка выхода)

    private var header: some View {
        VStack(spacing: SpacingTokens.sp3) {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .explaining, size: 72)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                    Text(String(localized: "storyLibrary.title"))
                        .font(TypographyTokens.kidDisplay(26))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)

                    Text(String(localized: "storyLibrary.subtitle"))
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            exitButton
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
    }

    private var exitButton: some View {
        Button {
            exitGame()
        } label: {
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "house.fill")
                    .font(TypographyTokens.headline(16))
                    .accessibilityHidden(true)
                Text(String(localized: "storyLibrary.back_home"))
                    .font(TypographyTokens.headline(16))
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                Capsule().fill(ColorTokens.Brand.primary)
            )
        }
        .buttonStyle(.plain)
        .tapFeedback()
        .accessibilityLabel(String(localized: "storyLibrary.back_home.accessibility"))
        .accessibilityHint(String(localized: "storyLibrary.back_home.hint"))
    }
}

// MARK: - StoryCoverCard

/// Карточка-обложка одной истории: градиент из `backgroundGradient`,
/// бейдж целевого звука, название и кнопка «Смотреть».
private struct StoryCoverCard: View {

    let story: AnimatedStory
    let action: () -> Void

    private var coverColors: [Color] {
        let colors = story.backgroundGradient.map { Color(hex: $0) }
        return colors.isEmpty
            ? [ColorTokens.Brand.lilac, ColorTokens.Brand.rose]
            : colors
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                coverArt

                Text(story.title)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                watchHint
            }
            .padding(SpacingTokens.sp3)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .strokeBorder(ColorTokens.Kid.inkMuted.opacity(0.12), lineWidth: 1)
            )
            .shadow(
                color: ColorTokens.Kid.ink.opacity(0.08),
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(.plain)
        .tapFeedback()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                format: String(localized: "storyLibrary.card.accessibility"),
                story.title,
                story.targetSound
            )
        )
        .accessibilityHint(String(localized: "storyLibrary.card.hint"))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Cover art (градиент + бейдж звука + play-иконка)

    private var coverArt: some View {
        ZStack {
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: coverColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack {
                HStack {
                    soundBadge
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
                HStack {
                    Spacer(minLength: 0)
                    Image(systemName: "play.circle.fill")
                        .font(TypographyTokens.title(30))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1)
                }
            }
            .padding(SpacingTokens.sp2)
        }
        .frame(height: 110)
        .accessibilityHidden(true)
    }

    private var soundBadge: some View {
        Text(story.targetSound)
            .font(TypographyTokens.headline(15))
            .foregroundStyle(ColorTokens.Kid.ink)
            .frame(minWidth: 30, minHeight: 30)
            .padding(.horizontal, SpacingTokens.sp1)
            .background(
                Capsule().fill(ColorTokens.Overlay.onAccent.opacity(0.92))
            )
    }

    private var watchHint: some View {
        HStack(spacing: SpacingTokens.sp1) {
            Image(systemName: "sparkles")
                .font(TypographyTokens.caption(12))
                .accessibilityHidden(true)
            Text(String(localized: "storyLibrary.card.watch"))
                .font(TypographyTokens.caption(13).weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(ColorTokens.Brand.primary)
    }
}

// MARK: - Preview

#Preview("Story Library — Light") {
    StoryLibraryView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("Story Library — Dark") {
    StoryLibraryView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
