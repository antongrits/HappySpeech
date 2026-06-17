import SwiftUI

// MARK: - ListenYourselfView (Clean Swift: View)
//
// «Послушай себя» — слуховой самоконтроль (2 внутренних экрана).
//
//   Экран 1 «Два дубля»: слово дня + эталон Ляли, две «пластинки»-дубля
//     (выбранная крутится + сердечко), strip перезаписи, live-mic (halo +
//     волна из реального RMS).
//   Экран 2 «Сравни с Лялей»: A/B-строки (Ляля coral-tinted / ребёнок neutral,
//     обе с волной + play), самооценка 3 эмодзи (БЕЗ цифр), опоры-картинки
//     артикуляции, опциональный «секретный совет» (lilac, после выбора).
//
// Принцип: оценку даёт РЕБЁНОК, не приложение. Никаких числовых score.
//
// Accessibility:
//   • Kid circuit, интерактивные элементы ≥ 56pt;
//   • VoiceOver-метки на дублях, play, самооценке, опорах, совете;
//   • Dynamic Type: minimumScaleFactor + fixedSize, без обрезки;
//   • Reduced Motion: пульс halo и кружение пластинки гейтятся reduceMotion;
//   • Light + Dark: ColorTokens.Kid адаптируются.

struct ListenYourselfView: View {

    // MARK: - API

