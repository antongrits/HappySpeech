import AVFoundation
import OSLog
import SwiftUI

// MARK: - ParentVoiceNoteViewModelHolder

@MainActor
@Observable
final class ParentVoiceNoteViewModelHolder: ParentVoiceNoteDisplayLogic {

    var loadVM: ParentVoiceNoteModels.Load.ViewModel?
    var lastError: String?
    var lastSavedClip: ParentVoiceClipData?

    func displayLoad(viewModel: ParentVoiceNoteModels.Load.ViewModel) async {
        loadVM = viewModel
        lastError = nil
    }

    func displaySave(savedClip: ParentVoiceClipData) async {
        lastSavedClip = savedClip
        lastError = nil
    }

    func displayDelete(deletedId: String) async {
        lastError = nil
    }

    func displayToggle(isEnabled: Bool) async {
        if var vm = loadVM {
            vm = .init(
                title: vm.title,
                introMessage: vm.introMessage,
                templates: vm.templates,
                isEnabledGlobally: isEnabled,
                optInLabel: vm.optInLabel,
                optInSubtitle: vm.optInSubtitle
            )
            loadVM = vm
        }
    }

    func displayError(message: String) async {
        lastError = message
    }
}

// MARK: - ParentVoiceNoteView (Clean Swift: View)
//
// v31 Волна B, Функция Ф.4 «Parent voice notes».
//
// UX: список из 16 шаблонов уроков. У шаблона с записью — иконка
// «зелёная галочка» + длительность. Тап → лист с кнопкой «Записать»
// (или «Перезаписать»), счётчиком (макс. 30 с), кнопкой «Сохранить» /
// «Удалить». На уровне родителя есть тумблер «Включить мамин голос
// в уроках».

struct ParentVoiceNoteView: View {

    let childId: String

