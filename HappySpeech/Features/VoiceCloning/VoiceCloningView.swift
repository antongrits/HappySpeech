import SwiftUI

// MARK: - VoiceCloningView
//
// «Голосовой архив» — kid contour экран:
// 1. Hero (маскот Ляля) + заголовок «Послушай, как ты говоришь!»
// 2. Карточка с подсказкой слова + большая кнопка записи (5 сек).
// 3. Список архивных записей, сгруппированных по неделям.
//    — tap → playback, long-press → удалить (parental gate).
//
// Доступ из ChildHome → «Голосовой архив».
// Все строки локализованы через String(localized:).
// Reduce Motion compliant (анимации pulse/wave отключаются).

struct VoiceCloningView: View {

    let childId: String

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - VIP

    @State private var viewModel = VoiceCloningViewModel()
    @State private var interactor: VoiceCloningInteractor?
    @State private var presenter: VoiceCloningPresenter?
    @State private var router: VoiceCloningRouter?

    // MARK: - Local UI

    @State private var pulseScale: CGFloat = 1.0
    @State private var showDeleteAlert: Bool = false
    @State private var sampleToDelete: VoiceCloning.ArchiveRow?

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: SpacingTokens.sectionGap) {
                    heroSection
                    recordingCard
                    contentSection
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp8)
            }
        }
        .navigationTitle(String(localized: "voice_cloning.nav_title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbar }
        .task { await bootstrap() }
        .alert(
            String(localized: "voice_cloning.delete.title"),
            isPresented: $showDeleteAlert,
            presenting: sampleToDelete
        ) { row in
            Button(role: .destructive) {
                Task { await delete(row.id) }
            } label: {
                Text(String(localized: "voice_cloning.delete.confirm"))
            }
            Button(role: .cancel) {} label: {
                Text(String(localized: "voice_cloning.delete.cancel"))
            }
        } message: { row in
            Text(String(format: String(localized: "voice_cloning.delete.message"), row.title))
        }
        .overlay(alignment: .top) {
            if let toast = viewModel.toastMessage {
                ToastBanner(text: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, SpacingTokens.sp4)
                    .onAppear {
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(2))
                            viewModel.toastMessage = nil
                        }
                    }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        HStack(alignment: .center, spacing: SpacingTokens.sp3) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                Text(String(localized: "voice_cloning.hero.title"))
                    .font(TypographyTokens.headline(20))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .accessibilityAddTraits(.isHeader)

                Text(String(localized: "voice_cloning.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: SpacingTokens.sp2)

            LyalyaMascotView(state: .happy, size: 72)
                .accessibilityHidden(true)
        }
        .padding(.top, SpacingTokens.sp3)
    }

    // MARK: - Recording card

    private var recordingCard: some View {
        HSCard(style: .elevated) {
            VStack(spacing: SpacingTokens.sp3) {
                // Подсказка слова
                HStack(spacing: SpacingTokens.sp2) {
                    HSBadge(viewModel.targetSound, style: .filled(ColorTokens.Brand.primary))
                    Text(String(localized: "voice_cloning.say_word"))
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                    Spacer()
                }

                Text(viewModel.suggestedWord)
                    .font(TypographyTokens.titleLarge(36))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityLabel(
                        String(format: String(localized: "voice_cloning.a11y.say_word"),
                               viewModel.suggestedWord)
                    )

                // Кнопка записи
                recordButton

                // Прогресс
                if viewModel.isRecording {
                    VStack(spacing: SpacingTokens.sp1) {
                        HSProgressBar(
                            value: viewModel.recordingProgress,
                            style: .kid,
                            tint: ColorTokens.Semantic.error
                        )
                        Text(viewModel.recordingElapsedText)
                            .font(TypographyTokens.mono(12))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                    }
                    .transition(.opacity)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var recordButton: some View {
        Button {
            Task { await toggleRecording() }
        } label: {
            ZStack {
                Circle()
                    .fill(viewModel.isRecording ? ColorTokens.Semantic.error : ColorTokens.Brand.primary)
                    .frame(width: 88, height: 88)
                    .scaleEffect(reduceMotion ? 1.0 : pulseScale)
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: pulseScale
                    )

                Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            if !reduceMotion && viewModel.isRecording {
                pulseScale = 1.12
            }
        }
        .onChange(of: viewModel.isRecording) { _, recording in
            if reduceMotion {
                pulseScale = 1.0
            } else {
                pulseScale = recording ? 1.12 : 1.0
            }
        }
        .accessibilityLabel(
            viewModel.isRecording
                ? String(localized: "voice_cloning.a11y.button_stop")
                : String(localized: "voice_cloning.a11y.button_record")
        )
        .accessibilityHint(String(localized: "voice_cloning.a11y.button_hint"))
    }

    // MARK: - Content section (archive)

    @ViewBuilder
    private var contentSection: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, SpacingTokens.sp4)

        case .empty:
            HSEmptyState(
                icon: "mic.slash.circle",
                title: String(localized: "voice_cloning.empty.title"),
                message: String(localized: "voice_cloning.empty.message"),
                actionTitle: nil
            ) {}

        case .ready:
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                ForEach(viewModel.archiveSections) { section in
                    sectionHeader(section.title)
                    VStack(spacing: SpacingTokens.sp2) {
                        ForEach(section.rows) { row in
                            ArchiveRowView(
                                row: row,
                                isPlaying: viewModel.currentlyPlayingSampleId == row.id,
                                onPlay: { Task { await play(row.id) } },
                                onLongPress: {
                                    sampleToDelete = row
                                    showDeleteAlert = true
                                }
                            )
                        }
                    }
                }
            }

        case .error(let message):
            HSEmptyState(
                icon: "exclamationmark.triangle",
                title: String(localized: "voice_cloning.error.title"),
                message: message,
                actionTitle: String(localized: "voice_cloning.error.retry")
            ) {
                Task { await refresh() }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            Image(systemName: "calendar")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Brand.primary)
                .accessibilityHidden(true)
            Text(title)
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Kid.ink)
            Spacer()
        }
        .padding(.top, SpacingTokens.sp2)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Text("\(viewModel.totalSamplesCount)")
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Brand.primary)
                .accessibilityLabel(
                    String(format: String(localized: "voice_cloning.a11y.total_count"),
                           viewModel.totalSamplesCount)
                )
        }
    }

    // MARK: - VIP bootstrap

    private func bootstrap() async {
        if interactor == nil {
            let presenter = VoiceCloningPresenter()
            let interactor = VoiceCloningInteractor(
                audioService: container.audioService,
                realmActor: container.realmActor
            )
            let router = VoiceCloningRouter(coordinator: coordinator)
            presenter.viewModel = viewModel
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = router
        }
        await refresh()
    }

    private func refresh() async {
        viewModel.state = .loading
        await interactor?.load(VoiceCloning.LoadRequest(childId: childId))
    }

    private func toggleRecording() async {
        if viewModel.isRecording {
            await interactor?.stopRecording(VoiceCloning.StopRecordingRequest(childId: childId))
        } else {
            let word = viewModel.suggestedWord.isEmpty
                ? VoiceCloning.SuggestedWordCatalog.defaultWord(forSound: viewModel.targetSound)
                : viewModel.suggestedWord
            await interactor?.startRecording(VoiceCloning.StartRecordingRequest(
                childId: childId,
                word: word,
                targetSound: viewModel.targetSound
            ))
        }
    }

    private func play(_ sampleId: String) async {
        if viewModel.currentlyPlayingSampleId == sampleId, viewModel.isPlaying {
            interactor?.stopPlayback()
        } else {
            await interactor?.playSample(VoiceCloning.PlaySampleRequest(sampleId: sampleId))
        }
    }

    private func delete(_ sampleId: String) async {
        await interactor?.delete(VoiceCloning.DeleteSampleRequest(sampleId: sampleId))
        sampleToDelete = nil
    }
}

