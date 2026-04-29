import SwiftUI

// MARK: - OfflineMiniGameView
//
// Sheet-based mini-game hub for the offline state screen.
// Three games for children 5–8 years old:
//  1. TapLyalya  — tap the jumping butterfly mascot as many times as possible in 5 s
//  2. DragClouds — drag drifting clouds to the mascot
//  3. FindPair   — 4×3 emoji memory grid
//
// VIP wiring is lightweight: interactor lives locally (no DI needed — fully offline,
// no repositories, no network). All state is @State / @Observable inside the view.

struct OfflineMiniGameView: View {

    @State private var selectedGame: OfflineMiniGameModels.GameType?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: SpacingTokens.sp6) {
                Spacer(minLength: SpacingTokens.sp4)

                mascotHeader

                Text(String(localized: "offline.minigame.title"))
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .accessibilityAddTraits(.isHeader)

                pickerCards

                Spacer()
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .background(ColorTokens.Kid.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "offline.minigame.exit")) {
                        dismiss()
                    }
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .accessibilityLabel(String(localized: "offline.minigame.exit"))
                }
            }
        }
        .sheet(item: $selectedGame) { gameType in
            gameSheetContent(for: gameType)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header

    private var mascotHeader: some View {
        Text("\u{1F98B}")
            .font(.system(size: 64))
            .accessibilityHidden(true)
    }

    // MARK: - Picker cards

    private var pickerCards: some View {
        VStack(spacing: SpacingTokens.sp3) {
            gameCard(
                emoji: "\u{1F98B}",
                titleKey: "offline.minigame.tap.title",
                instrKey: "offline.minigame.tap.instruction",
                accentColor: ColorTokens.Brand.rose,
                gameType: .tapLyalya
            )
            gameCard(
                emoji: "\u{2601}\u{FE0F}",
                titleKey: "offline.minigame.drag.title",
                instrKey: "offline.minigame.drag.instruction",
                accentColor: ColorTokens.Brand.sky,
                gameType: .dragClouds
            )
            gameCard(
                emoji: "\u{1F195}",
                titleKey: "offline.minigame.pair.title",
                instrKey: "offline.minigame.pair.instruction",
                accentColor: ColorTokens.Brand.mint,
                gameType: .findPair
            )
        }
    }

    private func gameCard(
        emoji: String,
        titleKey: String.LocalizationValue,
        instrKey: String.LocalizationValue,
        accentColor: Color,
        gameType: OfflineMiniGameModels.GameType
    ) -> some View {
        Button {
            selectedGame = gameType
        } label: {
            HStack(spacing: SpacingTokens.sp3) {
                Text(emoji)
                    .font(.system(size: 36))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                    Text(String(localized: titleKey))
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(String(localized: instrKey))
                        .font(TypographyTokens.caption(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accentColor)
            }
            .padding(SpacingTokens.sp4)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .strokeBorder(accentColor.opacity(0.25), lineWidth: 1.5)
            )
        }
        .accessibilityLabel(String(localized: titleKey))
        .accessibilityHint(String(localized: instrKey))
    }

    // MARK: - Game routing

    @ViewBuilder
    private func gameSheetContent(for gameType: OfflineMiniGameModels.GameType) -> some View {
        switch gameType {
        case .tapLyalya:
            TapLyalyaGameView()
        case .dragClouds:
            DragCloudsGameView()
        case .findPair:
            FindPairGameView()
        }
    }
}

// MARK: - OfflineMiniGameModels.GameType: Identifiable

extension OfflineMiniGameModels.GameType: Identifiable {
    public var id: String { rawValue }
}

// MARK: - TapLyalyaGameView

private struct TapLyalyaGameView: View {

    @State private var taps: Int = 0
    @State private var timeLeft: Int = 5
    @State private var isRunning: Bool = false
    @State private var isFinished: Bool = false
    @State private var mascotPosition: CGPoint = CGPoint(x: 160, y: 280)
    @State private var timerTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()

