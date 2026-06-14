import SwiftUI

// MARK: - SessionCompleteView
//
// Финальный экран сессии (kid-контур). Компактная вёрстка по эталону
// `session-complete.html`: hero (маскот в золотой медали + награда «+N» +
// 3 звезды) → одна карточка «Итоги занятия» с 2×2 чипами (слова / правильно /
// время / звёзды) + строка-похвала → опциональные reveal-карточки (достижение /
// наклейка / серия) → CTA в нижней safe-area-вставке.
//
// Стадийный reward-reveal сохранён (RewardStage) — каждая стадия раскрывается с
// задержкой, что синхронизирует появление элементов и persistence-pipeline:
//   .celebration — маскот + награда + заголовок (opacity fade-in)
//   .scoreReveal — карточка «Итоги занятия» (заменяет прежнее кольцо счёта)
//   .stars       — 3 звезды последовательным bounce
//   .achievement — разблокированное достижение (если есть)
//   .sticker     — новая наклейка (flip animation, если есть)
//   .streak      — серия дней + milestone (если есть)
//   .nextPreview — показ CTA («Продолжить» / «Ещё раз» / «Поделиться»)
//
// CTA: "Продолжить" (primary) + ряд "Ещё раз" (secondary) / "Поделиться" (ghost).
// Сигнатура `init(result:onContinue:onReplay:)` сохранена для AppCoordinator.
//
// Permissions (P1-2 v31 SE 3 audit):
//   Экран НЕ запрашивает доступ к микрофону или камере. Урок уже закончен,
//   запись более не нужна — рендерим только итоги.
//   Запрос permission делает соответствующий шаблон урока on-demand
//   (RepeatAfterModel, NarrativeQuest, PuzzleReveal, Breathing) либо
//   PermissionFlowView в онбординге. SessionComplete намеренно остаётся
//   permission-free, чтобы итоговый экран никогда не перекрывался системным
//   alert'ом.
//   Если будете добавлять новые reward-фичи: НЕ инициализируйте AudioService
//   и НЕ вызывайте AVAudioSession.setActive(true) в этом экране.

struct SessionCompleteView: View {

    // MARK: - Inputs

