import OSLog
import SwiftUI

// MARK: - TongueTwistersView
//
// «Чистоговорки-конструктор» — kid-игра автоматизации звука во фразе с ритмом.
// Стадии (см. open-design kid-game-tongue-twisters-1/2.html):
//   1. rhyme — «Собери чистоговорку»: слоговая разминка (BeatPillRow с золотыми
//      ритм-точками) + строка с пропуском-рифмой (BlankSlot) + 3 картинки-ответа.
//   2. say   — «Скажи целиком»: рифма выбрана, крупная кнопка записи + мягкий
//      ASR-статус-пилл «слышу звук С».
//   3. train — «Поезд из слов»: вагончики наращивания (done=mint, now=коралл,
//      locked=opacity), под поездом — золотая награда при сборке.
//
// Метроном — переиспользуемый движок StutteringModule; мягкий, замедляемый,
// ОТКЛЮЧАЕМЫЙ (для заикающихся — без таймера). Целевой звук — коралл, выделяется
// в каждом вхождении. Палитра тёплая (cream-фон). Reduced Motion уважается.

struct TongueTwistersView: View {

    // MARK: - Input

    let childId: String

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - VIP

    @State private var display = TongueTwistersDisplay()
    @State private var interactor: TongueTwistersInteractor?
    @State private var presenter: TongueTwistersPresenter?
    @State private var router: TongueTwistersRouter?
    @State private var bootstrapped = false
    @State private var celebrate = false

