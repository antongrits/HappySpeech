import OSLog
import SwiftUI

// MARK: - WorldMapView
//
// Kid-контур. «Карта звуков»: 5 цветных зон, маскот сверху, sticky bottom-панель
// с общим прогрессом и стриком. Прогресс приходит из Realm (на текущем спринте —
// in-memory seed в Interactor'е). Сигнатура `init(childId:targetSound:)`
// сохранена — вью подключён в AppCoordinator.
//
// VIP: View → Interactor → Presenter → Display.

struct WorldMapView: View {

    // MARK: - Inputs

    let childId: String
    let targetSound: String

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    /// Единая точка выхода из kid-маршрутов (заменяет dismiss() — маршрут
    /// меняется через navigate(to:), поэтому dismiss() — no-op).
    @Environment(\.exitGame) private var exitGame

    // MARK: - VIP State

    @State private var display = WorldMapDisplay()
    @State private var interactor: WorldMapInteractor?
    @State private var presenter: WorldMapPresenter?
    @State private var router: WorldMapRouter?
    @State private var bootstrapped = false
    @State private var appeared = false

    // MARK: - Optional callbacks

    private let onDismiss: (() -> Void)?
    private let onOpenZone: ((String) -> Void)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "WorldMapView")

    // MARK: - Init

    init(
        childId: String,
        targetSound: String,
        onDismiss: (() -> Void)? = nil,
        onOpenZone: ((String) -> Void)? = nil
    ) {
        self.childId = childId
        self.targetSound = targetSound
        self.onDismiss = onDismiss
        self.onOpenZone = onOpenZone
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundLayer

            // Эталон «карта приключений»: шапка острова сверху (заголовок +
            // звёзды + коралловый трек), путь-квест по центру, CTA-карточка
            // «текущий уровень» снизу — единый визуальный язык всех карт.
            VStack(spacing: 0) {
                MapJourneyHeader(
                    title: headerTitle,
                    subtitle: headerSubtitle,
                    starsCollected: starsCollectedLabel,
                    starsTotal: starsTotalLabel,
                    progress: display.totalProgressFraction,
                    onLeadingTap: { exitGame() },
                    reduceMotion: reduceMotion
                )
                .padding(.top, SpacingTokens.tiny)

                if useGridFallback {
                    // iPad / accessibility size: классическая сетка плиток.
                    ScrollView {
                        VStack(spacing: SpacingTokens.large) {
                            zonesGrid
                            Spacer(minLength: 110)
                        }
                        .padding(.top, SpacingTokens.medium)
                        .padding(.bottom, SpacingTokens.xxLarge)
                    }
                } else {
                    // Redesign §1 — вертикальный путь-квест: канвас островов
                    // скроллится сам, заполняя вертикаль.
                    islandsCanvas
                        .padding(.bottom, 96)
                }
            }

            stickyCTAPanel

            if let toast = display.toastMessage {
                HSToast(toast, type: .info)
                    .padding(.bottom, 110)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(2.0))
                        withAnimation(.easeInOut(duration: 0.25)) {
                            display.clearToast()
                        }
                    }
            }
        }
        .navigationTitle(String(localized: "worldMap.navTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.circuitContext, .kid)
        .task { await bootstrap() }
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.5).delay(0.1)) {
                appeared = true
            }
        }
        .sheet(item: Binding(
            get: { display.zoneDetailViewModel },
            set: { if $0 == nil { display.dismissZoneDetailSheet() } }
        )) { detail in
            WorldZoneDetailSheet(
                viewModel: detail,
                reduceMotion: reduceMotion,
                onStart: { handleStartZone(detail.zoneId) },
                onDismiss: { display.dismissZoneDetailSheet() }
            )
            .presentationDetents([.large, .fraction(0.72)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(RadiusTokens.xl)
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        // Эталон kid-map.html: тёплый кремово-персиковый фон без синих/зелёных
        // холодных тонов. Kid.bg (cream) + мягкий коралловый radial сверху +
        // butter radial снизу = ощущение тёплого летнего острова.
        ZStack {
            ColorTokens.Kid.bg
                .ignoresSafeArea()
            RadialGradient(
                colors: [
                    ColorTokens.Brand.primaryLo.opacity(colorScheme == .dark ? 0.18 : 0.30),
                    Color.clear
                ],
                center: .top,
                startRadius: 0,
                endRadius: 380
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [
                    ColorTokens.Brand.butter.opacity(colorScheme == .dark ? 0.12 : 0.22),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 0.9),
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Header derived values
    //
    // Шапка эталона показывает ТЕКУЩИЙ остров (где стоит Ляля) — заголовок,
    // звуки-подзаголовок, прогресс. Значения берутся из готовых `display.zones`
    // (никакой бизнес-логики во View) — текущий остров либо первый открытый.

    /// Текущий остров: маркированный `isCurrentLocation` и открытый, иначе —
    /// первый открытый, иначе — первый в списке.
    private var currentZone: WorldZoneCard? {
        display.zones.first(where: { $0.isCurrentLocation && !$0.isLocked })
            ?? display.zones.first(where: { !$0.isLocked })
            ?? display.zones.first
    }

    private var headerTitle: String {
        currentZone?.name ?? String(localized: "worldmap.title")
    }

    private var headerSubtitle: String {
        if let zone = currentZone, !zone.soundsLabel.isEmpty {
            return zone.soundsLabel
        }
        return String(localized: "worldMap.mascot.greeting")
    }

    /// Численная часть собранных звёзд из готового `totalStarsLabel` (например
    /// «12 ⭐» → «12»). Не пересчитывает данные — лишь форматирует под пилюлю.
    private var starsCollectedLabel: String {
        let digits = display.totalStarsLabel.filter { $0.isNumber }
        return digits.isEmpty ? "0" : digits
    }

    /// «из N» — N = сумма доступных звёзд (1 звезда / урок) по открытым зонам;
    /// чтобы не дублировать логику Presenter'а, показываем только когда понятно.
    private var starsTotalLabel: String? { nil }

    // MARK: - Islands canvas

    private var islandsCanvas: some View {
        // Канвас сам центрирует карточки по горизонтали и скроллится вертикально.
        WorldMapIslandsCanvas(
            cards: display.zones,
            appeared: appeared,
            reduceMotion: reduceMotion,
            onTapZone: { handleZoneTap($0) }
        )
    }

    /// Использовать сеточный fallback вместо канваса:
    /// — на iPad/regular size class (там много места — карточки выглядят лучше);
    /// — на больших Dynamic Type, где плашки на канвасе перестают помещаться.
    private var useGridFallback: Bool {
        if hSizeClass == .regular { return true }
        return dynamicTypeSize >= .accessibility1
    }

    // MARK: - Zones grid

    private var zonesGrid: some View {
        let isCompact = hSizeClass == .compact
        // Fix #2b — adaptive grid (min 120) уменьшает пустые поля при
        // 2 столбцах на iPhone SE 3 / при крупных Dynamic Type, и плотно
        // упаковывает плитки на iPad regular size class.
        let columns: [GridItem] = [
            GridItem(.adaptive(minimum: 120), spacing: SpacingTokens.large)
        ]

        return VStack(spacing: SpacingTokens.regular) {
            // Первые 4 зоны — грид 2×2
            LazyVGrid(columns: columns, spacing: SpacingTokens.regular) {
                ForEach(Array(display.zones.prefix(4).enumerated()), id: \.element.id) { index, card in
                    WorldZoneTile(
                        card: card,
                        cardWidth: isCompact ? nil : 220,
                        appeared: appeared,
                        index: index,
                        reduceMotion: reduceMotion
                    ) {
                        handleZoneTap(card.id)
                    }
                    // Block J v18 — kavsoft-style tilt carousel scroll transition.
                    .hsScrollEffect(.tiltCarousel)
                    // Step 10 Batch C — Pattern 3: scrollTransition stagger fade+scale,
                    // gated by reduce-motion.
                    .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                        content
                            .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                            .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.92))
                    }
                    // Step 10 Batch C — Pattern 4: мягкий parallax drift на island tiles.
                    .hsParallaxTile(factor: 0.25)
                }
            }

            // 5-я зона — отдельной полной шириной
            if let last = display.zones.dropFirst(4).first {
                WorldZoneTile(
                    card: last,
                    cardWidth: nil,
                    appeared: appeared,
                    index: 4,
                    reduceMotion: reduceMotion,
                    isWide: true
                ) {
                    handleZoneTap(last.id)
                }
                // Block J v18 — kavsoft-style tilt carousel scroll transition.
                .hsScrollEffect(.tiltCarousel)
                // Step 10 Batch C — Pattern 3 + 4: stagger fade+scale + parallax drift.
                .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                    content
                        .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                        .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.92))
                }
                .hsParallaxTile(factor: 0.25)
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
    }

    // MARK: - Sticky CTA panel
    //
    // Нижняя карточка «текущий уровень» по эталону: бейдж со звуком, название
    // острова и кнопка «Играть»/«Открыть». Заблокированный текущий остров —
    // приглушённая карточка с замком. Тап открывает detail-sheet острова, как и
    // раньше (вся навигация/логика — без изменений).

    @ViewBuilder
    private var stickyCTAPanel: some View {
        if let zone = currentZone {
            MapLevelCTACard(
                badgeText: ctaBadgeText(for: zone),
                kicker: String(localized: "worldMap.cta.kicker", defaultValue: "Текущий остров"),
                levelTitle: zone.name,
                actionTitle: zone.isLocked
                    ? String(localized: "worldMap.cta.locked", defaultValue: "Закрыто")
                    : (zone.progress > 0
                        ? String(localized: "worldMap.cta.continue", defaultValue: "Продолжить")
                        : String(localized: "action.play", defaultValue: "Играть")),
                actionIcon: "play.fill",
                isLocked: zone.isLocked,
                reduceMotion: reduceMotion,
                onTap: { handleZoneTap(zone.id) }
            )
            .padding(.bottom, SpacingTokens.tiny)
        }
    }

    /// Первая буква звука острова для бейджа CTA (например «Ц»). Если звуков нет
    /// — fallback на иконку.
    private func ctaBadgeText(for zone: WorldZoneCard) -> String {
        guard let first = zone.soundsLabel.split(separator: "·").first?
            .trimmingCharacters(in: .whitespaces), !first.isEmpty else {
            return ""
        }
        return String(first.prefix(2))
    }

    // MARK: - Actions

    private func handleZoneTap(_ id: String) {
        container.hapticService.impact(.medium)
        interactor?.selectZone(.init(zoneId: id))
        // Всегда открываем detail sheet — для locked зон там информация о блокировке
        interactor?.loadZoneDetail(.init(zoneId: id))
        if let card = display.zones.first(where: { $0.id == id }), card.isLocked {
            container.hapticService.notification(.warning)
        } else {
            container.soundService.playUISound(.tap)
        }
    }

    private func handleStartZone(_ id: String) {
        display.dismissZoneDetailSheet()
        // Интро-кат-сцена острова перед уроком (не гейтит вход — показывается
        // поверх, skippable, один раз/остров). CutsceneService проверит seen +
        // наличие видео/постера; если нечего показывать — просто не всплывёт.
        if let island = islandId(forZoneId: id) {
            container.cutsceneService.enqueue(.islandIntro(island), childId: childId)
        }
        router?.routeOpenZone(zoneId: id)
    }

    // MARK: - Bootstrap

    @MainActor
    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        // D-18 v27 — гарантируем, что карта показывается первой:
        // detail-sheet зоны открывается только осознанным тапом по зоне,
        // а не остаётся поднятым из stale-состояния при входе на экран.
        display.dismissZoneDetailSheet()

        let interactor = WorldMapInteractor()
        let presenter = WorldMapPresenter()
        let router = WorldMapRouter()

        // Даём интерактору доступ к реальным репозиториям: childRepository —
        // источник progressSummary (прогресс зон), sessionRepository — источник
        // серии активных дней. Без них карта остаётся честно пустой.
        interactor.childRepository = container.childRepository
        interactor.sessionRepository = container.sessionRepository
        interactor.presenter = presenter
        presenter.display = display
        router.onDismiss = onDismiss
        router.onOpenZone = onOpenZone

        self.interactor = interactor
        self.presenter = presenter
        self.router = router

        interactor.loadMap(.init(
            childId: childId,
            highlightedSound: targetSound.isEmpty ? nil : targetSound,
            childAge: nil
        ))

        // Кат-сцена-пролог «Страна Звуков уснула»: первый показ карты после
        // онбординга. CutsceneService сам проверит seen-флаг (один раз/ребёнка)
        // и наличие видео/постера — повторно не всплывёт.
        container.cutsceneService.enqueue(.onboardingComplete, childId: childId)

        // Страховка триумфов/майлстоунов: если ребёнок завершил остров или
        // достиг стрика, но триумф ещё не показан (например вернулся на карту
        // мимо SessionComplete) — догоняем здесь по реальному прогрессу.
        await enqueueCompletedIslandCutscenes()
    }

    // MARK: - Cutscene triggers

    /// Маппинг `zoneId → MapIslandID` для интро-кат-сцен острова.
    private func islandId(forZoneId zoneId: String) -> MapIslandID? {
        switch zoneId {
        case "zone-vowels":     return .vowels
        case "zone-whistling":  return .whistling
        case "zone-hissing":    return .hissing
        case "zone-affricates": return .affricates
        case "zone-sonorant":   return .sonorant
        case "zone-velar":      return .velar
        case "zone-grammar":    return .special
        default:                return nil
        }
    }

    /// Догоняет триумф-кат-сцены уже завершённых островов и стрик-майлстоуны на
    /// основе РЕАЛЬНОГО прогресса ребёнка (без фабрикации). Каждая сцена
    /// проходит через `shouldPlay` (seen + видео/постер), так что повторно не
    /// покажется. Вызывается из `bootstrap`.
    @MainActor
    private func enqueueCompletedIslandCutscenes() async {
        guard !childId.isEmpty else { return }
        guard let profile = try? await container.childRepository.fetch(id: childId) else { return }

        let summary = profile.progressSummary
        var completedCount = 0
        for (zoneId, sounds) in Self.islandSounds {
            guard !sounds.isEmpty else { continue }
            let mastery = sounds.reduce(0.0) { $0 + (summary[$1] ?? 0) } / Double(sounds.count)
            if mastery >= 1.0 {
                completedCount += 1
                if let island = islandId(forZoneId: zoneId) {
                    container.cutsceneService.enqueue(.islandComplete(island), childId: childId)
                }
            }
        }
        // Все 5 звуковых островов завершены → финал (грамматика — бонус, см.
        // contentIslandCount).
        if completedCount >= Self.contentIslandCount {
            container.cutsceneService.enqueue(.allIslandsComplete, childId: childId)
        }
        // Стрик-майлстоуны 7 / 30.
        for milestone in [7, 30] where profile.currentStreak >= milestone {
            container.cutsceneService.enqueue(.streak(days: milestone), childId: childId)
        }
    }

    /// Звуки контентных островов (vowels не получает своей пары — его роль
    /// играет пролог; см. спеку §2). Используется для honest-проверки
    /// завершённости острова из `progressSummary`.
    private static let islandSounds: [(zoneId: String, sounds: [String])] = [
        ("zone-whistling", ["С", "Сь", "З", "Зь", "Ц"]),
        ("zone-hissing", ["Ш", "Ж"]),
        ("zone-affricates", ["Ч", "Щ"]),
        ("zone-sonorant", ["Р", "Рь", "Л", "Ль"]),
        ("zone-velar", ["К", "Кь", "Г", "Гь", "Х", "Хь"])
    ]

    /// Контентных островов с собственной парой кат-сцен (для триггера финала).
    /// Грамматика без звуков не детектится из progressSummary, поэтому финал
    /// триггерится по завершению 5 звуковых островов (см. спеку §5 п.2 —
    /// финалом считается прохождение звуковых островов; грамматика — бонус).
    private static let contentIslandCount = 5
}
