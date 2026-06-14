import SwiftUI

// MARK: - ParentHomeOverviewCards
//
// Эталон parenthome.html (+ states-empty-error-loading.html). Блок «Обзор»
// родительского дашборда вынесен в самостоятельные View-структуры, чтобы:
//  • держать `ParentDashboardTab` в пределах SwiftLint type_body_length;
//  • держать `ParentHomeView.swift` в пределах file_length;
//  • давать чистую переиспользуемую иерархию карточек.
//
// Все данные — реальные из `ParentHomeViewModel` (Interactor/Presenter):
// никаких фабрикаций цифр во View. Тёплая палитра Parent; единые отступы;
// без обрезки текста и horizontal overflow на SE (375pt). Каждая аналитическая
// карточка имеет осмысленное пустое состояние (а не пустой график с 0%).

// MARK: - Shared card head (эталон .card-head)

/// Заголовок карточки: title слева + meta справа. Без обрезки (скейл-фактор).
struct ParentCardHead: View {
    let title: String
    let meta: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Parent.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: SpacingTokens.sp2)
            Text(meta)
                .font(TypographyTokens.caption(12).weight(.medium))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

// MARK: - Header (greeting + 3D Ляля)

/// Эталон parenthome.html (greeting-row): «hi» (muted) + крупный заголовок
/// «Обзор за неделю» слева; компактная 3D-Ляля справа как тёплый якорь.
struct ParentHeaderSection: View {
    let greeting: String

    var body: some View {
        HStack(alignment: .center, spacing: SpacingTokens.sp3) {
            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text(greeting)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "parentHome.overview.title"))
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: SpacingTokens.sp2)
            LyalyaHeroView(state: .waving, size: 88)
                .accessibilityHidden(true)
        }
        .padding(.top, SpacingTokens.sp3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(greeting + ". " + String(localized: "parentHome.overview.title"))
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Child card (аватар + имя/возраст + чипы + streak)

/// Эталон parenthome.html (.child-card): аватар-плашка с инициалом + имя/возраст
/// + коралловые чипы целевых звуков слева; справа — вертикальный streak-badge.
/// Чипы переносятся (нет overflow на SE), единый отступ sp4 (симметричный).
struct ParentChildCard: View {
    let name: String
    let nameWithAge: String
    let soundChips: [String]
    let streak: Int

    var body: some View {
        HSCard(style: .elevated, padding: SpacingTokens.sp4) {
            HStack(spacing: SpacingTokens.sp3) {
                avatar
                VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                    Text(nameWithAge)
                        .font(TypographyTokens.headline(18))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    if !soundChips.isEmpty { chipsRow }
                }
                Spacer(minLength: SpacingTokens.sp2)
                if streak > 0 { streakBadge }
            }
        }
        .environment(\.circuitContext, .parent)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11yLabel)
    }

    private var avatar: some View {
        RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 56, height: 56)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(TypographyTokens.kidDisplay(24))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
            )
            .shadow(color: ColorTokens.Brand.primary.opacity(0.3), radius: 8, y: 4)
            .accessibilityHidden(true)
    }

    private var chipsRow: some View {
        HStack(spacing: SpacingTokens.micro) {
            ForEach(soundChips.prefix(3), id: \.self) { sound in
                Text(String(format: String(localized: "parentHome.child.soundChip"), sound))
                    .font(TypographyTokens.caption(12).weight(.semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, SpacingTokens.sp2)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(ColorTokens.Brand.primary.opacity(0.14)))
            }
        }
    }

    private var streakBadge: some View {
        VStack(spacing: 2) {
            ZStack {
                RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                    .fill(ColorTokens.Brand.butter.opacity(0.22))
                    .frame(width: 38, height: 38)
                Image(systemName: "flame.fill")
                    .font(TypographyTokens.subtitle(18))
                    .foregroundStyle(ColorTokens.Brand.gold)
            }
            Text("\(streak)")
                .font(TypographyTokens.kidDisplay(15))
                .foregroundStyle(ColorTokens.Parent.ink)
            Text(String(localized: "parentHome.child.streakDays"))
                .font(TypographyTokens.caption(10))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityHidden(true)
    }

    private var a11yLabel: String {
        var parts = [nameWithAge]
        if !soundChips.isEmpty {
            parts.append(String(localized: "screening.card.sounds_label") + " " + soundChips.joined(separator: ", "))
        }
        if streak > 0 {
            parts.append("\(streak) " + String(localized: "parentHome.child.streakDays"))
        }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Stat strip (эталон .stat-strip — 3-grid)

/// Компактный 3-колоночный ряд статистики на всех устройствах (включая SE):
/// серия / минуты за всё время / общий успех. Единый gap, без overflow.
struct ParentStatStrip: View {
    let streak: Int
    let totalMinutes: Int
    let overallRate: Double

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.sp2) {
            ParentStatCard(
                value: "\(streak)",
                unit: String(localized: "parentHome.stat.unit.days"),
                label: String(localized: "parentHome.stat.streak"),
                icon: "flame.fill",
                color: ColorTokens.Brand.gold
            )
            ParentStatCard(
                value: "\(totalMinutes)",
                unit: String(localized: "parentHome.stat.unit.minutes"),
                label: String(localized: "parentHome.stat.totalMinutes"),
                icon: "clock.fill",
                color: ColorTokens.Brand.sky
            )
            ParentStatCard(
                value: "\(Int(overallRate * 100))",
                unit: "%",
                label: String(localized: "parentHome.stat.success"),
                icon: "checkmark.seal.fill",
                color: ColorTokens.Brand.gold
            )
        }
    }
}

