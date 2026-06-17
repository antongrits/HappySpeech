import SwiftUI

// MARK: - SpecialistHomeViewComponents
//
// Подкомпоненты `SpecialistHomeView`.
// Sheets и список сессий вынесены в `SpecialistHomeViewSheets.swift`.

// MARK: - SpecChildListView

struct SpecChildListView: View {
    @Environment(AppContainer.self) private var container
    @State private var children: [ChildProfileDTO] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var sortOrder: SpecialistModels.Fetch.Request.SortOrder = .byLastActivity
    @State private var showSortSheet = false
    @State private var showAddChildInfo = false

    var filteredChildren: [ChildProfileDTO] {
        guard !searchText.isEmpty else { return children }
        return children.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }

    // v27 visual modernization (#9) — специалист аналитический контур: depth
    // скромный. Поверх Spec.bg — едва заметный accent-radial в hero-зоне
    // (верхний угол), чтобы экран не был чисто системно-серым.
    @ViewBuilder
    private var specBackground: some View {
        ZStack(alignment: .top) {
            ColorTokens.Spec.bg
            RadialGradient(
                colors: [ColorTokens.Spec.accent.opacity(0.07), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                specBackground
                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .tint(ColorTokens.Spec.accent)
                } else if filteredChildren.isEmpty && !isLoading {
                    // E v21: 3D Ляля в empty state SpecChildList (students list)
                    // — требование «3D героев на каждом экране».
                    VStack(spacing: SpacingTokens.regular) {
                        LyalyaHeroView(state: .thinking, size: 140)
                            .accessibilityHidden(true)
                        HSEmptyState(
                            icon: "person.2.fill",
                            title: String(localized: "spec.children.empty.title"),
                            message: String(localized: "spec.children.empty.message")
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Эталон specialist-home: карточки подопечных — не системный
                    // UITableView-List, а ScrollView с VStack карточек на Spec.bg.
                    // Белая карточка + тень на нейтральном фоне = аналитический
                    // специалистский стиль (паттерн из open-design specialist-home.html).
                    ScrollView {
                        VStack(spacing: 0) {
                            // Заголовок секции
                            HStack {
                                Text(String(
                                    format: String(localized: "spec.children.listHeader"),
                                    filteredChildren.count
                                ))
                                .font(TypographyTokens.caption(12).weight(.semibold))
                                .foregroundStyle(ColorTokens.Spec.inkMuted)
                                .textCase(.uppercase)
                                Spacer()
                            }
                            .padding(.horizontal, SpacingTokens.screenEdge)
                            .padding(.top, SpacingTokens.regular)
                            .padding(.bottom, SpacingTokens.small)

                            // Единая карточка-контейнер с разделителями (как в эталоне)
                            VStack(spacing: 0) {
                                ForEach(Array(filteredChildren.enumerated()), id: \.element.id) { index, child in
                                    NavigationLink(value: child.id) {
                                        VStack(spacing: 0) {
                                            SpecChildRow(child: child)
                                                .padding(.horizontal, SpacingTokens.regular)
                                            if index < filteredChildren.count - 1 {
                                                Divider()
                                                    .padding(.leading, 76)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("specialistStudentRow_\(index)")
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                                    .fill(ColorTokens.Spec.surface)
                                    .shadow(color: ColorTokens.Overlay.shadow, radius: 8, x: 0, y: 2)
                            )
                            .padding(.horizontal, SpacingTokens.screenEdge)

                            // Подсказка внизу
                            HStack(alignment: .top, spacing: SpacingTokens.sp2) {
                                Image(systemName: "lightbulb.fill")
                                    .font(TypographyTokens.caption(12))
                                    .foregroundStyle(ColorTokens.Spec.accent)
                                    .accessibilityHidden(true)
                                Text(String(localized: "spec.children.hint"))
                                    .font(TypographyTokens.caption(12))
                                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineLimit(nil)
                            }
                            .padding(.horizontal, SpacingTokens.screenEdge)
                            .padding(.top, SpacingTokens.regular)
                            .accessibilityElement(children: .combine)

                            Spacer(minLength: SpacingTokens.xLarge)
                        }
                    }
                    .accessibilityIdentifier("specialistStudentList")
                }
            }
            .searchable(
                text: $searchText,
                prompt: String(localized: "spec.children.search.prompt")
            )
            .navigationTitle(String(localized: "spec.children.title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSortSheet = true
                    } label: {
                        Label(
                            String(localized: "spec.sort.button"),
                            systemImage: "arrow.up.arrow.down"
                        )
                        .accessibilityHint(String(localized: "spec.sort.hint"))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddChildInfo = true
                    } label: {
                        Image(systemName: "plus")
                            .accessibilityHidden(true)
                    }
                    .accessibilityLabel(String(localized: "spec.addChild.button"))
                    .accessibilityHint(String(localized: "spec.addChild.hint"))
                }
            }
            .confirmationDialog(
                String(localized: "spec.sort.title"),
                isPresented: $showSortSheet,
                titleVisibility: .visible
            ) {
                ForEach(SpecialistModels.Fetch.Request.SortOrder.allCases, id: \.self) { order in
                    Button(order.rawValue) {
                        sortOrder = order
                        applySort()
                    }
                }
            }
            .navigationDestination(for: String.self) { childId in
                SpecChildDashboardView(childId: childId)
            }
            .sheet(isPresented: $showAddChildInfo) {
                SpecAddChildInfoSheet()
                    .presentationDetents([.medium])
            }
            .task { await reload() }
            .refreshable { await reload() }
        }
    }

    private func reload() async {
        isLoading = true
        do {
            let all = try await container.childRepository.fetchAll()
            children = sortChildren(all)
        } catch {
            HSLogger.app.error("SpecChildList reload: \(error.localizedDescription, privacy: .public)")
        }
        isLoading = false
    }

    private func applySort() {
        children = sortChildren(children)
    }

    private func sortChildren(_ list: [ChildProfileDTO]) -> [ChildProfileDTO] {
        switch sortOrder {
        case .byLastActivity:
            return list.sorted {
                ($0.lastSessionAt ?? .distantPast) > ($1.lastSessionAt ?? .distantPast)
            }
        case .byName:
            return list.sorted { $0.name < $1.name }
        case .byProgress:
            return list.sorted { a, b in
                let rateA = a.progressSummary.values.reduce(0, +) / Double(max(1, a.progressSummary.count))
                let rateB = b.progressSummary.values.reduce(0, +) / Double(max(1, b.progressSummary.count))
                return rateA > rateB
            }
        }
    }
}

// MARK: - SpecChildRow

struct SpecChildRow: View {
    let child: ChildProfileDTO

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.unitsStyle = .full
        return f
    }()

    var lastSessionLabel: String {
        guard let date = child.lastSessionAt else {
            return String(localized: "spec.neverPracticed")
        }
        return Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    var overallProgressPercent: Int {
        guard !child.progressSummary.isEmpty else { return 0 }
        let avg = child.progressSummary.values.reduce(0, +) / Double(child.progressSummary.count)
        return Int((avg * 100).rounded())
    }

    var body: some View {
        // РЕДИЗАЙН specialist-home (эталон `.client` карточки): avatar →
        // info-колонка (имя + возраст inline, звук-чипы, прогресс-бар) → правая
        // колонка (процент-пилюля + статус последнего занятия) → chevron.
        //
        // Fix-обрезка возраста: прежде «6 лет» усекалось до «6…», потому что
        // подзаголовок-HStack делил ширину строки с длинной правой меткой «Не
        // отрабатывали» (lineLimit 2). Теперь возраст и звук-чипы вынесены в
        // отдельные строки и получают `.fixedSize`/`layoutPriority`, а правая
        // колонка ограничена по ширине — возраст всегда виден целиком.
        HStack(spacing: SpacingTokens.sp3) {
            ZStack {
                Circle()
                    .fill(ColorTokens.Spec.accent.opacity(0.12))
                    .frame(width: 48, height: 48)
                Text(String(child.name.prefix(1)))
                    .font(TypographyTokens.titleSmall(20))
                    .foregroundStyle(ColorTokens.Spec.accent)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.sp2) {
                    Text(child.name)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Spec.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .layoutPriority(1)
                    if let ageLine {
                        Text(ageLine)
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Spec.inkMuted)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }

                if !child.targetSounds.isEmpty {
                    HStack(spacing: SpacingTokens.sp1) {
                        Text(String(localized: "spec.child.row.goalPrefix", defaultValue: "Цель:"))
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Spec.inkMuted)
                            .fixedSize(horizontal: true, vertical: false)
                        ForEach(child.targetSounds.prefix(3), id: \.self) { sound in
                            HSBadge(sound, style: .filled(ColorTokens.Spec.accent))
                        }
                    }
                }

                SpecProgressBar(percent: overallProgressPercent)
                    .frame(height: 4)
                    .padding(.top, 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(overallProgressPercent)%")
                    .font(TypographyTokens.headline(14))
                    .foregroundStyle(progressPillColor)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, SpacingTokens.sp2)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(progressPillColor.opacity(0.14)))
                Text(lastSessionLabel)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 96, alignment: .trailing)
            }
            .fixedSize(horizontal: false, vertical: true)

            Image(systemName: "chevron.right")
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, SpacingTokens.sp2)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(String(localized: "spec.child.row.hint"))
        .accessibilityAddTraits(.isButton)
    }

    /// Цвет процент-пилюли: тёплый amber/gold по эталону specialist-home.
    /// Семантическое разделение rose/warning/gold — только для
    /// специализированных аналитических экранов, не для списка подопечных.
    private var progressPillColor: Color {
        overallProgressPercent >= 70 ? ColorTokens.Brand.gold : ColorTokens.Brand.primary
    }

    /// Локализованная подпись возраста или `nil`, если возраст неизвестен.
    private var ageLine: String? {
        ChildAgeFormatter.yearsLabel(for: child.age)
    }

    private var accessibilityLabel: String {
        let sounds = child.targetSounds.joined(separator: ", ")
        let nameAge = ChildAgeFormatter.nameWithAge(name: child.name, age: child.age)
        return String(
            format: String(localized: "specialistHome.childRow.a11y"),
            nameAge,
            sounds,
            overallProgressPercent,
            lastSessionLabel
        )
    }
}

// MARK: - SpecProgressBar
//
// Эталон specialist-home: единый тёплый коралловый трек прогресса
// (Brand.primary). Цвет не меняется по значению — это прогресс, не оценка.
// Семантические цвета (rose/warning/gold) остаются только у процент-пилюли
// справа (маленький акцент), не у горизонтального трека.

struct SpecProgressBar: View {
    let percent: Int

