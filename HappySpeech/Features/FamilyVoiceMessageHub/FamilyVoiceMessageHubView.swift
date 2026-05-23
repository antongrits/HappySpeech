import SwiftUI

// MARK: - FamilyVoiceMessageHubView

struct FamilyVoiceMessageHubView: View {

    @State private var interactor = FamilyVoiceMessageHubInteractor()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()
                content
            }
            .navigationTitle(Text(String(localized: "voiceMessageHub.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
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
                list
                cta
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp3)
            .padding(.bottom, SpacingTokens.sp6)
        }
    }

    private var hero: some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "voiceMessageHub.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "voiceMessageHub.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                if interactor.state.unreadCount > 0 {
                    Text("Непрочитано: \(interactor.state.unreadCount)")
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.accent)
                        .padding(.top, 4)
                }
            }
        }
    }

    private var list: some View {
        VStack(spacing: SpacingTokens.sp2) {
            ForEach(interactor.state.messages) { message in
                row(message) {
                    hapticService.impact(.light)
                    interactor.markRead(message.id)
                }
            }
        }
    }

    private func row(
        _ message: FamilyVoiceMessageHubModels.Message,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HSCard(style: message.isUnread
                   ? .tinted(ColorTokens.Parent.accent.opacity(0.10))
                   : .flat) {
                HStack(spacing: SpacingTokens.sp3) {
                    Text(message.sender.emoji)
                        .font(.system(size: 30))
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(message.sender.title)
                                .font(TypographyTokens.headline(14))
                                .foregroundStyle(ColorTokens.Parent.ink)
                            if message.isUnread {
                                Circle()
                                    .fill(ColorTokens.Brand.primary)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        Text(message.preview)
                            .font(TypographyTokens.body(13))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                            .lineLimit(1)
                        Text(message.timeLabel)
                            .font(TypographyTokens.caption(10))
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(ColorTokens.Parent.accent)
                        Text("\(message.durationSeconds)с")
                            .font(TypographyTokens.caption(10))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Сообщение от \(message.sender.title), \(message.durationSeconds) секунд"))
        .accessibilityAddTraits(.isButton)
    }

    private var cta: some View {
        HSButton(
            String(localized: "voiceMessageHub.cta.action"),
            style: .primary,
            size: .large,
            icon: "checkmark.circle.fill"
        ) {
            hapticService.notification(.success)
            interactor.markAllRead()
        }
    }
}

// MARK: - Preview

#Preview("FamilyVoiceMessageHub — Light") {
    FamilyVoiceMessageHubView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("FamilyVoiceMessageHub — Dark") {
    FamilyVoiceMessageHubView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
