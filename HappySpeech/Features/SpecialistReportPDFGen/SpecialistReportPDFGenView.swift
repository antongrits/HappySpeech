import SwiftUI

// MARK: - SpecialistReportPDFGenView

struct SpecialistReportPDFGenView: View {

    let childId: String
    let specialistId: String

    @State private var interactor: SpecialistReportPDFGenInteractor?
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
            .navigationTitle(Text(String(localized: "reportPDFGen.nav.title")))
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
                    interactor = SpecialistReportPDFGenInteractor(
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
                    sectionsList(interactor: interactor)
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

    private func hero(state: SpecialistReportPDFGenModels.ViewState) -> some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp4) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "reportPDFGen.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "reportPDFGen.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                HStack(spacing: 8) {
                    Label(state.childName, systemImage: "person.fill")
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Spec.accent)
                    Text("·")
                        .foregroundStyle(ColorTokens.Spec.inkMuted)
                    Text(state.periodLabel)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Spec.inkMuted)
                }
                .padding(.top, 4)
            }
        }
    }

    private func sectionsList(interactor: SpecialistReportPDFGenInteractor) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            ForEach(Array(SpecialistReportPDFGenModels.Section.allCases.enumerated()), id: \.element) { index, section in
                row(section, isOn: interactor.state.sections.contains(section)) {
                    hapticService.impact(.light)
                    interactor.toggle(section)
                }
                .scrollTransition(.animated(reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.85))) { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0)
                        .scaleEffect(phase.isIdentity ? 1 : 0.96)
                }
                .zIndex(Double(SpecialistReportPDFGenModels.Section.allCases.count - index))
            }
        }
    }

    private func row(
        _ section: SpecialistReportPDFGenModels.Section,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HSCard(style: isOn ? .tinted(ColorTokens.Spec.accent.opacity(0.10)) : .flat) {
                HStack(spacing: SpacingTokens.sp3) {
                    Image(systemName: section.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(ColorTokens.Spec.accent)
                        .frame(width: 32, height: 32)
                    Text(section.title)
                        .font(TypographyTokens.headline(15))
                        .foregroundStyle(ColorTokens.Spec.ink)
                    Spacer()
                    Image(systemName: isOn ? "checkmark.square.fill" : "square")
                        .font(.system(size: 22))
                        .foregroundStyle(isOn ? ColorTokens.Brand.primary : ColorTokens.Spec.inkMuted)
                        .hsSymbolEffect(.bounce, value: isOn)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(section.title))
        .accessibilityValue(Text(isOn ? "включено" : "выключено"))
        .accessibilityAddTraits(.isButton)
    }

    private func cta(interactor: SpecialistReportPDFGenInteractor) -> some View {
        HSButton(
            String(localized: "reportPDFGen.cta.action"),
            style: .primary,
            size: .large,
            icon: "square.and.arrow.down.fill"
        ) {
            hapticService.notification(.success)
            Task { await interactor.generate() }
        }
        .disabled(interactor.state.isGenerating || interactor.state.sections.isEmpty)
        .opacity((interactor.state.isGenerating || interactor.state.sections.isEmpty) ? 0.5 : 1)
    }
}

// MARK: - Preview

#Preview("SpecialistReportPDFGen — Light") {
    SpecialistReportPDFGenView(childId: "preview-child-1", specialistId: "local-parent")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("SpecialistReportPDFGen — Dark") {
    SpecialistReportPDFGenView(childId: "preview-child-1", specialistId: "local-parent")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
