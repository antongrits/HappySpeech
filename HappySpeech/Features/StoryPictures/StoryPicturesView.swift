import OSLog
import SwiftUI

// MARK: - StoryPicturesView
//
// «Рассказ по серии картинок» — kid-игра связной речи по сюжетной серии
// (Глухов / Ткаченко). Три экрана:
//   1. order — drag-сетка перемешанных кадров серии → правильный порядок;
//      мягкая подсказка «Что было сначала?».
//   2. tell  — активный кадр крупно + опора-вопросы (Кто?/Что делает?/Чем
//      закончилось?), запись AudioService; ASRService + смысловые теги
//      отмечают названные звенья (галочки mint).
//   3. movie — плеер «мультика» (точки-кадры сверху) + радар-арка полноты
//      завязка→действие→развязка (mint — мелкий success-акцент); «Показать
//      маме» через parental gate.
//
// Архитектура: Clean Swift VIP, компоненты создаются один раз в bootstrap().
// Палитра тёплая (cream-фон); mint/gold — только мелкие семантические акценты.
// Reduced Motion уважается во всех анимациях. CTA min-height 60.

struct StoryPicturesView: View {

    // MARK: - Input

    let childId: String

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - VIP

    @State private var display = StoryPicturesDisplay()
    @State private var interactor: StoryPicturesInteractor?
    @State private var presenter: StoryPicturesPresenter?
    @State private var router: StoryPicturesRouter?
    @State private var bootstrapped = false

    // MARK: - Local UI state

    @State private var selectedTrayFrameId: String?
    @State private var celebrate = false
    @State private var showParentalGate = false
    @State private var showShareSheet = false

    private let logger = Logger(subsystem: "ru.happyspeech", category: "StoryPicturesView")

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()
            content
            if celebrate {
                HSConfettiView(preset: .celebration, isActive: $celebrate)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .task { await bootstrap() }
        .onDisappear { interactor?.cancel() }
        .onChange(of: display.pendingExit) { _, exit in
            if exit { router?.dismiss() }
        }
        .sheet(isPresented: $showParentalGate) {
            ParentalGate(isPresented: $showParentalGate) {
                showParentalGate = false
                showShareSheet = true
            }
        }
        .sheet(isPresented: $showShareSheet) {
            shareSheet
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(
            localized: "storyPictures.screen.a11y",
            defaultValue: "Рассказ по серии картинок: разложи по порядку и расскажи историю"
        ))
    }

    // MARK: - Content switch

    @ViewBuilder
    private var content: some View {
        switch display.phase {
        case .loading: loadingView
        case .order:   orderView
        case .tell:    tellView
        case .movie:   movieView
        }
    }

    // MARK: - Shared chrome

    private func topBar(title: String, subtitle: String, trailing: TopTrailing) -> some View {
        HStack(spacing: SpacingTokens.small) {
            Button { backOrExit() } label: {
                Image(systemName: display.phase == .order ? "xmark" : "chevron.left")
                    .font(TypographyTokens.headline(16).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(ColorTokens.Kid.surfaceAlt))
            }
            .accessibilityLabel(display.phase == .order
                ? String(localized: "common.close", defaultValue: "Выйти")
                : String(localized: "common.back", defaultValue: "Назад"))

            VStack(spacing: 2) {
                Text(title)
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(subtitle)
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)

            trailingButton(trailing)
        }
    }

    private enum TopTrailing { case hint, voice, share }

    @ViewBuilder
    private func trailingButton(_ kind: TopTrailing) -> some View {
        switch kind {
        case .hint:
            Button { speakMascotHint() } label: {
                topIcon("questionmark.circle")
            }
            .accessibilityLabel(String(localized: "storyPictures.hint.a11y", defaultValue: "Подсказка"))
        case .voice:
            Button { speakMascotHint() } label: {
                topIcon("speaker.wave.2.fill")
            }
            .accessibilityLabel(String(localized: "storyPictures.listenLyalya.a11y", defaultValue: "Послушать Лялю"))
        case .share:
            Button { showParentalGate = true } label: {
                topIcon("square.and.arrow.up")
            }
            .accessibilityLabel(String(localized: "storyPictures.share.a11y", defaultValue: "Поделиться"))
        }
    }

