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

    @Environment(\.exitToParentHome) private var exitToParentHome
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ParentVoiceNote.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                HSMeshGradientBackground(palette: .calm, animated: !reduceMotion)
                    .ignoresSafeArea()
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
                        exitToParentHome()
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
                HSPrivacyPill()

                Text(loadVM.introMessage)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(nil)

                HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp3) {
                    optInRow(loadVM)
                }

                if let error = holder.lastError {
                    errorBanner(error)
                }

                templatesList(loadVM.templates)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.vertical, SpacingTokens.sp3)
        }
    }

    @ViewBuilder
    private func templatesList(
        _ templates: [ParentVoiceNoteModels.Load.TemplateViewModel]
    ) -> some View {
        let total = templates.count
        let spring = Animation.spring(response: 0.5, dampingFraction: 0.85)
        let animation: Animation = reduceMotion ? .linear(duration: 0) : spring
        LazyVStack(spacing: SpacingTokens.sp2) {
            ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
                templateRow(template)
                    .scrollTransition(.animated(animation)) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0)
                            .scaleEffect(phase.isIdentity ? 1 : 0.96)
                    }
                    .zIndex(Double(total - index))
            }
        }
    }

    private func optInRow(
        _ loadVM: ParentVoiceNoteModels.Load.ViewModel
    ) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            // Icon circle — pulses when enabled
            ZStack {
                Circle()
                    .fill(
                        loadVM.isEnabledGlobally
                            ? ColorTokens.Parent.accent.opacity(0.18)
                            : ColorTokens.Parent.accent.opacity(0.10)
                    )
                    .frame(width: 48, height: 48)
                Image(systemName: loadVM.isEnabledGlobally ? "speaker.wave.3.fill" : "speaker.slash.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(ColorTokens.Parent.accent)
                    .contentTransition(.symbolEffect(.replace))
            }
            .hsSymbolEffect(.variableColor, value: loadVM.isEnabledGlobally)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text(loadVM.optInLabel)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                Text(loadVM.optInSubtitle)
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: SpacingTokens.sp2)

            Toggle("", isOn: Binding(
                get: { loadVM.isEnabledGlobally },
                set: { newVal in
                    Task { await toggleEnabled(newVal) }
                }
            ))
            .labelsHidden()
            .tint(ColorTokens.Parent.accent)
            .accessibilityLabel(Text(loadVM.optInLabel))
        }
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
                // Icon circle — larger, warm accent fill
                ZStack {
                    Circle()
                        .fill(
                            template.hasClip
                                ? ColorTokens.Brand.butter.opacity(0.22)
                                : ColorTokens.Parent.accent.opacity(0.12)
                        )
                        .frame(width: 48, height: 48)
                    Image(systemName: template.symbolName)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(
                            template.hasClip
                                ? ColorTokens.Brand.gold
                                : ColorTokens.Parent.accent
                        )
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(template.title)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                    if template.hasClip,
                       let duration = template.durationLabel,
                       let recordedAt = template.recordedAtLabel {
                        Text("\(duration) · \(recordedAt)")
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    } else {
                        Text(String(localized: "voice.row.empty", defaultValue: "Ещё нет записи"))
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                }

                Spacer(minLength: SpacingTokens.sp2)

                if template.hasClip {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(ColorTokens.Semantic.success)
                        .hsSymbolEffect(.bounce, value: template.hasClip)
                } else {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(ColorTokens.Parent.accent.opacity(0.6))
                }
            }
            .padding(.horizontal, SpacingTokens.sp4)
            .padding(.vertical, SpacingTokens.sp3)
            .frame(minHeight: 68)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(
                        template.hasClip
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        ColorTokens.Parent.surface,
                                        ColorTokens.Brand.butter.opacity(0.12)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                              )
                            : AnyShapeStyle(ColorTokens.Parent.surface)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .strokeBorder(
                        template.hasClip
                            ? ColorTokens.Brand.gold.opacity(0.25)
                            : ColorTokens.Parent.line,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(template.title))
        .accessibilityHint(Text(template.hasClip
            ? String(localized: "voice.row.hint.exists", defaultValue: "Нажмите, чтобы перезаписать")
            : String(localized: "voice.row.hint.empty", defaultValue: "Нажмите, чтобы записать")))
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
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SpacingTokens.sp4) {
                        // Privacy pill — matches reference "Приватно · на устройстве"
                        HSPrivacyPill()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, SpacingTokens.sp3)

                        // Template icon + title
                        VStack(spacing: SpacingTokens.sp2) {
                            ZStack {
                                Circle()
                                    .fill(ColorTokens.Parent.accent.opacity(0.13))
                                    .frame(width: 72, height: 72)
                                Image(systemName: template.symbolName)
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundStyle(ColorTokens.Parent.accent)
                            }
                            .accessibilityHidden(true)

                            Text(template.title)
                                .font(TypographyTokens.title(22))
                                .foregroundStyle(ColorTokens.Parent.ink)
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .minimumScaleFactor(0.85)
                        }

                        // "Прочитайте вслух" prompt card — key element from design ref
                        if let phrase = template.promptPhrase, !phrase.isEmpty {
                            promptPhraseCard(phrase)
                        }

                        // State hint text
                        if !promptForRecorderState().isEmpty {
                            Text(promptForRecorderState())
                                .font(TypographyTokens.caption(14))
                                .foregroundStyle(ColorTokens.Parent.inkMuted)
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, SpacingTokens.sp4)
                        }

                        // Timer dial
                        elapsedDial()

                        // Action buttons
                        recorderButtons(template: template)

                        Spacer(minLength: SpacingTokens.sp8)
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        cleanupAndDismissSheet()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                    .accessibilityLabel(Text("voice.recorder.close.a11y"))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// «Прочитайте вслух» — карточка с фразой-подсказкой (дизайн-эталон).
    private func promptPhraseCard(_ phrase: String) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(ColorTokens.Parent.accent)
                    .accessibilityHidden(true)
                Text(String(localized: "voice.recorder.readAloud", defaultValue: "ПРОЧИТАЙТЕ ВСЛУХ"))
                    .font(TypographyTokens.caption(11).weight(.bold))
                    .foregroundStyle(ColorTokens.Parent.accent)
                    .textCase(.uppercase)
                    .kerning(0.6)
            }
            Text(phrase)
                .font(TypographyTokens.title(18).italic())
                .foregroundStyle(ColorTokens.Parent.ink)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SpacingTokens.sp4)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            ColorTokens.Parent.accent.opacity(0.06),
                            ColorTokens.Brand.butter.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .strokeBorder(
                    ColorTokens.Parent.accent.opacity(0.22),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String(localized: "voice.recorder.readAloud", defaultValue: "Прочитайте вслух") + ": " + phrase))
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
            // Large mic button matching design reference
            VStack(spacing: SpacingTokens.sp3) {
                Button {
                    Task { await startRecording() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(ColorTokens.Brand.primary)
                            .frame(width: 80, height: 80)
                            .shadow(color: ColorTokens.Brand.primary.opacity(0.35), radius: 12, y: 4)
                        Image(systemName: "mic.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(ColorTokens.Overlay.onAccent)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(String(localized: "voice.recorder.start", defaultValue: "Начать запись")))

                Text(String(localized: "voice.recorder.start", defaultValue: "Начать запись"))
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
            }

        case .recording:
            // Stop button — red circle with STOP
            VStack(spacing: SpacingTokens.sp3) {
                Button {
                    stopRecording()
                } label: {
                    ZStack {
                        Circle()
                            .fill(ColorTokens.Semantic.error)
                            .frame(width: 80, height: 80)
                            .shadow(color: ColorTokens.Semantic.error.opacity(0.35), radius: 12, y: 4)
                        Image(systemName: "stop.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(ColorTokens.Overlay.onAccent)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(String(localized: "voice.recorder.stop", defaultValue: "Остановить запись")))

                Text(String(localized: "voice.recorder.stop", defaultValue: "Остановить"))
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
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
                    title: String(localized: "voice.recorder.save", defaultValue: "Сохранить"),
                    tint: ColorTokens.Brand.primary
                ) {
                    Task { await saveRecording(template: template) }
                }
                if template.hasClip {
                    Button {
                        Task { await deleteExistingClip(template: template) }
                    } label: {
                        Text(String(localized: "voice.recorder.deleteExisting", defaultValue: "Удалить предыдущую запись"))
                            .font(TypographyTokens.caption(13).weight(.medium))
                            .foregroundStyle(ColorTokens.Semantic.error)
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.plain)
                }
            }

        case .playingPreview:
            Text(String(localized: "voice.recorder.playing.hint", defaultValue: "Воспроизведение..."))
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
            self.router = ParentVoiceNoteRouter(dismissAction: { exitToParentHome() })
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
