import OSLog
import SwiftUI

// MARK: - SpeechNormsEncyclopediaViewModelHolder

@MainActor
@Observable
final class SpeechNormsEncyclopediaViewModelHolder: SpeechNormsEncyclopediaDisplayLogic {

    var loadVM: SpeechNormsEncyclopediaModels.Load.ViewModel?

    func displayLoad(viewModel: SpeechNormsEncyclopediaModels.Load.ViewModel) async {
        self.loadVM = viewModel
    }
}

// MARK: - SpeechNormsEncyclopediaView (Clean Swift: View)
//
// v31 Волна A, Функция Ф10 «Что должно быть в возрасте».
//
// Layout:
//   1. Hero header + этическая сноска
//   2. Tab-селектор возраста (5 / 6 / 7 / 8 лет)
//   3. Поиск по карточкам (Searchable)
//   4. Секции по осям: звуки, словарь, грамматика, связная речь, моторика,
//      красные флаги (последние — акцентированы)
//   5. Tap по карточке — раскрывается inline (DisclosureGroup-стиль)
//
// Accessibility:
//   • VoiceOver: каждая карточка имеет combined label, красный флаг помечается
//   • Dynamic Type: ScrollView root, .lineLimit(nil), .fixedSize по вертикали
//   • Reduced Motion: анимация раскрытия — easeInOut, выключается reduceMotion
//   • Touch targets: tabs ≥ 56pt, карточки ≥ 56pt
//   • Light + Dark: ColorTokens.Parent

struct SpeechNormsEncyclopediaView: View {

    /// Стартовый возраст. По умолчанию — 6 лет (наиболее частый возраст
    /// обращения родителя перед школой).
    let initialAge: NormAge

