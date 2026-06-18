import OSLog
import SwiftUI

// MARK: - SoundHunterDayView
//
// «Звуковой охотник дня» — перенос звука из упражнений в спонтанную бытовую речь
// (завершающий этап коррекции). Два контура в одном экране:
//   • kid    — «Миссия дня» (hero-миссия со звуком, 2 задания-охоты, «сачок» из
//              5 слотов-звёзд, CTA «Поймал слово!») → «Копилка дня» (трофей-сачок,
//              слова-чипы, серия дней охоты).
//   • parent — «Подтверждение переноса» (3-градационный чек-ин + голосовая
//              заметка-перл + пояснение влияния на AdaptivePlannerService).
//
// Архитектура: Clean Swift VIP. Палитра тёплая (kid — cream; parent — Parent.bg
// #F0EFF6 с коралл-акцентом). Reduced Motion уважается во всех анимациях.
// Контентные отступы — 22pt (open-design), CTA min-height 60.

struct SoundHunterDayView: View {

    // MARK: - Input

    let childId: String
    /// Контур: kid (по умолчанию из ChildHome) или parent (из ParentHome).
    var circuit: SoundHunterDayModels.Circuit = .kid

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - VIP

    @State private var display = SoundHunterDayDisplay()
    @State private var interactor: SoundHunterDayInteractor?
    @State private var presenter: SoundHunterDayPresenter?
    @State private var router: SoundHunterDayRouter?
    @State private var bootstrapped = false
    @State private var celebrate = false
    /// Какой kid-экран показан: миссия (false) или копилка (true).
    @State private var showCollection = false

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SoundHunterDayView")

    private enum Metrics {
        /// Симметричный контентный отступ (open-design: 22pt).
        static let contentPadding: CGFloat = 22
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
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
    }

    private var backgroundColor: Color {
        display.circuit == .parent ? ColorTokens.Parent.bg : ColorTokens.Kid.bg
    }

    // MARK: - Content switch

    @ViewBuilder
    private var content: some View {
        switch display.phase {
        case .loading:
            loadingView
        case .unavailable:
            unavailableView
        case .ready:
            if display.circuit == .parent {
                parentScreen
            } else if showCollection {
                kidCollectionScreen
            } else {
                kidMissionScreen
            }
        }
    }

