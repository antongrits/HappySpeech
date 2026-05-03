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
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: SpacingTokens.sp2) {
                    // Priority usage banner
                    priorityBanner

                    ForEach(interactor.recordings) { recording in
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
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.vertical, SpacingTokens.sp4)
            }
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
        }
    }

    // MARK: - Priority Banner

    private var priorityBanner: some View {
        HSCard(style: .tinted(ColorTokens.Brand.primary.opacity(0.08))) {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "checkmark.seal.fill")
                    .font(TypographyTokens.headline(20))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .accessibilityHidden(true)

                Text(String(localized: "family.voice.priority_used"))
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .ctaTextStyle()

                Spacer()
            }
        }
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sp5) {
            Spacer()

            Image(systemName: "mic.slash.circle")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(ColorTokens.Parent.inkSoft.opacity(0.5))
                .accessibilityHidden(true)

            Text(String(localized: "family.voice.library.empty"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .multilineTextAlignment(.center)
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

    var body: some View {
        HSCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                // Play / Stop button
                Button(action: onPlay) {
                    Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .font(TypographyTokens.display(36))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .frame(minWidth: 44, minHeight: 44)
                        .animation(.easeInOut(duration: 0.2), value: isPlaying)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    isPlaying
                        ? String(localized: "family.voice.library.play") + " " + recording.word
                        : String(localized: "family.voice.library.play") + " " + recording.word
                )

                // Word + date
                VStack(alignment: .leading, spacing: 2) {
                    Text(recording.word)
                        .font(TypographyTokens.headline())
                        .foregroundStyle(ColorTokens.Parent.ink)

                    Text(
                        String(
                            format: String(localized: "family.voice.library.last_recorded"),
                            recording.recordedAt.formatted(date: .abbreviated, time: .omitted)
                        )
                    )
                    .font(TypographyTokens.caption())
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(1)

                    Text(recording.durationText)
                        .font(TypographyTokens.mono(11))
                        .foregroundStyle(ColorTokens.Parent.inkSoft)
                }

                Spacer()

                // Rerecord
                Button(action: onRerecord) {
                    Image(systemName: "arrow.clockwise")
                        .font(TypographyTokens.body(16))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .frame(minWidth: 36, minHeight: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "family.voice.library.rerecord") + " " + recording.word)

                // Delete
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(TypographyTokens.body(16))
                        .foregroundStyle(ColorTokens.Semantic.error)
                        .frame(minWidth: 36, minHeight: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "parent_child.recorder.cta.delete") + " " + recording.word)
            }
            .padding(SpacingTokens.sp3)
        }
        .environment(\.circuitContext, .parent)
        .accessibilityElement(children: .contain)
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
    private let realmActor: RealmActor
    private var player: AVAudioPlayer?
    private var playbackTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "ru.happyspeech.app", category: "FamilyVoiceLibraryInteractor")

    // MARK: - Init

    init(parentId: String, realmActor: RealmActor) {
        self.parentId = parentId
        self.realmActor = realmActor
    }

    // MARK: - Load

    func load() async {
        let dtos = await FamilyRecordingStore.fetchAll(parentId: parentId, realmActor: realmActor)
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

        await FamilyRecordingStore.delete(id: recordingId, realmActor: realmActor)
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
