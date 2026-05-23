import SwiftUI

// MARK: - SoundExplorerMapView

struct SoundExplorerMapView: View {

    let childId: String

    @State private var interactor: SoundExplorerMapInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService
    @Environment(AppCoordinator.self) private var coordinator

    private let columns = Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sp2), count: 5)

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                content
            }
            .navigationTitle(Text(String(localized: "soundMap.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
            .task {
                if interactor == nil {
                    interactor = SoundExplorerMapInteractor(childId: childId)
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            ScrollView {
                VStack(spacing: SpacingTokens.sp3) {
                    hero
                    filterBar(interactor: interactor)
                    grid(interactor: interactor)
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

    private var hero: some View {
        HSCard(style: .tinted(ColorTokens.Brand.mint.opacity(0.16))) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .explaining, size: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "soundMap.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "soundMap.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func filterBar(interactor: SoundExplorerMapInteractor) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.sp2) {
                ForEach(SoundExplorerMapModels.MasteryFilter.allCases) { f in
                    chip(f, interactor: interactor)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(
        _ f: SoundExplorerMapModels.MasteryFilter,
        interactor: SoundExplorerMapInteractor
    ) -> some View {
        let selected = interactor.filter == f
        return Button {
            hapticService.impact(.light)
            interactor.setFilter(f)
        } label: {
            Text(f.title)
                .font(TypographyTokens.body(13))
                .foregroundStyle(selected
                                 ? ColorTokens.Overlay.onAccent
                                 : ColorTokens.Kid.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(selected
                                   ? ColorTokens.Brand.primary
                                   : ColorTokens.Kid.bgSoft)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(f.title))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func grid(interactor: SoundExplorerMapInteractor) -> some View {
        LazyVGrid(columns: columns, spacing: SpacingTokens.sp2) {
            ForEach(interactor.visible) { cell in
                soundCell(cell)
            }
        }
    }

    private func soundCell(_ cell: SoundExplorerMapModels.SoundCell) -> some View {
        let tint: Color = {
            switch cell.mastery {
            case .known:    return ColorTokens.Semantic.successBg
            case .learning: return ColorTokens.Semantic.warningBg
            case .untried:  return ColorTokens.Kid.bgSoft
            }
        }()
        return Button {
            hapticService.impact(.light)
            coordinator.navigate(to: .articulationGym(soundGroup: .sibilant))
        } label: {
            VStack(spacing: 2) {
                Text(cell.id)
                    .font(TypographyTokens.title(22).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Text(cell.group)
                    .font(TypographyTokens.caption(9))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.vertical, SpacingTokens.sp2)
            .background(RoundedRectangle(cornerRadius: 14).fill(tint))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(cell.id), группа \(cell.group)"))
    }

    private var cta: some View {
        HSButton(
            String(localized: "soundMap.cta.start"),
            style: .primary,
            size: .large,
            icon: "play.circle.fill"
        ) {
            hapticService.notification(.success)
            coordinator.navigate(to: .articulationGym(soundGroup: .sibilant))
        }
    }
}

// MARK: - Preview

#Preview("SoundExplorerMap — Light") {
    SoundExplorerMapView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("SoundExplorerMap — Dark") {
    SoundExplorerMapView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
