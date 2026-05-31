import OSLog
import SwiftUI

// MARK: - LogopedistChatViewModelHolder

@MainActor
@Observable
final class LogopedistChatViewModelHolder: LogopedistChatDisplayLogic {

    var loadVM: LogopedistChatModels.Load.ViewModel?
    var sendVM: LogopedistChatModels.Send.ViewModel?
    var attachVM: LogopedistChatModels.AttachAudio.ViewModel?
    var connectVM: LogopedistChatModels.Connect.ViewModel?
    var showToast: Bool = false
    var isSending: Bool = false
    var isConnecting: Bool = false

    func displayLoad(viewModel: LogopedistChatModels.Load.ViewModel) async {
        self.loadVM = viewModel
    }

    func displaySend(viewModel: LogopedistChatModels.Send.ViewModel) async {
        self.sendVM = viewModel
        self.isSending = false
        self.showToast = true
    }

    func displayAttachAudio(viewModel: LogopedistChatModels.AttachAudio.ViewModel) async {
        self.attachVM = viewModel
        self.showToast = true
    }

    func displayConnect(viewModel: LogopedistChatModels.Connect.ViewModel) async {
        self.connectVM = viewModel
        self.isConnecting = false
        if viewModel.successMessage != nil {
            self.showToast = true
        }
    }
}

// MARK: - LogopedistChatView (Clean Swift: View)
//
// Block R.2 v18 — экран чата parent ↔ specialist.
//
// Layout (sheet, presentationDetent .large):
//   1. Header — имя specialist + credentials + online dot
//   2. ScrollView с message bubbles (parent right / specialist left)
//      • Каждый bubble: text + attachment + time + status
//   3. Composer внизу — TextField + attach button + send button
//
// Accessibility:
//   • VoiceOver: каждое message bubble = «<отправитель>, <текст>, <время>»
//   • Dynamic Type: scaledFont, lineLimit(nil)
//   • Reduced Motion: пропуск scroll-to-bottom анимации
//   • Touch targets ≥56pt: send button, attach button

struct LogopedistChatView: View {

    let parentId: String
    let specialistId: String

    @State private var holder: LogopedistChatViewModelHolder
    @State private var interactor: LogopedistChatInteractor?
    @State private var presenter: LogopedistChatPresenter?
    @State private var router: LogopedistChatRouter?
    @State private var composerText: String = ""
    @State private var connectCode: String = ""
    @State private var attachActionShown: Bool = false
    @State private var subscriptionTask: Task<Void, Never>?

