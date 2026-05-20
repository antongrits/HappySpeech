import OSLog
import SwiftUI

// MARK: - ComprehensionDetectiveViewModelHolder

@MainActor
@Observable
final class ComprehensionDetectiveViewModelHolder: ComprehensionDetectiveDisplayLogic {

    var startVM: ComprehensionDetectiveModels.Start.ViewModel?
    var lastPick: ComprehensionDetectiveModels.Pick.ViewModel?

    func displayStart(viewModel: ComprehensionDetectiveModels.Start.ViewModel) async {
        startVM = viewModel
        lastPick = nil
    }

    func displayPick(viewModel: ComprehensionDetectiveModels.Pick.ViewModel) async {
        lastPick = viewModel
    }
}

// MARK: - ComprehensionDetectiveView (Clean Swift: View)
//
// v31 Волна B, Функция Ф.2 «Понимание-детектив».
//
// UX: верх — инструкция + кнопка «Повторить» (озвучивает Ляля / Siri TTS).
// Ниже — 2×2 сетка SF-картинок. Тап по картинке проверяет ответ. На ошибке
// можно тапнуть другую; на успехе — кнопка «Следующее».
//
// Accessibility:
//   • Kid circuit: картинки ≥ 120pt; кнопки ≥ 56pt.
//   • VoiceOver: каждая картинка озвучивается своей подписью.
//   • Dynamic Type: инструкция multiline с minimumScaleFactor.
//   • Reduced Motion: подсветка правильной — без spring анимации.

struct ComprehensionDetectiveView: View {

    let childId: String
    let preferredTier: GrammarTier?

    @State private var holder = ComprehensionDetectiveViewModelHolder()
    @State private var interactor: ComprehensionDetectiveInteractor?
    @State private var presenter: ComprehensionDetectivePresenter?
    @State private var router: ComprehensionDetectiveRouter?
    @State private var pickInFlight = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    init(childId: String, preferredTier: GrammarTier? = nil) {
        self.childId = childId
        self.preferredTier = preferredTier
    }

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ComprehensionDetective.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()

