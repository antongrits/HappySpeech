import AVFoundation
import OSLog
import SwiftUI

// MARK: - FamilyVoiceLibraryView
//
// Экран «Семейные записи» — позволяет просматривать, воспроизводить,
// удалять и перезаписывать голосовые файлы, сохранённые родителем.
// VIP: View + LibraryInteractor (inline, ~100 LOC) — без отдельного Presenter,
// т.к. ViewModel формируется прямо из RecordingDTO для CRUD-экрана.

struct FamilyVoiceLibraryView: View {

    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var interactor: FamilyVoiceLibraryInteractor?
    @State private var showDeleteConfirm = false
    @State private var pendingDeleteId: String?

    var parentId: String = "local-parent"

    var body: some View {
        Group {
            if let interactor {
                libraryContent(interactor: interactor)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ColorTokens.Parent.bg.ignoresSafeArea())
            }
        }
        .navigationTitle(String(localized: "family.voice.library.title"))
        .navigationBarTitleDisplayMode(.inline)
        .background(ColorTokens.Parent.bg.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    coordinator.navigate(to: .familyVoice)
                } label: {
                    Label(
                        String(localized: "family.voice.library.add"),
                        systemImage: "mic.badge.plus"
                    )
                    .font(TypographyTokens.body(14).weight(.medium))
                }
                .accessibilityLabel(String(localized: "family.voice.library.add"))
            }
        }
        .confirmationDialog(
            String(localized: "family.voice.library.delete_confirm"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "family.voice.library.delete_confirm"), role: .destructive) {
                if let id = pendingDeleteId, let interactor {
                    Task { await interactor.delete(recordingId: id) }
                }
            }
            Button(String(localized: "OK"), role: .cancel) {}
        }
        .task {
            if interactor == nil {
                let created = FamilyVoiceLibraryInteractor(
                    parentId: parentId,
                    realmActor: container.realmActor
                )
                interactor = created
            }
            await interactor?.load()
        }
    }

    // MARK: - Library Content

    @ViewBuilder
    private func libraryContent(interactor: FamilyVoiceLibraryInteractor) -> some View {
        if interactor.recordings.isEmpty {
            emptyState
        } else {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()

                HSMeshGradientBackground(palette: .calm, animated: !reduceMotion)
                    .ignoresSafeArea()
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: SpacingTokens.sp2) {
                        HSPrivacyPill()
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Priority usage banner
                        priorityBanner

                        ForEach(Array(interactor.recordings.enumerated()), id: \.element.id) { index, recording in
                            FamilyRecordingRow(
                                recording: recording,
                                isPlaying: interactor.playingId == recording.id,
                                onPlay: {
                                    Task { await interactor.play(recording) }
                                },
                                onDelete: {
                                    pendingDeleteId = recording.id
                                    showDeleteConfirm = true
                                },
                                onRerecord: {
                                    coordinator.navigate(to: .familyVoice)
                                }
                            )
                            .scrollTransition(
                                .animated(reduceMotion ? .linear(duration: 0) : .spring(response: 0.55, dampingFraction: 0.85))
                            ) { content, phase in
                                content
                                    .opacity(phase.isIdentity ? 1 : 0)
                                    .scaleEffect(phase.isIdentity ? 1 : 0.94)
                            }
                            .hsParallaxTile(factor: 0.18)
                            .zIndex(Double(interactor.recordings.count - index))
                        }
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.vertical, SpacingTokens.sp4)
                }
            }
        }
    }

    // MARK: - Priority Banner

    private var priorityBanner: some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.regular) {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "checkmark.seal.fill")
                    .font(TypographyTokens.headline(20))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .hsSymbolEffect(.bounce, value: pendingDeleteId)
                    .accessibilityHidden(true)

                Text(String(localized: "family.voice.priority_used"))
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .ctaTextStyle()

                Spacer(minLength: SpacingTokens.tiny)
            }
        }
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sp5) {
            Spacer()

            LyalyaMascotView(state: .explaining, size: 140)
                .accessibilityHidden(true)

            Text(String(localized: "family.voice.library.empty"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .ctaTextStyle()
                .padding(.horizontal, SpacingTokens.sp8)

            Button {
                coordinator.navigate(to: .familyVoice)
            } label: {
                Label(
                    String(localized: "family.voice.library.add"),
                    systemImage: "mic.badge.plus"
                )
                .font(TypographyTokens.headline())
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
                .frame(minWidth: 200, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(ColorTokens.Brand.primary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(ColorTokens.Parent.bg.ignoresSafeArea())
    }
}

// MARK: - FamilyRecordingRow

struct FamilyRecordingRow: View {
    let recording: RecordingItemViewModel
    let isPlaying: Bool
    let onPlay: () -> Void
    let onDelete: () -> Void
    let onRerecord: () -> Void

    private var dateSubtitle: String {
        recording.recordedAt.formatted(date: .abbreviated, time: .omitted)
    }

    private var rowA11y: String {
        String(localized: "family.voice.library.play") + " "
            + recording.word + ", "
            + dateSubtitle + ", "
            + recording.durationText
    }

    var body: some View {
        HStack(spacing: SpacingTokens.sp3) {
            HSVoiceClipRow(
                title: recording.word,
                subtitle: dateSubtitle,
                durationText: recording.durationText,
                isPlaying: isPlaying,
                accessibilityLabel: rowA11y,
                onPlay: onPlay
            )

            Menu {
                Button {
                    onRerecord()
                } label: {
                    Label(
                        String(localized: "family.voice.library.rerecord"),
                        systemImage: "arrow.clockwise"
                    )
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label(
                        String(localized: "parent_child.recorder.cta.delete"),
                        systemImage: "trash"
                    )
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text("family.voice.library.row.menu.a11y"))
        }
        .environment(\.circuitContext, .parent)
    }
}

// MARK: - FamilyVoiceLibraryInteractor

@Observable
@MainActor
final class FamilyVoiceLibraryInteractor {

    // MARK: - Published state

    var recordings: [RecordingItemViewModel] = []
    var playingId: String?

    // MARK: - Private

    private let parentId: String
    /// Персистентность записей за Realm-границей (DTO-only). Features → Worker.
    private let recordingStore: any FamilyRecordingStoring
    private var player: AVAudioPlayer?
    private var playbackTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "ru.happyspeech.app", category: "FamilyVoiceLibraryInteractor")

    // MARK: - Init

    init(
        parentId: String,
        realmActor: RealmActor,
        recordingStore: (any FamilyRecordingStoring)? = nil
    ) {
        self.parentId = parentId
        self.recordingStore = recordingStore ?? FamilyRecordingStoreWorker(realmActor: realmActor)
    }

    // MARK: - Load

    func load() async {
        let dtos = await recordingStore.fetchAll(parentId: parentId)
        recordings = dtos
            .sorted { $0.recordedAt > $1.recordedAt }
            .map { dto in
                let mins = Int(dto.durationSeconds) / 60
                let secs = Int(dto.durationSeconds) % 60
                let dur = mins > 0 ? "\(mins):\(String(format: "%02d", secs))" : "\(secs)с"
                return RecordingItemViewModel(
                    id: dto.id,
                    word: dto.word,
                    durationText: dur,
                    recordedAt: dto.recordedAt,
                    audioFilePath: dto.audioFilePath
                )
            }
    }

    // MARK: - Play

    func play(_ recording: RecordingItemViewModel) async {
        // Toggle stop if already playing this recording
        if playingId == recording.id {
            stopPlayback()
            return
        }
        stopPlayback()

        guard let url = resolveURL(recording.audioFilePath) else {
            logger.warning("Family recording file not found: \(recording.audioFilePath, privacy: .public)")
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.prepareToPlay()
            newPlayer.play()
            player = newPlayer
            playingId = recording.id
            logger.debug("Playing family recording: \(recording.word, privacy: .private)")

            let duration = newPlayer.duration
            playbackTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(duration + 0.1))
                await MainActor.run { [weak self] in
                    self?.playingId = nil
                    self?.player = nil
                }
            }
        } catch {
            logger.error("FamilyVoiceLibrary playback error: \(error.localizedDescription)")
            playingId = nil
        }
    }

    // MARK: - Delete

    func delete(recordingId: String) async {
        guard let recording = recordings.first(where: { $0.id == recordingId }) else { return }
        if playingId == recordingId { stopPlayback() }

        if let url = resolveURL(recording.audioFilePath) {
            try? FileManager.default.removeItem(at: url)
        }

        await recordingStore.delete(id: recordingId)
        recordings.removeAll { $0.id == recordingId }
        logger.info("Deleted family recording: \(recordingId, privacy: .public)")
    }

    // MARK: - Helpers

    private func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        player?.stop()
        player = nil
        playingId = nil
    }

    private func resolveURL(_ relativePath: String) -> URL? {
        try? FamilyVoiceRecorderWorker.resolveFilePath(relativePath)
    }
}

// MARK: - Preview

#Preview("FamilyVoiceLibraryView — empty") {
    NavigationStack {
        FamilyVoiceLibraryView(parentId: "preview-parent")
            .environment(AppContainer.preview())
            .environment(AppCoordinator())
    }
}