    private var fraction: Double { Double(min(max(percent, 0), 100)) / 100.0 }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(ColorTokens.Brand.primaryLo.opacity(0.28))
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(ColorTokens.Brand.primary)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .accessibilityLabel(String(format: String(localized: "spec.progress.a11y"), percent))
    }
}

// MARK: - SpecDashboardHeader

struct SpecDashboardHeader: View {
    let child: ChildProfileDTO
    let summary: ReportSummary?

    var body: some View {
        HSLiquidGlassCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                HStack(spacing: SpacingTokens.sp4) {
                    ZStack {
                        Circle()
                            .fill(ColorTokens.Spec.accent.opacity(0.15))
                            .frame(width: 56, height: 56)
                        Text(String(child.name.prefix(1)))
                            .font(TypographyTokens.titleMedium(24))
                            .foregroundStyle(ColorTokens.Spec.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(child.name)
                            .font(TypographyTokens.headline(18))
                            .foregroundStyle(ColorTokens.Spec.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Text(childRowSubtitle(age: child.age, sounds: child.targetSounds))
                            .font(TypographyTokens.caption(13))
                            .foregroundStyle(ColorTokens.Spec.inkMuted)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: SpacingTokens.sp1)
                }

                if let summary {
                    Divider()
                    HStack(spacing: SpacingTokens.sp4) {
                        SpecMetricTile(
                            value: "\(summary.totalSessions)",
                            label: String(localized: "spec.metric.sessions"),
                            icon: "waveform.path"
                        )
                        SpecMetricTile(
                            value: "\(summary.totalMinutes)",
                            label: String(localized: "spec.metric.minutes"),
                            icon: "clock"
                        )
                        SpecMetricTile(
                            value: "\(Int(summary.overallSuccessRate * 100))%",
                            label: String(localized: "spec.metric.success"),
                            icon: "checkmark.seal"
                        )
                    }
                }
            }
            .padding(SpacingTokens.regular)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(headerA11yLabel)
    }

    /// Подпись «6 лет · звуки: …», либо «Звуки: …», если возраст неизвестен.
    private func childRowSubtitle(age: Int, sounds: [String]) -> String {
        let soundsText = sounds.joined(separator: ", ")
        guard let years = ChildAgeFormatter.yearsLabel(for: age) else {
            return String(
                format: String(localized: "specialistHome.childRow.soundsOnly"),
                soundsText
            )
        }
        return String(
            format: String(localized: "specialistHome.childRow.ageSounds"),
            years,
            soundsText
        )
    }

    private var headerA11yLabel: String {
        let nameAge = ChildAgeFormatter.nameWithAge(name: child.name, age: child.age)
        guard let summary else { return nameAge }
        return String(
            format: String(localized: "specialistHome.header.a11y.withSummary"),
            nameAge,
            summary.totalSessions,
            summary.totalMinutes,
            Int(summary.overallSuccessRate * 100)
        )
    }
}

// MARK: - SpecMetricTile

struct SpecMetricTile: View {
    let value: String
    let label: String
    // D-29 v27 — опциональная иконка метрики: добавляет аналитичность
    // специалистскому контуру, тайлы перестают быть голым текстом.
    var icon: String? = nil