// MARK: - ArchiveRowView

private struct ArchiveRowView: View {

    let row: VoiceCloning.ArchiveRow
    let isPlaying: Bool
    let onPlay: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        HSCard(style: .flat, padding: SpacingTokens.sp3) {
            HStack(spacing: SpacingTokens.sp3) {
                // Play / pause button
                Button(action: onPlay) {
                    ZStack {
                        Circle()
                            .fill(isPlaying ? ColorTokens.Semantic.success : ColorTokens.Brand.primary.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(TypographyTokens.headline(16))
                            .foregroundStyle(isPlaying ? ColorTokens.Overlay.onAccent : ColorTokens.Brand.primary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    isPlaying
                        ? String(localized: "voice_cloning.a11y.row_pause")
                        : String(localized: "voice_cloning.a11y.row_play")
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: SpacingTokens.sp1) {
                        Text(row.title)
                            .font(TypographyTokens.headline(16))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        HSBadge(row.targetSound, style: .neutral)
                    }
                    Text(row.dateText)
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }

                Spacer(minLength: SpacingTokens.sp1)

                Text(row.durationText)
                    .font(TypographyTokens.mono(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.6) {
            onLongPress()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(format: String(localized: "voice_cloning.a11y.row_summary"),
                   row.title, row.targetSound, row.dateText, row.durationText)
        )
        .accessibilityHint(String(localized: "voice_cloning.a11y.row_hint"))
    }
}

// MARK: - ToastBanner (private)

private struct ToastBanner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(TypographyTokens.body(14).weight(.medium))
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .padding(.horizontal, SpacingTokens.sp4)
            .padding(.vertical, SpacingTokens.sp2)
            .background(
                Capsule().fill(ColorTokens.Semantic.success)
            )
            .accessibilityLabel(text)
    }
}

// MARK: - Preview

#Preview("Voice Cloning — Empty") {
    let container = AppContainer.preview()
    return NavigationStack {
        VoiceCloningView(childId: "preview-child-1")
            .environment(container)
            .environment(AppCoordinator())
    }
}