// MARK: - Sound progress card (эталон «Прогресс по звукам»)

/// Пер-звуковые бары прогресса из реального `soundProgress`. При отсутствии
/// целевых звуков — осмысленное пустое состояние (не пустой график).
struct ParentSoundProgressCard: View {
    let progress: [ParentHomeModels.SoundProgress]

    /// Ротация тёплых акцентов (коралл → лилак → gold → rose), не off-theme.
    private static let tints: [Color] = [
        ColorTokens.Brand.primary,
        ColorTokens.Brand.lilac,
        ColorTokens.Brand.gold,
        ColorTokens.Brand.rose
    ]

    var body: some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
                ParentCardHead(
                    title: String(localized: "parentHome.soundProgress.title"),
                    meta: String(localized: "parentHome.soundProgress.meta")
                )
                if progress.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: SpacingTokens.sp4) {
                        ForEach(Array(progress.enumerated()), id: \.element.sound) { index, item in
                            row(item: item, tint: Self.tints[index % Self.tints.count])
                        }
                    }
                }
            }
        }
        .environment(\.circuitContext, .parent)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11yLabel)
    }

    private func row(item: ParentHomeModels.SoundProgress, tint: Color) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.85), tint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 42, height: 42)
                .overlay(
                    Text(item.sound)
                        .font(TypographyTokens.kidDisplay(20))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.familyName)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: SpacingTokens.sp2)
                    Text("\(Int(item.overallRate * 100))%")
                        .font(TypographyTokens.kidDisplay(15))
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                HSProgressBar(value: item.overallRate, style: .parent, tint: tint)
            }
        }
    }

    private var emptyState: some View {
        HStack(spacing: SpacingTokens.sp3) {
            Image(systemName: "waveform.path")
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Parent.accent)
                .accessibilityHidden(true)
            Text(String(localized: "parentHome.soundProgress.empty"))
                .font(TypographyTokens.body(13))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, SpacingTokens.sp2)
    }

    private var a11yLabel: String {
        guard !progress.isEmpty else {
            return String(localized: "parentHome.soundProgress.title") + ". " +
                String(localized: "parentHome.soundProgress.empty")
        }
        let parts = progress
            .map { "\($0.sound) \(Int($0.overallRate * 100))%" }
            .joined(separator: ", ")
        return String(localized: "parentHome.soundProgress.title") + ". " + parts
    }
}

// MARK: - Last session card (эталон «Последнее занятие»)

