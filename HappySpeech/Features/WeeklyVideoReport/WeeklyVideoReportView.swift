import AVKit
import SwiftUI

// MARK: - WeeklyVideoReportView
//
// Анимированный еженедельный ВИДЕО-отчёт для родителя (п.26 — Remotion).
//
// Видео-фон — пред-рендеренный шаблон (Remotion, 1080×1920, 39 с): заставка →
// бары по звукам → достижения с конфетти → рекомендация. Поверх видео —
// панель с РЕАЛЬНЫМИ числами ребёнка из недельной агрегации SessionRepository.
//
// Честное ограничение (показано в подписи): Remotion рендерит на маке (node),
// не on-device, поэтому сама композиция — общий тёплый шаблон, а персональные
// данные ребёнка отображаются оверлеем (реальные, из Realm, не выдуманные).
//
// Reduced Motion: видео ставится на первый кадр (статично), числа видны сразу.

struct WeeklyVideoReportView: View {

    let childId: String

    @Environment(AppContainer.self) private var container
    @Environment(\.exitToParentHome) private var exitToParentHome
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var interactor = WeeklyVideoReportInteractor()
    @State private var player: AVPlayer?
    @State private var looper: AVPlayerLooper?
    @State private var bootstrapped = false
    @State private var showOverlay = false