    var body: some View {
        VStack(spacing: SpacingTokens.micro) {
            if let icon {
                Image(systemName: icon)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Spec.accent.opacity(0.75))
                    .accessibilityHidden(true)
            }
            Text(value)
                .font(TypographyTokens.kidDisplay(20))
                .foregroundStyle(ColorTokens.Spec.accent)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - SpecSoundBreakdownSection

struct SpecSoundBreakdownSection: View {
    let rows: [SoundBreakdownRow]

    var body: some View {
        if rows.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                Text(String(localized: "spec.section.soundBreakdown"))
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Spec.ink)

                ForEach(rows) { row in
                    SpecSoundRow(row: row)
                }
            }
        }
    }
}

// MARK: - SpecSoundRow

struct SpecSoundRow: View {
    let row: SoundBreakdownRow

    private var confidence: Double { max(0, min(1, row.averageConfidence)) }
    private var percent: Int { Int((confidence * 100).rounded()) }
    private var deltaSign: String { row.weekOverWeekDelta >= 0 ? "+" : "" }
    private var deltaText: String { "\(deltaSign)\(Int((row.weekOverWeekDelta * 100).rounded()))%" }
    private var barColor: Color {
        switch percent {
        case ..<50: return ColorTokens.Brand.rose
        case ..<80: return ColorTokens.Semantic.warning
        default: return ColorTokens.Brand.gold
        }
    }