/// 3-cell grid (длительность / точность / слова) + дисклеймер. Реальные данные.
struct ParentLastSessionCard: View {
    let session: ParentHomeModels.SessionSummary

    var body: some View {
        let accuracyTint = session.successRate >= 0.7
            ? ColorTokens.Brand.gold
            : ColorTokens.Semantic.warning
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                ParentCardHead(
                    title: String(localized: "parentHome.lastSession.title"),
                    meta: session.dateText
                )
                HStack(spacing: SpacingTokens.sp2) {
                    cell(
                        value: session.durationText,
                        caption: String(localized: "parentHome.lastSession.duration"),
                        tint: ColorTokens.Parent.ink
                    )
                    cell(
                        value: "\(Int(session.successRate * 100))%",
                        caption: String(localized: "parentHome.lastSession.accuracy"),
                        tint: accuracyTint
                    )
                    cell(
                        value: "\(session.totalAttempts)",
                        caption: String(localized: "parentHome.lastSession.words"),
                        tint: ColorTokens.Parent.ink
                    )
                }
                disclaimer
            }
        }
        .environment(\.circuitContext, .parent)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(String(localized: "parentHome.lastSession.title")), \(session.dateText). "
            + "\(session.durationText), \(Int(session.successRate * 100))%, \(session.totalAttempts)"
        )
    }

    private func cell(value: String, caption: String, tint: Color) -> some View {
        VStack(spacing: SpacingTokens.micro) {
            Text(value)
                .font(TypographyTokens.kidDisplay(17))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.sp3)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                .fill(ColorTokens.Parent.bgDeep)
        )
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: SpacingTokens.sp2) {
            Image(systemName: "info.circle")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkSoft)
                .accessibilityHidden(true)
            Text(String(localized: "parentHome.disclaimer"))
                .font(TypographyTokens.caption(11.5))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, SpacingTokens.micro)
    }
}

// MARK: - No session (empty state)

/// Дружелюбное пустое состояние (эталон states-empty-error-loading.html):
/// маскот Ляля + тёплый текст + CTA. Никогда не пустой график с 0%.
struct ParentNoSessionCard: View {
    let onStart: () -> Void

    var body: some View {
        HSCard(style: .elevated) {
            VStack(spacing: SpacingTokens.sp4) {
                LyalyaHeroView(state: .idle, size: 96)
                    .accessibilityHidden(true)
                VStack(spacing: SpacingTokens.tiny) {
                    Text(String(localized: "parentHome.empty.firstSession.title"))
                        .font(TypographyTokens.headline(18))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(String(localized: "parentHome.empty.firstSession.subtitle"))
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HSButton(
                    String(localized: "parentHome.empty.firstSession.cta"),
                    style: .primary,
                    action: onStart
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp3)
        }
        .environment(\.circuitContext, .parent)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "parentHome.empty.firstSession.title") + ". " +
            String(localized: "parentHome.empty.firstSession.subtitle")
        )
    }
}

// MARK: - Home task card (эталон .task-card)

/// Тёплая коралловая карточка задания на дом: заголовок + meta «5–7 минут»,
/// текст задания (реальный из Interactor/LLM) и полноширинный CTA.
struct ParentHomeTaskCard: View {
    let task: String
    let onStart: () -> Void

    var body: some View {
        HSCard(style: .tinted(ColorTokens.Brand.primary.opacity(0.10))) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                ParentCardHead(
                    title: String(localized: "parentHome.homeTask.title"),
                    meta: String(localized: "parentHome.homeTask.meta")
                )
                HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                    ZStack {
                        RoundedRectangle(cornerRadius: RadiusTokens.xs, style: .continuous)
                            .fill(ColorTokens.Brand.primary)
                            .frame(width: 24, height: 24)
                        Image(systemName: "1.circle.fill")
                            .font(TypographyTokens.caption(14))
                            .foregroundStyle(ColorTokens.Overlay.onAccent)
                    }
                    .accessibilityHidden(true)
                    Text(task)
                        .font(TypographyTokens.body())
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                        .ctaTextStyle()
                }
                HSButton(
                    String(localized: "parentHome.homeTask.cta"),
                    style: .primary,
                    icon: "play.fill",
                    action: onStart
                )
            }
        }
        .environment(\.circuitContext, .parent)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "parentHome.homeTask.title") + ". " + task)
    }
}