    let childId: String

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.exitGame) private var exitGame
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - VIP stack

    // internal (не private): подвью экрана сравнения вынесены в расширение
    // (`ListenYourselfCompareComponents`), которому нужен доступ к стору.
    @State var store = ListenYourselfStore()
    @State private var interactor: ListenYourselfInteractor?
    @State private var router: ListenYourselfRouter?

    // MARK: - Local UI state

    @State private var didBootstrap = false
    @State private var haloPulse = false
    @State private var liveAmplitudes: [Float] = []
    @State private var amplitudeTask: Task<Void, Never>?

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()
            HSMeshGradientBackground(palette: .calm, animated: false)
                .ignoresSafeArea()
                .accessibilityHidden(true)
                .allowsHitTesting(false)

            content
        }
        .task { await bootstrap() }
        .onDisappear { teardown() }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Content router

    @ViewBuilder
    private var content: some View {
        switch store.screen {
        case .loading:
            loadingView
        case .takes:
            takesScreen
        case .compare:
            compareScreen
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.3)
            Text(String(localized: "listenYourself.loading"))
                .font(TypographyTokens.kidBody())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
    }

    // MARK: - Screen 1: Two takes

    private var takesScreen: some View {
        VStack(spacing: 0) {
            topBar(
                title: isRecording
                    ? String(localized: "listenYourself.title.recording")
                    : String(localized: "listenYourself.title.takes"),
                subtitle: isRecording
                    ? String(localized: "listenYourself.subtitle.recording")
                    : String(localized: "listenYourself.subtitle.takes"),
                leadingIsClose: true
            )

            ScrollView {
                VStack(spacing: SpacingTokens.regular) {
                    targetCard
                    if isRecording {
                        recordingPrompt
                        liveMicSection
                    } else {
                        takesPrompt
                        takesRow
                        if !store.bothTakesReady {
                            recordPrimaryButton
                        } else {
                            againStrip
                        }
                    }
                    if let error = store.recordingErrorMessage {
                        errorNote(error)
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.tiny)
                .padding(.bottom, SpacingTokens.regular)
            }
            .scrollBounceBehavior(.basedOnSize)

            mascotRow(message: takesMascotMessage)

            if store.bothTakesReady {
                bottomBar {
                    HSButton(
                        String(localized: "listenYourself.cta.compare"),
                        icon: "arrow.right",
                        action: { goToCompare() }
                    )
                }
            }
        }
    }

    private var isRecording: Bool { store.recordingTakeNumber != nil }

    // MARK: - Screen 2: Compare with Lyalya

    private var compareScreen: some View {
        VStack(spacing: 0) {
            topBar(
                title: String(localized: "listenYourself.title.compare"),
                subtitle: String(format: String(localized: "listenYourself.subtitle.compare"), store.word),
                leadingIsClose: false
            )

            ScrollView {
                VStack(spacing: SpacingTokens.regular) {
                    compareRow(isLyalya: true)
                    compareRow(isLyalya: false)
                    reflectSection
                    judgeRow
                    if store.secretTipRequested, let tip = store.secretTip {
                        secretTipBox(tip)
                    } else if store.judgement != nil && !store.secretTipRequested {
                        secretTipButton
                    }
                    cuesSection
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.tiny)
                .padding(.bottom, SpacingTokens.regular)
            }
            .scrollBounceBehavior(.basedOnSize)

            mascotRow(message: compareMascotMessage)

            bottomBar {
                HStack(spacing: SpacingTokens.small) {
                    Button(action: { reRecord() }) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .frame(width: 60, height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                                    .fill(ColorTokens.Kid.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                                            .stroke(ColorTokens.Brand.primary, lineWidth: 1.5)
                                    )
                            )
                    }
                    .accessibilityLabel(String(localized: "listenYourself.reRecord.a11y"))

                    HSButton(
                        String(localized: "listenYourself.cta.done"),
                        icon: "arrow.right",
                        action: { router?.routeToExit() }
                    )
                }
            }
        }
    }

    // MARK: - Top bar

    private func topBar(title: String, subtitle: String, leadingIsClose: Bool) -> some View {
        HStack(spacing: SpacingTokens.small) {
            Button(action: { handleLeading(isClose: leadingIsClose) }) {
                Image(systemName: leadingIsClose ? "xmark" : "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(ColorTokens.Kid.surfaceAlt))
            }
            .accessibilityLabel(
                leadingIsClose
                    ? String(localized: "listenYourself.close.a11y")
                    : String(localized: "listenYourself.back.a11y")
            )

            VStack(spacing: 2) {
                Text(title)
                    .font(TypographyTokens.kidTitle(20))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.85)
                    .lineLimit(2)
                Text(subtitle)
                    .font(TypographyTokens.kidBody(13))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.85)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.tiny)
    }

    private func handleLeading(isClose: Bool) {
        if isClose {
            router?.routeToExit()
        } else {
            // Назад с экрана сравнения → к выбору дублей.
            store.screen = .takes
        }
    }

    // MARK: - Target card (слово дня + эталон Ляли)

    private var targetCard: some View {
        HStack(spacing: SpacingTokens.small) {
            HSContentSymbol(store.illustrationSymbol, size: 34)
                .frame(width: 56, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .fill(ColorTokens.Kid.surfaceAlt)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "listenYourself.wordOfDay.label"))
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .textCase(.uppercase)
                highlightedWord
            }

            Spacer(minLength: 0)

            Button(action: { playReference() }) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                            .fill(ColorTokens.Brand.primaryLo.opacity(0.30))
                    )
            }
            .accessibilityLabel(String(localized: "listenYourself.playReference.a11y"))
        }
        .padding(SpacingTokens.small)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .fill(ColorTokens.Kid.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                        .stroke(ColorTokens.Kid.line, lineWidth: 1)
                )
        )
    }

    /// Слово с подсветкой целевой буквы (первое вхождение в верхнем регистре).
    private var highlightedWord: some View {
        let word = store.word
        let target = store.highlightLetter
        return HStack(spacing: 0) {
            ForEach(Array(word.enumerated()), id: \.offset) { _, ch in
                let isTarget = String(ch).uppercased() == target
                Text(String(ch))
                    .font(TypographyTokens.kidTitle(24))
                    .foregroundStyle(isTarget ? ColorTokens.Brand.primary : ColorTokens.Kid.ink)
            }
        }
        .accessibilityLabel(word)
    }

    // MARK: - Prompts

    private var takesPrompt: some View {
        VStack(spacing: SpacingTokens.micro) {
            Text(prompts.title)
                .font(TypographyTokens.kidTitle(20))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            Text(prompts.subtitle)
                .font(TypographyTokens.kidBody(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, SpacingTokens.micro)
    }

    private var prompts: (title: String, subtitle: String) {
        if !store.bothTakesReady {
            return (
                String(localized: "listenYourself.prompt.record.title"),
                String(localized: "listenYourself.prompt.record.subtitle")
            )
        }
        return (
            String(format: String(localized: "listenYourself.prompt.choose.title"), store.highlightLetter),
            String(localized: "listenYourself.prompt.choose.subtitle")
        )
    }

    private var recordingPrompt: some View {
        VStack(spacing: SpacingTokens.micro) {
            Text(String(format: String(localized: "listenYourself.prompt.recordingTake"), store.recordingTakeNumber ?? 1))
                .font(TypographyTokens.kidTitle(20))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
            Text(String(format: String(localized: "listenYourself.prompt.sayAgain"), store.word.lowercased()))
                .font(TypographyTokens.kidBody(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, SpacingTokens.tiny)
    }

    // MARK: - Takes row (две пластинки)

    private var takesRow: some View {
        HStack(spacing: SpacingTokens.small) {
            takeDisc(number: 1)
            takeDisc(number: 2)
        }
    }

    @ViewBuilder
    private func takeDisc(number: Int) -> some View {
        let recorded = store.takeDurations[number] != nil
        let selected = store.chosenTakeNumber == number
        Button(action: { chooseAndPlay(number) }) {
            VStack(spacing: SpacingTokens.tiny) {
                ZStack(alignment: .topLeading) {
                    VinylDisc(selected: selected, spinning: selected && !reduceMotion)
                        .frame(width: 96, height: 96)
                        .frame(maxWidth: .infinity)
                        .padding(.top, SpacingTokens.micro)

                    Text("\(number)")
                        .font(TypographyTokens.kidCardTitle(13))
                        .foregroundStyle(selected ? Color.white : ColorTokens.Kid.inkMuted)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle().fill(selected ? ColorTokens.Brand.primary : ColorTokens.Kid.surfaceAlt)
                        )

                    if selected {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.top, 3)
                    }
                }

                Text(store.takeDurations[number] ?? "0:00")
                    .font(TypographyTokens.kidCardTitle(15))
                    .foregroundStyle(ColorTokens.Kid.ink)

                Label(
                    String(format: String(localized: "listenYourself.take.play"), number),
                    systemImage: "play.fill"
                )
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Brand.primary)
                .labelStyle(.titleAndIcon)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.small)
            .padding(.horizontal, SpacingTokens.tiny)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                            .stroke(
                                selected ? ColorTokens.Brand.primary : ColorTokens.Kid.line,
                                lineWidth: selected ? 2 : 1.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!recorded)
        .opacity(recorded ? 1 : 0.4)
        .accessibilityLabel(
            recorded
                ? String(format: String(localized: "listenYourself.take.a11y"), number)
                : String(format: String(localized: "listenYourself.take.empty.a11y"), number)
        )
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(String(localized: "listenYourself.take.hint"))
    }

    // MARK: - Record primary button / again strip

    private var recordPrimaryButton: some View {
        HSButton(
            store.takeDurations.isEmpty
                ? String(localized: "listenYourself.cta.recordFirst")
                : String(localized: "listenYourself.cta.recordSecond"),
            icon: "mic.fill",
            action: { startRecording() }
        )
        .padding(.top, SpacingTokens.micro)
    }

    private var againStrip: some View {
        Button(action: { reRecord() }) {
            HStack(spacing: SpacingTokens.small) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                            .fill(ColorTokens.Kid.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                                    .stroke(ColorTokens.Kid.line, lineWidth: 1)
                            )
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text(String(localized: "listenYourself.again.title"))
                        .font(TypographyTokens.kidBody(13))
                        .foregroundStyle(ColorTokens.Kid.ink)
                    Text(String(localized: "listenYourself.again.subtitle"))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
                Spacer(minLength: 0)
            }
            .padding(SpacingTokens.small)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(ColorTokens.Kid.surfaceAlt)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                            .stroke(ColorTokens.Kid.line, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "listenYourself.again.a11y"))
    }

    // MARK: - Live mic section (запись)

    private var liveMicSection: some View {
        VStack(spacing: SpacingTokens.large) {
            ZStack {
                if !reduceMotion {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [ColorTokens.Brand.primary.opacity(0.28), .clear],
                                center: .center, startRadius: 8, endRadius: 74
                            )
                        )
                        .frame(width: 148, height: 148)
                        .scaleEffect(haloPulse ? 1.08 : 0.92)
                        .opacity(haloPulse ? 0.9 : 0.5)
                        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: haloPulse)
                }
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 104, height: 104)
                    .overlay(
                        Image(systemName: "mic.fill")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .shadow(color: ColorTokens.Brand.primary.opacity(0.4), radius: 14, y: 8)
            }
            .frame(height: 148)
            .accessibilityLabel(String(localized: "listenYourself.recording.a11y"))

            HSAudioWaveform(
                amplitudes: liveAmplitudes,
                style: .recording,
                tint: ColorTokens.Brand.primary,
                barCount: 13
            )
            .frame(height: 42)
            .accessibilityHidden(true)
        }
        .padding(.top, SpacingTokens.medium)
        .onAppear { haloPulse = true }
    }

    // MARK: - Mascot row

    private func mascotRow(message: String) -> some View {
        HStack(alignment: .bottom, spacing: SpacingTokens.small) {
            HSMascotView(mood: mascotMood, size: 56)
            HSSpeechBubble(message, maxWidth: 240)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.vertical, SpacingTokens.tiny)
    }

    private var mascotMood: MascotMood {
        if store.screen == .compare, store.judgement != nil { return .celebrating }
        if isRecording { return .thinking }
        if store.bothTakesReady { return .happy }
        return .encouraging
    }

    // MARK: - Bottom bar

    private func bottomBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        bar()
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.small)
    }

    private func errorNote(_ message: String) -> some View {
        Text(message)
            .font(TypographyTokens.kidBody(13))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(SpacingTokens.small)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(ColorTokens.Kid.surfaceAlt)
            )
    }

    // MARK: - Mascot copy

    private var takesMascotMessage: String {
        if isRecording { return String(format: String(localized: "listenYourself.mascot.listening"), store.word.lowercased()) }
        if store.bothTakesReady { return String(localized: "listenYourself.mascot.youChose") }
        return String(localized: "listenYourself.mascot.sayTwice")
    }

    private var compareMascotMessage: String {
        store.mascotMessage.isEmpty
            ? String(localized: "listenYourself.mascot.compareIntro")
            : store.mascotMessage
    }

    // MARK: - Actions

    private func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true

        let presenter = ListenYourselfPresenter(display: store)
        let worker = SelfCompareSessionWorker(
            audioService: container.audioService,
            asrService: container.asrService,
            scorer: container.pronunciationService,
            voiceService: container.personalVoiceService
        )
        let interactor = ListenYourselfInteractor(
            presenter: presenter,
            worker: worker,
            adaptivePlanner: container.adaptivePlannerService,
            childRepository: container.childRepository,
            childId: childId.isEmpty ? container.currentChildId : childId
        )
        self.interactor = interactor
        self.router = ListenYourselfRouter(exitAction: { exitGame() })

        let resolvedChildId = childId.isEmpty ? container.currentChildId : childId
        await interactor.loadWord(.init(childId: resolvedChildId))
    }

    private func teardown() {
        amplitudeTask?.cancel()
        amplitudeTask = nil
        interactor?.cancel()
        haloPulse = false
    }

    private func startRecording() {
        container.soundService.playUISound(.tap)
        startAmplitudeMonitor()
        Task { await interactor?.recordTake(.init()) }
    }

    private func reRecord() {
        container.soundService.playUISound(.tap)
        stopAmplitudeMonitor()
        interactor?.resetTakes()
    }

    private func chooseAndPlay(_ number: Int) {
        container.soundService.playUISound(.tap)
        interactor?.chooseTake(.init(takeNumber: number))
        Task { await interactor?.playTake(number: number) }
    }

    private func playReference() {
        container.soundService.playUISound(.tap)
        Task { await interactor?.playReference() }
    }

    private func playChosenTake() {
        guard let chosen = store.chosenTakeNumber else { return }
        container.soundService.playUISound(.tap)
        Task { await interactor?.playTake(number: chosen) }
    }

    func playCompareRow(isLyalya: Bool) {
        if isLyalya {
            playReference()
        } else {
            playChosenTake()
        }
    }

    private func goToCompare() {
        container.soundService.playUISound(.tap)
        stopAmplitudeMonitor()
        interactor?.goToCompare()
    }

    func selfJudge(_ option: ListenYourselfModels.SelfJudgement) {
        container.soundService.playUISound(.correct)
        container.hapticService.impact(.light)
        Task { await interactor?.judge(.init(judgement: option)) }
    }

    func revealSecret() {
        container.soundService.playUISound(.tap)
        Task { await interactor?.revealSecretTip(.init()) }
    }

    // MARK: - Live amplitude monitor

    private func startAmplitudeMonitor() {
        amplitudeTask?.cancel()
        amplitudeTask = Task { @MainActor in
            while !Task.isCancelled {
                guard isRecordingState() else {
                    liveAmplitudes = []
                    try? await Task.sleep(for: .milliseconds(80))
                    continue
                }
                // Реальные амплитуды микрофона из AudioService → живая волна.
                let snapshot = container.audioService.amplitudeBuffer()
                liveAmplitudes = snapshot.isEmpty ? [] : Array(snapshot.suffix(13))
                try? await Task.sleep(for: .milliseconds(60))
            }
        }
    }

    private func stopAmplitudeMonitor() {
        amplitudeTask?.cancel()
        amplitudeTask = nil
        liveAmplitudes = []
    }

    private func isRecordingState() -> Bool { store.recordingTakeNumber != nil }
}