    private let logger = Logger(subsystem: "ru.happyspeech", category: "TongueTwistersView")

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
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(
            localized: "tongueTwisters.screen.a11y",
            defaultValue: "Чистоговорки: собери и проговори чистоговорку под ритм"
        ))
    }

    // MARK: - Content switch

    @ViewBuilder
    private var content: some View {
        switch display.phase {
        case .loading:   loadingView
        case .rhyme:     rhymeView
        case .say:       sayView
        case .train:     trainView
        case .completed: completedView
        }
    }

    // MARK: - Shared chrome

    private func topBar(title: String, subtitle: String) -> some View {
        HStack(spacing: SpacingTokens.small) {
            Button { exit() } label: {
                Image(systemName: "xmark")
                    .font(TypographyTokens.headline(16).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(ColorTokens.Kid.surfaceAlt))
            }
            .accessibilityLabel(String(localized: "common.close", defaultValue: "Выйти"))

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

            Button { interactor?.playModel() } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(TypographyTokens.headline(16).weight(.semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(ColorTokens.Kid.surfaceAlt))
            }
            .accessibilityLabel(String(localized: "tongueTwisters.replay.a11y", defaultValue: "Послушать чистоговорку"))
        }
    }

    private var progressBar: some View {
        VStack(spacing: SpacingTokens.tiny) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(ColorTokens.Kid.line)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * progressFraction)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: progressFraction)
                }
            }
            .frame(height: 9)

            Text(String(
                format: String(localized: "tongueTwisters.progress %lld %lld %@",
                               defaultValue: "Чистоговорка %lld из %lld · звук %@"),
                display.phraseIndex + 1, display.totalPhrases, display.targetSound.uppercased()
            ))
            .font(TypographyTokens.body(13).weight(.semibold))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(
            format: String(localized: "tongueTwisters.progress.a11y %lld %lld",
                           defaultValue: "Чистоговорка %lld из %lld"),
            display.phraseIndex + 1, display.totalPhrases
        ))
    }

    private var progressFraction: CGFloat {
        guard display.totalPhrases > 0 else { return 0 }
        return CGFloat(display.phraseIndex + 1) / CGFloat(display.totalPhrases)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(ColorTokens.Brand.primary)
                .scaleEffect(1.4)
            Text(String(localized: "tongueTwisters.loading", defaultValue: "Готовим чистоговорки…"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Stage 1: rhyme

    private var rhymeView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.regular) {
                topBar(
                    title: String(localized: "tongueTwisters.rhyme.title", defaultValue: "Собери чистоговорку"),
                    subtitle: String(localized: "tongueTwisters.rhyme.subtitle", defaultValue: "Договори словечко в рифму")
                )
                progressBar
                BeatPillRow(
                    syllable: display.warmupSyllable,
                    beats: display.warmupBeats,
                    activeBeat: display.metronomeOn ? display.activeBeat : 0,
                    metronomeOn: display.metronomeOn,
                    reduceMotion: reduceMotion
                )
                phraseCard(showBlank: true)
                answersRow
                metronomeRow
                mascotRow(text: rhymeMascotText, state: .explaining)
            }
            .padding(.horizontal, TongueTwistersMetrics.contentPadding)
            .padding(.top, SpacingTokens.tiny)
            .padding(.bottom, SpacingTokens.regular)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding(.bottom, SpacingTokens.small)
    }

    private var answersRow: some View {
        HStack(spacing: SpacingTokens.small) {
            ForEach(display.answers) { answer in
                AnswerChip(
                    answer: answer,
                    isSelected: display.selectedAnswerId == answer.id,
                    reduceMotion: reduceMotion
                ) {
                    handleRhymePick(answer)
                }
            }
        }
    }

    private var rhymeMascotText: String {
        if !display.feedbackText.isEmpty { return display.feedbackText }
        return String(
            format: String(localized: "tongueTwisters.mascot.rhyme %@",
                           defaultValue: "Что звучит в рифму на звук %@? Скажи всю чистоговорку под стук!"),
            display.targetSound.uppercased()
        )
    }

    // MARK: - Stage 2: say (запись + ASR)

    private var sayView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.regular) {
                topBar(
                    title: String(localized: "tongueTwisters.say.title", defaultValue: "Скажи целиком"),
                    subtitle: String(localized: "tongueTwisters.say.subtitle", defaultValue: "Рифма найдена — повтори под ритм")
                )
                progressBar
                BeatPillRow(
                    syllable: display.warmupSyllable,
                    beats: display.warmupBeats,
                    activeBeat: display.metronomeOn ? display.activeBeat : 0,
                    metronomeOn: display.metronomeOn,
                    reduceMotion: reduceMotion
                )
                phraseCard(showBlank: false)
                recordBlock
                metronomeRow
                mascotRow(text: sayMascotText, state: display.soundHeard ? .celebrating : .encouraging)
                TongueTwistersCTA(
                    title: String(localized: "tongueTwisters.cta.toTrain", defaultValue: "Собрать поезд из слов"),
                    icon: "arrow.right"
                ) {
                    container.soundService.playUISound(.tap)
                    container.hapticService.selection()
                    interactor?.enterTrain()
                }
            }
            .padding(.horizontal, TongueTwistersMetrics.contentPadding)
            .padding(.top, SpacingTokens.tiny)
            .padding(.bottom, SpacingTokens.regular)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding(.bottom, SpacingTokens.small)
    }

    private var recordBlock: some View {
        VStack(spacing: SpacingTokens.small) {
            RecordButton(
                isRecording: display.isRecording,
                reduceMotion: reduceMotion
            ) {
                handleRecord()
            }
            Text(display.isRecording
                 ? String(localized: "tongueTwisters.record.active", defaultValue: "Слушаю тебя…")
                 : String(localized: "tongueTwisters.record.prompt", defaultValue: "Нажми и проговори чистоговорку"))
                .font(TypographyTokens.headline(15).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            if display.showStatus, !display.statusText.isEmpty {
                statusPill
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var statusPill: some View {
        HStack(spacing: SpacingTokens.tiny) {
            Circle()
                .fill(display.soundHeard ? ColorTokens.Brand.primary : ColorTokens.Kid.inkSoft)
                .frame(width: 8, height: 8)
            Text(display.statusText)
                .font(TypographyTokens.body(12).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, SpacingTokens.small)
        .padding(.vertical, 6)
        .background(Capsule().fill(ColorTokens.Kid.surfaceAlt))
        .overlay(Capsule().strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
        .transition(.opacity)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: display.statusText)
        .accessibilityLabel(display.statusText)
    }

    private var sayMascotText: String {
        if display.showStatus, display.soundHeard {
            return String(
                format: String(localized: "tongueTwisters.mascot.sayGood %@",
                               defaultValue: "Здорово! Звук %@ прозвучал чисто. Скажешь ещё разок?"),
                display.targetSound.uppercased()
            )
        }
        return String(localized: "tongueTwisters.mascot.say",
                      defaultValue: "Нажми кнопку и скажи всю чистоговорку. Я послушаю!")
    }

    // MARK: - Stage 3: train (наращивание / вагончики)

    private var trainView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.regular) {
                topBar(
                    title: allWagonsDone
                        ? String(localized: "tongueTwisters.train.titleDone", defaultValue: "Поезд готов!")
                        : String(localized: "tongueTwisters.train.title", defaultValue: "Поезд из слов"),
                    subtitle: allWagonsDone
                        ? String(localized: "tongueTwisters.train.subDone", defaultValue: "Вся чистоговорка собрана")
                        : String(localized: "tongueTwisters.train.sub", defaultValue: "Строчка растёт вагон за вагоном")
                )
                wagonDots
                trainStack
                if allWagonsDone {
                    rewardBanner
                }
                mascotRow(text: trainMascotText, state: allWagonsDone ? .celebrating : .explaining)
                TongueTwistersCTA(
                    title: allWagonsDone
                        ? (isLastPhrase
                            ? String(localized: "tongueTwisters.cta.finish", defaultValue: "Завершить")
                            : String(localized: "tongueTwisters.cta.next", defaultValue: "Следующая чистоговорка"))
                        : String(localized: "tongueTwisters.cta.sayLine", defaultValue: "Сказать строчку"),
                    icon: allWagonsDone ? "arrow.right" : "mic.fill"
                ) {
                    handleTrainCTA()
                }
            }
            .padding(.horizontal, TongueTwistersMetrics.contentPadding)
            .padding(.top, SpacingTokens.tiny)
            .padding(.bottom, SpacingTokens.regular)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding(.bottom, SpacingTokens.small)
        .onChange(of: allWagonsDone) { _, done in
            if done, !reduceMotion { celebrate = true }
            if done { container.hapticService.notification(.success) }
        }
    }

    private var wagonDots: some View {
        VStack(spacing: SpacingTokens.tiny) {
            HStack(spacing: SpacingTokens.small) {
                ForEach(Array(display.wagons.enumerated()), id: \.offset) { idx, _ in
                    let isDone = display.state(at: idx) == .done
                    let isNow = display.state(at: idx) == .now
                    Circle()
                        .fill(isDone || isNow ? ColorTokens.Brand.primary : ColorTokens.Kid.line)
                        .frame(width: isNow ? 13 : 9, height: isNow ? 13 : 9)
                }
            }
            Text(String(
                format: String(localized: "tongueTwisters.wagon.count %lld %lld %@",
                               defaultValue: "Вагон %lld из %lld · звук %@"),
                min((display.currentWagonIndex ?? display.wagons.count) + (allWagonsDone ? 0 : 1), display.wagons.count),
                display.wagons.count, display.targetSound.uppercased()
            ))
            .font(TypographyTokens.body(13).weight(.semibold))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(
            format: String(localized: "tongueTwisters.wagon.a11y %lld %lld",
                           defaultValue: "Вагонов собрано из %lld: %lld"),
            display.wagons.count, doneWagonCount
        ))
    }

    private var trainStack: some View {
        VStack(spacing: SpacingTokens.small) {
            ForEach(Array(display.wagons.enumerated()), id: \.element.id) { idx, wagon in
                WagonRow(
                    wagon: wagon,
                    index: idx,
                    state: display.state(at: idx),
                    targetSound: display.targetSound,
                    reduceMotion: reduceMotion,
                    onListen: {
                        container.soundService.playUISound(.tap)
                        interactor?.playWagon(index: idx)
                    }
                )
            }
        }
    }

    private var rewardBanner: some View {
        HStack(spacing: SpacingTokens.regular) {
            ZStack {
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(LinearGradient(
                        colors: [ColorTokens.Brand.butter, ColorTokens.Brand.gold],
                        startPoint: .top, endPoint: .bottom
                    ))
                Image(systemName: "star.fill")
                    .font(TypographyTokens.title(26).weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 54, height: 54)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "tongueTwisters.reward.title", defaultValue: "Чистоговорка целиком!"))
                    .font(TypographyTokens.title(17).weight(.black))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                Text(String(
                    format: String(localized: "tongueTwisters.reward.sub %@",
                                   defaultValue: "Звук %@ прозвучал чисто во всех словах"),
                    display.targetSound.uppercased()
                ))
                .font(TypographyTokens.body(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.regular)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .fill(LinearGradient(
                    colors: [ColorTokens.Brand.butter.opacity(0.28), ColorTokens.Kid.surface],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .strokeBorder(ColorTokens.Brand.gold.opacity(0.35), lineWidth: 1)
        )
        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7), value: allWagonsDone)
    }

    private var trainMascotText: String {
        if allWagonsDone {
            return String(
                format: String(localized: "tongueTwisters.mascot.trainDone %@",
                               defaultValue: "Ура! Поезд из слов поехал — ты сказал звук %@ в длинной фразе!"),
                display.targetSound.uppercased()
            )
        }
        let line = currentWagonText
        return String(
            format: String(localized: "tongueTwisters.mascot.train %@",
                           defaultValue: "Теперь строчка: «%@». Скажи её целиком!"),
            line
        )
    }

    private var currentWagonText: String {
        guard let idx = display.currentWagonIndex, display.wagons.indices.contains(idx) else {
            return display.wagons.last?.text ?? ""
        }
        return display.wagons[idx].text
    }

    // MARK: - Completed

    private var completedView: some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer()
            starsRow
            Text(display.scoreLabel)
                .font(TypographyTokens.title(28))
                .foregroundStyle(ColorTokens.Kid.ink)
                .monospacedDigit()
            Text(display.completionMessage)
                .font(TypographyTokens.body(17))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, SpacingTokens.xLarge)
            Spacer()
        }
        .padding(.horizontal, TongueTwistersMetrics.contentPadding)
        .padding(.bottom, SpacingTokens.sp16)
        .safeAreaInset(edge: .bottom) {
            TongueTwistersCTA(
                title: String(localized: "tongueTwisters.cta.done", defaultValue: "Готово"),
                icon: "checkmark.circle.fill"
            ) {
                finalize()
            }
            .padding(.horizontal, TongueTwistersMetrics.contentPadding)
            .padding(.bottom, SpacingTokens.small)
            .accessibilityIdentifier("gameNextButton")
        }
        .onAppear {
            if !reduceMotion { celebrate = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "tongueTwisters.completed.a11y", defaultValue: "Игра завершена"))
    }

    private var starsRow: some View {
        HStack(spacing: SpacingTokens.small) {
            ForEach(0..<3, id: \.self) { idx in
                Image(systemName: idx < display.starsEarned ? "star.fill" : "star")
                    .font(TypographyTokens.display(44).weight(.semibold))
                    .foregroundStyle(idx < display.starsEarned ? ColorTokens.Brand.butter : ColorTokens.Kid.line)
                    .scaleEffect(idx < display.starsEarned ? 1.0 : 0.85)
                    .animation(reduceMotion ? nil
                               : .spring(response: 0.5, dampingFraction: 0.65).delay(Double(idx) * 0.12),
                               value: display.starsEarned)
            }
        }
        .accessibilityLabel(String(
            format: String(localized: "tongueTwisters.stars.a11y %lld", defaultValue: "Получено звёзд: %lld из 3"),
            display.starsEarned
        ))
    }

    // MARK: - Phrase card (строка с пропуском / собранная)

    private func phraseCard(showBlank: Bool) -> some View {
        VStack(spacing: SpacingTokens.small) {
            Text(showBlank
                 ? String(localized: "tongueTwisters.card.listen", defaultValue: "ПОСЛУШАЙ И ПОВТОРИ")
                 : String(localized: "tongueTwisters.card.sayAll", defaultValue: "СКАЖИ ВСЮ СТРОЧКУ"))
                .font(TypographyTokens.body(12).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .tracking(1)

            phraseLine(showBlank: showBlank)
                .multilineTextAlignment(.center)

            Button { interactor?.playModel() } label: {
                HStack(spacing: SpacingTokens.tiny) {
                    Image(systemName: display.isPlaying ? "waveform" : "speaker.wave.2.fill")
                        .font(TypographyTokens.body(14).weight(.semibold))
                        .symbolEffect(.variableColor, isActive: display.isPlaying && !reduceMotion)
                    Text(showBlank
                         ? String(localized: "tongueTwisters.replay.more", defaultValue: "Послушать ещё раз")
                         : String(localized: "tongueTwisters.replay.model", defaultValue: "Послушать образец"))
                        .font(TypographyTokens.headline(14).weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(ColorTokens.Brand.primary)
                .padding(.horizontal, SpacingTokens.regular)
                .padding(.vertical, SpacingTokens.small)
                .background(Capsule().fill(ColorTokens.Brand.primaryLo.opacity(0.35)))
                .overlay(Capsule().strokeBorder(ColorTokens.Brand.primary.opacity(0.28), lineWidth: 1.5))
            }
            .accessibilityLabel(String(localized: "tongueTwisters.replay.a11y", defaultValue: "Послушать чистоговорку"))
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.large)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .fill(ColorTokens.Kid.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
        )
        .shadow(color: ColorTokens.Overlay.shadow.opacity(0.5), radius: 14, y: 8)
    }

    @ViewBuilder
    private func phraseLine(showBlank: Bool) -> some View {
        VStack(spacing: 6) {
            // Пролог-строка с подсвеченным целевым звуком («Са-са-са —»).
            Text(highlightedTarget(display.linePrefix))
                .font(TypographyTokens.display(26).weight(.black))
            // Хвост строки + пропуск или собранное слово.
            HStack(spacing: 6) {
                Text(display.lineSuffix)
                    .font(TypographyTokens.display(26).weight(.black))
                    .foregroundStyle(ColorTokens.Kid.ink)
                if showBlank {
                    BlankSlot(filled: display.filledWord)
                } else {
                    HStack(spacing: 4) {
                        Text(highlightedTarget(display.answerWord))
                            .font(TypographyTokens.display(26).weight(.black))
                        Image(systemName: "checkmark.circle.fill")
                            .font(TypographyTokens.headline(18))
                            .foregroundStyle(ColorTokens.Feedback.correct)
                    }
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(showBlank
            ? String(format: String(localized: "tongueTwisters.line.blank.a11y %@ %@",
                                     defaultValue: "%@ %@ пропуск"), display.linePrefix, display.lineSuffix)
            : String(format: String(localized: "tongueTwisters.line.full.a11y %@",
                                     defaultValue: "Чистоговорка: %@"), display.linePrefix + " " + display.lineSuffix + " " + display.answerWord))
    }

    /// Подсвечивает целевой звук кораллом в каждом вхождении (без регистра).
    private func highlightedTarget(_ text: String) -> AttributedString {
        var attr = AttributedString(text)
        attr.foregroundColor = ColorTokens.Kid.ink
        let sound = display.targetSound.lowercased()
            .replacingOccurrences(of: "ь", with: "")
            .replacingOccurrences(of: "'", with: "")
        guard let first = sound.first else { return attr }
        let lowerVariants = [String(first), String(first).uppercased()]
        for variant in lowerVariants {
            var searchRange = attr.startIndex..<attr.endIndex
            while let r = attr[searchRange].range(of: variant) {
                attr[r].foregroundColor = ColorTokens.Brand.primary
                searchRange = r.upperBound..<attr.endIndex
            }
        }
        return attr
    }

    // MARK: - Metronome row (опционален, замедляем)

    private var metronomeRow: some View {
        HStack(spacing: SpacingTokens.small) {
            ZStack {
                RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                    .fill(ColorTokens.Brand.gold.opacity(0.16))
                Image(systemName: "metronome.fill")
                    .font(TypographyTokens.headline(18))
                    .foregroundStyle(ColorTokens.Brand.gold)
                    .symbolEffect(.bounce, value: display.metronomeOn ? display.activeBeat : 0)
            }
            .frame(width: 38, height: 38)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(display.metronomeOn
                     ? String(localized: "tongueTwisters.metro.on", defaultValue: "Метроном: спокойно")
                     : String(localized: "tongueTwisters.metro.off", defaultValue: "Метроном выключен"))
                    .font(TypographyTokens.headline(14).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(display.metronomeOn
                     ? String(localized: "tongueTwisters.metro.onSub", defaultValue: "Ритм мягкий, можно замедлить")
                     : String(localized: "tongueTwisters.metro.offSub", defaultValue: "Говори в своём темпе"))
                    .font(TypographyTokens.body(12).weight(.semibold))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)

            if display.metronomeOn {
                Button { interactor?.slowDownMetronome() } label: {
                    Image(systemName: "tortoise.fill")
                        .font(TypographyTokens.body(15).weight(.semibold))
                        .foregroundStyle(ColorTokens.Brand.gold)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(ColorTokens.Brand.gold.opacity(0.14)))
                }
                .accessibilityLabel(String(localized: "tongueTwisters.metro.slow.a11y", defaultValue: "Замедлить ритм"))
            }

            Toggle("", isOn: Binding(
                get: { display.metronomeOn },
                set: { _ in interactor?.toggleMetronome() }
            ))
            .labelsHidden()
            .tint(ColorTokens.Brand.gold)
            .accessibilityLabel(String(localized: "tongueTwisters.metro.toggle.a11y", defaultValue: "Метроном — включить или выключить ритм"))
        }
        .padding(.horizontal, SpacingTokens.regular)
        .padding(.vertical, SpacingTokens.small)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .fill(ColorTokens.Kid.surfaceAlt)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
        )
    }

    // MARK: - Mascot row

    private func mascotRow(text: String, state: LyalyaState) -> some View {
        HStack(alignment: .bottom, spacing: SpacingTokens.small) {
            LyalyaMascotView(state: reduceMotion ? .idle : state, size: 64)
                .accessibilityHidden(true)
            HSSpeechBubble(text, direction: .left, style: .lyalya, maxWidth: 240)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Derived state

    private var allWagonsDone: Bool {
        !display.wagons.isEmpty && display.currentWagonIndex == nil
            && display.wagonStates.allSatisfy { $0 == .done }
    }

    private var doneWagonCount: Int {
        display.wagonStates.filter { $0 == .done }.count
    }

    private var isLastPhrase: Bool {
        display.phraseIndex + 1 >= display.totalPhrases
    }

    // MARK: - Actions

    private func handleRhymePick(_ answer: RhymeAnswer) {
        container.soundService.playUISound(.tap)
        container.hapticService.selection()
        interactor?.chooseRhyme(.init(answerId: answer.id))
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(160))
            if display.rhymeCorrect {
                container.soundService.playUISound(.correct)
                container.hapticService.notification(.success)
            } else {
                container.soundService.playUISound(.incorrect)
                container.hapticService.notification(.warning)
            }
        }
    }

    private func handleRecord() {
        guard !display.isRecording else { return }
        container.soundService.playUISound(.tap)
        container.hapticService.impact(.medium)
        Task { @MainActor in
            await interactor?.recordAndCheck()
            if display.soundHeard {
                container.hapticService.notification(.success)
            }
        }
    }

    private func handleTrainCTA() {
        if allWagonsDone {
            container.soundService.playUISound(.tap)
            container.hapticService.selection()
            Task { await interactor?.advancePhrase() }
        } else {
            // «Сказать строчку» — подтверждаем текущий вагон (наращивание).
            guard let idx = display.currentWagonIndex else { return }
            container.soundService.playUISound(.correct)
            container.hapticService.notification(.success)
            interactor?.speakWagon(index: idx)
        }
    }

    private func exit() {
        container.soundService.playUISound(.tap)
        display.pendingExit = true
    }

    private func finalize() {
        guard !display.pendingExit else { return }
        container.soundService.playUISound(.complete)
        container.hapticService.notification(.success)
        display.pendingExit = true
    }

    // MARK: - Bootstrap

    @MainActor
    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        let age = await resolveChildAge()
        let presenter = TongueTwistersPresenter()
        // Kid circuit: ASR — только on-device (Tier A). HF/Tier B недоступен.
        let speech = TongueTwistersSpeechWorker(
            audioService: container.audioService,
            asrService: container.asrService
        )
        let interactor = TongueTwistersInteractor(
            childId: childId,
            childAge: age,
            speech: speech,
            adaptivePlanner: container.adaptivePlannerService
        )
        let router = TongueTwistersRouter()

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

// MARK: - Metrics

private enum TongueTwistersMetrics {
    /// Симметричный контентный отступ (open-design: 22pt).
    static let contentPadding: CGFloat = 22
}

// MARK: - BeatPillRow (слоговая разминка с золотыми ритм-точками)

private struct BeatPillRow: View {
    let syllable: String
    let beats: Int
    let activeBeat: Int
    let metronomeOn: Bool
    let reduceMotion: Bool

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            ForEach(0..<max(1, beats), id: \.self) { idx in
                BeatPill(
                    syllable: syllable,
                    isNow: metronomeOn ? (idx == activeBeat) : (idx == 0),
                    pulse: metronomeOn && idx == activeBeat && !reduceMotion
                )
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(
            format: String(localized: "tongueTwisters.warmup.a11y %@", defaultValue: "Разминка: повтори слог %@"),
            syllable
        ))
    }
}

private struct BeatPill: View {
    let syllable: String
    let isNow: Bool
    let pulse: Bool

    var body: some View {
        Text(syllable)
            .font(TypographyTokens.title(20).weight(.black))
            .foregroundStyle(ColorTokens.Brand.primary)
            .frame(maxWidth: 88)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .strokeBorder(isNow ? ColorTokens.Brand.gold : ColorTokens.Kid.line, lineWidth: 2)
            )
            .overlay(alignment: .top) {
                // Золотая ритм-точка над пилюлей.
                Circle()
                    .fill(ColorTokens.Brand.gold)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(ColorTokens.Brand.gold.opacity(0.24), lineWidth: 4))
                    .offset(y: -7)
            }
            .scaleEffect(pulse ? 1.08 : 1)
            .animation(pulse ? .spring(response: 0.18, dampingFraction: 0.5) : .easeOut(duration: 0.2), value: pulse)
    }
}

// MARK: - BlankSlot (пунктир-коралл для рифмы)

private struct BlankSlot: View {
    let filled: String?

    var body: some View {
        Group {
            if let filled {
                Text(filled)
                    .font(TypographyTokens.display(24).weight(.black))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .padding(.horizontal, 12)
                    .frame(minWidth: 96, minHeight: 42)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                            .fill(ColorTokens.Brand.primaryLo.opacity(0.3))
                    )
            } else {
                Text("?")
                    .font(TypographyTokens.display(24).weight(.black))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(minWidth: 96, minHeight: 42)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                            .fill(ColorTokens.Brand.primaryLo.opacity(0.18))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                            .strokeBorder(ColorTokens.Brand.primary,
                                          style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    )
            }
        }
    }
}