    // MARK: - Loading / Unavailable

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(ColorTokens.Brand.primary)
                .scaleEffect(1.4)
            Text(String(localized: "soundHunter.loading", defaultValue: "Готовим миссию дня…"))
                .font(TypographyTokens.body())
                .foregroundStyle(inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var unavailableView: some View {
        VStack(spacing: SpacingTokens.medium) {
            Image(systemName: "target")
                .font(TypographyTokens.display(48).weight(.semibold))
                .foregroundStyle(ColorTokens.Brand.primaryLo)
                .accessibilityHidden(true)
            Text(String(localized: "soundHunter.unavailable.title", defaultValue: "Миссия пока недоступна"))
                .font(TypographyTokens.title(20))
                .foregroundStyle(ink)
                .multilineTextAlignment(.center)
            Text(String(localized: "soundHunter.unavailable.body",
                        defaultValue: "Выбери профиль ребёнка, и охота за звуком начнётся."))
                .font(TypographyTokens.body(15))
                .foregroundStyle(inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, SpacingTokens.xLarge)
            SoundHunterCTA(
                title: String(localized: "common.close", defaultValue: "Закрыть"),
                icon: "checkmark.circle.fill",
                circuit: display.circuit
            ) { exit() }
            .padding(.top, SpacingTokens.small)
        }
        .padding(.horizontal, Metrics.contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Top bar

    private func topBar(title: String, subtitle: String, trailingIcon: String, trailingLabel: String, trailingAction: @escaping () -> Void) -> some View {
        HStack(spacing: SpacingTokens.small) {
            Button { exit() } label: {
                Image(systemName: "chevron.left")
                    .font(TypographyTokens.headline(17).weight(.bold))
                    .foregroundStyle(inkMuted)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(surfaceAlt))
                    .overlay(Circle().strokeBorder(line, lineWidth: 1))
            }
            .accessibilityLabel(String(localized: "common.back", defaultValue: "Назад"))

            VStack(spacing: 2) {
                Text(title)
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(subtitle)
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)

            Button(action: trailingAction) {
                Image(systemName: trailingIcon)
                    .font(TypographyTokens.headline(17).weight(.semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(surfaceAlt))
                    .overlay(Circle().strokeBorder(line, lineWidth: 1))
            }
            .accessibilityLabel(trailingLabel)
        }
    }

    // MARK: - KID screen 1: миссия дня

    private var kidMissionScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.small) {
                topBar(
                    title: String(localized: "soundHunter.kid.title", defaultValue: "Охотник дня"),
                    subtitle: display.isNetFull
                        ? String(localized: "soundHunter.kid.subtitle.full", defaultValue: "Сачок полон — ты настоящий охотник!")
                        : String(localized: "soundHunter.kid.subtitle", defaultValue: "Ловим звук в обычной жизни"),
                    trailingIcon: "speaker.wave.2.fill",
                    trailingLabel: String(
                        format: String(localized: "soundHunter.listen.a11y %@", defaultValue: "Послушать звук %@"),
                        display.sound
                    )
                ) { playSound() }

                missionHero
                tasksCard
                netCard
                if display.showHint {
                    hintBanner
                }
                mascotRow(text: kidMascotText, state: display.isNetFull ? .celebrating : .encouraging)
                kidMissionControls
            }
            .padding(.horizontal, Metrics.contentPadding)
            .padding(.top, SpacingTokens.tiny)
            .padding(.bottom, SpacingTokens.regular)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding(.bottom, SpacingTokens.small)
        .accessibilityLabel(String(localized: "soundHunter.kid.screen.a11y", defaultValue: "Миссия дня: лови звук в жизни"))
    }

    private var missionHero: some View {
        ZStack(alignment: .topLeading) {
            // Солнце-блик (butter) в правом верхнем углу.
            Circle()
                .fill(RadialGradient(
                    colors: [ColorTokens.Brand.butter.opacity(0.55), .clear],
                    center: .center, startRadius: 2, endRadius: 54
                ))
                .frame(width: 96, height: 96)
                .offset(x: 250, y: -28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                kickerChip(String(localized: "soundHunter.mission.kicker", defaultValue: "Миссия на сегодня"))
                HStack(alignment: .center, spacing: SpacingTokens.small) {
                    soundball
                    VStack(alignment: .leading, spacing: 4) {
                        Text(display.missionTitle)
                            .font(TypographyTokens.title(20).weight(.black))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(display.missionSubtitle)
                            .font(TypographyTokens.body(13.5).weight(.semibold))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(SpacingTokens.regular)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(
                    colors: [
                        ColorTokens.Brand.primaryHi.opacity(0.30),
                        ColorTokens.Brand.rose.opacity(0.16)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(ColorTokens.Brand.primary.opacity(0.24), lineWidth: 1)
        )
        .shadow(color: ColorTokens.Brand.primary.opacity(0.28), radius: 18, y: 10)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var soundball: some View {
        ZStack(alignment: .bottomTrailing) {
            Text(display.sound)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient(
                            colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                )
                .shadow(color: ColorTokens.Brand.primary.opacity(0.55), radius: 12, y: 6)
            Text(display.soundball)
                .font(.system(size: 14))
                .frame(width: 26, height: 26)
                .background(Circle().fill(ColorTokens.Brand.butter))
                .shadow(color: ColorTokens.Overlay.shadow.opacity(0.4), radius: 3, y: 1)
                .offset(x: 7, y: 7)
        }
        .accessibilityHidden(true)
    }

    private func kickerChip(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "sun.max.fill")
                .font(TypographyTokens.body(11).weight(.bold))
            Text(text.uppercased())
                .font(TypographyTokens.body(11).weight(.heavy))
                .tracking(0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(ColorTokens.Brand.primary)
        .padding(.horizontal, SpacingTokens.small)
        .padding(.vertical, 6)
        .background(Capsule().fill(ColorTokens.Kid.surface))
        .shadow(color: ColorTokens.Overlay.shadow.opacity(0.3), radius: 6, y: 2)
    }

    // MARK: - Tasks

    private var tasksCard: some View {
        VStack(spacing: SpacingTokens.small) {
            ForEach(display.tasks) { task in
                taskRow(task)
            }
        }
    }

    private func taskRow(_ task: CarryoverTask) -> some View {
        let done = display.completedTaskIds.contains(task.id)
        return Button {
            container.soundService.playUISound(.tap)
            container.hapticService.selection()
            Task { await interactor?.toggleTask(.init(taskId: task.id)) }
        } label: {
            HStack(spacing: SpacingTokens.small) {
                Text(task.icon)
                    .font(.system(size: 24))
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 14).fill(ColorTokens.Kid.surfaceAlt))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(TypographyTokens.headline(15).weight(.bold))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    if !task.subtitle.isEmpty {
                        Text(task.subtitle)
                            .font(TypographyTokens.body(12).weight(.semibold))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
                checkDot(done: done, fill: ColorTokens.Brand.mint)
            }
            .padding(SpacingTokens.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20).fill(ColorTokens.Kid.surface))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
            .shadow(color: ColorTokens.Overlay.shadow.opacity(0.3), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.title)
        .accessibilityValue(done
            ? String(localized: "soundHunter.task.done.a11y", defaultValue: "Выполнено")
            : String(localized: "soundHunter.task.todo.a11y", defaultValue: "Не выполнено"))
        .accessibilityHint(String(localized: "soundHunter.task.hint", defaultValue: "Нажми, чтобы отметить задание"))
    }

    private func checkDot(done: Bool, fill: Color) -> some View {
        ZStack {
            Circle()
                .fill(done ? fill : Color.clear)
                .overlay(Circle().strokeBorder(done ? fill : ColorTokens.Kid.line, lineWidth: 2))
                .frame(width: 24, height: 24)
            if done {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Net (сачок)

    private var netCard: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            HStack {
                HStack(spacing: 8) {
                    Text("🥅").font(.system(size: 18)).accessibilityHidden(true)
                    Text(String(
                        format: String(localized: "soundHunter.net.title %@", defaultValue: "Сачок звука %@"),
                        display.sound
                    ))
                    .font(TypographyTokens.headline(15.5).weight(.heavy))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                Text("\(display.caughtWords.count) / \(display.netGoal)")
                    .font(TypographyTokens.headline(14).weight(.heavy))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .monospacedDigit()
                    .padding(.horizontal, SpacingTokens.small)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(ColorTokens.Brand.primaryLo.opacity(0.45)))
            }

            HStack(spacing: 9) {
                ForEach(0..<display.netGoal, id: \.self) { idx in
                    netSlot(index: idx)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(
                format: String(localized: "soundHunter.net.a11y %lld %lld", defaultValue: "Поймано слов: %lld из %lld"),
                display.caughtWords.count, display.netGoal
            ))

            // Прогресс-полоска (butter→gold).
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(ColorTokens.Kid.line)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [ColorTokens.Brand.butter, ColorTokens.Brand.gold],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: max(0, geo.size.width * display.netProgress))
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: display.netProgress)
                }
            }
            .frame(height: 9)

            Text(netFootLabel)
                .font(TypographyTokens.body(12).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
        }
        .padding(SpacingTokens.regular)
        .background(RoundedRectangle(cornerRadius: 24).fill(ColorTokens.Kid.surface))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
        .shadow(color: ColorTokens.Overlay.shadow.opacity(0.5), radius: 18, y: 8)
    }

    private func netSlot(index: Int) -> some View {
        let caught = index < display.caughtWords.count
        return ZStack {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(caught
                      ? AnyShapeStyle(RadialGradient(
                            colors: [ColorTokens.Brand.butter.opacity(0.4), ColorTokens.Kid.surface],
                            center: .init(x: 0.5, y: 0.4), startRadius: 2, endRadius: 28))
                      : AnyShapeStyle(ColorTokens.Kid.surfaceAlt))
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(
                    caught ? ColorTokens.Brand.gold.opacity(0.55) : ColorTokens.Kid.line,
                    style: StrokeStyle(lineWidth: 1.5, dash: caught ? [] : [5, 4])
                )
            if caught {
                Image(systemName: "star.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(ColorTokens.Brand.gold)
                    .shadow(color: ColorTokens.Brand.gold.opacity(0.4), radius: 3, y: 2)
                    .transition(reduceMotion ? .identity : .scale.combined(with: .opacity))
            } else {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.6), value: display.caughtWords.count)
    }

    private var netFootLabel: String {
        let remaining = max(0, display.netGoal - display.caughtWords.count)
        if remaining == 0 {
            return String(localized: "soundHunter.net.full", defaultValue: "Сачок полный — ты поймал все слова!")
        }
        if remaining == 1 {
            return String(localized: "soundHunter.net.last", defaultValue: "Остался один шаг до полного сачка!")
        }
        return String(
            format: String(localized: "soundHunter.net.remaining %lld", defaultValue: "Ещё %lld слова — и сачок полный!"),
            remaining
        )
    }

    // MARK: - Hint

    private var hintBanner: some View {
        HStack(alignment: .top, spacing: SpacingTokens.small) {
            Image(systemName: "lightbulb.fill")
                .font(TypographyTokens.title(18).weight(.semibold))
                .foregroundStyle(ColorTokens.Brand.lilac)
                .accessibilityHidden(true)
            Text(display.missionHint)
                .font(TypographyTokens.body(13.5).weight(.semibold))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: RadiusTokens.md).fill(ColorTokens.Brand.lilac.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: RadiusTokens.md).strokeBorder(ColorTokens.Brand.lilac.opacity(0.26), lineWidth: 1))
        .transition(.opacity)
    }

    // MARK: - Kid mission controls

    private var kidMissionControls: some View {
        HStack(spacing: SpacingTokens.small) {
            Button {
                container.soundService.playUISound(.tap)
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    interactor?.toggleHint()
                    display.showHint.toggle()
                }
            } label: {
                Image(systemName: "lightbulb")
                    .font(TypographyTokens.headline(20).weight(.semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(width: 58, height: 58)
                    .background(RoundedRectangle(cornerRadius: 20).fill(ColorTokens.Kid.surface))
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(ColorTokens.Brand.primary.opacity(0.35), lineWidth: 1.5))
            }
            .accessibilityLabel(String(localized: "soundHunter.hint.a11y", defaultValue: "Подсказка — где искать"))

            if display.isNetFull {
                SoundHunterCTA(
                    title: String(localized: "soundHunter.cta.showCollection", defaultValue: "Показать копилку"),
                    icon: "arrow.right",
                    circuit: .kid
                ) {
                    container.soundService.playUISound(.tap)
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                        showCollection = true
                    }
                }
            } else {
                SoundHunterCTA(
                    title: String(
                        format: String(localized: "soundHunter.cta.catch %@", defaultValue: "Поймал слово с %@!"),
                        display.sound
                    ),
                    icon: "checkmark",
                    circuit: .kid
                ) { catchWord() }
                .accessibilityIdentifier("soundHunterCatchButton")
            }
        }
        .padding(.top, SpacingTokens.tiny)
    }

    // MARK: - KID screen 2: копилка дня

    private var kidCollectionScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.small) {
                topBar(
                    title: String(localized: "soundHunter.collection.title", defaultValue: "Копилка дня"),
                    subtitle: String(
                        format: String(localized: "soundHunter.collection.subtitle %@", defaultValue: "Все слова с %@ пойманы!"),
                        display.sound
                    ),
                    trailingIcon: "speaker.wave.2.fill",
                    trailingLabel: String(
                        format: String(localized: "soundHunter.listen.a11y %@", defaultValue: "Послушать звук %@"),
                        display.sound
                    )
                ) { playSound() }

                trophyCard
                caughtCard
                streakCard
                mascotRow(text: collectionMascotText, state: .celebrating)
                SoundHunterCTA(
                    title: String(localized: "soundHunter.cta.backToMission", defaultValue: "Вернуться к охоте"),
                    icon: "arrow.uturn.left",
                    circuit: .kid
                ) {
                    container.soundService.playUISound(.tap)
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                        showCollection = false
                    }
                }
                .padding(.top, SpacingTokens.tiny)
            }
            .padding(.horizontal, Metrics.contentPadding)
            .padding(.top, SpacingTokens.tiny)
            .padding(.bottom, SpacingTokens.regular)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding(.bottom, SpacingTokens.small)
        .onAppear {
            if !reduceMotion { celebrate = true }
            container.hapticService.notification(.success)
        }
        .accessibilityLabel(String(localized: "soundHunter.collection.screen.a11y", defaultValue: "Копилка дня: пойманные слова и серия охоты"))
    }

    private var trophyCard: some View {
        VStack(spacing: SpacingTokens.small) {
            Text("🥅")
                .font(.system(size: 44))
                .frame(width: 88, height: 88)
                .background(Circle().fill(ColorTokens.Kid.surface))
                .overlay(Circle().strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
                .shadow(color: ColorTokens.Brand.gold.opacity(0.4), radius: 14, y: 6)
                .accessibilityHidden(true)
            Text(String(
                format: String(localized: "soundHunter.trophy.title %lld %lld", defaultValue: "Сачок полный — %lld из %lld!"),
                display.caughtWords.count, display.netGoal
            ))
            .font(TypographyTokens.title(21).weight(.black))
            .foregroundStyle(ColorTokens.Kid.ink)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .minimumScaleFactor(0.85)
            Text(String(
                format: String(localized: "soundHunter.trophy.body %@", defaultValue: "Ты весь день ловил звук %@ в обычной жизни. Настоящий охотник!"),
                display.sound
            ))
            .font(TypographyTokens.body(13.5).weight(.semibold))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.large)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(
                    colors: [
                        ColorTokens.Brand.butter.opacity(0.40),
                        ColorTokens.Brand.primaryHi.opacity(0.22)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(ColorTokens.Brand.gold.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: ColorTokens.Brand.gold.opacity(0.35), radius: 18, y: 10)
        .accessibilityElement(children: .combine)
    }

    private var caughtCard: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            HStack {
                HStack(spacing: 8) {
                    Text("🎒").font(.system(size: 17)).accessibilityHidden(true)
                    Text(String(localized: "soundHunter.caught.title", defaultValue: "Что поймал сегодня"))
                        .font(TypographyTokens.headline(15.5).weight(.heavy))
                        .foregroundStyle(ColorTokens.Kid.ink)
                }
                Spacer(minLength: 0)
                Text("+\(display.caughtWords.count) ★")
                    .font(TypographyTokens.headline(13).weight(.heavy))
                    .foregroundStyle(ColorTokens.Brand.gold)
                    .padding(.horizontal, SpacingTokens.small)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(ColorTokens.Brand.butter.opacity(0.32)))
                    .overlay(Capsule().strokeBorder(ColorTokens.Brand.gold.opacity(0.3), lineWidth: 1))
            }
            FlowWrap(spacing: 9) {
                ForEach(Array(display.caughtWords.enumerated()), id: \.offset) { _, word in
                    wordChip(word)
                }
            }
        }
        .padding(SpacingTokens.regular)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24).fill(ColorTokens.Kid.surface))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
        .shadow(color: ColorTokens.Overlay.shadow.opacity(0.5), radius: 18, y: 8)
    }

    private func wordChip(_ word: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ColorTokens.Brand.gold)
                .frame(width: 26, height: 26)
                .background(Circle().fill(ColorTokens.Brand.primaryLo.opacity(0.5)))
                .accessibilityHidden(true)
            Text(coloredWord(word))
                .font(TypographyTokens.headline(14).weight(.heavy))
        }
        .padding(.leading, 8)
        .padding(.trailing, 13)
        .padding(.vertical, 7)
        .background(Capsule().fill(ColorTokens.Kid.surfaceAlt))
        .overlay(Capsule().strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
        .accessibilityLabel(word)
    }

    /// Окрашивает буквы целевого звука в слове коралловым.
    private func coloredWord(_ word: String) -> AttributedString {
        var attr = AttributedString(word)
        attr.foregroundColor = ColorTokens.Kid.ink
        let target = display.sound.lowercased()
        guard let first = target.first else { return attr }
        var search = attr.startIndex
        while search < attr.endIndex {
            if let range = attr[search...].range(of: String(first), options: [.caseInsensitive]) {
                attr[range].foregroundColor = ColorTokens.Brand.primary
                search = range.upperBound
            } else {
                break
            }
        }
        return attr
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            HStack {
                HStack(spacing: 7) {
                    Text("🔥").font(.system(size: 15)).accessibilityHidden(true)
                    Text(String(localized: "soundHunter.streak.title", defaultValue: "Серия охоты"))
                        .font(TypographyTokens.headline(14).weight(.bold))
                        .foregroundStyle(ColorTokens.Kid.ink)
                }
                Spacer(minLength: 0)
                Text(streakLabel)
                    .font(TypographyTokens.headline(14).weight(.heavy))
                    .foregroundStyle(ColorTokens.Brand.primary)
            }
            HStack(spacing: 7) {
                ForEach(display.weekDots) { dot in
                    weekDot(dot)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(
                format: String(localized: "soundHunter.streak.a11y %lld", defaultValue: "Серия охоты: %lld дней подряд"),
                display.streakDays
            ))
        }
        .padding(SpacingTokens.regular)
        .background(RoundedRectangle(cornerRadius: 22).fill(ColorTokens.Kid.surface))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
        .shadow(color: ColorTokens.Overlay.shadow.opacity(0.3), radius: 12, y: 4)
    }

    private func weekDot(_ dot: SoundHunterDayModels.DayDot) -> some View {
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(dotFill(dot))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(dotStroke(dot), lineWidth: 1.5))
                    .frame(width: 30, height: 30)
                if dot.isOn || dot.isToday {
                    Image(systemName: "star.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(dot.isToday ? .white : ColorTokens.Brand.gold)
                }
            }
            Text(dot.weekdayLabel)
                .font(TypographyTokens.body(10.5).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func dotFill(_ dot: SoundHunterDayModels.DayDot) -> AnyShapeStyle {
        if dot.isToday {
            return AnyShapeStyle(LinearGradient(
                colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        if dot.isOn {
            return AnyShapeStyle(RadialGradient(
                colors: [ColorTokens.Brand.butter.opacity(0.45), ColorTokens.Kid.surface],
                center: .init(x: 0.5, y: 0.4), startRadius: 2, endRadius: 22))
        }
        return AnyShapeStyle(ColorTokens.Kid.surfaceAlt)
    }

    private func dotStroke(_ dot: SoundHunterDayModels.DayDot) -> Color {
        if dot.isToday { return ColorTokens.Brand.primary }
        if dot.isOn { return ColorTokens.Brand.gold.opacity(0.4) }
        return ColorTokens.Kid.line
    }

    private var streakLabel: String {
        String(
            format: String(localized: "soundHunter.streak.days %lld", defaultValue: "%lld дней подряд"),
            display.streakDays
        )
    }
}

// MARK: - SoundHunterDayView + Parent & Helpers
//
// PARENT-экран подтверждения переноса, mascot-row, parent-хелперы, actions,
// circuit-aware цвета и bootstrap вынесены в same-file extension, чтобы тело
// `SoundHunterDayView` не превышало SwiftLint type_body_length. Доступ private
// сохраняется (same-file scope). Чистый view-рендер, без бизнес-логики.

extension SoundHunterDayView {

    // MARK: - PARENT screen: подтверждение переноса

    private var parentScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.small) {
                topBar(
                    title: String(localized: "soundHunter.parent.title", defaultValue: "Подтверждение дня"),
                    subtitle: String(localized: "soundHunter.parent.subtitle", defaultValue: "Перенос звука в речь"),
                    trailingIcon: "clock.arrow.circlepath",
                    trailingLabel: String(localized: "soundHunter.parent.history.a11y", defaultValue: "История чек-инов")
                ) {}

                parentChildCard
                parentPromptCard
                parentVoiceNotePearl
                parentSignalCard
                SoundHunterCTA(
                    title: String(localized: "soundHunter.parent.save", defaultValue: "Сохранить наблюдение"),
                    icon: "checkmark",
                    circuit: .parent
                ) {
                    container.soundService.playUISound(.complete)
                    container.hapticService.notification(.success)
                    Task { await interactor?.saveAndClose() }
                }
                .padding(.top, SpacingTokens.tiny)
                .accessibilityIdentifier("soundHunterSaveButton")
            }
            .padding(.horizontal, Metrics.contentPadding)
            .padding(.top, SpacingTokens.tiny)
            .padding(.bottom, SpacingTokens.regular)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding(.bottom, SpacingTokens.small)
        .accessibilityLabel(String(localized: "soundHunter.parent.screen.a11y", defaultValue: "Подтверждение переноса звука в свободную речь"))
    }

    private var parentChildCard: some View {
        HStack(spacing: SpacingTokens.small) {
            Text(childInitial)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Circle().fill(LinearGradient(
                    colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                    startPoint: .topLeading, endPoint: .bottomTrailing)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(childTitle)
                    .font(TypographyTokens.headline(16).weight(.bold))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(String(
                    format: String(
                        localized: "soundHunter.parent.caughtSummary %lld %@",
                        defaultValue: "Сегодня поймал(а) %lld слов(а) с %@ в копилку охотника"
                    ),
                    display.caughtWords.count, display.sound
                ))
                .font(TypographyTokens.body(12.5).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Text(display.sound)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(ColorTokens.Brand.primary)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 13).fill(ColorTokens.Brand.primaryLo.opacity(0.5)))
                .accessibilityHidden(true)
        }
        .padding(SpacingTokens.small)
        .background(RoundedRectangle(cornerRadius: 20).fill(ColorTokens.Parent.surface))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(ColorTokens.Parent.line, lineWidth: 1))
        .shadow(color: ColorTokens.Overlay.shadow.opacity(0.3), radius: 12, y: 4)
    }

    private var parentPromptCard: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Text(String(
                format: String(localized: "soundHunter.parent.q %@", defaultValue: "Слышали сегодня чистый %@ в свободной речи?"),
                display.sound
            ))
            .font(TypographyTokens.headline(16).weight(.bold))
            .foregroundStyle(ColorTokens.Parent.ink)
            .lineLimit(nil)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
            Text(String(localized: "soundHunter.parent.qs",
                        defaultValue: "Не на занятии, а в обычном разговоре — за столом, в игре, по дороге."))
                .font(TypographyTokens.body(12.5).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: SpacingTokens.small) {
                checkOption(.clean,
                            title: String(localized: "soundHunter.grade.clean", defaultValue: "Да, говорит чисто"),
                            sub: String(localized: "soundHunter.grade.clean.sub", defaultValue: "Сказал(а) слово сам(а), без напоминания"))
                checkOption(.sometimes,
                            title: String(localized: "soundHunter.grade.sometimes", defaultValue: "Иногда, с напоминанием"),
                            sub: String(localized: "soundHunter.grade.sometimes.sub", defaultValue: "Чисто, только когда подсказываю следить за звуком"))
                checkOption(.notyet,
                            title: String(localized: "soundHunter.grade.notyet", defaultValue: "Пока нет"),
                            sub: String(localized: "soundHunter.grade.notyet.sub", defaultValue: "В свободной речи звук ещё «теряется»"))
            }
        }
        .padding(SpacingTokens.regular)
        .background(RoundedRectangle(cornerRadius: 22).fill(ColorTokens.Parent.surface))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(ColorTokens.Parent.line, lineWidth: 1))
        .shadow(color: ColorTokens.Overlay.shadow.opacity(0.4), radius: 18, y: 8)
    }

    private func checkOption(_ grade: CarryoverGrade, title: String, sub: String) -> some View {
        let selected = display.parentGrade == grade
        let isWarn = grade == .notyet
        let accent = isWarn ? ColorTokens.Brand.primary : ColorTokens.Brand.mint
        return Button {
            container.soundService.playUISound(.tap)
            container.hapticService.selection()
            Task { await interactor?.parentCheckIn(.init(grade: grade)) }
        } label: {
            HStack(spacing: SpacingTokens.small) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selected ? accent : ColorTokens.Parent.surface)
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(selected ? accent : ColorTokens.Parent.line, lineWidth: 2))
                        .frame(width: 26, height: 26)
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(TypographyTokens.headline(14.5).weight(.bold))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    Text(sub)
                        .font(TypographyTokens.body(11.5).weight(.semibold))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(SpacingTokens.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16)
                .fill(selected ? accent.opacity(0.10) : ColorTokens.Parent.bgDeep))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(selected ? accent : ColorTokens.Parent.line, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selected
            ? String(localized: "soundHunter.grade.selected.a11y", defaultValue: "Выбрано")
            : "")
        .accessibilityHint(sub)
    }

    private var parentVoiceNotePearl: some View {
        Button {
            toggleVoiceNote()
        } label: {
            HStack(spacing: SpacingTokens.small) {
                Image(systemName: display.isRecordingNote ? "stop.fill" : "mic.fill")
                    .font(TypographyTokens.headline(18).weight(.semibold))
                    .foregroundStyle(ColorTokens.Brand.lilac)
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 14).fill(ColorTokens.Brand.lilac.opacity(0.18)))
                VStack(alignment: .leading, spacing: 6) {
                    Text(voiceNoteTitle)
                        .font(TypographyTokens.headline(13.5).weight(.bold))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    voiceWave
                }
                Spacer(minLength: 0)
                Text(voiceNoteDurationLabel)
                    .font(TypographyTokens.headline(12).weight(.bold))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .monospacedDigit()
            }
            .padding(SpacingTokens.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18).fill(ColorTokens.Brand.lilac.opacity(0.09)))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(ColorTokens.Brand.lilac.opacity(0.26), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(voiceNoteTitle)
        .accessibilityHint(display.isRecordingNote
            ? String(localized: "soundHunter.voice.stop.a11y", defaultValue: "Нажми, чтобы остановить запись")
            : String(localized: "soundHunter.voice.start.a11y", defaultValue: "Нажми, чтобы записать голосовую заметку"))
    }

    private var voiceWave: some View {
        let heights: [CGFloat] = [6, 12, 9, 14, 7, 11, 5, 13, 8]
        return HStack(alignment: .center, spacing: 3) {
            ForEach(Array(heights.enumerated()), id: \.offset) { idx, h in
                Capsule()
                    .fill(ColorTokens.Brand.lilac.opacity(display.isRecordingNote ? 0.8 : 0.55))
                    .frame(width: 3, height: display.isRecordingNote && !reduceMotion ? h + 2 : h)
                    .animation(
                        reduceMotion || !display.isRecordingNote ? nil
                        : .easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(Double(idx) * 0.05),
                        value: display.isRecordingNote
                    )
            }
        }
        .frame(height: 16)
        .accessibilityHidden(true)
    }

    private var parentSignalCard: some View {
        HStack(alignment: .top, spacing: SpacingTokens.small) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(TypographyTokens.body(14).weight(.bold))
                .foregroundStyle(ColorTokens.Brand.mint)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 9).fill(ColorTokens.Brand.mint.opacity(0.18)))
                .accessibilityHidden(true)
            Text(String(
                format: String(
                    localized: "soundHunter.parent.signal %@",
                    // swiftlint:disable:next line_length
                    defaultValue: "Ваша отметка помогает плану занятий: при чистой свободной речи звук %@ двигается к завершению, иначе вернутся упражнения автоматизации."
                ),
                display.sound
            ))
            .font(TypographyTokens.body(12.5).weight(.semibold))
            .foregroundStyle(ColorTokens.Parent.inkMuted)
            .lineLimit(nil)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: RadiusTokens.md).fill(ColorTokens.Brand.mint.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: RadiusTokens.md).strokeBorder(ColorTokens.Brand.mint.opacity(0.22), lineWidth: 1))
    }

    // MARK: - Mascot row

    private func mascotRow(text: String, state: LyalyaState) -> some View {
        HStack(alignment: .bottom, spacing: SpacingTokens.small) {
            LyalyaMascotView(state: reduceMotion ? .idle : state, size: 60)
                .accessibilityHidden(true)
            HSSpeechBubble(text, direction: .left, style: .lyalya, maxWidth: 250)
            Spacer(minLength: 0)
        }
        .padding(.top, SpacingTokens.tiny)
    }

    private var kidMascotText: String {
        if display.isNetFull {
            return String(localized: "soundHunter.mascot.full",
                          defaultValue: "Сачок полон! Покажи маме свою копилку и расскажи, какие слова поймал 🌟")
        }
        return String(
            format: String(
                localized: "soundHunter.mascot.catch %@",
                defaultValue: "Когда услышишь слово со звуком %@ — нажми «Поймал!». Я добавлю звёздочку в сачок 🌟"
            ),
            display.sound
        )
    }

    private var collectionMascotText: String {
        String(
            format: String(
                localized: "soundHunter.mascot.collection %@",
                defaultValue: "Покажи маме свою копилку — пусть тоже порадуется твоему чистому %@! Завтра новая охота 🎯"
            ),
            display.sound
        )
    }

    // MARK: - Parent helpers

    private var childInitial: String {
        let trimmed = display.childName.trimmingCharacters(in: .whitespaces)
        return String(trimmed.first ?? "•").uppercased()
    }

    private var childTitle: String {
        let name = display.childName.trimmingCharacters(in: .whitespaces)
        if name.isEmpty {
            return String(localized: "soundHunter.parent.child.unnamed", defaultValue: "Ваш ребёнок")
        }
        return String(
            format: String(localized: "soundHunter.parent.child %@ %lld", defaultValue: "%@, %lld лет"),
            name, display.childAge
        )
    }

    private var voiceNoteTitle: String {
        if display.isRecordingNote {
            return String(localized: "soundHunter.voice.recording", defaultValue: "Идёт запись…")
        }
        if display.hasVoiceNote {
            return String(localized: "soundHunter.voice.saved", defaultValue: "Заметка записана")
        }
        return String(localized: "soundHunter.voice.title", defaultValue: "Заметка-перл (по желанию)")
    }

    private var voiceNoteDurationLabel: String {
        let total = Int(display.isRecordingNote ? display.noteDurationSec : display.noteDurationSec)
        return String(format: "0:%02d", min(total, 59))
    }

    // MARK: - Actions

    private func catchWord() {
        container.soundService.playUISound(.correct)
        container.hapticService.notification(.success)
        Task { await interactor?.catchWord(.init(word: nil)) }
    }

    private func toggleVoiceNote() {
        container.soundService.playUISound(.tap)
        if display.isRecordingNote {
            Task { await interactor?.stopVoiceNote() }
        } else {
            Task { await interactor?.startVoiceNote() }
        }
    }

    private func playSound() {
        container.soundService.playUISound(.tap)
    }

    private func exit() {
        container.soundService.playUISound(.tap)
        display.pendingExit = true
    }

    // MARK: - Color helpers (circuit-aware)

    private var ink: Color { display.circuit == .parent ? ColorTokens.Parent.ink : ColorTokens.Kid.ink }
    private var inkMuted: Color { display.circuit == .parent ? ColorTokens.Parent.inkMuted : ColorTokens.Kid.inkMuted }
    private var inkSoft: Color { display.circuit == .parent ? ColorTokens.Parent.inkSoft : ColorTokens.Kid.inkSoft }
    private var surfaceAlt: Color { display.circuit == .parent ? ColorTokens.Parent.bgDeep : ColorTokens.Kid.surfaceAlt }
    private var line: Color { display.circuit == .parent ? ColorTokens.Parent.line : ColorTokens.Kid.line }

    // MARK: - Bootstrap

    @MainActor
    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        let resolvedChildId = childId.isEmpty ? container.currentChildId : childId
        let presenter = SoundHunterDayPresenter()
        let interactor = SoundHunterDayInteractor(
            childId: resolvedChildId,
            childRepository: container.childRepository,
            carryoverRepository: container.carryoverLogRepository,
            missionLoader: CarryoverMissionLoader(),
            adaptivePlanner: container.adaptivePlannerService,
            stageProgressStore: container.stageProgressStore,
            notificationService: container.notificationService,
            voiceNoteWorker: CarryoverVoiceNoteWorker()
        )
        let router = SoundHunterDayRouter()

        interactor.presenter = presenter
        presenter.display = display

        self.presenter = presenter
        self.interactor = interactor
        self.router = router

        logger.info("bootstrap child=\(resolvedChildId, privacy: .public) circuit=\(String(describing: circuit), privacy: .public)")
        await interactor.start(.init(childId: resolvedChildId, circuit: circuit))
    }
}

// MARK: - SoundHunterCTA

private struct SoundHunterCTA: View {
    let title: String
    let icon: String
    let circuit: SoundHunterDayModels.Circuit
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
                RoundedRectangle(cornerRadius: 20, style: .continuous)
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

// MARK: - FlowWrap (chip wrapping layout)

/// Простой переносящий по строкам контейнер для чипов слов (как flex-wrap).
private struct FlowWrap: Layout {
    var spacing: CGFloat = 9

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Preview

#Preview("Sound Hunter — Kid") {
    SoundHunterDayView(childId: "preview-child-1", circuit: .kid)
        .environment(AppContainer.preview())
}

#Preview("Sound Hunter — Parent") {
    SoundHunterDayView(childId: "preview-child-1", circuit: .parent)
        .environment(AppContainer.preview())
}
