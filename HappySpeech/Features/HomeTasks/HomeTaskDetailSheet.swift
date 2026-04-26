import SwiftUI

// MARK: - HomeTaskDetailSheet
//
// Детальный bottom sheet задания.
// Показывается при tap на карточку в списке. Содержит:
// - Полное описание задания
// - Мета-информацию (звук, тип упражнения, назначил, дедлайн)
// - Кнопку напоминания (если есть dueDate)
// - CTA «Начать» / «Продолжить»
// - Маскот Ляля с соответствующим состоянием

struct HomeTaskDetailSheet: View {

    let viewModel: HomeTasksModels.FetchDetail.ViewModel
    let reduceMotion: Bool
    let onToggle: () -> Void
    let onStart: () -> Void
    let onScheduleReminder: () -> Void
    let onDismiss: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.large) {
                headerSection
                descriptionSection
                metaSection
                actionsSection
                Spacer(minLength: SpacingTokens.xxLarge)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.regular)
        }
        .background(ColorTokens.Parent.bg)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(viewModel.accessibilityLabel)
    }

    // MARK: Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: SpacingTokens.regular) {
            mascotForTask

            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                HStack(spacing: SpacingTokens.tiny) {
                    HSBadge(viewModel.soundBadgeText, style: .filled(ColorTokens.Brand.primary))
                    HSBadge(viewModel.priorityBadgeText, style: priorityStyle)
                    Spacer(minLength: 0)

                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "homeTasks.detail.close"))
                    .frame(width: 44, height: 44)
                }

                Text(viewModel.title)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .strikethrough(viewModel.isCompleted, color: ColorTokens.Parent.inkSoft)
                    .accessibilityAddTraits(.isHeader)

                Text(viewModel.subtitle)
                    .font(TypographyTokens.caption())
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    private var mascotForTask: some View {
        LyalyaMascotView(
            state: viewModel.isCompleted ? .celebrating : .explaining,
            size: 72
        )
        .accessibilityHidden(true)
    }

    private var priorityStyle: HSBadge.BadgeStyle {
        switch viewModel.priority {
        case .high:   return .outlined(ColorTokens.Semantic.error)
        case .medium: return .outlined(ColorTokens.Semantic.warning)
        case .low:    return .neutral
        }
    }

    // MARK: Description

    private var descriptionSection: some View {
        HSLiquidGlassCard(style: .primary, padding: SpacingTokens.cardPad) {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                HStack(spacing: SpacingTokens.tiny) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ColorTokens.Parent.accent)
                        .accessibilityHidden(true)
                    Text(String(localized: "homeTasks.detail.descriptionTitle"))
                        .font(TypographyTokens.caption(13).weight(.semibold))
                        .foregroundStyle(ColorTokens.Parent.inkSoft)
                        .textCase(.uppercase)
                }

                Text(viewModel.description)
                    .font(TypographyTokens.body(16))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(nil)
                    .lineSpacing(4)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Meta

    private var metaSection: some View {
        HSLiquidGlassCard(style: .primary, padding: SpacingTokens.cardPad) {
            VStack(spacing: SpacingTokens.regular) {
                metaRow(
                    icon: "gamecontroller.fill",
                    label: String(localized: "homeTasks.detail.exerciseType"),
                    value: exerciseTypeDisplayName(viewModel.exerciseType),
                    color: ColorTokens.Brand.primary
                )

                Divider().background(ColorTokens.Parent.line)

                metaRow(
                    icon: "waveform",
                    label: String(localized: "homeTasks.detail.targetSound"),
                    value: viewModel.targetSound,
                    color: ColorTokens.Brand.mint
                )

                if let due = viewModel.dueDateText {
                    Divider().background(ColorTokens.Parent.line)
                    metaRow(
                        icon: viewModel.isOverdue ? "exclamationmark.circle.fill" : "calendar",
                        label: String(localized: "homeTasks.detail.dueDate"),
                        value: due,
                        color: viewModel.isOverdue ? ColorTokens.Semantic.error : ColorTokens.Brand.sky
                    )
                }

                Divider().background(ColorTokens.Parent.line)
                metaRow(
                    icon: viewModel.isCompleted ? "checkmark.circle.fill" : "circle",
                    label: String(localized: "homeTasks.detail.status"),
                    value: viewModel.isCompleted
                        ? String(localized: "homeTasks.a11y.statusCompleted")
                        : String(localized: "homeTasks.a11y.statusActive"),
                    color: viewModel.isCompleted ? ColorTokens.Semantic.success : ColorTokens.Parent.accent
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func metaRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(alignment: .center, spacing: SpacingTokens.regular) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 24, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(TypographyTokens.caption(11).weight(.semibold))
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .textCase(.uppercase)
                Text(value)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private func exerciseTypeDisplayName(_ type: String) -> String {
        switch type {
        case "repeat-after-model":     return String(localized: "exercise.type.repeatAfterModel")
        case "breathing":              return String(localized: "exercise.type.breathing")
        case "bingo":                  return String(localized: "exercise.type.bingo")
        case "story-completion":       return String(localized: "exercise.type.storyCompletion")
        case "sorting":                return String(localized: "exercise.type.sorting")
        case "articulation-imitation": return String(localized: "exercise.type.articulationImitation")
        case "minimal-pairs":          return String(localized: "exercise.type.minimalPairs")
        case "listen-and-choose":      return String(localized: "exercise.type.listenAndChoose")
        case "drag-and-match":         return String(localized: "exercise.type.dragAndMatch")
        default:                       return type
        }
    }

    // MARK: Actions

    private var actionsSection: some View {
        VStack(spacing: SpacingTokens.small) {
            HSButton(
                viewModel.startButtonTitle,
                style: .primary,
                icon: viewModel.isCompleted ? "arrow.clockwise" : "play.fill"
            ) {
                onStart()
                onDismiss()
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel(viewModel.startButtonTitle)
            .accessibilityHint(String(localized: "homeTasks.a11y.startHint"))

            HSButton(
                viewModel.isCompleted
                    ? String(localized: "homeTasks.detail.markIncomplete")
                    : String(localized: "homeTasks.detail.markComplete"),
                style: .secondary,
                icon: viewModel.isCompleted ? "arrow.uturn.left" : "checkmark"
            ) {
                onToggle()
            }
            .frame(maxWidth: .infinity)

            if viewModel.hasDueDate {
                HSButton(
                    viewModel.reminderButtonTitle,
                    style: viewModel.hasReminder ? .ghost : .secondary,
                    icon: viewModel.hasReminder ? "bell.fill" : "bell"
                ) {
                    onScheduleReminder()
                }
                .frame(maxWidth: .infinity)
                .disabled(viewModel.hasReminder)
                .accessibilityLabel(viewModel.reminderButtonTitle)
                .accessibilityHint(String(localized: "homeTasks.detail.reminderHint"))
            }
        }
    }
}