                if let startVM = holder.startVM {
                    contentSection(startVM)
                } else {
                    loadingSection
                }
            }
            .navigationTitle(Text("detective.title"))
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
                    .accessibilityLabel(Text("detective.close.a11y"))
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
        _ startVM: ComprehensionDetectiveModels.Start.ViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp4) {
            tierChipsRow(startVM)
            progressRow(startVM)
            instructionCard(startVM)
            picturesGrid(startVM)
            Spacer(minLength: SpacingTokens.sp2)
            feedbackOrAdvance(startVM)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.vertical, SpacingTokens.sp3)
    }

    private func tierChipsRow(
        _ startVM: ComprehensionDetectiveModels.Start.ViewModel
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
                                    ? ColorTokens.Brand.sky
                                    : ColorTokens.Kid.surfaceAlt)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(chip.title))
                    .accessibilityAddTraits(chip.isSelected ? .isSelected : [])
                }
            }
        }
    }

    private func progressRow(
        _ startVM: ComprehensionDetectiveModels.Start.ViewModel
    ) -> some View {
        Text(startVM.progressLabel)
            .font(TypographyTokens.caption(12).monospacedDigit())
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func instructionCard(
        _ startVM: ComprehensionDetectiveModels.Start.ViewModel
    ) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.sp3) {
            Image(systemName: "ear.fill")
                .font(.system(size: 32))
                .foregroundStyle(ColorTokens.Brand.sky)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text(startVM.instruction)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.7)
                    .accessibilityLabel(Text(startVM.accessibilityLabel))
                Text(startVM.tierHint)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(nil)
            }
            Spacer()
            Button {
                Task { await replayInstruction() }
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(ColorTokens.Brand.sky))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("detective.replay.a11y"))
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Kid.surface)
        )
        .depthShadow(ShadowTokens.kidDepth)
    }

    private func picturesGrid(
        _ startVM: ComprehensionDetectiveModels.Start.ViewModel
    ) -> some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: SpacingTokens.sp3),
            count: 2
        )
        return LazyVGrid(columns: columns, spacing: SpacingTokens.sp3) {
            ForEach(startVM.pictures) { picture in
                pictureTile(picture)
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: holder.lastPick?.correctPictureId)
    }

    private func pictureTile(
        _ picture: ComprehensionDetectiveModels.Start.PictureViewModel
    ) -> some View {
        let tint = tileTint(for: picture)
        return Button {
            Task { await pick(picture) }
        } label: {
            Image(systemName: picture.symbolName)
                .font(.system(size: 56))
                .foregroundStyle(tint.contentColor)
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(tint.background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .strokeBorder(tint.border, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .disabled(holder.lastPick?.isCorrect == true)
        .accessibilityLabel(Text(picture.accessibilityLabel))
        .accessibilityHint(Text("detective.tile.hint"))
    }

    private struct TileTint {
        let background: Color
        let border: Color
        let contentColor: Color
    }

    private func tileTint(
        for picture: ComprehensionDetectiveModels.Start.PictureViewModel
    ) -> TileTint {
        if let pick = holder.lastPick,
           pick.correctPictureId == picture.id {
            return .init(
                background: ColorTokens.Brand.mint.opacity(0.20),
                border: ColorTokens.Brand.mint,
                contentColor: ColorTokens.Brand.mint
            )
        }
        return .init(
            background: ColorTokens.Kid.surface,
            border: ColorTokens.Brand.sky.opacity(0.55),
            contentColor: ColorTokens.Kid.ink
        )
    }

    @ViewBuilder
    private func feedbackOrAdvance(
        _ startVM: ComprehensionDetectiveModels.Start.ViewModel
    ) -> some View {
        if let pick = holder.lastPick {
            VStack(spacing: SpacingTokens.sp2) {
                feedbackBanner(pick)
                if pick.isCorrect {
                    Button {
                        Task { await advance() }
                    } label: {
                        Text("detective.next")
                            .font(TypographyTokens.headline(17))
                            .foregroundStyle(ColorTokens.Overlay.onAccent)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(
                                RoundedRectangle(cornerRadius: RadiusTokens.card)
                                    .fill(ColorTokens.Brand.mint)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("detective.next.hint"))
                }
            }
        } else {
            Color.clear.frame(height: 1)
        }
    }

    private func feedbackBanner(
        _ pick: ComprehensionDetectiveModels.Pick.ViewModel
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.micro) {
            Text(pick.toastTitle)
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Kid.ink)
            Text(pick.toastDetail)
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SpacingTokens.sp3)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(pick.isCorrect
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
            Text("detective.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Wiring

    private func setupAndStart() async {
        if interactor == nil {
            let presenter = ComprehensionDetectivePresenter(displayLogic: holder)
            let worker = ComprehensionDetectiveWorker()
            let interactor = ComprehensionDetectiveInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = ComprehensionDetectiveRouter(dismissAction: { dismiss() })
        }
        await interactor?.start(request: .init(childId: childId, preferredTier: preferredTier))
    }

    private func pick(
        _ picture: ComprehensionDetectiveModels.Start.PictureViewModel
    ) async {
        guard !pickInFlight else { return }
        pickInFlight = true
        defer { pickInFlight = false }
        await interactor?.pick(request: .init(pictureId: picture.id))
    }

    private func advance() async {
        await interactor?.nextItem(request: .init(nextTier: nil))
    }

    private func switchTier(to rawValue: Int) async {
        guard let tier = GrammarTier(rawValue: rawValue) else { return }
        await interactor?.nextItem(request: .init(nextTier: tier))
    }

    private func replayInstruction() async {
        guard let item = interactor?.currentItem else { return }
        await ComprehensionDetectiveWorker().voiceInstruction(item.instruction)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("ComprehensionDetective / start") {
    ComprehensionDetectiveView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
