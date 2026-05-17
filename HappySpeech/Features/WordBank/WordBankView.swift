import OSLog
import SwiftUI

// MARK: - WordBankViewModelHolder

@MainActor
@Observable
final class WordBankViewModelHolder: WordBankDisplayLogic {

    var loadVM: WordBankModels.Load.ViewModel?
    var visibleTiles: [WordTileViewModel] = []
    var selectedDetail: WordBankModels.SelectWord.ViewModel?
    var practiceRequest: WordBankModels.Practice.Request?

    func displayLoad(viewModel: WordBankModels.Load.ViewModel) async {
        self.loadVM = viewModel
        self.visibleTiles = viewModel.tiles
    }

    func displayFilter(viewModel: WordBankModels.Filter.ViewModel) async {
        self.visibleTiles = viewModel.tiles
    }

    func displaySelectWord(viewModel: WordBankModels.SelectWord.ViewModel) async {
        self.selectedDetail = viewModel
    }

    func displayPractice(request: WordBankModels.Practice.Request) async {
        self.practiceRequest = request
    }
}

// MARK: - WordBankView (Clean Swift: View)
//
// F-303 v25 — экран «Мои слова» (детский контур).
//
// Layout:
//   1. Счётчик слов (градиентная карточка)
//   2. Фильтр по звуку (HSSegmentedPicker — только звуки с данными)
//   3. Сетка карточек слов (LazyVGrid, 3 / 2 колонки по Dynamic Type)
//   4. Bottom sheet с деталями слова + «Сказать снова»
//   5. Empty state (Ляля + приглашение к уроку)
//
// Accessibility: VoiceOver на карточках, Dynamic Type, Reduced Motion.

struct WordBankView: View {

    let childId: String

    @State private var holder = WordBankViewModelHolder()
    @State private var interactor: WordBankInteractor?
    @State private var presenter: WordBankPresenter?
    @State private var router: WordBankRouter?
    @State private var selectedFilter: String = WordBankView.allFilterTag
    @State private var showDetailSheet: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator

    /// Служебный тег пункта «Все» в пикере фильтра.
    static let allFilterTag = "__all__"