    private func topIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(TypographyTokens.headline(16).weight(.semibold))
            .foregroundStyle(ColorTokens.Brand.primary)
            .frame(width: 44, height: 44)
            .background(Circle().fill(ColorTokens.Kid.surfaceAlt))
    }

    private func mascotRow(text: String, state: LyalyaState) -> some View {
        HStack(alignment: .bottom, spacing: SpacingTokens.small) {
            LyalyaMascotView(state: reduceMotion ? .idle : state, size: 60)
                .accessibilityHidden(true)
            HSSpeechBubble(text, direction: .left, style: .lyalya, maxWidth: 240)
            Spacer(minLength: 0)
        }
    }

    private func hintBanner(_ text: String, success: Bool) -> some View {
        HStack(spacing: SpacingTokens.small) {
            Image(systemName: success ? "checkmark.seal.fill" : "lightbulb.fill")
                .font(TypographyTokens.headline(18))
                .foregroundStyle(success ? ColorTokens.Brand.mint : ColorTokens.Brand.primary)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: RadiusTokens.sm).fill(ColorTokens.Kid.surface))
                .overlay(RoundedRectangle(cornerRadius: RadiusTokens.sm).strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
            Text(text)
                .font(TypographyTokens.body(13).weight(.semibold))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.small)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .fill((success ? ColorTokens.Brand.mint : ColorTokens.Brand.primary).opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .strokeBorder((success ? ColorTokens.Brand.mint : ColorTokens.Brand.primary).opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(ColorTokens.Brand.primary)
                .scaleEffect(1.4)
            Text(String(localized: "storyPictures.loading", defaultValue: "Готовим историю…"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Screen 1: order

    private var orderView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.regular) {
                topBar(
                    title: display.isFilled && display.isOrderCorrect
                        ? String(localized: "storyPictures.order.title.done", defaultValue: "Порядок собран!")
                        : String(localized: "storyPictures.order.title", defaultValue: "Что было сначала?"),
                    subtitle: seriesSubtitle,
                    trailing: .hint
                )
                hintBanner(display.orderHintText, success: display.isFilled && display.isOrderCorrect)
                timelineSlots
                if !display.trayFrames.isEmpty {
                    trayCaption
                    trayRow
                }
                mascotRow(text: display.mascotText, state: display.isOrderCorrect ? .happy : .explaining)
                orderCTA
            }
            .padding(.horizontal, StoryPicturesMetrics.contentPadding)
            .padding(.top, SpacingTokens.tiny)
            .padding(.bottom, SpacingTokens.regular)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding(.bottom, SpacingTokens.small)
    }

    private var timelineSlots: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
            Text(String(localized: "storyPictures.timeline.cap", defaultValue: "Лента событий · 1 → \(display.frameCount)"))
                .font(TypographyTokens.headline(13).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
            HStack(spacing: SpacingTokens.tiny) {
                ForEach(display.slots) { slot in
                    StorySlotView(slot: slot, reduceMotion: reduceMotion) {
                        // Тап по заполненному слоту → снять кадр обратно в поднос.
                        if slot.frame != nil {
                            container.soundService.playUISound(.tap)
                            interactor?.removeFrame(slotIndex: slot.id)
                        } else if let fid = selectedTrayFrameId {
                            placeSelected(into: slot.id, frameId: fid)
                        }
                    }
                }
            }
        }
    }

    private var trayCaption: some View {
        Text(String(localized: "storyPictures.tray.cap", defaultValue: "Перетащи или нажми следующую картинку:"))
            .font(TypographyTokens.headline(13).weight(.bold))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var trayRow: some View {
        HStack(spacing: SpacingTokens.small) {
            ForEach(display.trayFrames) { frame in
                StoryTrayCard(
                    frame: frame,
                    isSelected: selectedTrayFrameId == frame.id,
                    reduceMotion: reduceMotion
                ) {
                    container.soundService.playUISound(.tap)
                    container.hapticService.selection()
                    // Тап: выбрать карточку → поставить в ближайший свободный слот.
                    if let next = display.nextSlotIndex {
                        placeSelected(into: next, frameId: frame.id)
                    } else {
                        selectedTrayFrameId = (selectedTrayFrameId == frame.id) ? nil : frame.id
                    }
                }
                .draggable(frame.id) {
                    StoryTrayCard(frame: frame, isSelected: true, reduceMotion: true, onTap: {})
                        .frame(width: 90, height: 100)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var orderCTA: some View {
        StoryPicturesCTA(
            title: display.isFilled && display.isOrderCorrect
                ? String(localized: "storyPictures.cta.tell", defaultValue: "Рассказать историю")
                : String(
                    format: String(localized: "storyPictures.cta.layout %lld", defaultValue: "Разложи все %lld картинки"),
                    display.frameCount
                ),
            icon: display.isFilled && display.isOrderCorrect ? "mic.fill" : "arrow.right",
            enabled: display.isFilled && display.isOrderCorrect
        ) {
            container.soundService.playUISound(.tap)
            container.hapticService.notification(.success)
            interactor?.confirmOrder()
        }
    }

    // MARK: - Screen 2: tell

    private var tellView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.regular) {
                topBar(
                    title: String(localized: "storyPictures.tell.title", defaultValue: "Расскажи историю"),
                    subtitle: String(
                        format: String(localized: "storyPictures.tell.sub %lld %lld", defaultValue: "Картинка %lld из %lld"),
                        display.tellFrameIndex + 1, display.frameCount
                    ),
                    trailing: .voice
                )
                filmstrip
                if let frame = display.tellFrame { bigPicture(frame) }
                supportsRow
                recBar
                mascotRow(text: display.mascotText, state: display.allFrameLinksNamed ? .encouraging : .explaining)
                tellControls
            }
            .padding(.horizontal, StoryPicturesMetrics.contentPadding)
            .padding(.top, SpacingTokens.tiny)
            .padding(.bottom, SpacingTokens.regular)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding(.bottom, SpacingTokens.small)
    }

    private var filmstrip: some View {
        HStack(spacing: SpacingTokens.tiny) {
            ForEach(Array(display.playerFramesForStrip.enumerated()), id: \.offset) { idx, frame in
                StoryFilmFrame(
                    frame: frame,
                    isCurrent: idx == display.tellFrameIndex,
                    isTold: frame.isTold
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func bigPicture(_ frame: StoryPicturesModels.TellFrameViewModel) -> some View {
        ZStack(alignment: .topLeading) {
            StorySceneView(scene: frame.scene, imageAsset: frame.imageAsset)
                .aspectRatio(1.6, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                        .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
                )

            Text(frame.badge)
                .font(TypographyTokens.headline(12).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, SpacingTokens.small)
                .padding(.vertical, SpacingTokens.tiny)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
                .padding(SpacingTokens.small)
        }
        .shadow(color: ColorTokens.Overlay.shadow.opacity(0.5), radius: 14, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(frame.badge)
    }

    private var supportsRow: some View {
        HStack(spacing: SpacingTokens.small) {
            ForEach(display.supports) { sup in
                StorySupportCard(support: sup)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var recBar: some View {
        HStack(spacing: SpacingTokens.small) {
            Circle()
                .fill(display.isRecording ? ColorTokens.Brand.primary : ColorTokens.Brand.mint)
                .frame(width: 13, height: 13)
                .scaleEffect(display.isRecording && !reduceMotion ? 1.15 : 1.0)
                .animation(
                    (display.isRecording && !reduceMotion)
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : nil,
                    value: display.isRecording
                )

            if display.isRecording {
                HSAudioWaveform(
                    amplitudes: reduceMotion ? Array(repeating: display.amplitude, count: 16) : [],
                    style: .recording,
                    tint: ColorTokens.Brand.primary,
                    barCount: 16
                )
                .frame(height: 24)
                Text(display.recordTimeLabel)
                    .font(TypographyTokens.headline(13).weight(.bold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .monospacedDigit()
            } else if display.allFrameLinksNamed {
                Text(String(localized: "storyPictures.tell.recorded", defaultValue: "Всё рассказано"))
                    .font(TypographyTokens.headline(13).weight(.bold))
                    .foregroundStyle(ColorTokens.Brand.mint)
                Spacer(minLength: 0)
            } else {
                Text(String(localized: "storyPictures.tell.tapToRecord", defaultValue: "Нажми и расскажи по картинке"))
                    .font(TypographyTokens.body(13).weight(.semibold))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
        }
        .padding(SpacingTokens.small)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .fill((display.allFrameLinksNamed && !display.isRecording ? ColorTokens.Brand.mint : ColorTokens.Brand.primary).opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .strokeBorder((display.allFrameLinksNamed && !display.isRecording ? ColorTokens.Brand.mint : ColorTokens.Brand.primary).opacity(0.25), lineWidth: 1)
        )
    }

    private var tellControls: some View {
        HStack(spacing: SpacingTokens.small) {
            Button { Task { await interactor?.toggleRecording() } } label: {
                Image(systemName: display.isRecording ? "stop.fill" : "mic.fill")
                    .font(TypographyTokens.headline(20).weight(.bold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(width: 60, height: 60)
                    .background(RoundedRectangle(cornerRadius: RadiusTokens.lg).fill(ColorTokens.Kid.surface))
                    .overlay(RoundedRectangle(cornerRadius: RadiusTokens.lg).strokeBorder(ColorTokens.Brand.primary, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(display.isRecording
                ? String(localized: "storyPictures.stopRec.a11y", defaultValue: "Остановить запись")
                : String(localized: "storyPictures.startRec.a11y", defaultValue: "Начать запись"))

            StoryPicturesCTA(
                title: isLastTellFrame
                    ? String(localized: "storyPictures.cta.buildMovie", defaultValue: "Собрать рассказ-мультик")
                    : String(localized: "storyPictures.cta.nextFrame", defaultValue: "Следующая картинка"),
                icon: isLastTellFrame ? "film.fill" : "arrow.right",
                enabled: true
            ) {
                container.soundService.playUISound(.tap)
                Task { await interactor?.nextTellFrame() }
            }
        }
    }

    private var isLastTellFrame: Bool {
        display.tellFrameIndex >= display.frameCount - 1
    }

    // MARK: - Screen 3: movie

    private var movieView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.regular) {
                topBar(title: display.movieTitle, subtitle: "«\(display.seriesTitle)»", trailing: .share)
                moviePlayer
                if let arc = display.arc { arcCard(arc) }
                if !display.pills.isEmpty { pillsRow }
                mascotRow(text: display.mascotText, state: display.isStoryComplete ? .celebrating : .encouraging)
                movieControls
            }
            .padding(.horizontal, StoryPicturesMetrics.contentPadding)
            .padding(.top, SpacingTokens.tiny)
            .padding(.bottom, SpacingTokens.regular)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding(.bottom, SpacingTokens.small)
    }

    private var moviePlayer: some View {
        ZStack {
            if let first = display.playerFrames.first {
                StorySceneView(scene: first.scene, imageAsset: first.imageAsset)
            }
            VStack {
                HStack(spacing: 5) {
                    ForEach(Array(display.playerFrames.enumerated()), id: \.offset) { idx, _ in
                        Circle()
                            .fill(.white.opacity(idx == 0 ? 1 : 0.4))
                            .frame(width: 9, height: 9)
                    }
                    Spacer()
                }
                .padding(SpacingTokens.small)
                Spacer()
            }
            Button { playMovie() } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 62, height: 62)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1.5))
            }
            .accessibilityLabel(String(localized: "storyPictures.playMovie.a11y", defaultValue: "Проиграть мультик"))
            VStack {
                Spacer()
                HStack {
                    Text("0:00").font(TypographyTokens.caption(11).weight(.bold)).foregroundStyle(.white)
                    Spacer()
                    Text(display.durationLabel).font(TypographyTokens.caption(11).weight(.bold)).foregroundStyle(.white)
                }
                .padding(SpacingTokens.small)
            }
        }
        .aspectRatio(1.66, contentMode: .fit)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous).strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
        .shadow(color: ColorTokens.Overlay.shadow.opacity(0.5), radius: 14, y: 8)
    }

    private func arcCard(_ arc: StoryPicturesModels.ArcViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            HStack {
                Image(systemName: "book.fill")
                    .font(TypographyTokens.headline(14))
                    .foregroundStyle(ColorTokens.Brand.primary)
                Text(String(localized: "storyPictures.arc.title", defaultValue: "Полнота рассказа"))
                    .font(TypographyTokens.headline(14).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Spacer()
                Text(arc.percentLabel)
                    .font(TypographyTokens.headline(14).weight(.black))
                    .foregroundStyle(arc.isComplete ? ColorTokens.Brand.mint : ColorTokens.Brand.gold)
            }
            HStack(alignment: .top, spacing: SpacingTokens.tiny) {
                ForEach(Array(arc.segments.enumerated()), id: \.element.id) { idx, seg in
                    StoryArcSegment(segment: seg, reduceMotion: reduceMotion)
                    if idx < arc.segments.count - 1 {
                        Rectangle()
                            .fill(ColorTokens.Kid.line)
                            .frame(width: 14, height: 2)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .padding(SpacingTokens.regular)
        .background(RoundedRectangle(cornerRadius: RadiusTokens.lg).fill(ColorTokens.Kid.surface))
        .overlay(RoundedRectangle(cornerRadius: RadiusTokens.lg).strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
        .shadow(color: ColorTokens.Overlay.shadow.opacity(0.3), radius: 8, y: 4)
    }

    private var pillsRow: some View {
        FlexibleHStack(spacing: SpacingTokens.tiny) {
            ForEach(display.pills) { pill in
                HStack(spacing: 5) {
                    Image(systemName: pill.isGold ? "star.fill" : "sparkles")
                        .font(.system(size: 11, weight: .bold))
                    Text(pill.text)
                        .font(TypographyTokens.headline(12).weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(pill.isGold ? ColorTokens.Brand.gold : ColorTokens.Brand.primary)
                .padding(.horizontal, SpacingTokens.small)
                .padding(.vertical, SpacingTokens.tiny)
                .background(
                    Capsule().fill((pill.isGold ? ColorTokens.Brand.gold : ColorTokens.Brand.primary).opacity(0.15))
                )
            }
        }
    }

    private var movieControls: some View {
        HStack(spacing: SpacingTokens.small) {
            Button { saveToDiary() } label: {
                Image(systemName: "bookmark.fill")
                    .font(TypographyTokens.headline(18).weight(.semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(width: 60, height: 60)
                    .background(RoundedRectangle(cornerRadius: RadiusTokens.lg).fill(ColorTokens.Kid.surface))
                    .overlay(RoundedRectangle(cornerRadius: RadiusTokens.lg).strokeBorder(ColorTokens.Brand.primary, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "storyPictures.saveDiary.a11y", defaultValue: "Сохранить в дневник"))

            StoryPicturesCTA(
                title: display.isStoryComplete
                    ? String(localized: "storyPictures.cta.showMom", defaultValue: "Показать маме")
                    : String(localized: "storyPictures.cta.tellEnd", defaultValue: "Дорассказать конец"),
                icon: display.isStoryComplete ? "square.and.arrow.up" : "mic.fill",
                enabled: true
            ) {
                if display.isStoryComplete {
                    showParentalGate = true
                } else {
                    returnToTellMissing()
                }
            }
        }
    }

    // MARK: - Share sheet (после parental gate)

    private var shareSheet: some View {
        VStack(spacing: SpacingTokens.large) {
            Capsule().fill(ColorTokens.Parent.line).frame(width: 40, height: 5).padding(.top, SpacingTokens.small)
            Image(systemName: "film.stack")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(ColorTokens.Brand.primary)
                .padding(.top, SpacingTokens.regular)
            Text(String(localized: "storyPictures.share.title", defaultValue: "Рассказ-мультик готов"))
                .font(TypographyTokens.title(20))
                .foregroundStyle(ColorTokens.Parent.ink)
            Text(String(
                format: String(localized: "storyPictures.share.body %@", defaultValue: "Серия «%@» с озвучкой ребёнка сохранена. Покажите её дома или отправьте специалисту из родительского кабинета."),
                display.seriesTitle
            ))
            .font(TypographyTokens.body(15))
            .foregroundStyle(ColorTokens.Parent.inkMuted)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .padding(.horizontal, SpacingTokens.large)
            Spacer()
            Button { showShareSheet = false } label: {
                Text(String(localized: "common.done", defaultValue: "Готово"))
                    .font(TypographyTokens.cta())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(RoundedRectangle(cornerRadius: RadiusTokens.lg).fill(ColorTokens.Brand.primary))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, SpacingTokens.large)
            .padding(.bottom, SpacingTokens.large)
        }
        .background(ColorTokens.Parent.bg.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Actions

    private func placeSelected(into slotIndex: Int, frameId: String) {
        container.soundService.playUISound(.tap)
        container.hapticService.selection()
        interactor?.placeFrame(.init(frameId: frameId, slotIndex: slotIndex))
        selectedTrayFrameId = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            if display.isFilled && display.isOrderCorrect {
                container.soundService.playUISound(.correct)
                container.hapticService.notification(.success)
                if !reduceMotion { celebrate = true }
            }
        }
    }

    private func speakMascotHint() {
        container.soundService.playUISound(.tap)
        let text = display.mascotText
        Task { @MainActor in
            await LessonVoiceWorker.shared.speak(text, lessonType: "story_pictures")
        }
    }

    private func playMovie() {
        container.soundService.playUISound(.tap)
        display.isPlaying = true
    }

    private func saveToDiary() {
        container.soundService.playUISound(.complete)
        container.hapticService.notification(.success)
    }

    private func returnToTellMissing() {
        container.soundService.playUISound(.tap)
        interactor?.loadTellFrame(.init(frameIndex: max(0, display.frameCount - 1)))
    }

    private func backOrExit() {
        container.soundService.playUISound(.tap)
        switch display.phase {
        case .tell:
            display.phase = .order
        case .movie:
            interactor?.loadTellFrame(.init(frameIndex: max(0, display.frameCount - 1)))
        default:
            display.pendingExit = true
        }
    }

    // MARK: - Computed

    private var seriesSubtitle: String {
        String(
            format: String(localized: "storyPictures.order.sub %@", defaultValue: "Серия «%@»"),
            display.seriesTitle
        )
    }

    // MARK: - Bootstrap

    @MainActor
    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        let age = await resolveChildAge()
        let presenter = StoryPicturesPresenter()
        let interactor = StoryPicturesInteractor(
            childId: childId,
            childAge: age,
            builder: StoryPicturesBuilder(),
            audioService: container.audioService,
            asrService: container.asrService,
            adaptivePlanner: container.adaptivePlannerService
        )
        let router = StoryPicturesRouter()

        interactor.presenter = presenter
        presenter.display = display

        self.presenter = presenter
        self.interactor = interactor
        self.router = router

        logger.info("bootstrap child=\(childId, privacy: .public) age=\(age, privacy: .public)")
        await interactor.start(.init(childId: childId))
    }

    private func resolveChildAge() async -> Int {
        do {
            let profile = try await container.childRepository.fetch(id: childId)
            return profile.age
        } catch {
            return 6
        }
    }
}

// MARK: - Display helpers (filmstrip / player ordering)

private extension StoryPicturesDisplay {
    /// Кадры для плёнки на экране рассказа — правильный порядок, с пометкой told.
    var playerFramesForStrip: [StoryPicturesModels.FrameViewModel] {
        orderedFrames.map { frame in
            StoryPicturesModels.FrameViewModel(
                id: frame.id,
                scene: frame.scene,
                imageAsset: frame.imageAsset,
                order: frame.order,
                isTold: toldFrameIds.contains(frame.id)
            )
        }
    }
}

// MARK: - Metrics

private enum StoryPicturesMetrics {
    /// Симметричный контентный отступ (open-design: 22pt).
    static let contentPadding: CGFloat = 22
}
