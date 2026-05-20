import OSLog
import SwiftUI

// MARK: - SyllableConstructorViewModelHolder

@MainActor
@Observable
final class SyllableConstructorViewModelHolder: SyllableConstructorDisplayLogic {

    var startVM: SyllableConstructorModels.Start.ViewModel?
    var lastSubmit: SyllableConstructorModels.SubmitGuess.ViewModel?
    /// Локальные плитки, оставшиеся в банке (ребёнок ещё не использовал).
    var bankTiles: [SyllableConstructorModels.Start.TileViewModel] = []
    /// Плитки в слотах ответа (в порядке, в котором ребёнок их добавил).
    var slotTiles: [SyllableConstructorModels.Start.TileViewModel] = []

    func displayStart(viewModel: SyllableConstructorModels.Start.ViewModel) async {
        startVM = viewModel
        bankTiles = viewModel.tiles
        slotTiles = []
        lastSubmit = nil
    }

    func displaySubmit(viewModel: SyllableConstructorModels.SubmitGuess.ViewModel) async {
        lastSubmit = viewModel
    }
}

// MARK: - SyllableConstructorView (Clean Swift: View)
//
// v31 Волна B, Функция Ф.1 «Слог-конструктор».
//
// UX: целевое слово сверху + N пустых слотов под слоги + плитки-слоги внизу
// (банк). Ребёнок тапает плитку → она добавляется в первый свободный слот.
// Тап по слоту с плиткой возвращает её в банк. По заполнению всех слотов
// доступна кнопка «Проверить». На ошибке плитки можно перетасовать и
// проверить снова; на успехе — переход к следующему слову.
//
// Accessibility:
//   • Kid circuit: плитки и кнопки ≥ 56pt, screenEdge padding.
//   • VoiceOver: каждая плитка — слог; слово — целевое произношение.
//   • Dynamic Type: word/tile тексты с minimumScaleFactor.
//   • Reduced Motion: тайл-перенос — opacity вместо spring.

struct SyllableConstructorView: View {

    let childId: String
    let preferredTier: SyllableTier?

    @State private var holder = SyllableConstructorViewModelHolder()
    @State private var interactor: SyllableConstructorInteractor?
    @State private var presenter: SyllableConstructorPresenter?
    @State private var router: SyllableConstructorRouter?
    @State private var isSubmitting: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    init(childId: String, preferredTier: SyllableTier? = nil) {
        self.childId = childId
        self.preferredTier = preferredTier
    }

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SyllableConstructor.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()