// MARK: - AnswerChip (картинка-ответ рифмы)

private struct AnswerChip: View {
    let answer: RhymeAnswer
    let isSelected: Bool
    let reduceMotion: Bool
    let onTap: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: SpacingTokens.tiny) {
                HSContentSymbol(answer.imageAsset, size: 34)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                            .fill(ColorTokens.Kid.surfaceAlt)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                            .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
                    )
                Text(answer.word)
                    .font(TypographyTokens.headline(15).weight(.black))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.small)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .strokeBorder(isSelected ? ColorTokens.Brand.primary : ColorTokens.Kid.line,
                                  lineWidth: isSelected ? 2.5 : 2)
            )
            .scaleEffect(pressed && !reduceMotion ? 0.96 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(answer.word)
        .accessibilityHint(String(localized: "tongueTwisters.answer.hint", defaultValue: "Выбрать это слово в рифму"))
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}

// MARK: - RecordButton (крупная кнопка записи с пульсом)

private struct RecordButton: View {
    let isRecording: Bool
    let reduceMotion: Bool
    let onTap: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(ColorTokens.Brand.primary.opacity(0.14))
                    .frame(width: 116, height: 116)
                    .scaleEffect(isRecording && !reduceMotion ? (pulse ? 1.12 : 1.0) : 1.0)
                Circle()
                    .fill(LinearGradient(
                        colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 96, height: 96)
                    .shadow(color: ColorTokens.Brand.primary.opacity(0.5), radius: 16, y: 8)
                Image(systemName: isRecording ? "waveform" : "mic.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
                    .symbolEffect(.variableColor, isActive: isRecording && !reduceMotion)
            }
        }
        .buttonStyle(.plain)
        .disabled(isRecording)
        .onChange(of: isRecording) { _, rec in
            guard !reduceMotion else { return }
            if rec {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { pulse = true }
            } else {
                pulse = false
            }
        }
        .accessibilityLabel(isRecording
            ? String(localized: "tongueTwisters.record.a11y.active", defaultValue: "Идёт запись")
            : String(localized: "tongueTwisters.record.a11y", defaultValue: "Записать чистоговорку"))
        .accessibilityAddTraits(.startsMediaSession)
    }
}

