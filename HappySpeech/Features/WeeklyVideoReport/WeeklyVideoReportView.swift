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
                // Эталон parent-report: фон Parent.bg (#F0EFF6 — нейтральный
                // тёплый лавандовый родительского контура), поверх — статичный
                // warm-mesh softlight для воздуха.
                ColorTokens.Parent.bg
                    .ignoresSafeArea()
                HSMeshGradientBackground(palette: .calm, animated: false)
                    .ignoresSafeArea()
                    .blendMode(.softLight)
                    .opacity(0.45)
                    .allowsHitTesting(false)
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
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Video hero card (thumbnail + coral play overlay + duration)

    private var videoCard: some View {
        HSCard(style: .elevated, padding: 0) {
            VStack(spacing: 0) {
                videoThumbnail
                videoCaption
            }
        }
    }

    private var videoThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .fill(ColorTokens.Brand.primaryLo.opacity(0.45))
                .aspectRatio(9 / 16, contentMode: .fit)

            if let player {
                VideoPlayer(player: player)
                    .disabled(true)
                    .aspectRatio(9 / 16, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous))
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

            // Coral round play button overlay
            Button {
                togglePlayback()
            } label: {
                Image(systemName: reduceMotion ? "play.fill" : "arrow.counterclockwise")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(ColorTokens.Brand.primary))
                    .shadow(color: ColorTokens.Brand.primary.opacity(0.45), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(String(localized: "weeklyVideoReport.video.replay")))

            // Duration badge (real metadata)
            if let duration = durationLabel {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(duration)
                            .font(TypographyTokens.caption(11).weight(.bold).monospacedDigit())
                            .foregroundStyle(ColorTokens.Overlay.onAccent)
                            .padding(.horizontal, SpacingTokens.sp2)
                            .padding(.vertical, SpacingTokens.micro)
                            .background(
                                Capsule().fill(Color.black.opacity(0.55))
                            )
                            .accessibilityHidden(true)
                    }
                }
                .padding(SpacingTokens.sp3)
            }
        }
        .frame(maxHeight: 460)
        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous))
        .accessibilityLabel(Text(String(localized: "weeklyVideoReport.video.a11y")))
    }

    private var videoCaption: some View {
        HStack(spacing: SpacingTokens.sp3) {
            Image(systemName: "film.stack")
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Brand.primary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                        .fill(ColorTokens.Brand.primary.opacity(0.14))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "weeklyVideoReport.video.label"))
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "weeklyVideoReport.video.subtitle"))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.sp4)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Real-data panel (overlay numbers)
    //
    // Эталон parent-report: крупный заголовок «Отличная неделя, Артём!» (title 28, bold),
    // дата и имя ребёнка под ним (body 14, inkMuted). Затем секции «В цифрах» и «Прогресс».

    private var realDataPanel: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
            // Заголовок с именем + неделей
            VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                Text(headerTitle)
                    .font(TypographyTokens.title(28))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.80)
                Text(String(localized: "weeklyVideoReport.realData.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // «Эта неделя в цифрах» — всегда 2 колонки (2×2 сетка).
            // Эталон: 4 плитки в 2 ряда — равномерно заполняют ширину на SE и 16 Pro.
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                sectionHeader(String(localized: "weeklyVideoReport.stats.title"))
                let columns = Array(
                    repeating: GridItem(.flexible(), spacing: SpacingTokens.sp2),
                    count: 2
                )
                LazyVGrid(columns: columns, spacing: SpacingTokens.sp2) {
                    ForEach(Array(interactor.state.overlayMetrics.enumerated()), id: \.element.id) { index, metric in
                        metricTile(metric, accent: metricAccent(index))
                    }
                }
            }

            // Прогресс по звукам
            if !interactor.state.sounds.isEmpty {
                VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                    sectionHeader(String(localized: "weeklyVideoReport.sounds.title"))
                    VStack(spacing: SpacingTokens.sp2) {
                        ForEach(interactor.state.sounds) { row in
                            soundRow(row)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(showOverlay ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: showOverlay)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            Circle()
                .fill(ColorTokens.Brand.primary)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Text(title)
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Parent.ink)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
        }
        .padding(.leading, SpacingTokens.micro)
        .accessibilityAddTraits(.isHeader)
    }

    private func metricAccent(_ index: Int) -> Color {
        let palette = [
            ColorTokens.Brand.primary,
            ColorTokens.Brand.lilac,
            ColorTokens.Brand.rose,
            ColorTokens.Brand.gold
        ]
        return palette[index % palette.count]
    }

    private func metricTile(_ metric: WeeklyVideoReportModels.OverlayMetric, accent: Color) -> some View {
        VStack(spacing: SpacingTokens.sp1) {
            Image(systemName: metric.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                        .fill(accent.opacity(0.14))
                )
            Text(metric.value)
                .font(TypographyTokens.title(20))
                .foregroundStyle(ColorTokens.Parent.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(metric.caption)
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.sp3)
        .padding(.horizontal, SpacingTokens.sp1)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(ColorTokens.Parent.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .strokeBorder(ColorTokens.Parent.line, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(metric.caption): \(metric.value)"))
    }

    private func soundRow(_ row: WeeklyVideoReportModels.SoundRow) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            Text(row.sound)
                .font(TypographyTokens.headline(20))
                .foregroundStyle(soundTint(row.sound))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                        .fill(soundTint(row.sound).opacity(0.14))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "[\(row.sound)]")
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Parent.ink)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(soundTint(row.sound).opacity(0.16))
                        Capsule()
                            .fill(soundTint(row.sound))
                            .frame(width: geo.size.width * CGFloat(row.accuracyPercent) / 100)
                    }
                }
                .frame(height: 8)
            }

            HStack(spacing: SpacingTokens.sp1) {
                Image(systemName: trendIcon(row.trend))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(trendTint(row.trend))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(trendTint(row.trend).opacity(0.14)))
                Text("\(row.accuracyPercent)%")
                    .font(TypographyTokens.headline(15).monospacedDigit())
                    .foregroundStyle(ColorTokens.Parent.ink)
            }
            .frame(minWidth: 64, alignment: .trailing)
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(ColorTokens.Parent.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .strokeBorder(ColorTokens.Parent.line, lineWidth: 1)
        )
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
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .fill(ColorTokens.Parent.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .strokeBorder(ColorTokens.Parent.line, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var limitationNote: some View {
        HStack(alignment: .top, spacing: SpacingTokens.sp2) {
            Image(systemName: "info.circle")
                .font(TypographyTokens.caption(14))
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

    /// Длительность видео из реальных метаданных манифеста («0:45»), или nil.
    private var durationLabel: String? {
        guard let meta = VideoCatalog.metadata(for: .weeklyReport(.sample)),
              meta.durationSeconds > 0 else { return nil }
        let total = Int(meta.durationSeconds.rounded())
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

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
        // Mint — крошечный позитивный акцент (по эталону отчёта), не на крупной заливке.
        case .up: return ColorTokens.Brand.mint
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