    let result: SessionResult
    let onContinue: () -> Void
    let onReplay: () -> Void

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppContainer.self) private var container

    // MARK: - VIP State

    @State private var display = SessionCompleteDisplay()
    @State private var interactor: SessionCompleteInteractor?
    @State private var presenter: SessionCompletePresenter?
    @State private var router: SessionCompleteRouter?
    @State private var bootstrapped = false

    // MARK: - Local UI state

    @State private var sharePresented = false
    @State private var shareText: String = ""
    @State private var confettiVisible = false
    @State private var stickerFlipped = false
    @State private var achievementPopVisible = false

    /// Fix #11f — screenshot-tour mode (true when launched with
    /// `-HSStartRoute`). Заморозить анимированный mesh-фон + конфетти, чтобы
    /// захват получил стабильный кадр.
    fileprivate static var isScreenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-HSStartRoute")
    }

    // MARK: - Init

    init(
        result: SessionResult,
        onContinue: @escaping () -> Void,
        onReplay: @escaping () -> Void
    ) {
        self.result = result
        self.onContinue = onContinue
        self.onReplay = onReplay
    }

    // MARK: - Body

    var body: some View {
        // Fix v35 (SE 3 footer overlap) — корневая причина:
        // прежний ZStack(alignment:.bottom) клал actionButtons как absolute
        // overlay поверх ScrollView, а контент компенсировался ручным
        // `.padding(.bottom, 240)`. На iPhone SE (3rd gen) высота footer
        // (primary + ряд из 2 кнопок + gradient) превышала 240pt, поэтому
        // нижние чипы счёта/карточки перекрывались кнопками.
        // Решение — footer вынесен в `.safeAreaInset(edge:.bottom)` у ScrollView:
        // SwiftUI сам резервирует под него высоту, контент раскладывается
        // НАД footer и физически не может быть перекрыт на любом устройстве.
        // ZStack оставлен только для overlay-слоёв (toast / popup / confetti),
        // которые обязаны лежать поверх всего экрана.
        ZStack {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)

            backgroundLayer
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                // Эталон session-complete.html — компактный, сбалансированный по
                // высоте экран: hero (маскот + награда + звёзды) → одна карточка
                // «Итоги занятия» с 2×2 чипами → опциональные reveal-карточки
                // (достижение / наклейка / серия) → CTA в нижней safe-area-вставке.
                VStack(spacing: SpacingTokens.large) {
                    celebrationPhase
                    starsPhase
                    summaryCard
                    achievementPhase
                    stickerPhase
                    streakPhase
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.large)
                .padding(.bottom, SpacingTokens.large)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionButtons
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.top, SpacingTokens.medium)
                    .padding(.bottom, SpacingTokens.small)
                    .background(
                        LinearGradient(
                            colors: [ColorTokens.Kid.bg.opacity(0), ColorTokens.Kid.bg],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea(edges: .bottom)
                    )
            }

            if let toast = display.toastMessage {
                // Fix v35 — ZStack теперь центрирован (footer уехал в
                // safeAreaInset). Toast прижимаем к низу через frame-alignment,
                // чтобы он по-прежнему всплывал над footer-кнопками.
                VStack {
                    Spacer()
                    HSToast(toast, type: .error)
                        .padding(.bottom, SpacingTokens.xLarge)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .zIndex(13)
                .task {
                    try? await Task.sleep(for: .seconds(2.4))
                    withAnimation(.easeInOut(duration: 0.25)) {
                        display.clearToast()
                    }
                }
            }

            if achievementPopVisible, let achievement = display.pendingAchievements.first {
                AchievementPopupView(info: achievement) {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                        achievementPopVisible = false
                    }
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .zIndex(12)
                .accessibilityAddTraits(.isModal)
            }

            if confettiVisible {
                ConfettiCanvasView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .zIndex(11)
                    .task {
                        try? await Task.sleep(for: .seconds(3.0))
                        withAnimation(.easeOut(duration: 0.4)) {
                            confettiVisible = false
                        }
                    }
            }

            // Block J v18 — HSConfettiView layered поверх existing ConfettiCanvasView.
            // Pattern .celebration (разноцветное), HSRewardBurst остаётся в score reveal.
            // Per Block J одобрение #9: keep BOTH layered.
            HSConfettiView(preset: .celebration, isActive: $confettiVisible)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .zIndex(12)
                .accessibilityHidden(true)

            // Lottie-салют по числу звёзд (под Reduced Motion — не показываем, как и конфетти).
            if confettiVisible, !reduceMotion {
                HSLottieContainer(
                    asset: celebrationAsset,
                    fallback: AnyView(EmptyView()),
                    size: CGSize(width: 280, height: 280)
                )
                .allowsHitTesting(false)
                .zIndex(13)
                .accessibilityHidden(true)
            }
        }
        .navigationBarBackButtonHidden()
        // Fix #15e — на SessionComplete просвечивал системный tab bar
        // от родительского NavigationStack (kid-контур). Скрываем явно — иначе
        // оранжевый footer bleed-ил через mesh-фон celebration-экрана.
        .toolbar(.hidden, for: .tabBar)
        .environment(\.circuitContext, .kid)
        .accessibilityElement(children: .contain)
        .task { await bootstrap() }
        .sheet(isPresented: $sharePresented) {
            SessionCompleteShareSheet(text: shareText)
        }
        .onChange(of: display.pendingShareText) { _, text in
            guard let text else { return }
            shareText = text
            sharePresented = true
            display.consumeShare()
        }
        .onChange(of: display.pendingPlayAgain) { _, value in
            guard value else { return }
            display.consumePlayAgain()
            onReplay()
        }
        .onChange(of: display.pendingProceed) { _, value in
            guard value else { return }
            display.consumeProceed()
            onContinue()
        }
    }

    /// Подбирает Lottie-салют по числу заработанных звёзд.
    private var celebrationAsset: HSLottieAsset {
        switch display.starsEarned {
        case 3...: return .celebrate3Stars
        case 2:    return .celebratePerfectRound
        default:   return .celebrateFirstSession
        }
    }

    // MARK: - Stage 1: Celebration (маскот)

    @ViewBuilder
    private var celebrationPhase: some View {
        let visible = display.isPhaseVisible(.celebration)
        VStack(spacing: SpacingTokens.small) {
            // Эталон session-complete.html (.hero): маскот в круглой золотой
            // медали-виньетке + награда «+N» в правом-верхнем углу.
            // Block I v19: scaleEffect убран с 2D Ляли — только opacity fade-in.
            // Fix v32-postreaudit — PNG ассета mascot_lyalya_* содержит
            // непрозрачный белый прямоугольник (не альфа-канал); клипуем по кругу
            // и оборачиваем в прозрачный gradient-«сияние» — белый прямоугольник
            // больше не виден, маскот вписан в круглую медаль.
            LyalyaHeroView(state: lyalyaResultState, size: 160)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(ColorTokens.Brand.gold.opacity(0.4), lineWidth: 3)
                )
                .background(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    ColorTokens.Brand.gold.opacity(0.30),
                                    ColorTokens.Brand.gold.opacity(0.0)
                                ],
                                center: .center,
                                startRadius: 60,
                                endRadius: 110
                            )
                        )
                        .frame(width: 200, height: 200)
                )
                .overlay(alignment: .topTrailing) {
                    rewardBadge
                        .opacity(visible ? 1 : 0)
                        .scaleEffect(visible ? 1 : 0.6)
                        .animation(
                            reduceMotion ? nil : MotionTokens.bounce.delay(0.25),
                            value: visible
                        )
                        .offset(x: SpacingTokens.regular, y: -SpacingTokens.tiny)
                }
                .opacity(visible ? (colorScheme == .dark ? 0.92 : 1.0) : 0)
                .animation(
                    reduceMotion ? nil : MotionTokens.spring,
                    value: visible
                )
                .accessibilityHidden(true)

            Text(display.mascotTagline)
                .font(TypographyTokens.title(28))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(visible ? 1 : 0)
                .padding(.horizontal, SpacingTokens.large)

            Text(String(localized: "sessionComplete.hero.subtitle"))
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(visible ? 1 : 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(display.mascotTagline). \(String(localized: "sessionComplete.hero.subtitle"))"
        )
    }

    /// Награда «+N ⭐» в углу медали (эталон .reward-badge). N — итоговый счёт
    /// сессии (`display.scoreInt`), реальные баллы из Interactor.
    private var rewardBadge: some View {
        HStack(spacing: SpacingTokens.micro) {
            Text("+\(display.scoreInt)")
                .font(TypographyTokens.headline(16).weight(.heavy).monospacedDigit())
            Image(systemName: "star.fill")
                .font(TypographyTokens.caption(13).weight(.bold))
        }
        .foregroundStyle(ColorTokens.Brand.gold)
        .padding(.horizontal, SpacingTokens.small)
        .padding(.vertical, SpacingTokens.tiny)
        .background(
            Capsule(style: .continuous)
                .fill(ColorTokens.Brand.butter.opacity(0.95))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(ColorTokens.Brand.gold.opacity(0.5), lineWidth: 1.5)
        )
        .shadow(color: ColorTokens.Brand.butter.opacity(0.5), radius: 8, x: 0, y: 3)
        .accessibilityHidden(true)
    }

    // MARK: - Summary card («Итоги занятия» — эталон .card)

    /// Консолидированная карточка итогов: заголовок + 2×2 сетка чипов
    /// (слова / правильно / время / звёзды) + строка-похвала. Заменяет прежнее
    /// большое кольцо счёта и разрозненные stat-карточки — компактно и
    /// сбалансировано по высоте, как в эталоне session-complete.html.
    @ViewBuilder
    private var summaryCard: some View {
        let visible = display.isPhaseVisible(.scoreReveal)
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.medium) {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                Text(String(localized: "sessionComplete.summary.title"))
                    .font(TypographyTokens.headline(17).weight(.heavy))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                summaryChipGrid

                praiseRow

                if let next = display.nextLessonTitle {
                    nextLessonRow(title: next)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .opacity(visible ? 1 : 0)
        .scaleEffect(visible ? 1 : 0.96)
        .animation(reduceMotion ? nil : MotionTokens.spring, value: visible)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sessionSummaryCard")
    }

    private var summaryChipGrid: some View {
        VStack(spacing: SpacingTokens.tiny) {
            HStack(spacing: SpacingTokens.tiny) {
                summaryChip(
                    icon: "text.book.closed.fill",
                    tint: ColorTokens.Brand.primary,
                    value: wordsChipValue,
                    label: String(localized: "sessionComplete.chip.words")
                )
                summaryChip(
                    icon: "checkmark.circle.fill",
                    tint: ColorTokens.Feedback.correct,
                    value: correctChipValue,
                    label: String(localized: "sessionComplete.chip.correct")
                )
            }
            HStack(spacing: SpacingTokens.tiny) {
                summaryChip(
                    icon: "clock.fill",
                    tint: ColorTokens.Brand.lilac,
                    value: display.durationLabel,
                    label: String(localized: "sessionComplete.chip.time")
                )
                summaryChip(
                    icon: "star.fill",
                    tint: ColorTokens.Brand.gold,
                    value: starsChipValue,
                    label: String(localized: "sessionComplete.chip.stars")
                )
            }
        }
    }

    private func summaryChip(icon: String, tint: Color, value: String, label: String) -> some View {
        HStack(spacing: SpacingTokens.small) {
            Image(systemName: icon)
                .font(TypographyTokens.body(16).weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(TypographyTokens.headline(17).weight(.heavy))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(label)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.Kid.surfaceAlt, in: RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    /// Строка-похвала (эталон .praise): «Звук X стал чётче!» — мягкий
    /// rose-tinted блок с золотой искрой. Текст из presenter (mascotTagline уже
    /// в заголовке hero — здесь даём предметную похвалу по целевому звуку).
    private var praiseRow: some View {
        HStack(spacing: SpacingTokens.small) {
            Image(systemName: "sparkles")
                .font(TypographyTokens.body(16).weight(.semibold))
                .foregroundStyle(ColorTokens.Brand.gold)
                .accessibilityHidden(true)
            Text(praiseText)
                .font(TypographyTokens.body(14).weight(.semibold))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ColorTokens.Brand.rose.opacity(0.12),
            in: RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(praiseText)
    }

    /// Превью следующего занятия — встроено в карточку итогов (lilac-акцент).
    private func nextLessonRow(title: String) -> some View {
        HStack(spacing: SpacingTokens.small) {
            Image(systemName: "arrow.right.circle.fill")
                .font(TypographyTokens.body(16).weight(.semibold))
                .foregroundStyle(ColorTokens.Brand.lilac)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(String(localized: "sessionComplete.nextLesson.label"))
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Text(title)
                    .font(TypographyTokens.body(14).weight(.semibold))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ColorTokens.Brand.lilac.opacity(0.12),
            in: RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(String(localized: "sessionComplete.nextLesson.label")): \(title)"
        )
    }

    // MARK: - Stage 3: Stars

    @ViewBuilder
    private var starsPhase: some View {
        let visible = display.isPhaseVisible(.stars)
        // Fix #11g — добавляем явный caption «Звёзд: N из M» под рядом
        // звёзд: kids в скриншот-туре не видят прогресса «3 заполненные vs
        // пустые», а родитель/специалист тоже хочет численную оценку.
        VStack(spacing: SpacingTokens.sp2) {
            HStack(spacing: SpacingTokens.medium) {
                ForEach(0..<display.starsTotal, id: \.self) { index in
                    let earned = index < display.starsEarned
                    Image(systemName: earned ? "star.fill" : "star")
                        .font(TypographyTokens.display(44).weight(.semibold))
                        .foregroundStyle(earned ? ColorTokens.Brand.gold : ColorTokens.Kid.line)
                        .scaleEffect(visible ? 1 : 0.2)
                        .opacity(visible ? 1 : 0)
                        .shadow(color: earned ? ColorTokens.Brand.gold.opacity(0.5) : .clear, radius: 8, x: 0, y: 2)
                        .animation(
                            reduceMotion ? nil : MotionTokens.bounce.delay(Double(index) * 0.18),
                            value: visible
                        )
                        .accessibilityHidden(true)
                }
            }
            if visible {
                Text(String(
                    format: String(localized: "sessionComplete.stars.caption"),
                    display.starsEarned,
                    display.starsTotal
                ))
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                format: String(localized: "sessionComplete.a11y.stars"),
                display.starsEarned,
                display.starsTotal
            )
        )
    }

    // MARK: - Stage 4: Achievement unlock

    @ViewBuilder
    private var achievementPhase: some View {
        let visible = display.isPhaseVisible(.achievement) && display.hasNewAchievements
        if visible && !display.pendingAchievements.isEmpty {
            VStack(spacing: SpacingTokens.small) {
                ForEach(display.pendingAchievements.indices, id: \.self) { idx in
                    let ach = display.pendingAchievements[idx]
                    achievementCard(info: ach, index: idx)
                }
            }
            .transition(reduceMotion ? .identity : .scale(scale: 0.9).combined(with: .opacity))
        }
    }

    private func achievementCard(info: UnlockedAchievementInfo, index: Int) -> some View {
        HSLiquidGlassCard(style: .tinted(ColorTokens.Brand.gold), padding: SpacingTokens.medium) {
            HStack(spacing: SpacingTokens.medium) {
                Image(systemName: info.iconName)
                    .font(TypographyTokens.title(26).weight(.semibold))
                    .foregroundStyle(ColorTokens.Brand.gold)
                    .frame(width: 44, height: 44)
                    .background(ColorTokens.Brand.gold.opacity(0.15), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(String(localized: "sessionComplete.achievement.newLabel"))
                        .font(TypographyTokens.caption(11).weight(.semibold))
                        .foregroundStyle(ColorTokens.Brand.gold)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text(info.title)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(info.description)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(TypographyTokens.body(18))
                    .foregroundStyle(ColorTokens.Brand.gold)
                    // Step 10 Batch C — Pattern 5: bounce when achievement
                    // unlocks (state-reactive).
                    .hsSymbolEffect(.bounce, value: info.title)
                    .accessibilityHidden(true)
            }
        }
        .modifier(StaggeredAppear(visible: true, index: index, reduceMotion: reduceMotion))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(String(localized: "sessionComplete.achievement.newLabel")): \(info.title). \(info.description)")
    }

    // MARK: - Stage 5: Sticker reveal

    @ViewBuilder
    private var stickerPhase: some View {
        let visible = display.isPhaseVisible(.sticker)
        if visible, let sticker = display.pendingSticker {
            stickerRevealCard(sticker: sticker)
                .transition(reduceMotion ? .identity : .scale(scale: 0.85).combined(with: .opacity))
        }
    }

    private func stickerRevealCard(sticker: StickerRevealInfo) -> some View {
        HSLiquidGlassCard(style: .tinted(ColorTokens.Brand.lilac), padding: SpacingTokens.medium) {
            HStack(spacing: SpacingTokens.medium) {
                HSContentSymbol(sticker.emoji, size: 44, tint: ColorTokens.Brand.gold)
                    .rotation3DEffect(
                        .degrees(stickerFlipped ? 0 : 180),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.65).delay(0.1),
                        value: stickerFlipped
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(String(localized: "sessionComplete.sticker.newLabel"))
                        .font(TypographyTokens.caption(11).weight(.semibold))
                        .foregroundStyle(ColorTokens.Brand.lilac)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text(sticker.name)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(sticker.collectionName)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
                Spacer()
                Image(systemName: "sparkles")
                    .font(TypographyTokens.body(18))
                    .foregroundStyle(ColorTokens.Brand.lilac)
                    // Step 10 Batch C — Pattern 5: variableColor sparkles
                    // (kavsoft-style «magic shine» on sticker reveal).
                    .hsSymbolEffect(.variableColor, value: sticker.name)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(String(localized: "sessionComplete.sticker.newLabel")): \(sticker.name)")
        .onAppear {
            guard !reduceMotion else {
                stickerFlipped = true
                return
            }
            Task {
                try? await Task.sleep(for: .milliseconds(200))
                withAnimation { stickerFlipped = true }
            }
        }
    }

    // MARK: - Stage 6: Streak

    @ViewBuilder
    private var streakPhase: some View {
        let visible = display.isPhaseVisible(.streak)
        if visible, let streak = display.streakInfo, streak.currentStreak > 0 {
            HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.medium) {
                HStack(spacing: SpacingTokens.medium) {
                    Image(systemName: display.streakIconName)
                        .font(TypographyTokens.title(26).weight(.semibold))
                        .foregroundStyle(
                            streak.isMilestone ? ColorTokens.Brand.gold : ColorTokens.Brand.primary
                        )
                        .frame(width: 44, height: 44)
                        .background(
                            (streak.isMilestone ? ColorTokens.Brand.gold : ColorTokens.Brand.primary)
                                .opacity(0.15),
                            in: Circle()
                        )
                        // Step 10 Batch C — Pattern 5: pulse on streak icon
                        // when streak count advances (kid milestone feedback).
                        .hsSymbolEffect(.pulse, value: streak.currentStreak)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                        Text(display.streakLabel)
                            .font(TypographyTokens.headline(16))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                        if let milestone = display.streakMilestoneLabel {
                            Text(milestone)
                                .font(TypographyTokens.body(13).weight(.semibold))
                                .foregroundStyle(ColorTokens.Brand.gold)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                        }
                    }
                    Spacer()
                    Text("\(streak.currentStreak)")
                        .font(TypographyTokens.kidDisplay(34))
                        .foregroundStyle(
                            streak.isMilestone ? ColorTokens.Brand.gold : ColorTokens.Brand.primary
                        )
                        .monospacedDigit()
                        .accessibilityHidden(true)
                }
            }
            .modifier(StaggeredAppear(visible: visible, index: 0, reduceMotion: reduceMotion))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(display.streakLabel)
        }
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        VStack(spacing: SpacingTokens.sp3) {
            HSButton(
                String(localized: "sessionComplete.cta.continue"),
                style: .primary,
                icon: "arrow.right.circle.fill"
            ) {
                interactor?.proceedToNext(.init())
            }

            HStack(spacing: SpacingTokens.small) {
                HSButton(
                    String(localized: "sessionComplete.cta.playAgain"),
                    style: .secondary,
                    size: .medium,
                    icon: "arrow.counterclockwise"
                ) {
                    interactor?.playAgain(.init())
                }
                HSButton(
                    String(localized: "sessionComplete.cta.share"),
                    style: .ghost,
                    size: .medium,
                    icon: "square.and.arrow.up"
                ) {
                    interactor?.shareResult(.init())
                }
            }
        }
        .opacity(display.isPhaseVisible(.nextPreview) ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: display.currentPhase)
    }

    // MARK: - Background

    // Тёплый celebration-фон: чистый кремовый Kid.bg + золотое mesh-сияние
    // под reward-reveal + два radial-блика (gold/primaryLo). Растровой
    // подложки-«wash» (Hero/celebration_*.png с blendMode .screen) больше нет —
    // PNG имели непрозрачный белый прямоугольник, давали бахрому по краям и
    // «грязнили» тёплый фон. Эталон session-complete.html — чистый тёплый
    // градиент без растровых иллюстраций на фоне.
    @ViewBuilder
    private var backgroundLayer: some View {
        ZStack {
            ColorTokens.Kid.bg
            // Fix #11f — анимация mesh-фазы отключается под
            // -HSStartRoute (скриншот-тур), иначе на захвате ловится
            // волнистый артефакт переходного кадра.
            HSMeshGradientBackground(palette: .rewards, animated: !Self.isScreenshotMode)
                .opacity(colorScheme == .dark ? 0.40 : 0.78)
                .transaction { tx in
                    if Self.isScreenshotMode { tx.disablesAnimations = true }
                }

            // Fix v34 — после уплощения mesh-палитры .rewards до
            // монохромного butter (см. HSMeshGradientBackground) восстанавливаем
            // gold/primaryLo сияние через radial overlay. Banding больше не
            // появляется (radial — не интерполяция между точками), а золотой
            // характер celebration-экрана остаётся.
            RadialGradient(
                colors: [
                    ColorTokens.Brand.gold.opacity(colorScheme == .dark ? 0.18 : 0.32),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 0.35),
                startRadius: 30,
                endRadius: 380
            )
            RadialGradient(
                colors: [
                    ColorTokens.Brand.primaryLo.opacity(colorScheme == .dark ? 0.10 : 0.18),
                    Color.clear
                ],
                center: UnitPoint(x: 0.85, y: 0.92),
                startRadius: 30,
                endRadius: 320
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Helpers

    private var lyalyaResultState: LyalyaState {
        // Fix #15a — SessionComplete всегда celebrating: финальный
        // экран — кульминация урока, маскот празднует, независимо от score.
        // Поощрение/обучение через score breakdown ниже, а не через мрачную
        // мордочку Ляли. Канонический asset обновляется параллельно (icon-
        // generator regen для mascot_lyalya_celebrate).
        .celebrating
    }

    // MARK: - Summary chip values (реальные данные из result/display)

    /// «N слов» — число сыгранных слов в сессии (= число попыток).
    private var wordsChipValue: String {
        String(format: String(localized: "sessionComplete.chip.words.value"), result.attempts)
    }

    /// «N из M» — правильных из всех (эталон «7 из 8»). Из реального
    /// `correctAttempts` / `attempts`.
    private var correctChipValue: String {
        String(
            format: String(localized: "sessionComplete.chip.correct.value"),
            result.correctAttempts,
            max(result.attempts, result.correctAttempts)
        )
    }

    /// «N звёзд» — заработанные звёзды (склонение через String Catalog).
    private var starsChipValue: String {
        String(format: String(localized: "sessionComplete.chip.stars.value"), display.starsEarned)
    }

    /// Предметная похвала «Звук X стал чётче!» при хорошем результате; при
    /// слабом — мягкое «Звук X ещё тренируем». Из реального `soundTarget`/score.
    private var praiseText: String {
        let template = result.score >= 0.6
            ? String(localized: "sessionComplete.praise.clearer")
            : String(localized: "sessionComplete.praise.keepPracticing")
        return String(format: template, result.soundTarget)
    }

    // MARK: - Bootstrap

    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        let presenter = SessionCompletePresenter()
        presenter.display = display
        // P0-2: боевой интерактор поверх живого контейнера с включённой
        // персистенцией. Стикер/стрик/ачивки реально пишутся в Realm. Демо-результат
        // (скриншот-тур, пустой/preview childId) персистенцию не запускает — иначе
        // async-обновления гонятся с захватом кадра и пишут мусор в preview-Realm.
        let isDemoResult = Self.isScreenshotMode
            || result.childId.isEmpty
            || result.childId.hasPrefix("preview-")
        let interactor = SessionCompleteInteractor.live(
            container: container,
            skipsPersistence: isDemoResult
        )
        interactor.presenter = presenter
        let router = SessionCompleteRouter()
        router.onContinue = onContinue
        router.onReplay = onReplay
        router.onDismiss = { dismiss() }

        self.presenter = presenter
        self.interactor = interactor
        self.router = router

        interactor.loadResult(.init(result: result))

        // Страховка кат-сцен (дубль к WorldMap): если эта сессия закрыла остров
        // или подняла стрик до 7/30 — ставим триумф/майлстоун в очередь. Проверка
        // честная (по реальному progressSummary ребёнка), повторно не покажется.
        await enqueueCutsceneIfNeeded()

        await runStageSchedule()
    }

    /// Честная страховка-триггер кат-сцен по итогам сессии. Маппит
    /// `result.soundTarget → остров`, проверяет завершённость острова и стрик по
    /// реальным данным ребёнка. Каждый enqueue гейтится `shouldPlay` (seen +
    /// видео/постер) внутри CutsceneService.
    @MainActor
    private func enqueueCutsceneIfNeeded() async {
        let childId = result.childId
        guard !childId.isEmpty else { return }
        guard let profile = try? await container.childRepository.fetch(id: childId) else { return }
        let summary = profile.progressSummary

        // Триумф острова целевого звука сессии — только если остров реально завершён.
        if let (island, sounds) = Self.island(forSound: result.soundTarget), !sounds.isEmpty {
            let mastery = sounds.reduce(0.0) { $0 + (summary[$1] ?? 0) } / Double(sounds.count)
            if mastery >= 1.0 {
                container.cutsceneService.enqueue(.islandComplete(island), childId: childId)
            }
        }

        // Стрик-майлстоуны 7 / 30.
        for milestone in [7, 30] where profile.currentStreak >= milestone {
            container.cutsceneService.enqueue(.streak(days: milestone), childId: childId)
        }
    }

    /// Остров (+ его звуки) для целевого звука сессии. Грамматика (без звуков)
    /// и гласные исключены — их триумф не триггерится из SessionComplete.
    private static func island(forSound sound: String) -> (MapIslandID, [String])? {
        let map: [(MapIslandID, [String])] = [
            (.whistling, ["С", "Сь", "З", "Зь", "Ц"]),
            (.hissing, ["Ш", "Ж"]),
            (.affricates, ["Ч", "Щ"]),
            (.sonorant, ["Р", "Рь", "Л", "Ль"]),
            (.velar, ["К", "Кь", "Г", "Гь", "Х", "Хь"])
        ]
        return map.first { $0.1.contains(sound) }
    }

    private func runStageSchedule() async {
        guard let interactor else { return }

        // Задержки стадий. Reduced Motion: всё мгновенно в .nextPreview.
        let plan: [(RewardStage, Double)] = reduceMotion
            ? [(.scoreReveal, 0), (.stars, 0), (.achievement, 0), (.sticker, 0), (.streak, 0), (.nextPreview, 0)]
            : [(.scoreReveal, 0.50), (.stars, 0.70), (.achievement, 0.60), (.sticker, 0.60), (.streak, 0.60), (.nextPreview, 0.60)]

        // Немедленно: стадии до .achievement идут последовательно с задержками
        for (stage, delay) in plan.prefix(3) {
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            withAnimation(reduceMotion ? nil : MotionTokens.spring) {
                interactor.advancePhase(.init(to: stage))
            }
        }

        // Стадии .achievement, .sticker, .streak, .nextPreview — после persistence pipeline
        // Ждём чуть дольше, чтобы persistence успела вернуть данные
        if !reduceMotion {
            try? await Task.sleep(for: .seconds(1.2))
        }

        for (stage, delay) in plan.dropFirst(3) {
            if delay > 0 && !reduceMotion {
                try? await Task.sleep(for: .seconds(delay))
            }
            withAnimation(reduceMotion ? nil : MotionTokens.spring) {
                interactor.advancePhase(.init(to: stage))
            }
        }

        // Confetti при высокой точности. Подавляем при Reduced Motion (Apple HIG —
        // салют это чистое движение, убираем для motion-sensitive детей) и в
        // screenshot/snapshot-режиме (частицы случайны → детерминизм кадра).
        if display.showConfetti && !reduceMotion && !Self.isScreenshotMode {
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.1 : 0.5))
            withAnimation(reduceMotion ? nil : .easeIn(duration: 0.25)) {
                confettiVisible = true
            }
            // v31 Wave A research F-07 — programmatic Core Haptics composer
            // даёт 3-event level-up чувство, синхронно с появлением конфетти.
            await container.hapticService.playLevelUp()
        }

        // Achievement popup при наличии новых ачивок. Под Reduced Motion / snapshot
        // показываем синхронно без задержки — иначе захват кадра гонится с
        // 0.1s-таймером (popup то виден, то нет → недетерминированный снимок).
        if display.hasNewAchievements && !display.pendingAchievements.isEmpty {
            if !reduceMotion && !Self.isScreenshotMode {
                try? await Task.sleep(for: .seconds(0.8))
            }
            withAnimation(reduceMotion ? nil : MotionTokens.bounce) {
                achievementPopVisible = true
            }
        }
    }
}