// MARK: - WagonRow (вагончик наращивания)

private struct WagonRow: View {
    let wagon: WagonStep
    let index: Int
    let state: WagonState
    let targetSound: String
    let reduceMotion: Bool
    let onListen: () -> Void

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            numberBadge
            Text(highlighted)
                .font(TypographyTokens.headline(19).weight(.black))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            if state == .now {
                Button(action: onListen) {
                    Image(systemName: "play.fill")
                        .font(TypographyTokens.body(15).weight(.bold))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(ColorTokens.Brand.primaryLo.opacity(0.3)))
                }
                .accessibilityLabel(String(localized: "tongueTwisters.wagon.listen.a11y", defaultValue: "Послушать строчку"))
            }
        }
        .padding(SpacingTokens.regular)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .fill(backgroundFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .strokeBorder(borderColor, lineWidth: state == .now ? 2.5 : 2)
        )
        .opacity(state == .locked ? 0.5 : 1)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: state)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11y)
    }

    private var numberBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                .fill(badgeFill)
            badgeContent
        }
        .frame(width: 34, height: 34)
    }

    @ViewBuilder
    private var badgeContent: some View {
        if state == .done {
            Image(systemName: "checkmark")
                .font(TypographyTokens.body(15).weight(.black))
                .foregroundStyle(.white)
        } else {
            Text("\(index + 1)")
                .font(TypographyTokens.headline(15).weight(.black))
                .foregroundStyle(state == .now ? .white : ColorTokens.Kid.inkMuted)
        }
    }

    private var highlighted: AttributedString {
        var attr = AttributedString(wagon.text)
        attr.foregroundColor = ColorTokens.Kid.ink
        let sound = targetSound.lowercased()
            .replacingOccurrences(of: "ь", with: "")
            .replacingOccurrences(of: "'", with: "")
        guard let first = sound.first else { return attr }
        for variant in [String(first), String(first).uppercased()] {
            var range = attr.startIndex..<attr.endIndex
            while let r = attr[range].range(of: variant) {
                attr[r].foregroundColor = ColorTokens.Brand.primary
                range = r.upperBound..<attr.endIndex
            }
        }
        return attr
    }

    private var backgroundFill: Color {
        switch state {
        case .done: return ColorTokens.Brand.mint.opacity(0.07)
        case .now:  return ColorTokens.Brand.primary.opacity(0.06)
        case .locked: return ColorTokens.Kid.surface
        }
    }

    private var borderColor: Color {
        switch state {
        case .done: return ColorTokens.Brand.mint.opacity(0.55)
        case .now:  return ColorTokens.Brand.primary
        case .locked: return ColorTokens.Kid.line
        }
    }

    private var badgeFill: Color {
        switch state {
        case .done: return ColorTokens.Brand.mint
        case .now:  return ColorTokens.Brand.primary
        case .locked: return ColorTokens.Kid.surfaceAlt
        }
    }

    private var a11y: String {
        let stateWord: String
        switch state {
        case .done: stateWord = String(localized: "tongueTwisters.wagon.state.done", defaultValue: "пройдено")
        case .now:  stateWord = String(localized: "tongueTwisters.wagon.state.now", defaultValue: "сейчас")
        case .locked: stateWord = String(localized: "tongueTwisters.wagon.state.locked", defaultValue: "закрыто")
        }
        return "\(wagon.text), \(stateWord)"
    }
}

// MARK: - CTA

private struct TongueTwistersCTA: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.small) {
                Image(systemName: icon)
                    .font(TypographyTokens.headline(18).weight(.bold))
                Text(title)
                    .font(TypographyTokens.cta())
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(LinearGradient(
                        colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                        startPoint: .top, endPoint: .bottom
                    ))
            )
            .shadow(color: ColorTokens.Brand.primary.opacity(0.4), radius: 14, y: 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("TongueTwisters") {
    TongueTwistersView(childId: "preview-child")
        .environment(AppContainer.preview())
}
