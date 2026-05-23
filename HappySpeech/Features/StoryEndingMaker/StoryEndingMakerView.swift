import SwiftUI

// MARK: - StoryEndingMakerView

struct StoryEndingMakerView: View {

    let childId: String

    @State private var interactor: StoryEndingMakerInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService

    private let columns = Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sp3), count: 3)

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                content
            }
            .navigationTitle(Text(String(localized: "storyEnding.nav.title")))
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
                    interactor = StoryEndingMakerInteractor(childId: childId)
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
                    cards(interactor: interactor)
                    if interactor.state.phase == .saved {
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

    private func hero(state: StoryEndingMakerModels.ViewState) -> some View {
        HSCard(style: .tinted(ColorTokens.Brand.sky.opacity(0.18))) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .thinking, size: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "storyEnding.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "storyEnding.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                    phaseLabel(state.phase)
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func phaseLabel(_ phase: StoryEndingMakerModels.Phase) -> some View {
        let text: String = {
            switch phase {
            case .choosing:  return "Шаг 1 из 3: выбери картинку"
            case .recording: return "Шаг 2 из 3: запиши голос"
            case .saved:     return "Готово!"
            }
        }()
        Text(text)
            .font(TypographyTokens.caption(12))
            .foregroundStyle(ColorTokens.Brand.primary)
            .padding(.top, 2)
    }

    private func cards(interactor: StoryEndingMakerInteractor) -> some View {
        LazyVGrid(columns: columns, spacing: SpacingTokens.sp3) {
            ForEach(interactor.state.cards) { card in
                cardTile(card, selected: interactor.state.selectedId == card.id) {
                    hapticService.impact(.light)
                    interactor.select(card.id)
                }
            }
        }
    }

    private func cardTile(
        _ card: StoryEndingMakerModels.PictureCard,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: SpacingTokens.sp2) {
                Text(card.emoji)
                    .font(.system(size: 56))
                Text(card.label)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 132)
            .padding(SpacingTokens.sp3)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selected ? ColorTokens.Brand.sky.opacity(0.20) : ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        selected ? ColorTokens.Brand.primary : ColorTokens.Kid.line,
                        lineWidth: selected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(card.label))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var savedBanner: some View {
        HSCard(style: .tinted(ColorTokens.Semantic.successBg)) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .celebrating, size: 48)
                    .accessibilityHidden(true)
                Text("Концовка сохранена!")
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Spacer()
            }
        }
    }

    private func cta(interactor: StoryEndingMakerInteractor) -> some View {
        let label: String = {
            switch interactor.state.phase {
            case .choosing:  return String(localized: "storyEnding.cta.action")
            case .recording: return "Сохранить"
            case .saved:     return "Начать заново"
            }
        }()
        let icon: String = {
            switch interactor.state.phase {
            case .choosing:  return "hand.point.up.left.fill"
            case .recording: return "checkmark.circle.fill"
            case .saved:     return "arrow.counterclockwise"
            }
        }()
        return HSButton(
            label,
            style: .primary,
            size: .large,
            icon: icon
        ) {
            hapticService.notification(.success)
            switch interactor.state.phase {
            case .choosing:  break // ждём выбора карточки
            case .recording: interactor.save()
            case .saved:     interactor.reset()
            }
        }
        .disabled(interactor.state.phase == .choosing && interactor.state.selectedId == nil)
        .opacity(
            interactor.state.phase == .choosing && interactor.state.selectedId == nil ? 0.5 : 1.0
        )
    }
}

// MARK: - Preview

#Preview("StoryEndingMaker — Light") {
    StoryEndingMakerView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("StoryEndingMaker — Dark") {
    StoryEndingMakerView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