            if isFinished {
                resultView
            } else {
                gameBoard
            }
        }
        .onDisappear { timerTask?.cancel() }
    }

    private var gameBoard: some View {
        GeometryReader { geo in
            ZStack {
                headerBar
                    .position(x: geo.size.width / 2, y: 50)

                Text("\u{1F98B}")
                    .font(.system(size: isRunning ? 60 : 52))
                    .position(mascotPosition)
                    .onTapGesture {
                        guard isRunning else { return }
                        taps += 1
                        jumpMascot(in: geo.size)
                    }
                    .accessibilityLabel(String(localized: "offline.minigame.tap.title"))
                    .accessibilityAddTraits(.isButton)

                if !isRunning && !isFinished {
                    startPrompt
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.75)
                }
            }
            .onAppear {
                mascotPosition = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .onTapGesture {
                if !isRunning && !isFinished {
                    startCounting(geo: geo.size)
                }
            }
        }
    }

    private var headerBar: some View {
        HStack(spacing: SpacingTokens.sp4) {
            Label(
                "\(timeLeft)",
                systemImage: "timer"
            )
            .font(TypographyTokens.headline(18))
            .foregroundStyle(timeLeft <= 2 ? ColorTokens.Semantic.error : ColorTokens.Kid.ink)

            Spacer()

            Text(String(format: String(localized: "offline.minigame.score.format"), taps))
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Brand.primary)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .frame(maxWidth: .infinity)
    }

    private var startPrompt: some View {
        VStack(spacing: SpacingTokens.sp2) {
            Text(String(localized: "offline.minigame.tap.instruction"))
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.sp8)
            Text(String(localized: "offline.minigame.tap.start"))
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
    }

    private var resultView: some View {
        VStack(spacing: SpacingTokens.sp6) {
            Spacer()
            Text("\u{1F38A}")
                .font(.system(size: 72))
                .accessibilityHidden(true)
            Text(String(format: String(localized: "offline.minigame.score.format"), taps))
                .font(TypographyTokens.display(40))
                .foregroundStyle(ColorTokens.Brand.primary)
            Text(taps >= 10
                 ? String(localized: "offline.minigame.congrats.great")
                 : String(localized: "offline.minigame.congrats.good"))
                .font(TypographyTokens.title(20))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
            Spacer()
            HStack(spacing: SpacingTokens.sp3) {
                HSButton(String(localized: "offline.minigame.again"), style: .primary) {
                    resetGame()
                }
                HSButton(String(localized: "offline.minigame.exit"), style: .secondary) {
                    dismiss()
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp8)
        }
    }

    private func startCounting(geo: CGSize) {
        isRunning = true
        timerTask = Task { @MainActor in
            while timeLeft > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                timeLeft -= 1
            }
            isRunning = false
            isFinished = true
        }
    }

    private func jumpMascot(in size: CGSize) {
        guard !reduceMotion else { return }
        let margin: CGFloat = 60
        let newX = CGFloat.random(in: margin...(size.width - margin))
        let newY = CGFloat.random(in: 80...(size.height - 80))
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            mascotPosition = CGPoint(x: newX, y: newY)
        }
    }

    private func resetGame() {
        timerTask?.cancel()
        taps = 0
        timeLeft = 5
        isRunning = false
        isFinished = false
    }
}

// MARK: - DragCloudsGameView

private struct DragCloudsGameView: View {

    private struct Cloud: Identifiable {
        let id = UUID()
        var position: CGPoint
        var isCaught: Bool = false
    }

    @State private var clouds: [Cloud] = []
    @State private var caught: Int = 0
    @State private var isFinished: Bool = false
    @State private var mascotPosition: CGPoint = .zero
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ColorTokens.Brand.sky.opacity(0.15).ignoresSafeArea()