    init(childId: String) {
        self.childId = childId
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()

                if let viewModel = holder.loadVM {
                    if viewModel.isEmpty {
                        emptyState
                    } else {
                        contentScroll(viewModel: viewModel)
                    }
                } else {
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .navigationTitle(Text("wordBank.screen.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text("wordBank.close.a11y"))
                }
            }
            .sheet(isPresented: $showDetailSheet) {
                if let detail = holder.selectedDetail {
                    detailSheet(detail)
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }
            }
            .task {
                await setupAndLoad()
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Content

    @ViewBuilder
    private func contentScroll(viewModel: WordBankModels.Load.ViewModel) -> some View {
        ScrollView {
            VStack(spacing: SpacingTokens.sp4) {
                counterCard(viewModel: viewModel)

                if viewModel.soundFilters.count > 1 {
                    filterPicker(viewModel: viewModel)
                }

                wordsGrid
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.vertical, SpacingTokens.sp4)
        }
    }

    @ViewBuilder
    private func counterCard(viewModel: WordBankModels.Load.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp1) {
            Image(systemName: "star.fill")
                .font(.system(size: 30))
                .foregroundStyle(ColorTokens.Brand.gold)
                .accessibilityHidden(true)

            Text(viewModel.counterText)
                .font(TypographyTokens.display(48).weight(.bold))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .contentTransition(.numericText())

            Text("wordBank.counter.subtitle")
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Overlay.onAccent.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.sp6)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(GradientTokens.kidDeep)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(
                String.localizedStringWithFormat(
                    String(localized: "wordBank.counter.a11y"),
                    viewModel.totalCount
                )
            )
        )
    }

    @ViewBuilder
    private func filterPicker(viewModel: WordBankModels.Load.ViewModel) -> some View {
        let items = [Self.allFilterTag] + viewModel.soundFilters
        HSSegmentedPicker(
            selection: $selectedFilter,
            items: items,
            style: .capsule,
            titleProvider: { tag in
                tag == Self.allFilterTag
                    ? LocalizedStringKey("wordBank.filter.all")
                    : LocalizedStringKey(stringLiteral: tag)
            }
        )
        .onChange(of: selectedFilter) { _, newValue in
            Task { await applyFilter(newValue) }
        }
    }

    @ViewBuilder
    private var wordsGrid: some View {
        let columnCount = dynamicTypeSize >= .accessibility1 ? 2 : 3
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: SpacingTokens.sp3),
            count: columnCount
        )
        LazyVGrid(columns: columns, spacing: SpacingTokens.sp3) {
            ForEach(holder.visibleTiles) { tile in
                wordTile(tile)
            }
        }
    }

    @ViewBuilder
    private func wordTile(_ tile: WordTileViewModel) -> some View {
        Button {
            Task { await selectWord(tile.id) }
        } label: {
            VStack(spacing: SpacingTokens.sp2) {
                Text(tile.word)
                    .font(TypographyTokens.headline(15).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)

                HStack(spacing: 2) {
                    ForEach(0..<tile.starRating, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.Brand.gold)
                    }
                }
                .accessibilityHidden(true)

                Text(tile.targetSoundLabel)
                    .font(TypographyTokens.caption(11).weight(.semibold))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .padding(.horizontal, SpacingTokens.sp2)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(ColorTokens.Kid.surfaceAlt)
                    )
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .padding(SpacingTokens.sp3)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .fill(tileBackground(tile.tileTint))
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .strokeBorder(tileBorder(tile.tileTint), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(tileAccessibilityLabel(tile)))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Detail sheet

    @ViewBuilder
    private func detailSheet(_ detail: WordBankModels.SelectWord.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp4) {
            Text(detail.word)
                .font(TypographyTokens.display(40).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.ink)
                .padding(.top, SpacingTokens.sp6)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: SpacingTokens.micro) {
                ForEach(0..<detail.starRating, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(ColorTokens.Brand.gold)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                Text(
                    String.localizedStringWithFormat(
                        String(localized: "wordBank.detail.stars.a11y"),
                        detail.starRating
                    )
                )
            )

            VStack(spacing: SpacingTokens.sp1) {
                Text(detail.attemptCountText)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Text(detail.lastPracticedText)
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }

            Spacer()

            VStack(spacing: SpacingTokens.sp3) {
                HSButton(
                    String(localized: "wordBank.detail.practiceAgain"),
                    style: .primary,
                    size: .large,
                    icon: "play.fill"
                ) {
                    Task { await practice(detail) }
                }
                .accessibilityHint(Text("wordBank.detail.practiceAgain.hint"))

                HSButton(
                    String(localized: "wordBank.detail.close"),
                    style: .ghost,
                    size: .medium
                ) {
                    showDetailSheet = false
                }
            }
            .padding(.bottom, SpacingTokens.sp6)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .frame(maxWidth: .infinity)
        .background(ColorTokens.Kid.surface.ignoresSafeArea())
    }

    // MARK: - Empty state

    private var emptyState: some View {
        HSEmptyStateView(
            mascot: .happy,
            title: String(localized: "wordBank.empty.title"),
            subtitle: String(localized: "wordBank.empty.subtitle"),
            actionTitle: String(localized: "wordBank.empty.action"),
            action: {
                router?.routeToWorldMap()
            }
        )
    }

    // MARK: - Tint helpers

    private func tileBackground(_ tint: WordTileTint) -> Color {
        switch tint {
        case .gold:    return ColorTokens.Brand.gold.opacity(0.16)
        case .mint:    return ColorTokens.Brand.mint.opacity(0.16)
        case .neutral: return ColorTokens.Kid.surfaceAlt
        }
    }

    private func tileBorder(_ tint: WordTileTint) -> Color {
        switch tint {
        case .gold:    return ColorTokens.Brand.gold.opacity(0.4)
        case .mint:    return ColorTokens.Brand.mint.opacity(0.4)
        case .neutral: return ColorTokens.Kid.line
        }
    }

    private func tileAccessibilityLabel(_ tile: WordTileViewModel) -> String {
        let starsPhrase = String.localizedStringWithFormat(
            String(localized: "wordBank.tile.stars.a11y"),
            tile.starRating
        )
        return String(
            format: String(localized: "wordBank.tile.a11y"),
            tile.word,
            starsPhrase,
            tile.targetSoundLabel
        )
    }

    // MARK: - Wiring

    private func setupAndLoad() async {
        if interactor == nil {
            let presenter = WordBankPresenter(displayLogic: holder)
            let interactor = WordBankInteractor(
                childId: childId,
                worker: WordBankWorker(sessionRepository: container.sessionRepository),
                analyticsService: container.analyticsService,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = WordBankRouter(
                coordinator: coordinator,
                childId: childId,
                dismissAction: { dismiss() }
            )
        }
        await interactor?.loadBank(request: .init(childId: childId))
    }

    private func applyFilter(_ tag: String) async {
        let sound: String? = tag == Self.allFilterTag ? nil : tag
        await interactor?.filterBySound(request: .init(soundTarget: sound))
    }

    private func selectWord(_ id: String) async {
        await interactor?.selectWord(request: .init(wordId: id))
        showDetailSheet = true
    }

    private func practice(_ detail: WordBankModels.SelectWord.ViewModel) async {
        await interactor?.practiceWord(
            request: .init(word: detail.word, targetSound: detail.targetSound)
        )
        showDetailSheet = false
        router?.routeToPractice(word: detail.word, targetSound: detail.targetSound)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("WordBank") {
    WordBankView(childId: "preview-child-1")
        .environment(AppContainer.preview())
        .environment(AppCoordinator())
}
#endif
