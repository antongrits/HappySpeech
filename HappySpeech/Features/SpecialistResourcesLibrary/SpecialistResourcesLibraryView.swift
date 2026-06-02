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
            .sheet(isPresented: readerBinding) {
                if let resource = interactor?.state.openedResource {
                    ResourceReaderView(resource: resource)
                }
            }
        }
        .environment(\.circuitContext, .specialist)
    }

    /// Биндинг видимости ридера к `openedResource` интерактора.
    private var readerBinding: Binding<Bool> {
        Binding(
            get: { interactor?.state.openedResource != nil },
            set: { isPresented in
                if !isPresented { interactor?.closeReader() }
            }
        )
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
                    Text(String(
                        format: String(localized: "resourcesLibrary.total %lld %lld"),
                        state.resources.count, state.readCount
                    ))
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
            .foregroundStyle(isActive ? ColorTokens.Overlay.onAccent : ColorTokens.Spec.ink)
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
            if interactor.state.filtered.isEmpty {
                emptyState
            } else {
                ForEach(interactor.state.filtered) { resource in
                    row(resource, interactor: interactor)
                        .hsParallaxTile(factor: 0.3)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.92).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
        }
        .animation(
            reduceMotion ? nil : MotionTokens.settleSpring,
            value: interactor.state.filtered.count
        )
    }

    private var emptyState: some View {
        HSCard(style: .flat) {
            VStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "bookmark.slash")
                    .font(.system(size: 30))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                Text(String(localized: "resourcesLibrary.empty"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp3)
        }
    }

    private func row(
        _ resource: SpecialistResourcesLibraryModels.Resource,
        interactor: SpecialistResourcesLibraryInteractor
    ) -> some View {
        HSCard(style: resource.isRead ? .tinted(ColorTokens.Spec.surface) : .flat) {
            HStack(spacing: SpacingTokens.sp3) {
                Button {
                    hapticService.impact(.light)
                    interactor.open(resource.id)
                } label: {
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
                            Text(resource.durationLabel)
                                .font(TypographyTokens.caption(11))
                                .foregroundStyle(ColorTokens.Spec.inkMuted)
                                .padding(.top, 1)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text(String(localized: "resourcesLibrary.a11y.open")))
                VStack(spacing: SpacingTokens.sp2) {
                    Button {
                        hapticService.impact(.light)
                        interactor.toggleSaved(resource.id)
                    } label: {
                        Image(systemName: resource.isSaved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 18))
                            .foregroundStyle(resource.isSaved ? ColorTokens.Spec.accent : ColorTokens.Spec.inkMuted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(resource.isSaved
                        ? String(localized: "resourcesLibrary.a11y.unsave")
                        : String(localized: "resourcesLibrary.a11y.save")))
                    Button {
                        hapticService.impact(.light)
                        interactor.toggleRead(resource.id)
                    } label: {
                        Image(systemName: resource.isRead ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundStyle(resource.isRead ? ColorTokens.Semantic.success : ColorTokens.Spec.inkMuted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(resource.isRead
                        ? String(localized: "resourcesLibrary.a11y.unread")
                        : String(localized: "resourcesLibrary.a11y.read")))
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var cta: some View {
        HSButton(
            String(localized: "resourcesLibrary.cta.done"),
            style: .primary,
            size: .large,
            icon: "checkmark"
        ) {
            hapticService.notification(.success)
            dismiss()
        }
    }
}

// MARK: - ResourceReaderView

/// Ридер методического ресурса: показывает реальный текст материала.
private struct ResourceReaderView: View {

    let resource: SpecialistResourcesLibraryModels.Resource

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
                    HStack(spacing: SpacingTokens.sp3) {
                        Image(systemName: resource.kind.icon)
                            .font(.system(size: 28))
                            .foregroundStyle(ColorTokens.Spec.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(resource.kind.title)
                                .font(TypographyTokens.caption(12))
                                .foregroundStyle(ColorTokens.Spec.accent)
                            Text(resource.durationLabel)
                                .font(TypographyTokens.caption(11))
                                .foregroundStyle(ColorTokens.Spec.inkMuted)
                        }
                        Spacer()
                    }

                    Text(resource.summary)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Spec.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.9)

                    Divider()

                    Text(resource.body)
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Spec.ink)
                        .lineLimit(nil)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.vertical, SpacingTokens.sp4)
            }
            .background(ColorTokens.Spec.bg.ignoresSafeArea())
            .navigationTitle(Text(resource.title))
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
