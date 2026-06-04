import SwiftUI

// MARK: - ChildAchievementShareView

struct ChildAchievementShareView: View {

    @State private var interactor = ChildAchievementShareInteractor()
    @State private var shareItem: ChildAchievementShareItem?
    @Environment(\.exitToParentHome) private var exitToParentHome
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                HSMeshGradientBackground(palette: .rewards, animated: !reduceMotion)
                    .ignoresSafeArea()
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                content
            }
            .navigationTitle(Text(String(localized: "achievementShare.nav.title")))
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
            .sheet(item: $shareItem) { item in
                ChildAchievementShareSheet(items: [item.text])
            }
        }
        .environment(\.circuitContext, .parent)
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.sp3) {
                hero
                list
                cta
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp3)
            .padding(.bottom, SpacingTokens.sp6)
        }
    }

    private var hero: some View {
        HSLiquidGlassCard(style: .elevated) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "achievementShare.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Parent.ink)
                Text(String(localized: "achievementShare.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    private var list: some View {
        VStack(spacing: SpacingTokens.sp2) {
            ForEach(Array(interactor.items.enumerated()), id: \.element.id) { index, item in
                row(item)
                    .scrollTransition(.animated(reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.85))) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0)
                            .scaleEffect(phase.isIdentity ? 1 : 0.96)
                    }
                    .hsParallaxTile(factor: 0.22)
                    .zIndex(Double(interactor.items.count - index))
            }
        }
    }

    private func row(_ item: ChildAchievementShareModels.Item) -> some View {
        let selected = interactor.selectedId == item.id
        return Button {
            hapticService.impact(.light)
            interactor.select(item.id)
        } label: {
            HSCard(style: selected ? .tinted(ColorTokens.Parent.accent.opacity(0.12)) : .flat) {
                HStack(spacing: SpacingTokens.sp3) {
                    Text(item.emoji).font(.system(size: 36))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Parent.ink)
                        Text(item.subtitle)
                            .font(TypographyTokens.body(13))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ColorTokens.Parent.accent)
                            .font(.system(size: 22))
                            .hsSymbolEffect(.bounce, value: selected)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(item.title). \(item.subtitle)"))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var cta: some View {
        HSButton(
            String(localized: "achievementShare.cta.share"),
            style: .primary,
            size: .large,
            icon: "square.and.arrow.up"
        ) {
            guard let text = interactor.makeShareText() else { return }
            hapticService.impact(.medium)
            shareItem = ChildAchievementShareItem(text: text)
        }
        .disabled(interactor.selectedId == nil)
        .opacity(interactor.selectedId == nil ? 0.5 : 1.0)
    }
}

// MARK: - Share helpers

private struct ChildAchievementShareItem: Identifiable {
    let id = UUID()
    let text: String
}

private struct ChildAchievementShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview("ChildAchievementShare — Light") {
    ChildAchievementShareView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("ChildAchievementShare — Dark") {
    ChildAchievementShareView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
