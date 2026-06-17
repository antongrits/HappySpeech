import AVFoundation
import SwiftUI

// MARK: - ARSoundHunterView (Clean Swift: View)
//
// Игра «Звуковой охотник по комнате». Камера задней стороны показывает комнату,
// Apple Vision классифицирует предмет в кадре. Когда найден предмет с целевым
// звуком — ребёнок называет его (запись), произношение оценивается on-device.
//
// Фоллбэк (нет задней камеры / iOS < 18 / нет доступа) — режим фото-карточек:
// ребёнок выбирает предмет из набора и называет его.

struct ARSoundHunterView: View {

    let childId: String

    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var interactor: ARSoundHunterInteractor?
    @State private var presenter: ARSoundHunterPresenter?
    @State private var router: ARSoundHunterRouter?
    @State private var display = ARSoundHunterDisplay()

    @State private var cameraSession: RoomCameraSession?
    @State private var classifier: (any VisionObjectClassifierWorkerProtocol)?

    init(childId: String) {
        self.childId = childId
    }

    var body: some View {
        ZStack {
            backgroundLayer
            contentLayer
            overlayHUD
        }
        .task { await bootstrap() }
        .onDisappear { teardown() }
        .navigationBarHidden(true)
        .background(ColorTokens.Kid.bgDeep.ignoresSafeArea())
    }

    // MARK: - Background (camera preview / fallback gradient)