                if let startVM = holder.startVM {
                    contentSection(startVM: startVM)
                } else {
                    loadingSection
                }
            }
            .navigationTitle(Text("syllable.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text("syllable.close.a11y"))
                }
            }
            .task {
                await setupAndStart()
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Content

    private func contentSection(
        startVM: SyllableConstructorModels.Start.ViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp4) {
            tierChipsRow(startVM)
            progressRow(startVM)
            wordHeader(startVM)
            slotsRow(startVM)
            tileBank
            Spacer(minLength: SpacingTokens.sp2)
            actionRow(startVM)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.vertical, SpacingTokens.sp3)
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: holder.bankTiles.map(\.id))
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: holder.slotTiles.map(\.id))
    }

    private func tierChipsRow(
        _ startVM: SyllableConstructorModels.Start.ViewModel
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.sp2) {
                ForEach(startVM.availableTiers) { chip in
                    Button {
                        Task { await switchTier(to: chip.id) }
                    } label: {
                        Text(chip.title)
                            .font(TypographyTokens.caption(13).weight(.medium))
                            .foregroundStyle(chip.isSelected
                                ? ColorTokens.Overlay.onAccent
                                : ColorTokens.Kid.ink)
                            .lineLimit(1)
                            .padding(.horizontal, SpacingTokens.sp3)
                            .padding(.vertical, SpacingTokens.sp1)
                            .background(
                                Capsule().fill(chip.isSelected
                                    ? ColorTokens.Brand.primary
                                    : ColorTokens.Kid.surfaceAlt)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(chip.title))
                    .accessibilityAddTraits(chip.isSelected ? .isSelected : [])
                }
            }
            .padding(.vertical, SpacingTokens.micro)
        }
    }

    private func progressRow(
        _ startVM: SyllableConstructorModels.Start.ViewModel
    ) -> some View {
        Text(startVM.progressLabel)
            .font(TypographyTokens.caption(12).monospacedDigit())
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func wordHeader(
        _ startVM: SyllableConstructorModels.Start.ViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            if let symbol = startVM.symbolName {
                Image(systemName: symbol)
                    .font(.system(size: 44))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .accessibilityHidden(true)
            }
            Text(startVM.wordLabel)
                .font(TypographyTokens.title(30))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityLabel(Text(startVM.accessibilityLabel))
            Text(startVM.tierHint)
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
        .padding(.vertical, SpacingTokens.sp2)
    }

    private func slotsRow(
        _ startVM: SyllableConstructorModels.Start.ViewModel
    ) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            ForEach(0..<startVM.placeholdersCount, id: \.self) { index in
                slotView(at: index)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func slotView(at index: Int) -> some View {
        if index < holder.slotTiles.count {
            let tile = holder.slotTiles[index]
            Button {
                returnTile(tile)
            } label: {
                Text(tile.text)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(minWidth: 64, minHeight: 56)
                    .padding(.horizontal, SpacingTokens.sp2)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .fill(ColorTokens.Brand.primary)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(tile.accessibilityLabel))
            .accessibilityHint(Text("syllable.slot.return.hint"))
        } else {
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .strokeBorder(
                    ColorTokens.Kid.line,
                    style: .init(lineWidth: 2, dash: [6, 4])
                )
                .frame(minWidth: 64, minHeight: 56)
                .accessibilityHidden(true)
        }
    }

    private var tileBank: some View {
        let columns = [GridItem(.adaptive(minimum: 72), spacing: SpacingTokens.sp2)]
        return LazyVGrid(columns: columns, spacing: SpacingTokens.sp2) {
            ForEach(holder.bankTiles) { tile in
                Button {
                    placeTile(tile)
                } label: {
                    Text(tile.text)
                        .font(TypographyTokens.title(22))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(minWidth: 64, minHeight: 56)
                        .padding(.horizontal, SpacingTokens.sp2)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(ColorTokens.Kid.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .strokeBorder(ColorTokens.Brand.primary, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(tile.accessibilityLabel))
                .accessibilityHint(Text("syllable.tile.place.hint"))
            }
        }
        .padding(.top, SpacingTokens.sp2)
    }

    @ViewBuilder
    private func actionRow(
        _ startVM: SyllableConstructorModels.Start.ViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            if let submit = holder.lastSubmit {
                feedbackBanner(submit)
            }
            HStack(spacing: SpacingTokens.sp2) {
                Button {
                    Task { await speakWord() }
                } label: {
                    Label {
                        Text("syllable.hear")
                            .font(TypographyTokens.headline(17))
                    } icon: {
                        Image(systemName: "speaker.wave.2.fill")
                    }
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .fill(ColorTokens.Brand.primary.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("syllable.hear.hint"))

                Button {
                    Task { await submitOrAdvance(startVM) }
                } label: {
                    Text(primaryButtonTitle(startVM))
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(primaryButtonColor(startVM))
                        )
                }
                .buttonStyle(.plain)
                .disabled(isPrimaryDisabled(startVM))
                .accessibilityHint(Text("syllable.primary.hint"))
            }
        }
    }

    private func primaryButtonTitle(
        _ startVM: SyllableConstructorModels.Start.ViewModel
    ) -> String {
        if holder.lastSubmit?.isCorrect == true {
            return String(localized: "syllable.next")
        }
        return String(localized: "syllable.check")
    }

    private func primaryButtonColor(
        _ startVM: SyllableConstructorModels.Start.ViewModel
    ) -> Color {
        if holder.lastSubmit?.isCorrect == true {
            return ColorTokens.Brand.mint
        }
        return holder.slotTiles.count == startVM.placeholdersCount
            ? ColorTokens.Brand.primary
            : ColorTokens.Kid.surfaceAlt
    }

    private func isPrimaryDisabled(
        _ startVM: SyllableConstructorModels.Start.ViewModel
    ) -> Bool {
        if holder.lastSubmit?.isCorrect == true { return false }
        return holder.slotTiles.count != startVM.placeholdersCount
    }

    private func feedbackBanner(
        _ submit: SyllableConstructorModels.SubmitGuess.ViewModel
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.micro) {
            Text(submit.toastTitle)
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Kid.ink)
            Text(submit.toastDetail)
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SpacingTokens.sp3)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(submit.isCorrect
                    ? ColorTokens.Brand.mint.opacity(0.18)
                    : ColorTokens.Semantic.warning.opacity(0.15))
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ProgressView()
                .controlSize(.large)
            Text("syllable.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Wiring

    private func setupAndStart() async {
        if interactor == nil {
            let presenter = SyllableConstructorPresenter(displayLogic: holder)
            let worker = SyllableConstructorWorker()
            let interactor = SyllableConstructorInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = SyllableConstructorRouter(dismissAction: { dismiss() })
        }
        await interactor?.start(request: .init(childId: childId, preferredTier: preferredTier))
    }

    private func placeTile(_ tile: SyllableConstructorModels.Start.TileViewModel) {
        guard let index = holder.bankTiles.firstIndex(of: tile) else { return }
        holder.bankTiles.remove(at: index)
        holder.slotTiles.append(tile)
        holder.lastSubmit = nil
        container.hapticService.selection()
    }

    private func returnTile(_ tile: SyllableConstructorModels.Start.TileViewModel) {
        guard let index = holder.slotTiles.firstIndex(of: tile) else { return }
        holder.slotTiles.remove(at: index)
        holder.bankTiles.append(tile)
        holder.lastSubmit = nil
        container.hapticService.selection()
    }

    private func submitOrAdvance(
        _ startVM: SyllableConstructorModels.Start.ViewModel
    ) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        if holder.lastSubmit?.isCorrect == true {
            await interactor?.nextWord(request: .init(nextTier: nil))
            return
        }
        let ids = holder.slotTiles.map(\.id)
        await interactor?.submitGuess(request: .init(tileIds: ids))
    }

    private func switchTier(to rawValue: Int) async {
        guard let tier = SyllableTier(rawValue: rawValue) else { return }
        await interactor?.nextWord(request: .init(nextTier: tier))
    }

    private func speakWord() async {
        guard let word = interactor?.currentWord else { return }
        await SyllableConstructorWorker().voiceWord(word)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SyllableConstructor / start") {
    SyllableConstructorView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
