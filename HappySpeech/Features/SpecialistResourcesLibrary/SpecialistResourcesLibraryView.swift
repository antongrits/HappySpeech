import SwiftUI

// MARK: - SpecialistResourcesLibraryView

struct SpecialistResourcesLibraryView: View {

    let specialistId: String

    @State private var interactor: SpecialistResourcesLibraryInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                HSMeshGradientBackground(palette: .calm, animated: !reduceMotion)
                    .ignoresSafeArea()
                content
            }
            .navigationTitle(Text(String(localized: "resourcesLibrary.nav.title")))
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
                    interactor = SpecialistResourcesLibraryInteractor(specialistId: specialistId)
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
                    filterStrip(interactor: interactor)
                    list(interactor: interactor)
                    cta
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp6)
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private func hero(state: SpecialistResourcesLibraryModels.ViewState) -> some View {
        HSLiquidGlassCard(style: .elevated) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "resourcesLibrary.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "resourcesLibrary.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                HStack(spacing: SpacingTokens.tiny) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.Spec.accent)
                        .hsSymbolEffect(.bounce, value: state.resources.count)
                    Text("Всего: \(state.resources.count)")
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Spec.accent)
                }
                .padding(.top, 4)
            }
        }
    }

    private func filterStrip(interactor: SpecialistResourcesLibraryInteractor) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.sp2) {
                ForEach(SpecialistResourcesLibraryModels.ResourceKind.allCases) { kind in
                    chip(kind: kind, isActive: interactor.state.filter == kind) {
                        hapticService.impact(.light)
                        interactor.setFilter(kind)
                    }
                }
            }
        }
    }

    private func chip(
        kind: SpecialistResourcesLibraryModels.ResourceKind,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: kind.icon)
                    .font(.system(size: 12))
                Text(kind.title)
                    .font(TypographyTokens.caption(12))
            }
            .foregroundStyle(isActive ? .white : ColorTokens.Spec.ink)
            .padding(.horizontal, SpacingTokens.sp3)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(isActive ? ColorTokens.Spec.accent : ColorTokens.Spec.surface)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }

    private func list(interactor: SpecialistResourcesLibraryInteractor) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            ForEach(interactor.state.filtered) { resource in
                row(resource)
                    .hsParallaxTile(factor: 0.3)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.92).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(
            reduceMotion ? nil : MotionTokens.settleSpring,
            value: interactor.state.filtered.count
        )
    }

    private func row(_ resource: SpecialistResourcesLibraryModels.Resource) -> some View {
        HSCard(style: .flat) {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: resource.kind.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(ColorTokens.Spec.accent)
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(resource.title)
                        .font(TypographyTokens.headline(15))
                        .foregroundStyle(ColorTokens.Spec.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(resource.summary)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Spec.inkMuted)
                        .lineLimit(2)
                }
                Spacer()
                Text(resource.durationLabel)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
            }
        }
    }

    private var cta: some View {
        HSButton(
            String(localized: "resourcesLibrary.cta.action"),
            style: .primary,
            size: .large,
            icon: "plus"
        ) {
            hapticService.notification(.success)
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview("SpecialistResourcesLibrary — Light") {
    SpecialistResourcesLibraryView(specialistId: "local-parent")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("SpecialistResourcesLibrary — Dark") {
    SpecialistResourcesLibraryView(specialistId: "local-parent")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