            if isFinished {
                dragResultView
            } else {
                GeometryReader { geo in
                    ZStack {
                        Text("\u{1F98B}")
                            .font(.system(size: 56))
                            .position(mascotPosition)
                            .accessibilityHidden(true)

                        ForEach($clouds) { $cloud in
                            if !cloud.isCaught {
                                Text("\u{2601}\u{FE0F}")
                                    .font(.system(size: 44))
                                    .position(cloud.position)
                                    .gesture(
                                        DragGesture()
                                            .onEnded { val in
                                                let dist = hypot(
                                                    val.location.x - mascotPosition.x,
                                                    val.location.y - mascotPosition.y
                                                )
                                                if dist < 80 {
                                                    cloud.isCaught = true
                                                    caught += 1
                                                    if caught >= clouds.filter({ !$0.isCaught }).count + caught {
                                                        isFinished = true
                                                    }
                                                }
                                            }
                                    )
                                    .accessibilityLabel(String(localized: "offline.minigame.drag.cloud.a11y"))
                                    .accessibilityAddTraits(.isButton)
                            }
                        }

                        scoreLabel
                            .position(x: geo.size.width / 2, y: 50)
                    }
                    .onAppear {
                        mascotPosition = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.75)
                        spawnClouds(in: geo.size)
                    }
                }
            }
        }
    }

    private var scoreLabel: some View {
        Text(String(format: String(localized: "offline.minigame.score.format"), caught))
            .font(TypographyTokens.headline(18))
            .foregroundStyle(ColorTokens.Brand.sky)
            .padding(.horizontal, SpacingTokens.screenEdge)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var dragResultView: some View {
        VStack(spacing: SpacingTokens.sp6) {
            Spacer()
            Text("\u{1F4AB}")
                .font(.system(size: 72))
                .accessibilityHidden(true)
            Text(String(format: String(localized: "offline.minigame.score.format"), caught))
                .font(TypographyTokens.display(40))
                .foregroundStyle(ColorTokens.Brand.sky)
            Text(caught >= 5
                 ? String(localized: "offline.minigame.congrats.great")
                 : String(localized: "offline.minigame.congrats.good"))
                .font(TypographyTokens.title(20))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
            Spacer()
            HStack(spacing: SpacingTokens.sp3) {
                HSButton(String(localized: "offline.minigame.again"), style: .primary) {
                    resetDrag()
                }
                HSButton(String(localized: "offline.minigame.exit"), style: .secondary) {
                    dismiss()
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp8)
        }
        .background(ColorTokens.Kid.bg.ignoresSafeArea())
    }

    private func spawnClouds(in size: CGSize) {
        clouds = (0..<7).map { i in
            let x = CGFloat.random(in: 60...(size.width - 60))
            let y = CGFloat.random(in: 80...(size.height * 0.6))
            return Cloud(position: CGPoint(x: x, y: y))
        }
        caught = 0
        isFinished = false
    }

    private func resetDrag() {
        caught = 0
        isFinished = false
        clouds = clouds.map { c in
            var fresh = c
            fresh.isCaught = false
            return fresh
        }
    }
}

// MARK: - FindPairGameView

private struct FindPairGameView: View {

    private struct Card: Identifiable {
        let id = UUID()
        let emoji: String
        var isFaceUp: Bool = false
        var isMatched: Bool = false
    }

    private static let emojis = ["🐶", "🐱", "🦁", "🐰", "🦊", "🐻"]

    @State private var cards: [Card] = []
    @State private var firstFlipped: Card?
    @State private var pairsFound: Int = 0
    @State private var moves: Int = 0
    @State private var isFinished: Bool = false
    @State private var isBlocked: Bool = false
    @Environment(\.dismiss) private var dismiss

    let columns = Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sp2), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            headerRow
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp4)

            Spacer(minLength: SpacingTokens.sp3)

            if isFinished {
                pairResultView
            } else {
                LazyVGrid(columns: columns, spacing: SpacingTokens.sp2) {
                    ForEach(cards) { card in
                        cardCell(card)
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
            }

            Spacer()
        }
        .background(ColorTokens.Kid.bg.ignoresSafeArea())
        .onAppear { setupCards() }
    }

    private var headerRow: some View {
        HStack {
            Text(String(localized: "offline.minigame.pair.title"))
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Kid.ink)
            Spacer()
            Text(String(format: String(localized: "offline.minigame.score.format"), pairsFound))
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Brand.mint)
        }
    }

    @ViewBuilder
    private func cardCell(_ card: Card) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(card.isMatched
                      ? ColorTokens.Brand.mint.opacity(0.25)
                      : (card.isFaceUp ? ColorTokens.Kid.surface : ColorTokens.Brand.lilac.opacity(0.45)))
                .aspectRatio(1, contentMode: .fit)
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)

            if card.isFaceUp || card.isMatched {
                Text(card.emoji)
                    .font(.system(size: 28))
            } else {
                Text("\u{2753}")
                    .font(.system(size: 24))
                    .accessibilityHidden(true)
            }
        }
        .onTapGesture {
            handleTap(card)
        }
        .accessibilityLabel(card.isFaceUp || card.isMatched
                            ? card.emoji
                            : String(localized: "offline.minigame.pair.card.hidden.a11y"))
        .accessibilityAddTraits(.isButton)
    }

    private var pairResultView: some View {
        VStack(spacing: SpacingTokens.sp6) {
            Spacer()
            Text("\u{1F3C6}")
                .font(.system(size: 72))
                .accessibilityHidden(true)
            Text(String(format: String(localized: "offline.minigame.score.format"), pairsFound))
                .font(TypographyTokens.display(40))
                .foregroundStyle(ColorTokens.Brand.mint)
            Text(String(localized: "offline.minigame.congrats.great"))
                .font(TypographyTokens.title(20))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
            Spacer()
            HStack(spacing: SpacingTokens.sp3) {
                HSButton(String(localized: "offline.minigame.again"), style: .primary) {
                    setupCards()
                }
                HSButton(String(localized: "offline.minigame.exit"), style: .secondary) {
                    dismiss()
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp8)
        }
    }

    private func handleTap(_ card: Card) {
        guard !isBlocked, !card.isMatched, !card.isFaceUp else { return }

        flipCard(id: card.id, faceUp: true)
        moves += 1

        if let first = firstFlipped {
            firstFlipped = nil
            if first.emoji == card.emoji {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    matchCards(emoji: card.emoji)
                    pairsFound += 1
                    if pairsFound >= Self.emojis.count {
                        isFinished = true
                    }
                }
            } else {
                isBlocked = true
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(800))
                    flipCard(id: first.id, faceUp: false)
                    flipCard(id: card.id, faceUp: false)
                    isBlocked = false
                }
            }
        } else {
            firstFlipped = cards.first(where: { $0.id == card.id })
        }
    }

    private func flipCard(id: UUID, faceUp: Bool) {
        if let idx = cards.firstIndex(where: { $0.id == id }) {
            cards[idx].isFaceUp = faceUp
        }
    }

    private func matchCards(emoji: String) {
        for idx in cards.indices where cards[idx].emoji == emoji {
            cards[idx].isMatched = true
            cards[idx].isFaceUp = true
        }
    }

    private func setupCards() {
        let pairs = Self.emojis.flatMap { [$0, $0] }.shuffled()
        cards = pairs.map { Card(emoji: $0) }
        pairsFound = 0
        moves = 0
        isFinished = false
        firstFlipped = nil
    }
}

// MARK: - Preview

#Preview("OfflineMiniGame Hub") {
    OfflineMiniGameView()
}