// MARK: - Recommendations card

/// Рекомендации обычным языком (реальные из Presenter). Скрыта при пустоте.
struct ParentRecommendationsCard: View {
    let recommendations: [String]

    var body: some View {
        if !recommendations.isEmpty {
            HSCard(style: .elevated) {
                VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                    ParentCardHead(
                        title: String(localized: "Рекомендации"),
                        meta: String(localized: "parentHome.recommendations.meta")
                    )
                    ForEach(recommendations, id: \.self) { rec in
                        HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                            Image(systemName: "lightbulb.fill")
                                .font(TypographyTokens.caption(14))
                                .foregroundStyle(ColorTokens.Brand.butter)
                                .padding(.top, 2)
                                .accessibilityHidden(true)
                            Text(rec)
                                .font(TypographyTokens.body(14))
                                .foregroundStyle(ColorTokens.Parent.inkMuted)
                                .lineLimit(nil)
                                .minimumScaleFactor(0.85)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .environment(\.circuitContext, .parent)
        }
    }
}

// MARK: - Tools section header (эталон .block-title)

/// Малый uppercase-заголовок секции «Инструменты», отделяющий навигационные
/// карточки от блока «Обзор».
struct ParentToolsSectionHeader: View {
    var body: some View {
        Text(String(localized: "parentHome.section.tools"))
            .font(TypographyTokens.caption(13).weight(.bold))
            .foregroundStyle(ColorTokens.Parent.inkMuted)
            .textCase(.uppercase)
            .tracking(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, SpacingTokens.sp2)
            .padding(.horizontal, SpacingTokens.micro)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Preview

#Preview("Overview — Populated") {
    let progress = [
        ParentHomeModels.SoundProgress(
            sound: "Р", familyName: "Соноры", currentStage: "Слова",
            overallRate: 0.64, sessions: 8
        ),
        ParentHomeModels.SoundProgress(
            sound: "Ш", familyName: "Шипящие", currentStage: "Фразы",
            overallRate: 0.81, sessions: 12
        )
    ]
    let session = ParentHomeModels.SessionSummary(
        id: "s1", targetSound: "Р", templateName: "Повтори за мной",
        dateText: "вчера, 18:30", durationText: "12 мин",
        totalAttempts: 24, correctAttempts: 20, successRate: 0.82
    )
    return ScrollView {
        VStack(spacing: SpacingTokens.large) {
            ParentHeaderSection(greeting: "Добрый день, Анна!")
            ParentChildCard(name: "Маша", nameWithAge: "Маша, 6 лет",
                            soundChips: ["Р", "Ш"], streak: 5)
            ParentStatStrip(streak: 5, totalMinutes: 87, overallRate: 0.78)
            ParentSoundProgressCard(progress: progress)
            ParentLastSessionCard(session: session)
            ParentHomeTaskCard(task: "Повторите перед зеркалом слова со звуком «Р»: рыба, рука, ракета.") {}
            ParentRecommendationsCard(recommendations: ["Чаще играйте в звуковые игры со звуком «Р»."])
            ParentToolsSectionHeader()
        }
        .padding(SpacingTokens.screenEdge)
    }
    .background(ColorTokens.Parent.bg)
    .environment(\.circuitContext, .parent)
}

#Preview("Overview — Empty / First run") {
    ScrollView {
        VStack(spacing: SpacingTokens.large) {
            ParentChildCard(name: "Маша", nameWithAge: "Маша",
                            soundChips: [], streak: 0)
            ParentStatStrip(streak: 0, totalMinutes: 0, overallRate: 0.0)
            ParentSoundProgressCard(progress: [])
            ParentNoSessionCard {}
        }
        .padding(SpacingTokens.screenEdge)
    }
    .background(ColorTokens.Parent.bg)
    .environment(\.circuitContext, .parent)
}