    var body: some View {
        HSLiquidGlassCard(style: .primary, padding: 0) {
            HStack(spacing: SpacingTokens.sp3) {
                ZStack {
                    Circle()
                        .fill(barColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Text(row.sound)
                        .font(TypographyTokens.kidDisplay(16))
                        .foregroundStyle(barColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("\(percent)%")
                            .font(TypographyTokens.headline(14))
                            .foregroundStyle(ColorTokens.Spec.ink)
                        Text(deltaText)
                            .font(TypographyTokens.caption(11))
                            .foregroundStyle(
                                row.weekOverWeekDelta >= 0
                                    ? ColorTokens.Brand.gold
                                    : ColorTokens.Brand.rose
                            )
                        Spacer()
                        Text(row.currentStageTitle)
                            .font(TypographyTokens.caption(11))
                            .foregroundStyle(ColorTokens.Spec.inkMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(barColor.opacity(0.15))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(barColor)
                                .frame(width: geo.size.width * confidence)
                        }
                    }
                    .frame(height: 5)

                    Text(
                        String(
                            format: String(localized: "spec.sound.attempts"),
                            row.attempts, row.successes
                        )
                    )
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                }
            }
            .padding(SpacingTokens.regular)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Звук \(row.sound): \(percent)%, изменение \(deltaText). \(row.currentStageTitle)"
        )
    }
}

// MARK: - SpecAddChildInfoSheet

/// Информационный лист «Как добавить ученика».
///
/// Специалист НЕ создаёт профили детей напрямую: данные ребёнка принадлежат
/// родителю (COPPA / Kids Category). Ученик появляется в кабинете специалиста,
/// когда родитель делится кодом-приглашением, а специалист его принимает в
/// родительском/семейном контуре. Лист честно объясняет этот путь — это
/// реальное действие кнопки «+», а не мёртвый no-op.
struct SpecAddChildInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: SpacingTokens.sp4) {
                LyalyaHeroView(state: .explaining, size: 120)
                    .accessibilityHidden(true)
                Text(String(
                    localized: "spec.addChild.sheet.title",
                    defaultValue: "Как добавить ученика"
                ))
                .font(TypographyTokens.title(20))
                .foregroundStyle(ColorTokens.Spec.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                Text(String(
                    localized: "spec.addChild.sheet.message",
                    defaultValue: """
                    Ученики добавляются по коду-приглашению от родителя. \
                    Попросите родителя поделиться кодом подключения — после \
                    его ввода ребёнок появится в вашем списке.
                    """
                ))
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, SpacingTokens.screenEdge)
                Spacer()
                HSButton(
                    String(localized: "spec.addChild.sheet.dismiss", defaultValue: "Понятно"),
                    style: .primary,
                    size: .large
                ) {
                    dismiss()
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
            }
            .padding(.top, SpacingTokens.sp5)
            .padding(.bottom, SpacingTokens.sp4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ColorTokens.Spec.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Spec.inkMuted)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
        }
        .environment(\.circuitContext, .specialist)
    }
}
