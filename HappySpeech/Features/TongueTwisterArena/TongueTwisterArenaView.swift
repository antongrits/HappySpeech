import SwiftUI

// MARK: - TongueTwisterArenaView

struct TongueTwisterArenaView: View {

    let childId: String

    @State private var interactor: TongueTwisterArenaInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                content
            }
            .navigationTitle(Text(String(localized: "tongueTwister.nav.title")))
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
                    interactor = TongueTwisterArenaInteractor(childId: childId)
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            if let selected = interactor.state.selected {
                ScrollView {
                    VStack(spacing: SpacingTokens.sp4) {
                        detail(twister: selected, interactor: interactor)
                        recordCTA(interactor: interactor)
                        backCTA(interactor: interactor)
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.top, SpacingTokens.sp3)
                    .padding(.bottom, SpacingTokens.sp6)
                }
            } else {
                ScrollView {
                    VStack(spacing: SpacingTokens.sp4) {
                        hero
                        list(interactor: interactor)
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.top, SpacingTokens.sp3)
                    .padding(.bottom, SpacingTokens.sp6)
                }
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private var hero: some View {
        HSCard(style: .tinted(ColorTokens.Brand.rose.opacity(0.18))) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .singing, size: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "tongueTwister.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "tongueTwister.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func list(interactor: TongueTwisterArenaInteractor) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            ForEach(interactor.state.twisters) { twister in
                Button {
                    hapticService.impact(.light)
                    interactor.select(twister)
                } label: {
                    HSCard(style: .elevated) {
                        HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                            Text(twister.targetSound)
                                .font(TypographyTokens.headline(16).weight(.bold))
                                .foregroundStyle(ColorTokens.Brand.primary)
                                .frame(width: 44, alignment: .leading)
                            Text(twister.text)
                                .font(TypographyTokens.body(14))
                                .foregroundStyle(ColorTokens.Kid.ink)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ColorTokens.Kid.inkSoft)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Скороговорка, \(twister.targetSound). \(twister.text)"))
                .accessibilityAddTraits(.isButton)
            }
        }
    }

    private func detail(
        twister: TongueTwisterArenaModels.Twister,
        interactor: TongueTwisterArenaInteractor
    ) -> some View {
        HSCard(style: .tinted(ColorTokens.Brand.butter.opacity(0.18))) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                Text(twister.targetSound)
                    .font(TypographyTokens.headline(16).weight(.bold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                Text(twister.text)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
            }
        }
    }

    private func recordCTA(interactor: TongueTwisterArenaInteractor) -> some View {
        HSButton(
            interactor.state.isRecording
                ? "Остановить запись"
                : String(localized: "tongueTwister.cta.action"),
            style: interactor.state.isRecording ? .danger : .primary,
            size: .large,
            icon: interactor.state.isRecording ? "stop.circle.fill" : "mic.fill"
        ) {
            hapticService.notification(.success)
            interactor.toggleRecord()
        }
    }

    private func backCTA(interactor: TongueTwisterArenaInteractor) -> some View {
        HSButton(
            "Назад к списку",
            style: .ghost,
            size: .medium,
            icon: "arrow.left"
        ) {
            hapticService.impact(.light)
            interactor.back()
        }
    }
}

// MARK: - Preview

#Preview("TongueTwisterArena — Light") {
    TongueTwisterArenaView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("TongueTwisterArena — Dark") {
    TongueTwisterArenaView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