    @ViewBuilder
    private var backgroundLayer: some View {
        if display.mode == .camera, let cameraSession {
            RoomCameraPreviewView(session: cameraSession.captureSession)
                .ignoresSafeArea()
                .accessibilityHidden(true)
        } else {
            ColorTokens.Kid.bg.ignoresSafeArea()
            HSMeshGradientBackground(palette: .kidWarm, animated: !reduceMotion)
                .ignoresSafeArea()
                .opacity(0.4)
                .blendMode(.softLight)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Content (prompt + cards / lock indicator)

    @ViewBuilder
    private var contentLayer: some View {
        VStack(spacing: SpacingTokens.medium) {
            Spacer()
            promptCard
            if display.mode == .photoCards, display.phase == .hunting {
                photoCardsGrid
                if let feedback = display.distractorFeedback {
                    distractorFeedbackBanner(feedback)
                } else {
                    // Гид-подсказка под сеткой: наполняет нижнюю часть экрана
                    // осмысленным содержанием (в фоллбэк-режиме фото-карточек
                    // их всего 4 → без подсказки низ оставался пустым) и явно
                    // направляет ребёнка нажать карточку, чтобы назвать предмет.
                    huntGuideHint
                }
            }
            if display.phase == .prompting || display.phase == .recording {
                nameItPanel
            }
            if display.phase == .scoring {
                ProgressView()
                    .tint(ColorTokens.Overlay.onAccent)
                    .padding(SpacingTokens.medium)
            }
            if display.phase == .roundComplete {
                resultPanel
            }
            Spacer()
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        // Резервируем высоту верхнего HUD (крестик + плашка заголовка), чтобы
        // центрируемый контент (промпт-карта «Найди и назови предмет…») не
        // налезал на хедер на компактных экранах.
        .padding(.top, hudReservedHeight)
    }

    /// Высота, под которой стартует контент, чтобы не пересекаться с `overlayHUD`.
    /// Кнопка-крестик HUD — 56pt + верхний отступ; плюс небольшой зазор.
    private var hudReservedHeight: CGFloat {
        56 + SpacingTokens.small + SpacingTokens.medium
    }

    // MARK: - Prompt card

    private var promptCard: some View {
        HSLiquidGlassCard(style: .elevated) {
            VStack(spacing: SpacingTokens.small) {
                HStack(spacing: SpacingTokens.tiny) {
                    Image(systemName: "magnifyingglass")
                        .font(TypographyTokens.headline())
                        .foregroundStyle(ColorTokens.Brand.mint)
                        .accessibilityHidden(true)
                    Text(display.targetSound)
                        .font(TypographyTokens.kidDisplay(48))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .accessibilityHidden(true)
                }
                Text(display.prompt)
                    .font(TypographyTokens.headline(17))
                    // Промпт-карта — светлое .elevated стекло; тёмный ink держит
                    // контраст в обеих темах (white сливался со светлым фоном).
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if display.mode == .camera, display.phase == .hunting {
                    lockProgressBar
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(display.prompt))
    }

    private var lockProgressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(ColorTokens.Overlay.highlight)
                Capsule()
                    .fill(ColorTokens.Brand.mint)
                    .frame(width: proxy.size.width * CGFloat(display.lockProgress))
            }
        }
        .frame(height: 12)
        .padding(.top, SpacingTokens.tiny)
        .accessibilityHidden(true)
    }

    // MARK: - Photo cards (fallback)

    private var photoCardsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: SpacingTokens.small),
                GridItem(.flexible(), spacing: SpacingTokens.small)
            ],
            spacing: SpacingTokens.small
        ) {
            ForEach(display.cards) { card in
                Button {
                    interactor?.selectCard(.init(cardId: card.id))
                } label: {
                    photoCard(card)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(card.word))
                .accessibilityHint(Text("arSoundHunter.card.hint"))
            }
        }
    }

    private func photoCard(_ card: ARSoundHunterModels.Card) -> some View {
        // Карточка-дистрактор после выбора подсвечивается мягким «не подходит»
        // контуром (без штрафа). Целевые/невыбранные — нейтральный surface.
        let isDistractorHighlighted = card.id == display.distractorCardId
        return VStack(spacing: SpacingTokens.tiny) {
            HSContentSymbol(card.assetName ?? "photo", size: 56)
            Text(card.word)
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.small)
        .background(ColorTokens.Kid.surface, in: RoundedRectangle(cornerRadius: RadiusTokens.md))
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .strokeBorder(
                    ColorTokens.Brand.gold,
                    lineWidth: isDistractorHighlighted ? 3 : 0
                )
        )
    }

    private func distractorFeedbackBanner(_ feedback: String) -> some View {
        HStack(spacing: SpacingTokens.tiny) {
            Image(systemName: "lightbulb.fill")
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Brand.gold)
                .accessibilityHidden(true)
            Text(feedback)
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SpacingTokens.small)
        .frame(maxWidth: .infinity)
        .background(ColorTokens.Overlay.dimmerHeavy, in: RoundedRectangle(cornerRadius: RadiusTokens.md))
        .accessibilityElement(children: .combine)
    }

    /// Гид-подсказка под сеткой фото-карточек (фоллбэк-режим). Маскот Ляля
    /// + дружелюбная инструкция «Выбери предмет, чтобы назвать его» —
    /// наполняет нижнюю зону экрана и помогает ребёнку понять, что делать.
    private var huntGuideHint: some View {
        HStack(spacing: SpacingTokens.small) {
            LyalyaMascotView(state: reduceMotion ? .idle : .pointing, size: 52)
                .accessibilityHidden(true)
            Text("arSoundHunter.card.hint")
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.small)
        .frame(maxWidth: .infinity)
        .background(ColorTokens.Overlay.dimmerHeavy, in: RoundedRectangle(cornerRadius: RadiusTokens.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("arSoundHunter.card.hint"))
    }

    // MARK: - Name-it panel (record voice)

    private var nameItPanel: some View {
        VStack(spacing: SpacingTokens.small) {
            Text(display.nameItPrompt)
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HSButton(
                display.phase == .recording
                    ? String(localized: "arSoundHunter.cta.listening")
                    : String(localized: "arSoundHunter.cta.sayWord"),
                style: .primary,
                icon: "mic.fill",
                isLoading: display.phase == .recording
            ) {
                Task { await recordAndScore() }
            }
            .accessibilityHint(Text("arSoundHunter.cta.sayWord.hint"))
        }
        .padding(SpacingTokens.medium)
        .background(ColorTokens.Overlay.dimmerHeavy, in: RoundedRectangle(cornerRadius: RadiusTokens.md))
    }

    // MARK: - Result panel

    private var resultPanel: some View {
        VStack(spacing: SpacingTokens.small) {
            HSStarRatingView(rating: display.stars, maxStars: 3, starSize: 34)
                .accessibilityLabel(Text(starsAccessibilityLabel))
            Text(display.feedback)
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HSButton(String(localized: "arSoundHunter.cta.huntMore"), style: .primary, icon: "arrow.right") {
                interactor?.nextRound(.init())
            }
        }
        .padding(SpacingTokens.medium)
        .background(ColorTokens.Overlay.dimmerHeavy, in: RoundedRectangle(cornerRadius: RadiusTokens.md))
        .overlay(alignment: .center) {
            // Конфетти только без Reduce Motion (Apple HIG).
            if !reduceMotion {
                HSConfettiView(preset: .celebration, isActive: $display.showConfetti)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    private var starsAccessibilityLabel: String {
        String(format: String(localized: "arSoundHunter.stars.a11y"), display.stars)
    }

    // MARK: - HUD

    private var overlayHUD: some View {
        VStack {
            ARGameHUD(
                title: "arSoundHunter.title",
                scoreText: display.totalFoundText,
                scoreIcon: display.totalFoundText == nil ? nil : "checkmark.seal.fill",
                onClose: { dismiss() }
            )
            Spacer()
        }
    }

    // MARK: - Bootstrap / teardown

    private func bootstrap() async {
        guard interactor == nil else { return }

        let worker: (any VisionObjectClassifierWorkerProtocol)
        do {
            worker = try VisionObjectClassifierWorker()
        } catch {
            // Маппинг недоступен — крайне маловероятно (ресурс в bundle). Mock не
            // даёт краша и оставляет режим фото-карточек со словами мока.
            worker = MockVisionObjectClassifierWorker()
        }
        self.classifier = worker

        let interactor = ARSoundHunterInteractor(
            classifier: worker,
            childRepository: container.childRepository
        )
        let presenter = ARSoundHunterPresenter()
        let router = ARSoundHunterRouter()
        interactor.presenter = presenter
        presenter.display = display
        router.dismiss = { dismiss() }
        self.interactor = interactor
        self.presenter = presenter
        self.router = router

        let cameraAvailable = await prepareCameraIfPossible()
        interactor.startGame(.init(
            childId: childId.isEmpty ? container.currentChildId : childId,
            cameraAvailable: cameraAvailable
        ))
    }

    /// Готовит заднюю камеру и запускает поток классификации, если возможно.
    /// Возвращает `false` → Interactor уйдёт в фоллбэк фото-карточек.
    private func prepareCameraIfPossible() async -> Bool {
        // iOS 17 fallback на фото-карточки — современный ClassifyImageRequest
        // доступен с iOS 18; для единообразия камеру включаем только на 18+.
        guard #available(iOS 18.0, *) else { return false }

        // Доступ к камере — через существующий ARService (room-hunting не требует
        // TrueDepth/face tracking, нужна только задняя камера + разрешение).
        let arService = container.arService
        let granted = arService.isCameraPermissionGranted
            ? true
            : await arService.requestCameraPermission()
        guard granted else { return false }

        let session = RoomCameraSession()
        // Захватываем reference-объекты (worker / interactor / display) — без self.
        let worker = self.classifier
        let display = self.display
        session.onPixelBuffer = { [weak interactor] pixelBuffer in
            // Эта closure вызывается на background-очереди RoomCameraSession.
            // CVPixelBuffer — CF-тип, не Sendable; перевозим через unchecked-обёртку.
            nonisolated(unsafe) let buffer = pixelBuffer
            Task { @MainActor [weak interactor] in
                // Классифицируем только пока ищем предмет — экономим ANE.
                guard display.phase == .hunting, let worker, let interactor else { return }
                let matches = (try? await worker.classify(
                    in: buffer,
                    targetSound: display.targetSound
                )) ?? []
                interactor.frameClassified(.init(matches: matches))
            }
        }
        guard session.start() else { return false }
        self.cameraSession = session
        return true
    }

    private func teardown() {
        cameraSession?.stop()
        cameraSession = nil
    }

    // MARK: - Record + score (on-device)

    @MainActor
    private func recordAndScore() async {
        guard display.phase != .recording, display.phase != .scoring else { return }
        let word = display.foundWord
        guard !word.isEmpty else { return }

        let audioService = container.audioService
        let scorer = container.pronunciationService
        let asr = container.asrService

        display.setPhase(.recording)

        if !audioService.isPermissionGranted {
            let granted = await audioService.requestPermission()
            guard granted else {
                interactor?.scoreNaming(.init(
                    word: word, transcript: "", asrConfidence: 0, pronunciationScore: .notScored
                ))
                return
            }
        }

        do {
            try await audioService.startRecording()
            // Короткая запись названия предмета (детский UX ~2.2 сек).
            try? await Task.sleep(for: .seconds(2.2))
            let url = try await audioService.stopRecording()
            display.setPhase(.scoring)

            // Параллельный on-device скоринг: произношение + ASR-распознавание.
            async let scoreCall = scorer.score(audioURL: url, targetSound: display.targetSound)
            async let asrCall = asr.transcribe(url: url, expectedWord: word, childAge: display.childAge)

            let score = (try? await scoreCall) ?? .notScored
            let asrResult = try? await asrCall

            interactor?.scoreNaming(.init(
                word: word,
                transcript: asrResult?.transcript ?? "",
                asrConfidence: asrResult?.confidence ?? 0,
                pronunciationScore: score
            ))
        } catch {
            interactor?.scoreNaming(.init(
                word: word, transcript: "", asrConfidence: 0, pronunciationScore: .notScored
            ))
        }
    }
}

// MARK: - ARSoundHunterDisplay (Observable view-state)

@Observable
@MainActor
final class ARSoundHunterDisplay: ARSoundHunterDisplayLogic {

    var targetSound: String = ""
    var prompt: String = ""
    var nameItPrompt: String = ""
    var mode: ARSoundHunterModels.Mode = .camera
    var phase: ARSoundHunterModels.Phase = .hunting
    var cards: [ARSoundHunterModels.Card] = []
    var lockProgress: Float = 0
    var foundWord: String = ""
    var stars: Int = 0
    var feedback: String = ""
    var totalFoundText: String?
    var showConfetti: Bool = false
    var childAge: Int = 6
    /// Мягкий фидбэк при выборе карточки-дистрактора (без целевого звука).
    var distractorFeedback: String?
    /// id карточки, подсвеченной как «не подходит» (выбран дистрактор).
    var distractorCardId: String?

    func setPhase(_ newPhase: ARSoundHunterModels.Phase) { phase = newPhase }

    // MARK: - DisplayLogic

    func displayStartGame(_ viewModel: ARSoundHunterModels.StartGame.ViewModel) {
        targetSound = viewModel.targetSound
        prompt = viewModel.prompt
        mode = viewModel.mode
        cards = viewModel.cards
        phase = .hunting
        lockProgress = 0
    }

    func displayFrameClassified(_ viewModel: ARSoundHunterModels.FrameClassified.ViewModel) {
        lockProgress = viewModel.lockProgress
        if viewModel.shouldPrompt, let word = viewModel.foundWord {
            foundWord = word
            nameItPrompt = String(format: String(localized: "arSoundHunter.prompt.nameIt"), word)
            phase = .prompting
        }
    }

    func displaySelectCard(_ viewModel: ARSoundHunterModels.SelectCard.ViewModel) {
        // Дистрактор: показываем мягкий фидбэк и подсветку, остаёмся в поиске,
        // ребёнок продолжает выбирать. Без перехода к называнию.
        if let feedback = viewModel.distractorFeedback {
            distractorFeedback = feedback
            distractorCardId = viewModel.distractorCardId
            phase = .hunting
            return
        }
        guard let word = viewModel.word, let prompt = viewModel.prompt else { return }
        distractorFeedback = nil
        distractorCardId = nil
        foundWord = word
        nameItPrompt = prompt
        phase = .prompting
    }

    func displayScoreNaming(_ viewModel: ARSoundHunterModels.ScoreNaming.ViewModel) {
        stars = viewModel.stars
        feedback = viewModel.feedback
        foundWord = viewModel.foundWord
        phase = .roundComplete
        showConfetti = viewModel.isSuccess
    }

    func displayNextRound(_ viewModel: ARSoundHunterModels.NextRound.ViewModel) {
        totalFoundText = viewModel.totalFoundText
        stars = 0
        feedback = ""
        foundWord = ""
        lockProgress = 0
        showConfetti = false
        phase = .hunting
    }

    func displayRetry(foundWord: String) {
        self.foundWord = foundWord
        nameItPrompt = String(localized: "arSoundHunter.feedback.didntHear")
        phase = .prompting
    }
}

// MARK: - RoomCameraPreviewView (AVCaptureVideoPreviewLayer)

/// SwiftUI-обёртка над `AVCaptureVideoPreviewLayer` для задней камеры.
private struct RoomCameraPreviewView: UIViewRepresentable {

    let session: AVCaptureSession

    func makeUIView(context _: Context) -> UIView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: UIView, context _: Context) {
        guard let preview = uiView as? PreviewView else { return }
        if preview.videoPreviewLayer.session !== session {
            preview.videoPreviewLayer.session = session
        }
    }

    final class PreviewView: UIView {
        // swiftlint:disable:next static_over_final_class
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        // swiftlint:disable:next force_cast
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - Preview

#Preview {
    ARSoundHunterView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