// MARK: - VinylDisc

/// Виниловый диск-пластинка дубля (Ø96 в эталоне). Выбранный — крутится.
private struct VinylDisc: View {
    let selected: Bool
    let spinning: Bool

    @State private var angle: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    selected
                        ? ColorTokens.Brand.primaryLo.opacity(0.35)
                        : ColorTokens.Kid.surfaceAlt
                )
                .overlay(
                    Circle().stroke(
                        selected ? ColorTokens.Brand.primary : ColorTokens.Kid.line,
                        lineWidth: 2
                    )
                )
            // Концентрические бороздки.
            ForEach(1..<4) { i in
                Circle()
                    .stroke(
                        (selected ? ColorTokens.Brand.primary : ColorTokens.Kid.inkSoft).opacity(0.25),
                        lineWidth: 1
                    )
                    .padding(CGFloat(i) * 11)
            }
            // Центр-шпиндель с иконкой play.
            Circle()
                .fill(ColorTokens.Kid.surface)
                .overlay(Circle().stroke(
                    selected ? ColorTokens.Brand.primary : ColorTokens.Kid.line, lineWidth: 2))
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(selected ? ColorTokens.Brand.primary : ColorTokens.Kid.inkMuted)
                )
        }
        .rotationEffect(.degrees(angle))
        .onChange(of: spinning) { _, isSpinning in
            updateSpin(isSpinning)
        }
        .onAppear { updateSpin(spinning) }
    }

    private func updateSpin(_ isSpinning: Bool) {
        if isSpinning {
            withAnimation(.linear(duration: 4.5).repeatForever(autoreverses: false)) {
                angle = 360
            }
        } else {
            withAnimation(.none) { angle = 0 }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("ListenYourself") {
    ListenYourselfView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
