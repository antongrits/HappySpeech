import SwiftUI

// MARK: - SpecialistQuickAssessmentView

struct SpecialistQuickAssessmentView: View {

    let childId: String
    let specialistId: String

    @State private var interactor: SpecialistQuickAssessmentInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Spec.bg.ignoresSafeArea()
                content
            }
            .navigationTitle(Text(String(localized: "quickAssessment.nav.title")))
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
            .task {
                if interactor == nil {
                    interactor = SpecialistQuickAssessmentInteractor(
                        childId: childId,
                        specialistId: specialistId
                    )
                }
            }
        }
        .environment(\.circuitContext, .specialist)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            ScrollView {
                VStack(spacing: SpacingTokens.sp4) {
                    hero(state: interactor.state)
                    categoriesList(interactor: interactor)
                    if interactor.state.isSaved {
                        savedBanner
                    }
                    cta(interactor: interactor)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp6)
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private func hero(state: SpecialistQuickAssessmentModels.ViewState) -> some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "quickAssessment.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "quickAssessment.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                Text(String(format: "Средняя оценка: %.1f / 5.0", state.averageStars))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Spec.accent)
                    .padding(.top, 2)
            }
        }
    }

    private func categoriesList(interactor: SpecialistQuickAssessmentInteractor) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            ForEach(interactor.state.ratings) { rating in
                categoryRow(rating, interactor: interactor)
            }
        }
    }

    private func categoryRow(
        _ rating: SpecialistQuickAssessmentModels.Rating,
        interactor: SpecialistQuickAssessmentInteractor
    ) -> some View {
        HSCard(style: .flat) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                HStack(spacing: SpacingTokens.sp2) {
                    Image(systemName: rating.id.iconSystemName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ColorTokens.Spec.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rating.id.title)
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Spec.ink)
                        Text(rating.id.subtitle)
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Spec.inkMuted)
                    }
                    Spacer()
                }
                HStack(spacing: 6) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            hapticService.impact(.light)
                            interactor.set(rating.id, stars: star)
                        } label: {
                            Image(systemName: star <= rating.stars ? "star.fill" : "star")
                                .font(.system(size: 26))
                                .foregroundStyle(
                                    star <= rating.stars ? ColorTokens.Brand.gold : ColorTokens.Spec.inkMuted
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Оценка \(star) из 5"))
                    }
                    Spacer()
                }
            }
        }
    }

    private var savedBanner: some View {
        HSCard(style: .tinted(ColorTokens.Semantic.successBg)) {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(ColorTokens.Semantic.success)
                Text("Оценка сохранена")
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Spec.ink)
                Spacer()
            }
        }
    }

    private func cta(interactor: SpecialistQuickAssessmentInteractor) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            HSButton(
                String(localized: "quickAssessment.cta.action"),
                style: .primary,
                size: .large,
                icon: "tray.and.arrow.down.fill"
            ) {
                hapticService.notification(.success)
                interactor.save()
            }
            .disabled(interactor.state.ratings.allSatisfy { $0.stars == 0 })
            .opacity(interactor.state.ratings.allSatisfy { $0.stars == 0 } ? 0.5 : 1)
            HSButton(
                "Сбросить",
                style: .ghost,
                size: .medium,
                icon: "arrow.counterclockwise"
            ) {
                hapticService.impact(.light)
                interactor.reset()
            }
        }
    }
}

// MARK: - Preview

#Preview("SpecialistQuickAssessment — Light") {
    SpecialistQuickAssessmentView(childId: "preview-child-1", specialistId: "local-parent")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("SpecialistQuickAssessment — Dark") {
    SpecialistQuickAssessmentView(childId: "preview-child-1", specialistId: "local-parent")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
