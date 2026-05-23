import SwiftUI

// MARK: - AnimalSoundsBingoView

struct AnimalSoundsBingoView: View {

    let childId: String

    @State private var interactor: AnimalSoundsBingoInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService

    private let columns = Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sp2), count: 4)

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                content
            }
            .navigationTitle(Text(String(localized: "animalBingo.nav.title")))
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
                    interactor = AnimalSoundsBingoInteractor(childId: childId)
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            ScrollView {
                VStack(spacing: SpacingTokens.sp4) {
                    hero(state: interactor.state)
                    calledOutCard(interactor: interactor)
                    grid(interactor: interactor)
                    if interactor.state.isBingo {
                        bingoBanner
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

    private func hero(state: AnimalSoundsBingoModels.ViewState) -> some View {
        HSCard(style: .tinted(ColorTokens.Brand.butter.opacity(0.18))) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .pointing, size: 56)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "animalBingo.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "animalBingo.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                    Text("Отмечено: \(state.markedCount) из \(state.cells.count)")
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkSoft)
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func calledOutCard(interactor: AnimalSoundsBingoInteractor) -> some View {
        if let id = interactor.state.calledOutId,
           let cell = interactor.state.cells.first(where: { $0.id == id }) {
            HSCard(style: .tinted(ColorTokens.Brand.sky.opacity(0.18))) {
                HStack(spacing: SpacingTokens.sp3) {
                    Text(cell.emoji).font(.system(size: 36))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Кто говорит «\(cell.soundDescription)»?")
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Kid.ink)
                        Text("Найди и отметь карточку!")
                            .font(TypographyTokens.body(13))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                    }
                    Spacer()
                }
            }
        }
    }

    private func grid(interactor: AnimalSoundsBingoInteractor) -> some View {
        LazyVGrid(columns: columns, spacing: SpacingTokens.sp2) {
            ForEach(interactor.state.cells) { cell in
                cellTile(cell, interactor: interactor)
            }
        }
    }

    private func cellTile(
        _ cell: AnimalSoundsBingoModels.Cell,
        interactor: AnimalSoundsBingoInteractor
    ) -> some View {
        let isCalled = interactor.state.calledOutId == cell.id
        return Button {
            hapticService.impact(.light)
            interactor.toggle(cell.id)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(cell.isMarked
                          ? ColorTokens.Semantic.successBg
                          : ColorTokens.Kid.surface)
                Text(cell.emoji).font(.system(size: 30))
                if cell.isMarked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(ColorTokens.Semantic.success)
                        .padding(4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isCalled ? ColorTokens.Brand.primary : Color.clear, lineWidth: 2.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(cell.label))
        .accessibilityValue(Text(cell.isMarked ? "Отмечено" : "Не отмечено"))
        .accessibilityAddTraits(.isButton)
    }

    private var bingoBanner: some View {
        HSCard(style: .tinted(ColorTokens.Semantic.successBg)) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .celebrating, size: 48)
                    .accessibilityHidden(true)
                Text("Бинго!")
                    .font(TypographyTokens.titleLarge(26).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Spacer()
            }
        }
    }

    private func cta(interactor: AnimalSoundsBingoInteractor) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            HSButton(
                String(localized: "animalBingo.cta.action"),
                style: .primary,
                size: .large,
                icon: "play.circle.fill"
            ) {
                hapticService.notification(.success)
                interactor.callRandom()
            }
            HSButton(
                "Перезапустить",
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

#Preview("AnimalSoundsBingo — Light") {
    AnimalSoundsBingoView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("AnimalSoundsBingo — Dark") {
    AnimalSoundsBingoView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