    var body: some View {
        NavigationStack {
            ZStack {
                HSMeshGradientBackground(palette: .calm, animated: false)
                    .ignoresSafeArea()
                content
            }
            .navigationTitle(Text(String(localized: "weeklyVideoReport.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exitToParentHome()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
        }
        .environment(\.circuitContext, .parent)
        .task { await bootstrap() }
        .onDisappear { player?.pause() }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.sp4) {
                videoCard
                if interactor.state.isEmpty {
                    emptyDataNote
                } else {
                    realDataPanel
                }
                limitationNote
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp3)
            .padding(.bottom, SpacingTokens.sp6)
        }
    }

    // MARK: - Video card (Remotion template)

    private var videoCard: some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                HStack(spacing: SpacingTokens.sp1) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTokens.Brand.primary)
                    Text(String(localized: "weeklyVideoReport.video.label"))
                        .font(TypographyTokens.caption(11))
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer()
                    Button {
                        togglePlayback()
                    } label: {
                        Image(systemName: reduceMotion ? "play.circle.fill" : "arrow.counterclockwise.circle")
                            .font(.system(size: 22))
                            .foregroundStyle(ColorTokens.Brand.primary)
                    }
                    .accessibilityLabel(Text(String(localized: "weeklyVideoReport.video.replay")))
                }

                ZStack {
                    RoundedRectangle(cornerRadius: RadiusTokens.lg)
                        .fill(ColorTokens.Brand.butter.opacity(0.22))
                        .aspectRatio(9 / 16, contentMode: .fit)

                    if let player {
                        VideoPlayer(player: player)
                            .disabled(true)
                            .aspectRatio(9 / 16, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg))
                            .allowsHitTesting(false)
                    } else {
                        VStack(spacing: SpacingTokens.sp2) {
                            Image(systemName: "film")
                                .font(.system(size: 40))
                                .foregroundStyle(ColorTokens.Brand.primary.opacity(0.4))
                            Text(String(localized: "weeklyVideoReport.video.loading"))
                                .font(TypographyTokens.caption(12))
                                .foregroundStyle(ColorTokens.Parent.inkMuted)
                        }
                        .aspectRatio(9 / 16, contentMode: .fit)
                    }
                }
                .frame(maxHeight: 460)
                .accessibilityLabel(Text(String(localized: "weeklyVideoReport.video.a11y")))

                Text(String(localized: "weeklyVideoReport.video.subtitle"))
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(SpacingTokens.sp4)
        }
    }

    // MARK: - Real-data panel (overlay numbers)

    private var realDataPanel: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            // Заголовок с именем + неделей
            VStack(alignment: .leading, spacing: 2) {
                Text(headerTitle)
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "weeklyVideoReport.realData.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }

            // Метрики 2×2
            let columns = Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sp2), count: 2)
            LazyVGrid(columns: columns, spacing: SpacingTokens.sp2) {
                ForEach(interactor.state.overlayMetrics) { metric in
                    metricTile(metric)
                }
            }

            // Звуки
            if !interactor.state.sounds.isEmpty {
                Text(String(localized: "weeklyVideoReport.sounds.title"))
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .padding(.top, SpacingTokens.sp1)
                VStack(spacing: SpacingTokens.sp2) {
                    ForEach(interactor.state.sounds) { row in
                        soundRow(row)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SpacingTokens.sp4)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg)
                .fill(ColorTokens.Brand.butter.opacity(0.15))
        )
        .opacity(showOverlay ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: showOverlay)
    }

    private func metricTile(_ metric: WeeklyVideoReportModels.OverlayMetric) -> some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: metric.icon)
                        .foregroundStyle(ColorTokens.Parent.accent)
                    Spacer()
                }
                Text(metric.value)
                    .font(TypographyTokens.titleLarge(26))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(metric.caption)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(metric.caption): \(metric.value)"))
    }

    private func soundRow(_ row: WeeklyVideoReportModels.SoundRow) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            Text(row.sound)
                .font(TypographyTokens.headline(18))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(soundTint(row.sound)))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(ColorTokens.Brand.butter.opacity(0.3))
                    Capsule()
                        .fill(soundTint(row.sound))
                        .frame(width: geo.size.width * CGFloat(row.accuracyPercent) / 100)
                }
            }
            .frame(height: 18)
            Text("\(row.accuracyPercent)%")
                .font(TypographyTokens.body(15).weight(.bold))
                .foregroundStyle(ColorTokens.Parent.ink)
                .frame(width: 52, alignment: .trailing)
            Image(systemName: trendIcon(row.trend))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(trendTint(row.trend))
                .frame(width: 20)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(
            String(
                format: String(localized: "weeklyVideoReport.sound.a11y"),
                row.sound, row.accuracyPercent
            )
        ))
    }

    // MARK: - Notes

    private var emptyDataNote: some View {
        VStack(spacing: SpacingTokens.sp2) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40))
                .foregroundStyle(ColorTokens.Parent.accent)
                .accessibilityHidden(true)
            Text(String(localized: "weeklyVideoReport.empty.title"))
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Parent.ink)
                .multilineTextAlignment(.center)
            Text(String(localized: "weeklyVideoReport.empty.message"))
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.sp4)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg)
                .fill(ColorTokens.Brand.butter.opacity(0.15))
        )
        .accessibilityElement(children: .combine)
    }

    private var limitationNote: some View {
        HStack(alignment: .top, spacing: SpacingTokens.sp2) {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.Parent.inkSoft)
            Text(String(localized: "weeklyVideoReport.limitation"))
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Parent.inkSoft)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Helpers

    private var headerTitle: String {
        let state = interactor.state
        if state.childName.isEmpty {
            return String(localized: "weeklyVideoReport.realData.titleNeutral")
        }
        return String(
            format: String(localized: "weeklyVideoReport.realData.title"),
            state.childName, state.weekLabel
        )
    }

    private func soundTint(_ sound: String) -> Color {
        let s = sound.trimmingCharacters(in: .whitespaces).uppercased()
        if ["С", "З", "Ц", "СЬ", "ЗЬ"].contains(s) { return ColorTokens.Brand.primary }
        if ["Ш", "Ж", "Ч", "Щ"].contains(s) { return ColorTokens.Brand.gold }
        if ["Р", "РЬ", "Л", "ЛЬ"].contains(s) { return ColorTokens.Brand.lilac }
        if ["К", "Г", "Х", "КЬ", "ГЬ", "ХЬ"].contains(s) { return ColorTokens.Brand.rose }
        return ColorTokens.Brand.primary
    }

    private func trendIcon(_ trend: ProgressTrend) -> String {
        switch trend {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .stable: return "minus"
        }
    }

    private func trendTint(_ trend: ProgressTrend) -> Color {
        switch trend {
        case .up: return ColorTokens.Brand.gold
        case .down: return ColorTokens.Brand.rose
        case .stable: return ColorTokens.Parent.inkMuted
        }
    }

    // MARK: - Lifecycle

    @MainActor
    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        let worker = ProgressDashboardWorker(
            sessionRepository: container.sessionRepository,
            childRepository: container.childRepository
        )
        interactor = WeeklyVideoReportInteractor(
            worker: worker,
            childRepository: container.childRepository
        )
        let resolvedChildId = childId.isEmpty ? container.currentChildId : childId
        await interactor.load(childId: resolvedChildId)

        setupPlayer()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.4)) {
            showOverlay = true
        }
    }

    private func setupPlayer() {
        guard let url = VideoCatalog.url(for: .weeklyReport(.sample)) else { return }
        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer()
        let playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        self.looper = playerLooper
        self.player = queuePlayer
        if reduceMotion {
            queuePlayer.seek(to: .zero, completionHandler: { _ in })
        } else {
            queuePlayer.play()
        }
    }

    private func togglePlayback() {
        guard let player else { return }
        hapticService.impact(.light)
        player.seek(to: .zero)
        player.play()
    }
}

// MARK: - Preview

#Preview("WeeklyVideoReport — Light") {
    let container = AppContainer.preview()
    container.currentChildId = "preview-child-1"
    return WeeklyVideoReportView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(container)
}

#Preview("WeeklyVideoReport — Dark") {
    let container = AppContainer.preview()
    container.currentChildId = "preview-child-1"
    return WeeklyVideoReportView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(container)
        .preferredColorScheme(.dark)
}