    @State private var holder = ParentVoiceNoteViewModelHolder()
    @State private var interactor: ParentVoiceNoteInteractor?
    @State private var presenter: ParentVoiceNotePresenter?
    @State private var router: ParentVoiceNoteRouter?
    @State private var recorder = ParentVoiceNoteRecorder()
    @State private var selectedTemplate: ParentVoiceNoteModels.Load.TemplateViewModel?
    @State private var recorderState: RecorderState = .idle
    @State private var elapsedTickTask: Task<Void, Never>?
    @State private var pendingTempURL: URL?
    @State private var pendingDuration: Double = 0

    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ParentVoiceNote.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()
                Group {
                    if let loadVM = holder.loadVM {
                        listSection(loadVM)
                    } else {
                        loadingSection
                    }
                }
            }
            .navigationTitle(Text("voice.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Parent.ink)
                    }
                    .accessibilityLabel(Text("voice.close.a11y"))
                }
            }
            .task {
                await setupAndLoad()
            }
            .sheet(item: $selectedTemplate) { template in
                recorderSheet(template)
                    .environment(container)
            }
        }
        .environment(\.circuitContext, .parent)
    }

    // MARK: - List

    private func listSection(
        _ loadVM: ParentVoiceNoteModels.Load.ViewModel
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                Text(loadVM.introMessage)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(nil)

                optInToggle(loadVM)

                if let error = holder.lastError {
                    errorBanner(error)
                }

                LazyVStack(spacing: SpacingTokens.sp2) {
                    ForEach(loadVM.templates) { template in
                        templateRow(template)
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.vertical, SpacingTokens.sp3)
        }
    }

    private func optInToggle(
        _ loadVM: ParentVoiceNoteModels.Load.ViewModel
    ) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 24))
                .foregroundStyle(ColorTokens.Parent.accent)
                .frame(width: 44, height: 44)
                .background(Circle().fill(ColorTokens.Parent.accent.opacity(0.12)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text(loadVM.optInLabel)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Parent.ink)
                Text(loadVM.optInSubtitle)
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(nil)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { loadVM.isEnabledGlobally },
                set: { newVal in
                    Task { await toggleEnabled(newVal) }
                }
            ))
            .labelsHidden()
            .accessibilityLabel(Text(loadVM.optInLabel))
        }
        .padding(SpacingTokens.sp3)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Parent.surface)
        )
    }

    private func templateRow(
        _ template: ParentVoiceNoteModels.Load.TemplateViewModel
    ) -> some View {
        Button {
            selectedTemplate = template
            recorderState = .idle
            pendingTempURL = nil
            pendingDuration = 0
        } label: {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: template.symbolName)
                    .font(.system(size: 22))
                    .foregroundStyle(ColorTokens.Parent.accent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(ColorTokens.Parent.accent.opacity(0.12)))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(template.title)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                    if template.hasClip,
                       let duration = template.durationLabel,
                       let recordedAt = template.recordedAtLabel {
                        Text("\(duration) · \(recordedAt)")
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    } else {
                        Text("voice.row.empty")
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }
                }

                Spacer()

                if template.hasClip {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(ColorTokens.Semantic.success)
                } else {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                }
            }
            .padding(SpacingTokens.sp3)
            .frame(minHeight: 64)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Parent.surface)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(template.title))
        .accessibilityHint(Text(template.hasClip
            ? "voice.row.hint.exists"
            : "voice.row.hint.empty"))
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(TypographyTokens.caption(13))
            .foregroundStyle(ColorTokens.Semantic.error)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SpacingTokens.sp2)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.button)
                    .fill(ColorTokens.Semantic.error.opacity(0.10))
            )
    }

    // MARK: - Recorder Sheet

    private func recorderSheet(
        _ template: ParentVoiceNoteModels.Load.TemplateViewModel
    ) -> some View {
        NavigationStack {
            VStack(spacing: SpacingTokens.sp4) {
                Image(systemName: template.symbolName)
                    .font(.system(size: 56))
                    .foregroundStyle(ColorTokens.Parent.accent)
                    .padding(.top, SpacingTokens.sp5)
                    .accessibilityHidden(true)
                Text(template.title)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)

                Text(promptForRecorderState())
                    .font(TypographyTokens.caption(14))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.sp4)

                elapsedDial()

                recorderButtons(template: template)

                Spacer()
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        cleanupAndDismissSheet()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(ColorTokens.Parent.ink)
                    }
                    .accessibilityLabel(Text("voice.recorder.close.a11y"))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func promptForRecorderState() -> String {
        switch recorderState {
        case .idle:
            return String(localized: "voice.recorder.idle.hint")
        case .recording:
            return String(localized: "voice.recorder.recording.hint")
        case .stopped:
            return String(localized: "voice.recorder.stopped.hint")
        case .playingPreview:
            return String(localized: "voice.recorder.playing.hint")
        case .failed(let message):
            return message
        }
    }

    private func elapsedDial() -> some View {
        ZStack {
            Circle()
                .stroke(ColorTokens.Parent.inkMuted.opacity(0.20), lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(min(1.0, recordedFraction)))
                .stroke(ColorTokens.Parent.accent,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(elapsedSeconds)) с")
                .font(TypographyTokens.title(28).monospacedDigit())
                .foregroundStyle(ColorTokens.Parent.ink)
        }
        .frame(width: 120, height: 120)
        .accessibilityLabel(Text("voice.recorder.timer.a11y"))
        .accessibilityValue(Text(verbatim: "\(Int(elapsedSeconds))"))
    }

    private var elapsedSeconds: Double {
        switch recorderState {
        case .idle, .failed:                            return 0
        case .recording(let seconds):                   return seconds
        case .stopped(let duration, _):                 return duration
        case .playingPreview:                           return pendingDuration
        }
    }

    private var recordedFraction: Double {
        let max = recorder.maxDurationSec
        guard max > 0 else { return 0 }
        return elapsedSeconds / max
    }

    @ViewBuilder
    private func recorderButtons(
        template: ParentVoiceNoteModels.Load.TemplateViewModel
    ) -> some View {
        switch recorderState {
        case .idle, .failed:
            primaryRowButton(
                title: String(localized: "voice.recorder.start"),
                tint: ColorTokens.Brand.primary
            ) {
                Task { await startRecording() }
            }
        case .recording:
            primaryRowButton(
                title: String(localized: "voice.recorder.stop"),
                tint: ColorTokens.Semantic.error
            ) {
                stopRecording()
            }
        case .stopped:
            VStack(spacing: SpacingTokens.sp2) {
                HStack(spacing: SpacingTokens.sp2) {
                    secondaryRowButton(
                        title: String(localized: "voice.recorder.preview"),
                        symbol: "play.circle.fill"
                    ) {
                        Task { await previewRecording() }
                    }
                    secondaryRowButton(
                        title: String(localized: "voice.recorder.redo"),
                        symbol: "arrow.counterclockwise"
                    ) {
                        Task { await startRecording() }
                    }
                }
                primaryRowButton(
                    title: String(localized: "voice.recorder.save"),
                    tint: ColorTokens.Semantic.success
                ) {
                    Task { await saveRecording(template: template) }
                }
                if template.hasClip {
                    Button {
                        Task { await deleteExistingClip(template: template) }
                    } label: {
                        Text("voice.recorder.deleteExisting")
                            .font(TypographyTokens.caption(13).weight(.medium))
                            .foregroundStyle(ColorTokens.Semantic.error)
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.plain)
                }
            }
        case .playingPreview:
            Text("voice.recorder.playing.hint")
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .frame(maxWidth: .infinity, minHeight: 56)
        }
    }

    private func primaryRowButton(
        title: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(TypographyTokens.headline(17))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(tint)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }

    private func secondaryRowButton(
        title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: symbol)
                Text(title)
                    .font(TypographyTokens.headline(16))
            }
            .foregroundStyle(ColorTokens.Parent.accent)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Parent.accent.opacity(0.10))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ProgressView()
                .controlSize(.large)
            Text("voice.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Wiring

    private func setupAndLoad() async {
        if interactor == nil {
            let presenter = ParentVoiceNotePresenter(displayLogic: holder)
            let worker = ParentVoiceNoteWorker(realmActor: container.realmActor)
            let optIn = ParentVoiceNoteOptInService()
            let interactor = ParentVoiceNoteInteractor(
                childId: childId,
                worker: worker,
                optInService: optIn
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = ParentVoiceNoteRouter(dismissAction: { dismiss() })
        }
        await interactor?.load(request: .init(childId: childId))
    }

    private func startRecording() async {
        do {
            let url = try await recorder.startRecording()
            pendingTempURL = url
            recorderState = .recording(elapsedSeconds: 0)
            elapsedTickTask?.cancel()
            elapsedTickTask = Task { @MainActor in
                while recorder.isRecording {
                    try? await Task.sleep(for: .milliseconds(250))
                    if case .recording = recorderState {
                        recorderState = .recording(elapsedSeconds: recorder.currentDurationSec)
                    }
                    // Auto-stop при достижении лимита.
                    if recorder.currentDurationSec >= recorder.maxDurationSec {
                        stopRecording()
                    }
                }
            }
        } catch {
            recorderState = .failed(message: error.localizedDescription)
        }
    }

    private func stopRecording() {
        elapsedTickTask?.cancel()
        elapsedTickTask = nil
        guard let result = recorder.stopRecording() else {
            recorderState = .idle
            return
        }
        pendingTempURL = result.fileURL
        pendingDuration = result.durationSec
        recorderState = .stopped(durationSeconds: result.durationSec, fileURL: result.fileURL)
        container.hapticService.notification(.success)
    }

    private func previewRecording() async {
        guard let url = pendingTempURL else { return }
        recorderState = .playingPreview
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            // Простая блокирующая ожидалка через polling — модулю достаточно,
            // продолжение управляется stop'ом или таймером дителельности.
            try? await Task.sleep(for: .seconds(min(player.duration + 0.2, recorder.maxDurationSec + 1)))
            recorderState = .stopped(durationSeconds: pendingDuration, fileURL: url)
        } catch {
            recorderState = .failed(message: error.localizedDescription)
        }
    }

    private func saveRecording(
        template: ParentVoiceNoteModels.Load.TemplateViewModel
    ) async {
        guard let url = pendingTempURL else { return }
        await interactor?.saveClip(
            request: .init(
                childId: childId,
                lessonTemplate: template.id,
                fileURL: url,
                durationSec: pendingDuration
            )
        )
        await interactor?.load(request: .init(childId: childId))
        cleanupAndDismissSheet()
    }

    private func deleteExistingClip(
        template: ParentVoiceNoteModels.Load.TemplateViewModel
    ) async {
        guard let existing = interactor?.clips.first(
            where: { $0.lessonTemplate == template.id }
        ) else { return }
        await interactor?.deleteClip(request: .init(clipId: existing.id))
        await interactor?.load(request: .init(childId: childId))
        cleanupAndDismissSheet()
    }

    private func toggleEnabled(_ isEnabled: Bool) async {
        await interactor?.toggleEnabled(request: .init(childId: childId, isEnabled: isEnabled))
        await interactor?.load(request: .init(childId: childId))
    }

    private func cleanupAndDismissSheet() {
        elapsedTickTask?.cancel()
        elapsedTickTask = nil
        if recorder.isRecording {
            _ = recorder.stopRecording()
        }
        pendingTempURL = nil
        pendingDuration = 0
        recorderState = .idle
        selectedTemplate = nil
    }
}

// MARK: - Preview

#if DEBUG
#Preview("ParentVoiceNote") {
    ParentVoiceNoteView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
