import SwiftUI

// MARK: - FamilyVoiceMessageHubView

struct FamilyVoiceMessageHubView: View {

    /// id родителя — канонический локальный профиль (как в остальных FamilyVoice-экранах).
    var parentId: String = "local-parent"

    @State private var interactor: FamilyVoiceMessageHubInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.exitToParentHome) private var exitToParentHome
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                HSMeshGradientBackground(palette: .calm, animated: !reduceMotion)
                    .ignoresSafeArea()
                if let interactor {
                    content(interactor)
                } else {
                    ProgressView().controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(Text(String(localized: "voiceMessageHub.nav.title")))
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
            .task {
                if interactor == nil {
                    let new = FamilyVoiceMessageHubInteractor(
                        parentId: parentId,
                        recordingStore: FamilyRecordingStoreWorker(realmActor: container.realmActor)
                    )
                    interactor = new
                    await new.load()
                }
            }
        }
        .environment(\.circuitContext, .parent)
    }

    private func content(_ interactor: FamilyVoiceMessageHubInteractor) -> some View {
        ScrollView {
            VStack(spacing: SpacingTokens.sp4) {
                HSPrivacyPill()
                    .frame(maxWidth: .infinity, alignment: .leading)
                hero(interactor)
                list(interactor)
                if !interactor.state.isEmpty {
                    cta(interactor)
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp3)
            .padding(.bottom, SpacingTokens.sp6)
        }
    }

    private func hero(_ interactor: FamilyVoiceMessageHubInteractor) -> some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp4) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "voiceMessageHub.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "voiceMessageHub.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                if interactor.state.unreadCount > 0 {
                    Text(String(format: String(localized: "voiceMessageHub.unread.count"), interactor.state.unreadCount))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.accent)
                        .padding(.top, SpacingTokens.micro)
                }
            }
        }
    }

    @ViewBuilder
    private func list(_ interactor: FamilyVoiceMessageHubInteractor) -> some View {
        if interactor.state.isEmpty {
            emptyState
        } else {
            messageList(interactor)
        }
    }

    private var emptyState: some View {
        HSCard(style: .flat) {
            VStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "waveform.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .accessibilityHidden(true)
                Text(String(localized: "voiceMessageHub.empty.title"))
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .multilineTextAlignment(.center)
                Text(String(localized: "voiceMessageHub.empty.body"))
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp3)
        }
        .accessibilityElement(children: .combine)
    }

    private func messageList(_ interactor: FamilyVoiceMessageHubInteractor) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            ForEach(Array(interactor.state.messages.enumerated()), id: \.element.id) { index, message in
                row(message) {
                    hapticService.impact(.light)
                    interactor.markRead(message.id)
                }
                .scrollTransition(.animated(reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.85))) { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0)
                        .scaleEffect(phase.isIdentity ? 1 : 0.96)
                }
                .zIndex(Double(interactor.state.messages.count - index))
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
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.85)
                        Text(message.timeLabel)
                            .font(TypographyTokens.caption(10))
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(ColorTokens.Parent.accent)
                            .hsSymbolEffect(.pulse, value: message.isUnread)
                        Text("\(message.durationSeconds)с")
                            .font(TypographyTokens.caption(10))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(format: String(localized: "voiceMessageHub.message.a11y"), message.sender.title, message.durationSeconds)))
        .accessibilityAddTraits(.isButton)
    }

    private func cta(_ interactor: FamilyVoiceMessageHubInteractor) -> some View {
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
