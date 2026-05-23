import SwiftUI

// MARK: - SpeechHomeworkPlannerView

struct SpeechHomeworkPlannerView: View {

    @State private var interactor = SpeechHomeworkPlannerInteractor()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()
                content
            }
            .navigationTitle(Text(String(localized: "homeworkPlanner.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
        }
        .environment(\.circuitContext, .parent)
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.sp3) {
                hero
                list
                cta
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp3)
            .padding(.bottom, SpacingTokens.sp6)
        }
    }

    private var hero: some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                Text(String(localized: "homeworkPlanner.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Parent.ink)
                Text(String(localized: "homeworkPlanner.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                HStack(spacing: SpacingTokens.sp2) {
                    HSProgressBar(value: interactor.progress, style: .parent)
                        .frame(height: 6)
                    Text("\(interactor.doneCount) / \(interactor.items.count)")
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .monospacedDigit()
                }
                .padding(.top, 2)
            }
        }
    }

    private var list: some View {
        VStack(spacing: SpacingTokens.sp2) {
            ForEach(interactor.items) { item in
                row(item)
            }
        }
    }

    private func row(_ item: SpeechHomeworkPlannerModels.Item) -> some View {
        Button {
            hapticService.impact(.light)
            interactor.toggle(item.id)
        } label: {
            HSCard(style: item.isDone ? .tinted(ColorTokens.Semantic.successBg) : .flat) {
                HStack(spacing: SpacingTokens.sp3) {
                    Text(item.dayOfWeek)
                        .font(TypographyTokens.caption(12).weight(.bold))
                        .foregroundStyle(ColorTokens.Parent.accent)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle().fill(ColorTokens.Parent.accent.opacity(0.12))
                        )
                    Text(item.title)
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Spacer()
                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(item.isDone
                                         ? ColorTokens.Semantic.success
                                         : ColorTokens.Parent.inkSoft)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(item.dayOfWeek). \(item.title)"))
        .accessibilityValue(Text(item.isDone ? "Сделано" : "Не сделано"))
        .accessibilityAddTraits(.isButton)
    }

    private var cta: some View {
        HSButton(
            String(localized: "homeworkPlanner.cta.confirm"),
            style: .primary,
            size: .large,
            icon: "checkmark.circle.fill"
        ) {
            hapticService.notification(.success)
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview("HomeworkPlanner — Light") {
    SpeechHomeworkPlannerView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("HomeworkPlanner — Dark") {
    SpeechHomeworkPlannerView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