    /// DEBUG-only seam: при `true` `.task`-bootstrap делает ранний return и не
    /// перетирает инжектированное состояние async-загрузкой (snapshot-детерминизм).
    private let skipBootstrapForSnapshot: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "LogopedistChat.View")

    init(parentId: String, specialistId: String) {
        self.parentId = parentId
        self.specialistId = specialistId
        _holder = State(initialValue: LogopedistChatViewModelHolder())
        self.skipBootstrapForSnapshot = false
    }

    #if DEBUG
    /// DEBUG-only init для snapshot-тестов: инжектит уже-загруженный holder.
    init(
        parentId: String,
        specialistId: String,
        previewState holder: LogopedistChatViewModelHolder
    ) {
        self.parentId = parentId
        self.specialistId = specialistId
        _holder = State(initialValue: holder)
        self.skipBootstrapForSnapshot = true
    }
    #endif

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ZStack {
                    ColorTokens.Parent.bg
                    HSMeshGradientBackground(palette: .calm, animated: !reduceMotion)
                        .blendMode(.softLight)
                        .accessibilityHidden(true)
                }
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    if let viewModel = holder.loadVM {
                        if viewModel.showConnectForm {
                            connectForm
                        } else {
                            chatHeader(viewModel: viewModel)
                            if let outboxLabel = viewModel.outboxLabel {
                                connectionWarning(text: outboxLabel)
                            } else if let connectionHint = viewModel.connectionHint {
                                connectionWarning(text: connectionHint)
                            }
                            messagesList(viewModel: viewModel)
                            Divider()
                                .background(ColorTokens.Parent.line)
                            composerView(viewModel: viewModel)
                        }
                    } else {
                        loadingSection
                            .frame(maxHeight: .infinity)
                    }
                }
            }
            .navigationTitle(Text("chat.screen.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                    .accessibilityLabel(Text("chat.close.a11y"))
                }
            }
            .overlay(alignment: .top) {
                if holder.showToast,
                   let toast = holder.connectVM?.successMessage
                                ?? holder.sendVM?.confirmationMessage
                                ?? holder.attachVM?.confirmationMessage {
                    toastBanner(text: toast)
                        .padding(.top, SpacingTokens.sp2)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.4), value: holder.showToast)
            .confirmationDialog(
                Text("chat.attach.dialog.title"),
                isPresented: $attachActionShown,
                titleVisibility: .visible
            ) {
                Button(String(localized: "chat.attach.audio")) {
                    Task { await attachAudio() }
                }
                Button(String(localized: "common.cancel"), role: .cancel) {}
            }
        }
        .environment(\.circuitContext, .parent)
        .task {
            await setupAndLoad()
        }
        .onDisappear {
            subscriptionTask?.cancel()
            subscriptionTask = nil
        }
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            LyalyaMascotView(state: .happy, size: 80)
                .accessibilityHidden(true)
            ProgressView()
                .controlSize(.large)
        }
        .padding(.top, SpacingTokens.sp10)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Connect form
    //
    // Показывается, пока логопед не подключён к семье. Родитель вводит
    // 6-символьный код, выданный специалистом. Честное состояние вместо
    // выдуманного собеседника (project guide §11).

    private var connectForm: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.sp4) {
                LyalyaMascotView(state: .waving, size: 120)
                    .frame(height: 120)
                    .accessibilityHidden(true)

                Text("chat.connect.title")
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text("chat.connect.subtitle")
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, SpacingTokens.sp4)

                TextField(
                    String(localized: "chat.connect.codePlaceholder"),
                    text: $connectCode
                )
                .font(TypographyTokens.headline(18))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled(true)
                .foregroundStyle(ColorTokens.Parent.ink)
                .padding(.vertical, SpacingTokens.sp3)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ColorTokens.Parent.bgDeep)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(ColorTokens.Parent.line, lineWidth: 1)
                )
                .onChange(of: connectCode) { _, newValue in
                    let filtered = newValue.uppercased().filter { $0.isLetter || $0.isNumber }
                    connectCode = String(filtered.prefix(6))
                }
                .accessibilityLabel(Text("chat.connect.codePlaceholder"))

                if let error = holder.connectVM?.errorMessage {
                    Text(error)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Semantic.warning)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .accessibilityLabel(Text(error))
                }

                HSButton(
                    String(localized: "chat.connect.cta"),
                    style: .primary,
                    size: .large,
                    icon: "link",
                    isLoading: holder.isConnecting
                ) {
                    Task { await connect() }
                }
                .disabled(connectCode.count != 6 || holder.isConnecting)

                Text("chat.connect.privacy")
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.top, SpacingTokens.sp2)
            }
            .padding(SpacingTokens.sp5)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func chatHeader(viewModel: LogopedistChatModels.Load.ViewModel) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            ZStack {
                Circle()
                    .fill(ColorTokens.Parent.accent.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: "person.fill")
                    .font(.title3)
                    .foregroundStyle(ColorTokens.Parent.accent)
                    .hsSymbolEffect(.bounce, value: viewModel.isOnline)
            }
            .overlay(alignment: .bottomTrailing) {
                if viewModel.isOnline {
                    Circle()
                        .fill(ColorTokens.Semantic.success)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle().strokeBorder(ColorTokens.Parent.bg, lineWidth: 2)
                        )
                        .accessibilityHidden(true)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.specialistName)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(viewModel.credentials)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(1)
                // Presence-подпись — только когда специалист реально подключён.
                if let onlineLabel = viewModel.onlineStatusLabel {
                    Text(onlineLabel)
                        .font(TypographyTokens.caption(10))
                        .foregroundStyle(
                            viewModel.isOnline
                                ? ColorTokens.Semantic.success
                                : ColorTokens.Parent.inkSoft
                        )
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.sp4)
        .background(ColorTokens.Parent.surface)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String(
            format: String(localized: "chat.header.a11y"),
            viewModel.specialistName,
            viewModel.credentials,
            viewModel.onlineStatusLabel ?? ""
        )))
    }

    @ViewBuilder
    private func connectionWarning(text: String) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            Image(systemName: "wifi.slash")
                .font(.caption)
                .foregroundStyle(ColorTokens.Semantic.warning)
                .accessibilityHidden(true)
            Text(text)
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Semantic.warning)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(.horizontal, SpacingTokens.sp4)
        .padding(.vertical, SpacingTokens.sp2)
        .background(ColorTokens.Semantic.warningBg)
    }

    // MARK: - Hero (empty state)
    //
    // Честное пустое состояние: пока к ребёнку не подключён реальный логопед,
    // никакой переписки нет. Не имитируем живого специалиста (project guide §11).

    @ViewBuilder
    private func chatHeroEmptyState(
        viewModel: LogopedistChatModels.Load.ViewModel
    ) -> some View {
        let title: String = viewModel.isConnected
            ? String(localized: "chat.empty.connected.title")
            : String(localized: "chat.empty.notConnected.title")
        let hint: String = viewModel.emptyStateHint
            ?? String(localized: "chat.empty.connected.hint")

        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp5) {
            VStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .waving, size: 140)
                    .frame(height: 140)
                    .accessibilityHidden(true)

                Text(title)
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(hint)
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, SpacingTokens.sp4)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(title). \(hint)"))
    }

    // MARK: - Messages

    @ViewBuilder
    private func messagesList(viewModel: LogopedistChatModels.Load.ViewModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: SpacingTokens.sp2) {
                    if viewModel.messages.isEmpty {
                        chatHeroEmptyState(viewModel: viewModel)
                            .padding(.top, SpacingTokens.sp6)
                    }
                    ForEach(viewModel.sections) { section in
                        dateSeparator(label: section.dateLabel)
                        ForEach(Array(section.messages.enumerated()), id: \.element.id) { index, message in
                            messageBubble(message: message)
                                .id(message.id)
                                .scrollTransition(
                                    .animated(reduceMotion
                                        ? .linear(duration: 0)
                                        : .spring(response: 0.5, dampingFraction: 0.85))
                                ) { content, phase in
                                    content
                                        .opacity(phase.isIdentity ? 1 : 0)
                                        .scaleEffect(phase.isIdentity ? 1 : 0.96)
                                }
                                .hsParallaxTile(factor: 0.12)
                                .zIndex(Double(section.messages.count - index))
                        }
                    }
                    Color.clear
                        .frame(height: 8)
                        .id("messages.bottom")
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.vertical, SpacingTokens.sp3)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if reduceMotion {
                    proxy.scrollTo("messages.bottom", anchor: .bottom)
                } else {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("messages.bottom", anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dateSeparator(label: String) -> some View {
        HStack {
            Spacer()
            Text(label)
                .font(TypographyTokens.caption(11).weight(.medium))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .padding(.horizontal, SpacingTokens.sp3)
                .padding(.vertical, SpacingTokens.sp1)
                .background(
                    Capsule().fill(ColorTokens.Parent.surface.opacity(0.85))
                )
            Spacer()
        }
        .padding(.vertical, SpacingTokens.sp1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(label))
    }

    @ViewBuilder
    private func messageBubble(message: LogopedistChatModels.Load.MessageRow) -> some View {
        HStack(alignment: .bottom) {
            if message.isFromParent {
                Spacer(minLength: 56)
            }

            VStack(alignment: message.isFromParent ? .trailing : .leading, spacing: 4) {
                if let att = message.attachment {
                    attachmentView(att: att, isFromParent: message.isFromParent)
                }

                Text(message.text)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(
                        message.isFromParent
                            ? ColorTokens.Overlay.onAccent
                            : ColorTokens.Parent.ink
                    )
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, SpacingTokens.sp3)
                    .padding(.vertical, SpacingTokens.sp2)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                message.isFromParent
                                    ? ColorTokens.Parent.accent
                                    : ColorTokens.Parent.surface
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                message.isFromParent
                                    ? Color.clear
                                    : ColorTokens.Parent.line,
                                lineWidth: 1
                            )
                    )

                HStack(spacing: 4) {
                    Text(message.timeLabel)
                        .font(.caption2)
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                    if message.isFromParent, let symbol = message.statusSymbol {
                        Image(systemName: symbol)
                            .font(.caption2)
                            .foregroundStyle(
                                message.isRead
                                    ? ColorTokens.Parent.accent
                                    : ColorTokens.Parent.inkMuted
                            )
                            .accessibilityHidden(true)
                    }
                }
            }

            if !message.isFromParent {
                Spacer(minLength: 56)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(message.accessibilityLabel))
    }

    @ViewBuilder
    private func attachmentView(
        att: LogopedistChatModels.Load.AttachmentRow,
        isFromParent: Bool
    ) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            Image(systemName: att.symbolName)
                .font(.body)
                .foregroundStyle(
                    isFromParent
                        ? ColorTokens.Overlay.onAccent
                        : ColorTokens.Parent.accent
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(att.title)
                    .font(TypographyTokens.caption(12).weight(.medium))
                    .foregroundStyle(
                        isFromParent
                            ? ColorTokens.Overlay.onAccent
                            : ColorTokens.Parent.ink
                    )
                    .lineLimit(1)
                if let dur = att.durationLabel {
                    Text(dur)
                        .font(.caption2)
                        .foregroundStyle(
                            isFromParent
                                ? ColorTokens.Overlay.onAccent.opacity(0.8)
                                : ColorTokens.Parent.inkMuted
                        )
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "play.circle.fill")
                .font(.title3)
                .foregroundStyle(
                    isFromParent
                        ? ColorTokens.Overlay.onAccent
                        : ColorTokens.Parent.accent
                )
                .accessibilityHidden(true)
        }
        .padding(.horizontal, SpacingTokens.sp3)
        .padding(.vertical, SpacingTokens.sp2)
        .frame(minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    isFromParent
                        ? ColorTokens.Parent.accent.opacity(0.85)
                        : ColorTokens.Parent.bgDeep
                )
        )
    }

    // MARK: - Composer

    @ViewBuilder
    private func composerView(viewModel: LogopedistChatModels.Load.ViewModel) -> some View {
        HStack(alignment: .bottom, spacing: SpacingTokens.sp2) {
            Button {
                attachActionShown = true
            } label: {
                Image(systemName: "paperclip")
                    .font(.title3)
                    .foregroundStyle(ColorTokens.Parent.accent)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(ColorTokens.Parent.accent.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.composerEnabled || holder.isSending)
            .accessibilityLabel(Text("chat.composer.attach.a11y"))

            HStack {
                TextField(
                    String(localized: "chat.composer.placeholder"),
                    text: $composerText,
                    axis: .vertical
                )
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Parent.ink)
                .lineLimit(1...4)
                .padding(.horizontal, SpacingTokens.sp3)
                .padding(.vertical, SpacingTokens.sp2)
                .frame(minHeight: 44)
            }
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(ColorTokens.Parent.bgDeep)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(ColorTokens.Parent.line, lineWidth: 1)
            )

            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        canSend
                            ? ColorTokens.Parent.accent
                            : ColorTokens.Parent.inkSoft
                    )
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel(Text("chat.composer.send.a11y"))
        }
        .padding(.horizontal, SpacingTokens.sp3)
        .padding(.vertical, SpacingTokens.sp2)
        .background(ColorTokens.Parent.surface)
    }

    private var canSend: Bool {
        !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !holder.isSending
            && (holder.loadVM?.composerEnabled ?? false)
    }

    // MARK: - Toast

    @ViewBuilder
    private func toastBanner(text: String) -> some View {
        Text(text)
            .font(TypographyTokens.caption(13))
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .padding(.horizontal, SpacingTokens.sp4)
            .padding(.vertical, SpacingTokens.sp2)
            .background(
                Capsule().fill(ColorTokens.Parent.accent)
            )
            .depthShadow(ShadowTokens.parentDepth)
            .task {
                try? await Task.sleep(for: .seconds(2.0))
                holder.showToast = false
            }
    }

    // MARK: - Wiring

    private func setupAndLoad() async {
        // Snapshot seam: holder уже инжектирован — не запускаем async-загрузку.
        if skipBootstrapForSnapshot { return }

        if interactor == nil {
            let presenter = LogopedistChatPresenter(displayLogic: holder)
            let interactor = LogopedistChatInteractor(
                parentId: parentId,
                specialistId: specialistId,
                repository: container.chatRepository,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = LogopedistChatRouter(dismissAction: { dismiss() })
        }

        await interactor?.load(request: .init(
            parentId: parentId,
            specialistId: specialistId
        ))

        // Запускаем real-time подписку (живёт пока View на экране).
        startSubscriptionIfNeeded()
    }

    private func startSubscriptionIfNeeded() {
        guard subscriptionTask == nil, let interactor else { return }
        subscriptionTask = Task { await interactor.subscribe() }
    }

    private func connect() async {
        guard connectCode.count == 6 else { return }
        holder.isConnecting = true
        await interactor?.connect(request: .init(
            familyId: parentId,
            code: connectCode
        ))
        // При успехе Interactor сам перезагрузит тред; запускаем подписку.
        if holder.connectVM?.isConnected == true {
            connectCode = ""
            startSubscriptionIfNeeded()
        }
    }

    private func send() async {
        guard canSend else { return }
        let text = composerText
        composerText = ""
        holder.isSending = true

        await interactor?.send(request: .init(
            parentId: parentId,
            specialistId: specialistId,
            text: text,
            now: Date()
        ))
    }

    private func attachAudio() async {
        await interactor?.attachAudio(request: .init(
            parentId: parentId,
            specialistId: specialistId,
            attachmentTitle: String(localized: "chat.attachment.audio.title"),
            durationSeconds: 30,
            now: Date()
        ))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("LogopedistChat / loaded") {
    LogopedistChatView(
        parentId: "preview-parent",
        specialistId: "preview-specialist"
    )
    .environment(AppContainer.preview())
}
#endif
