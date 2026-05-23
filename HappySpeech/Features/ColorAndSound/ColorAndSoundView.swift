import SwiftUI

// MARK: - ColorAndSoundView

struct ColorAndSoundView: View {

    let childId: String

    @State private var interactor: ColorAndSoundInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService

    private let columns = [
        GridItem(.flexible(), spacing: SpacingTokens.sp2),
        GridItem(.flexible(), spacing: SpacingTokens.sp2)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                content
            }
            .navigationTitle(Text(String(localized: "colorAndSound.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
            .task {
                if interactor == nil {
                    interactor = ColorAndSoundInteractor(childId: childId)
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            ScrollView {
                VStack(spacing: SpacingTokens.sp4) {
                    hero
                    grid(interactor: interactor)
                    cta
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp6)
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private var hero: some View {
        HSCard(style: .tinted(ColorTokens.Brand.mint.opacity(0.18))) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "colorAndSound.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "colorAndSound.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    private func grid(interactor: ColorAndSoundInteractor) -> some View {
        LazyVGrid(columns: columns, spacing: SpacingTokens.sp2) {
            ForEach(interactor.state.pairs) { pair in
                pairCard(pair) {
                    hapticService.impact(.light)
                    interactor.toggle(pair.id)
                }
            }
        }
    }

    private func pairCard(
        _ pair: ColorAndSoundModels.Pair,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HSCard(style: pair.isMatched ? .tinted(ColorTokens.Semantic.successBg) : .elevated) {
                VStack(spacing: SpacingTokens.sp2) {
                    Circle()
                        .fill(pair.color)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Text(pair.sound)
                                .font(TypographyTokens.title(22))
                                .foregroundStyle(.white)
                        )
                    Text(pair.colorName)
                        .font(TypographyTokens.headline(14))
                        .foregroundStyle(ColorTokens.Kid.ink)
                    Text(pair.example)
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                    if pair.isMatched {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(ColorTokens.Brand.primary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, SpacingTokens.sp2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Звук \(pair.sound), \(pair.colorName) цвет"))
        .accessibilityAddTraits(.isButton)
    }

    private var cta: some View {
        HSButton(
            String(localized: "colorAndSound.cta.action"),
            style: .primary,
            size: .large,
            icon: "checkmark"
        ) {
            hapticService.notification(.success)
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview("ColorAndSound — Light") {
    ColorAndSoundView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("ColorAndSound — Dark") {
    ColorAndSoundView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