    @State private var holder = SpeechNormsEncyclopediaViewModelHolder()
    @State private var interactor: SpeechNormsEncyclopediaInteractor?
    @State private var presenter: SpeechNormsEncyclopediaPresenter?
    @State private var router: SpeechNormsEncyclopediaRouter?
    @State private var expandedCards: Set<String> = []
    @State private var query: String = ""

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpeechNorms.View"
    )

    init(initialAge: NormAge = .six) {
        self.initialAge = initialAge
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: SpacingTokens.sp5) {
                        if let viewModel = holder.loadVM {
                            heroSection(viewModel)
                            ageTabsSection(viewModel.ageTabs)
                            ethicsSection(viewModel.ethicsNote)
                            if viewModel.isEmpty {
                                emptySection(viewModel.emptyMessage)
                            } else {
                                sectionsList(viewModel.sections)
                            }
                        } else {
                            loadingSection
                        }
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.vertical, SpacingTokens.sp4)
                }
            }
            .navigationTitle(Text("speechNorms.screen.title"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text("speechNorms.search.prompt")
            )
            .onChange(of: query) { _, newValue in
                Task { await interactor?.search(request: .init(query: newValue)) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                    .accessibilityLabel(Text("speechNorms.close.a11y"))
                }
            }
            .task {
                await setupAndLoad()
            }
        }
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Hero

    private func heroSection(
        _ viewModel: SpeechNormsEncyclopediaModels.Load.ViewModel
    ) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text(viewModel.headerTitle)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(viewModel.headerSubtitle)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "book.closed.fill")
                .font(.system(size: 34))
                .foregroundStyle(ColorTokens.Brand.lilac)
                .accessibilityHidden(true)
        }
        .padding(SpacingTokens.sp4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Parent.surface)
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Age tabs

    private func ageTabsSection(
        _ tabs: [SpeechNormsEncyclopediaModels.Load.AgeTabViewModel]
    ) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            ForEach(tabs) { tab in
                ageTabButton(tab)
            }
        }
        .padding(.vertical, SpacingTokens.micro)
        .accessibilityElement(children: .contain)
    }

    private func ageTabButton(
        _ tab: SpeechNormsEncyclopediaModels.Load.AgeTabViewModel
    ) -> some View {
        Button {
            Task { await interactor?.selectAge(request: .init(age: tab.age)) }
        } label: {
            Text(tab.title)
                .font(TypographyTokens.body(14).weight(.semibold))
                .foregroundStyle(
                    tab.isSelected
                        ? ColorTokens.Overlay.onAccent
                        : ColorTokens.Parent.ink
                )
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, minHeight: 56)
                .padding(.horizontal, SpacingTokens.sp2)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.md)
                        .fill(
                            tab.isSelected
                                ? ColorTokens.Brand.primary
                                : ColorTokens.Parent.surface
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.md)
                        .strokeBorder(
                            tab.isSelected
                                ? Color.clear
                                : ColorTokens.Parent.line,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(tab.accessibilityLabel))
        .accessibilityAddTraits(tab.isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Ethics

    private func ethicsSection(_ note: String) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.sp2) {
            Image(systemName: "info.circle")
                .font(.body)
                .foregroundStyle(ColorTokens.Brand.lilac)
                .padding(.top, 2)
                .accessibilityHidden(true)
            Text(note)
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.sm)
                .fill(ColorTokens.Brand.lilac.opacity(0.08))
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Sections list

    private func sectionsList(
        _ sections: [SpeechNormsEncyclopediaModels.Load.SectionViewModel]
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
            ForEach(sections) { section in
                sectionCard(section)
            }
        }
    }

    private func sectionCard(
        _ section: SpeechNormsEncyclopediaModels.Load.SectionViewModel
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: section.symbolName)
                    .font(.body)
                    .foregroundStyle(
                        section.isRedFlag
                            ? ColorTokens.Brand.rose
                            : ColorTokens.Brand.primary
                    )
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(
                            (section.isRedFlag
                                ? ColorTokens.Brand.rose
                                : ColorTokens.Brand.primary
                            ).opacity(0.12)
                        )
                    )
                    .accessibilityHidden(true)

                Text(section.title)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)

                Spacer()
            }
            .padding(.bottom, SpacingTokens.micro)
            .accessibilityAddTraits(.isHeader)

            VStack(spacing: SpacingTokens.sp2) {
                ForEach(section.cards) { card in
                    normCardView(card)
                }
            }
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Parent.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .strokeBorder(
                    section.isRedFlag
                        ? ColorTokens.Brand.rose.opacity(0.4)
                        : ColorTokens.Parent.line,
                    lineWidth: 1
                )
        )
    }

    private func normCardView(
        _ card: SpeechNormsEncyclopediaModels.Load.CardViewModel
    ) -> some View {
        let isExpanded = expandedCards.contains(card.id)
        return Button {
            toggleCard(card.id)
        } label: {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                HStack(alignment: .top, spacing: SpacingTokens.sp2) {
                    if card.isRedFlag {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(ColorTokens.Brand.rose)
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.title)
                            .font(TypographyTokens.body(15).weight(.semibold))
                            .foregroundStyle(ColorTokens.Parent.ink)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(card.summary)
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(ColorTokens.Parent.inkSoft)
                        .accessibilityHidden(true)
                }

                if isExpanded {
                    VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                        Text(card.body)
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Parent.ink)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        if !card.sources.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("speechNorms.card.sources.label")
                                    .font(TypographyTokens.caption(11).weight(.semibold))
                                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                                    .textCase(.uppercase)
                                ForEach(card.sources, id: \.self) { source in
                                    Text("• \(source)")
                                        .font(TypographyTokens.caption(11))
                                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.top, SpacingTokens.micro)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(SpacingTokens.sp3)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.sm)
                    .fill(
                        card.isRedFlag
                            ? ColorTokens.Brand.rose.opacity(0.06)
                            : ColorTokens.Parent.bg
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: isExpanded)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(card.accessibilityLabel))
        .accessibilityHint(
            isExpanded
                ? Text("speechNorms.card.collapse.hint")
                : Text("speechNorms.card.expand.hint")
        )
        .accessibilityAddTraits(isExpanded ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Empty

    private func emptySection(_ message: String) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(ColorTokens.Parent.inkSoft)
                .accessibilityHidden(true)
            Text(message)
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.sp6)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Parent.surface)
        )
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ProgressView()
                .controlSize(.large)
            Text("speechNorms.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SpacingTokens.sp10)
    }

    // MARK: - Actions

    private func toggleCard(_ id: String) {
        if expandedCards.contains(id) {
            expandedCards.remove(id)
        } else {
            expandedCards.insert(id)
        }
    }

    private func setupAndLoad() async {
        if interactor == nil {
            let presenter = SpeechNormsEncyclopediaPresenter(displayLogic: holder)
            let worker = SpeechNormsEncyclopediaWorker()
            let interactor = SpeechNormsEncyclopediaInteractor(worker: worker)
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = SpeechNormsEncyclopediaRouter(dismissAction: { dismiss() })
        }
        await interactor?.load(request: .init(initialAge: initialAge, query: query))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SpeechNorms / loaded") {
    SpeechNormsEncyclopediaView()
        .environment(AppContainer.preview())
}
#endif
