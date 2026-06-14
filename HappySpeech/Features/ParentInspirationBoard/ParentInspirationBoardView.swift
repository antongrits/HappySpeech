import SwiftUI

// MARK: - ParentInspirationBoardView

struct ParentInspirationBoardView: View {

    @State private var interactor = ParentInspirationBoardInteractor()
    @Environment(\.exitToParentHome) private var exitToParentHome
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                // Parent-контур: спокойный прохладный холст #F0EFF6 (light) /
                // #181820 (dark) из эталона. Статичный, без тёплого Kid-mesh —
                // как HomeTasks / SpeechHomeworkPlanner / FamilyCalendar.
                ColorTokens.Parent.bg.ignoresSafeArea()
                content
            }
            .navigationTitle(Text(String(localized: "inspirationBoard.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exitToParentHome()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
        }
        .environment(\.circuitContext, .parent)
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.sp4) {
                hero
                filterToggle
                if let quote = interactor.state.current {
                    quoteCard(quote)
                        .id(quote.id)
                        .transition(reduceMotion
                            ? .opacity
                            : .opacity.combined(with: .move(edge: .trailing)))
                    navControls
                } else {
                    emptyFavorites
                }
                cta
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp3)
            .padding(.bottom, SpacingTokens.sp6)
            .animation(reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.4, dampingFraction: 0.85),
                       value: interactor.state.current?.id)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var filterToggle: some View {
        HStack(spacing: SpacingTokens.sp2) {
            Button {
                hapticService.impact(.light)
                interactor.toggleFavoritesFilter()
            } label: {
                Label(
                    interactor.state.favoritesOnly
                        ? String(localized: "inspirationBoard.filter.all")
                        : String(localized: "inspirationBoard.filter.favorites"),
                    systemImage: interactor.state.favoritesOnly ? "rectangle.stack" : "heart.fill"
                )
                .font(TypographyTokens.caption(13).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.accent)
                .padding(.horizontal, SpacingTokens.sp3)
                .padding(.vertical, SpacingTokens.sp1)
                .background(Capsule().fill(ColorTokens.Parent.surface))
            }
            .buttonStyle(.plain)
            Spacer()
            Text(String(
                format: String(localized: "inspirationBoard.favoritesCount %lld"),
                interactor.state.favoritesCount
            ))
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
        }
    }

    private var emptyFavorites: some View {
        HSCard(style: .flat) {
            VStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "heart.slash")
                    .font(.system(size: 32))
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                Text(String(localized: "inspirationBoard.empty"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp3)
        }
    }

    private var hero: some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp4) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "inspirationBoard.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "inspirationBoard.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    private func quoteCard(_ quote: ParentInspirationBoardModels.Quote) -> some View {
        HSCard(style: .tinted(ColorTokens.Parent.accent.opacity(0.10))) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 28))
                    .foregroundStyle(ColorTokens.Parent.accent)
                    .hsSymbolEffect(.pulse, value: quote.id)
                Text(quote.text)
                    .font(TypographyTokens.body(16))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("— \(quote.author)")
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.ink)
                        Text(quote.role)
                            .font(TypographyTokens.caption(11))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }
                    Spacer()
                    Button {
                        hapticService.impact(.light)
                        interactor.toggleFavorite()
                    } label: {
                        Image(systemName: quote.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 22))
                            .foregroundStyle(
                                quote.isFavorite ? ColorTokens.Brand.primary : ColorTokens.Parent.inkSoft
                            )
                            .hsSymbolEffect(.bounce, value: quote.isFavorite)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(quote.isFavorite
                        ? String(localized: "inspirationBoard.a11y.unfavorite")
                        : String(localized: "inspirationBoard.a11y.favorite")))
                }
            }
        }
    }

    private var navControls: some View {
        HStack(spacing: SpacingTokens.sp3) {
            Button {
                hapticService.impact(.light)
                interactor.previous()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(ColorTokens.Parent.accent)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle().fill(ColorTokens.Parent.surface)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(String(localized: "inspirationBoard.a11y.previous")))

            Text("\(interactor.state.currentIndex + 1) / \(interactor.state.visibleQuotes.count)")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .frame(maxWidth: .infinity)

            Button {
                hapticService.impact(.light)
                interactor.next()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(ColorTokens.Parent.accent)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle().fill(ColorTokens.Parent.surface)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(String(localized: "inspirationBoard.a11y.next")))
        }
    }

    private var cta: some View {
        HSButton(
            String(localized: "inspirationBoard.cta.action"),
            style: .primary,
            size: .large,
            icon: "checkmark"
        ) {
            hapticService.notification(.success)
            exitToParentHome()
        }
    }
}

// MARK: - Preview

#Preview("ParentInspirationBoard — Light") {
    ParentInspirationBoardView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("ParentInspirationBoard — Dark") {
    ParentInspirationBoardView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
