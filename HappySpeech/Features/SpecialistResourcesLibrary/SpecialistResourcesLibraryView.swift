import SwiftUI

// MARK: - SpecialistResourcesLibraryView
//
// Справочная библиотека методических материалов специалиста.
// Дизайн-паттерн «Библиотека / Энциклопедия»: большой заголовок h1 +
// счётчик, поиск, фильтр-чипы, стекированный список карточек с иконкой/чипом/шевроном,
// ридер с реальным текстом.
//
// Accessibility:
//   • VoiceOver: каждая карточка — combined label + hint «открыть»
//   • Dynamic Type: ScrollView root, lineLimit/minimumScaleFactor
//   • Reduced Motion: пружины и parallax выключаются
//   • Light + Dark: ColorTokens.Spec

struct SpecialistResourcesLibraryView: View {

    let specialistId: String

    @State private var interactor: SpecialistResourcesLibraryInteractor?
    @State private var query: String = ""
    @Environment(\.exitToSpecialistHome) private var exitToSpecialistHome
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                ColorTokens.Spec.bg.ignoresSafeArea()
                content
                // Close button floated top-right matching reference design
                Button {
                    exitToSpecialistHome()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(ColorTokens.Spec.inkMuted)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .padding(.top, SpacingTokens.sp4)
                .padding(.trailing, SpacingTokens.screenEdge)
                .accessibilityLabel(Text(String(localized: "action.close")))
            }
            .navigationBarHidden(true)
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

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let interactor {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
                    // Space for floating close button
                    Color.clear.frame(height: SpacingTokens.sp10)
                    header(state: interactor.state)
                    searchField
                    filterStrip(interactor: interactor)
                    list(interactor: interactor)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        } else {
            HSLoadingView(message: String(localized: "resourcesLibrary.loading"))
        }
    }

    // MARK: - Header
    // Matches reference: large bold h1 title + subtitle "N материалов · обновлено сегодня"

    private func header(state: SpecialistResourcesLibraryModels.ViewState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "resourcesLibrary.hero.title"))
                .font(TypographyTokens.display(30))
                .foregroundStyle(ColorTokens.Spec.ink)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 0) {
                Text(
                    String(
                        format: String(localized: "resourcesLibrary.total %lld", defaultValue: "%lld материалов"),
                        state.resources.count
                    )
                )
                Text(" · ")
                Text(String(localized: "resourcesLibrary.updated_today", defaultValue: "обновлено сегодня"))
            }
            .font(TypographyTokens.body(14))
            .foregroundStyle(ColorTokens.Spec.inkMuted)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: SpacingTokens.sp2) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
                .accessibilityHidden(true)
            TextField(
                String(localized: "resourcesLibrary.search.prompt"),
                text: $query
            )
            .font(TypographyTokens.body(16))
            .foregroundStyle(ColorTokens.Spec.ink)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(TypographyTokens.callout(16))
                        .foregroundStyle(ColorTokens.Spec.inkMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(String(localized: "resourcesLibrary.search.clear")))
            }
        }
        .padding(.horizontal, SpacingTokens.sp3)
        .frame(height: 46)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.sm)
                .fill(ColorTokens.Spec.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.sm)
                .strokeBorder(ColorTokens.Spec.line, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String(localized: "resourcesLibrary.search.prompt")))
    }

    // MARK: - Filter chips

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
            .padding(.vertical, 2)
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
                    .font(.system(size: 12, weight: .semibold))
                Text(kind.title)
                    .font(TypographyTokens.caption(13).weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isActive ? ColorTokens.Spec.accent : ColorTokens.Spec.inkMuted)
            .padding(.horizontal, SpacingTokens.sp3)
            .frame(height: 34)
            .background(
                Capsule().fill(isActive
                    ? ColorTokens.Spec.accent.opacity(0.16)
                    : ColorTokens.Spec.surface)
            )
            .overlay(
                Capsule().strokeBorder(
                    isActive ? Color.clear : ColorTokens.Spec.line,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - List

    /// Реальные данные интерактора, дополнительно отфильтрованные локальным
    /// поиском по заголовку/описанию (презентационная фильтрация, данные реальны).
    private func searchFiltered(
        _ resources: [SpecialistResourcesLibraryModels.Resource]
    ) -> [SpecialistResourcesLibraryModels.Resource] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return resources }
        return resources.filter { resource in
            resource.title.localizedCaseInsensitiveContains(trimmed)
                || resource.summary.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private func list(interactor: SpecialistResourcesLibraryInteractor) -> some View {
        let items = searchFiltered(interactor.state.filtered)
        return VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            if items.isEmpty {
                emptyState
            } else {
                sectionLabel
                // Stacked card deck: top item sits on a visible "stack" of ghost cards
                // behind it (matching reference design with layered depth effect).
                if let featured = items.first {
                    featuredStack(featured, interactor: interactor)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.94).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
                // Remaining rows
                if items.count > 1 {
                    VStack(spacing: SpacingTokens.sp2) {
                        ForEach(items.dropFirst()) { resource in
                            row(resource, interactor: interactor)
                                .hsParallaxTile(factor: reduceMotion ? 0 : 0.25)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.92).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                }
            }
        }
        .animation(
            reduceMotion ? nil : MotionTokens.settleSpring,
            value: items.count
        )
    }

    private var sectionLabel: some View {
        Text(String(localized: "resourcesLibrary.section.recommended"))
            .font(TypographyTokens.headline(15))
            .foregroundStyle(ColorTokens.Spec.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    /// Стекированный «дек карточек» для первого/рекомендуемого ресурса.
    /// За верхней карточкой видны 3 призрачные карточки, смещённые вниз
    /// и сужающиеся — точный эффект «стопки книг» из эталона.
    private func featuredStack(
        _ resource: SpecialistResourcesLibraryModels.Resource,
        interactor: SpecialistResourcesLibraryInteractor
    ) -> some View {
        let ghostCount = 3
        return ZStack(alignment: .top) {
            // Ghost cards peek below — rendered bottom-most first so closest
            // ghost sits on top of the deeper ones (idx=3 deepest, idx=1 nearest).
            ForEach((1...ghostCount).reversed(), id: \.self) { idx in
                let frac = CGFloat(idx) / CGFloat(ghostCount + 1)
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(ColorTokens.Spec.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                            .strokeBorder(ColorTokens.Spec.line, lineWidth: 1)
                    )
                    .frame(maxWidth: .infinity, minHeight: 88)
                    // Narrow each ghost card — widest at the back, narrowest at front
                    .padding(.horizontal, CGFloat(ghostCount - idx + 1) * 5)
                    // Shift down — deepest card furthest below
                    .offset(y: CGFloat(idx) * 6)
                    .opacity(1.0 - frac * 0.6)
            }

            // Top (real) card — full interactable row, sits at top of ZStack
            row(resource, interactor: interactor)
                .hsParallaxTile(factor: reduceMotion ? 0 : 0.3)
        }
        // Extra bottom padding so the lowest ghost card peeks out without clipping
        .padding(.bottom, CGFloat(ghostCount) * 6)
        .clipped(antialiased: true)
    }

    private var emptyState: some View {
        HSEmptyStateView(
            icon: query.isEmpty ? "bookmark.slash" : "magnifyingglass",
            title: String(localized: query.isEmpty
                ? "resourcesLibrary.empty.title"
                : "resourcesLibrary.search.empty.title"),
            message: String(localized: query.isEmpty
                ? "resourcesLibrary.empty"
                : "resourcesLibrary.search.empty.message")
        )
        .frame(minHeight: 320)
    }

    // MARK: - Reference card row

    private func row(
        _ resource: SpecialistResourcesLibraryModels.Resource,
        interactor: SpecialistResourcesLibraryInteractor
    ) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            Button {
                hapticService.impact(.light)
                interactor.open(resource.id)
            } label: {
                HStack(spacing: SpacingTokens.sp3) {
                    thumbnail(for: resource)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(resource.title)
                            .font(TypographyTokens.headline(16))
                            .foregroundStyle(ColorTokens.Spec.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .multilineTextAlignment(.leading)
                        Text(resource.summary)
                            .font(TypographyTokens.caption(13))
                            .foregroundStyle(ColorTokens.Spec.inkMuted)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .multilineTextAlignment(.leading)
                        HStack(spacing: SpacingTokens.sp2) {
                            typeChip(for: resource.kind)
                            Text(resource.durationLabel)
                                .font(TypographyTokens.caption(11).weight(.semibold))
                                .foregroundStyle(ColorTokens.Spec.inkMuted)
                                .lineLimit(1)
                        }
                        .padding(.top, 2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ColorTokens.Spec.inkMuted)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("\(resource.title). \(resource.kind.title). \(resource.durationLabel)"))
            .accessibilityHint(Text(String(localized: "resourcesLibrary.a11y.open")))

            VStack(spacing: SpacingTokens.sp3) {
                Button {
                    hapticService.impact(.light)
                    interactor.toggleSaved(resource.id)
                } label: {
                    Image(systemName: resource.isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 18))
                        .foregroundStyle(resource.isSaved ? ColorTokens.Spec.accent : ColorTokens.Spec.inkMuted)
                        .frame(width: 32, height: 24)
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
                        .foregroundStyle(resource.isRead ? ColorTokens.Spec.accent : ColorTokens.Spec.inkMuted)
                        .frame(width: 32, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(resource.isRead
                    ? String(localized: "resourcesLibrary.a11y.unread")
                    : String(localized: "resourcesLibrary.a11y.read")))
            }
        }
        .padding(SpacingTokens.sp3)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .fill(ColorTokens.Spec.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .strokeBorder(
                    resource.isRead ? ColorTokens.Spec.accent.opacity(0.35) : ColorTokens.Spec.line,
                    lineWidth: 1
                )
        )
    }

    private func thumbnail(
        for resource: SpecialistResourcesLibraryModels.Resource
    ) -> some View {
        let tint = kindTint(resource.kind)
        return Image(systemName: resource.kind.icon)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 50, height: 50)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.sm)
                    .fill(tint.opacity(0.14))
            )
            .accessibilityHidden(true)
    }

    private func typeChip(
        for kind: SpecialistResourcesLibraryModels.ResourceKind
    ) -> some View {
        let tint = kindTint(kind)
        return Text(kindLabel(kind))
            .font(TypographyTokens.caption(11).weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .frame(height: 22)
            .background(Capsule().fill(tint.opacity(0.16)))
    }

    /// Тип-метка карточки (статья / видео / PDF) — материал.
    private func kindLabel(
        _ kind: SpecialistResourcesLibraryModels.ResourceKind
    ) -> String {
        switch kind {
        case .article: return String(localized: "resourcesLibrary.kind.article")
        case .video:   return String(localized: "resourcesLibrary.kind.video")
        case .pdf:     return String(localized: "resourcesLibrary.kind.pdf")
        case .all, .saved: return String(localized: "resourcesLibrary.kind.article")
        }
    }

    /// Цвет-акцент по типу материала: статья — lilac, видео — коралл, PDF — rose.
    /// Это мелкие семантические акценты на иконке/чипе (не крупные заливки).
    private func kindTint(
        _ kind: SpecialistResourcesLibraryModels.ResourceKind
    ) -> Color {
        switch kind {
        case .article: return ColorTokens.Brand.lilac
        case .video:   return ColorTokens.Spec.accent
        case .pdf:     return ColorTokens.Brand.rose
        case .all, .saved: return ColorTokens.Spec.accent
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
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(resource.kind.title)
                                .font(TypographyTokens.caption(12).weight(.semibold))
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
                        .fixedSize(horizontal: false, vertical: true)

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
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
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
