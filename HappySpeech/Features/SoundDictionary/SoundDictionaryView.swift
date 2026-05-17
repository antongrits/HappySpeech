import OSLog
import SwiftUI

// MARK: - SoundDictionaryViewModelHolder

@MainActor
@Observable
final class SoundDictionaryViewModelHolder: SoundDictionaryDisplayLogic {

    var loadVM: SoundDictionaryModels.Load.ViewModel?
    var selectedDetail: SoundDictionaryModels.SelectPhoneme.ViewModel?
    var toastMessage: String?
    var showToast: Bool = false
    var practiceRequest: SoundDictionaryModels.PracticePhoneme.ViewModel?

    func displayLoad(viewModel: SoundDictionaryModels.Load.ViewModel) async {
        self.loadVM = viewModel
    }

    func displaySelectPhoneme(viewModel: SoundDictionaryModels.SelectPhoneme.ViewModel) async {
        self.selectedDetail = viewModel
    }

    func displayPlayAudio(viewModel: SoundDictionaryModels.PlayAudio.ViewModel) async {
        if let toast = viewModel.toastMessage {
            self.toastMessage = toast
            self.showToast = true
        }
    }

    func displayPracticePhoneme(viewModel: SoundDictionaryModels.PracticePhoneme.ViewModel) async {
        self.practiceRequest = viewModel
    }
}

// MARK: - SoundDictionaryView (Clean Swift: View)
//
// Block AE v21 — экран интерактивной энциклопедии 42 фонем русского языка.
//
// Layout:
//   1. Header (title + total count)
//   2. ScrollView with sections — каждая группа звуков отдельной секцией,
//      внутри — LazyVGrid 4-колонок с фонемными карточками
//   3. Detail sheet (presentationDetent .medium) — IPA, articulation,
//      example word, play audio + practice CTAs
//
// Accessibility:
//   • VoiceOver: cell label = «<Cyrillic>, пример: <example>»; section header.
//   • Dynamic Type: ScrollView root + minimumScaleFactor.
//   • Reduced Motion: убираем sheet transition animations.
//   • Touch targets: ячейка — 64x64 (>= 44pt).

struct SoundDictionaryView: View {

    @State private var holder = SoundDictionaryViewModelHolder()
    @State private var interactor: SoundDictionaryInteractor?
    @State private var presenter: SoundDictionaryPresenter?
    @State private var router: SoundDictionaryRouter?
    @State private var showDetailSheet: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundDictionary.View"
    )

    private let gridColumns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: SpacingTokens.sp2),
        count: 4
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: SpacingTokens.sp5) {
                        if let viewModel = holder.loadVM {
                            heroSection(viewModel: viewModel)
                            ForEach(viewModel.sections) { section in
                                sectionView(section)
                            }
                            footerNote
                        } else {
                            loadingSection
                        }
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.vertical, SpacingTokens.sp4)
                }
            }
            .navigationTitle(Text("soundDictionary.screen.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                    .accessibilityLabel(Text("soundDictionary.close.a11y"))
                }
            }
            .sheet(isPresented: $showDetailSheet) {
                if let detail = holder.selectedDetail {
                    detailSheet(detail)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
            .overlay(alignment: .top) {
                if holder.showToast, let toast = holder.toastMessage {
                    toastBanner(text: toast)
                        .padding(.top, SpacingTokens.sp2)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.35), value: holder.showToast)
            .task {
                await setupAndLoad()
            }
        }
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Hero

    @ViewBuilder
    private func heroSection(viewModel: SoundDictionaryModels.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                    Text("soundDictionary.hero.title")
                        .font(TypographyTokens.title(22))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Text(viewModel.totalCountLabel)
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(nil)
                }
                Spacer()
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .accessibilityHidden(true)
            }

            Text("soundDictionary.hero.subtitle")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkSoft)
                .lineLimit(nil)
                .padding(.top, SpacingTokens.sp1)
        }
        .padding(SpacingTokens.sp4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Parent.surface)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Section

    @ViewBuilder
    private func sectionView(_ section: SoundDictionaryModels.Load.SectionViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: section.groupSymbol)
                    .font(.body)
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(ColorTokens.Brand.primary.opacity(0.12))
                    )
                    .accessibilityHidden(true)

                Text(section.groupTitle)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer()

                Text("\(section.cells.count)")
                    .font(TypographyTokens.caption(11).monospacedDigit())
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .padding(.horizontal, SpacingTokens.sp2)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(ColorTokens.Parent.bg)
                    )
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(section.groupAccessibilityLabel))

            LazyVGrid(columns: gridColumns, spacing: SpacingTokens.sp2) {
                ForEach(section.cells) { cell in
                    phonemeCell(cell)
                }
            }
        }
    }

    // MARK: - Phoneme cell

    @ViewBuilder
    private func phonemeCell(_ cell: SoundDictionaryModels.Load.CellViewModel) -> some View {
        Button {
            Task { await selectPhoneme(id: cell.id) }
        } label: {
            VStack(spacing: 2) {
                Text(cell.cyrillic)
                    .font(TypographyTokens.title(24).weight(.semibold))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(cell.ipa)
                    .font(TypographyTokens.caption(10).monospaced())
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.sm)
                    .fill(ColorTokens.Parent.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.sm)
                    .strokeBorder(ColorTokens.Parent.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(cell.accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Detail sheet

    @ViewBuilder
    private func detailSheet(_ viewModel: SoundDictionaryModels.SelectPhoneme.ViewModel) -> some View {
        ScrollView {
            VStack(spacing: SpacingTokens.sp4) {
                // Big phoneme letter
                Text(viewModel.title)
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .padding(.top, SpacingTokens.sp4)
                    .accessibilityHidden(true)

                Text(viewModel.ipaLabel)
                    .font(TypographyTokens.title(20).monospaced())
                    .foregroundStyle(ColorTokens.Parent.inkMuted)

                Text(viewModel.groupTitle)
                    .font(TypographyTokens.caption(12))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(ColorTokens.Brand.primary)

                // Example
                VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                    Text("soundDictionary.detail.example.label")
                        .font(TypographyTokens.caption(11))
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .foregroundStyle(ColorTokens.Parent.inkMuted)

                    Text(viewModel.exampleWord)
                        .font(TypographyTokens.title(24))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SpacingTokens.sp4)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.md)
                        .fill(ColorTokens.Parent.bg)
                )

                // Articulation note
                VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                    Text("soundDictionary.detail.articulation.label")
                        .font(TypographyTokens.caption(11))
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .foregroundStyle(ColorTokens.Parent.inkMuted)

                    Text(viewModel.articulationNote)
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SpacingTokens.sp4)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.md)
                        .fill(ColorTokens.Parent.bg)
                )

                // CTAs
                HStack(spacing: SpacingTokens.sp3) {
                    Button {
                        Task { await playAudio() }
                    } label: {
                        Label {
                            Text(viewModel.playAudioLabel)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        } icon: {
                            Image(systemName: "speaker.wave.2.fill")
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint(Text("soundDictionary.detail.cta.playAudio.hint"))

                    Button {
                        Task { await practice() }
                    } label: {
                        Label {
                            Text(viewModel.practiceCtaLabel)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        } icon: {
                            Image(systemName: "play.fill")
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint(Text("soundDictionary.detail.cta.practice.hint"))
                }
                .padding(.top, SpacingTokens.sp2)

                Spacer(minLength: SpacingTokens.sp4)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .background(ColorTokens.Parent.surface.ignoresSafeArea())
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ProgressView()
                .controlSize(.large)
            Text("soundDictionary.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SpacingTokens.sp10)
    }

    // MARK: - Footer

    private var footerNote: some View {
        Text("soundDictionary.footer.note")
            .font(TypographyTokens.caption(11))
            .foregroundStyle(ColorTokens.Parent.inkMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, SpacingTokens.sp4)
            .padding(.horizontal, SpacingTokens.sp4)
    }

    // MARK: - Toast

    @ViewBuilder
    private func toastBanner(text: String) -> some View {
        Text(text)
            .font(TypographyTokens.caption(13))
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .padding(.horizontal, SpacingTokens.sp4)
            .padding(.vertical, SpacingTokens.sp2)
            .background(
                Capsule().fill(ColorTokens.Brand.primary)
            )
            .shadow(color: ColorTokens.Overlay.shadow, radius: 8, y: 4)
            .task {
                try? await Task.sleep(for: .seconds(2.0))
                holder.showToast = false
            }
    }

    // MARK: - Wiring

    private func setupAndLoad() async {
        if interactor == nil {
            let presenter = SoundDictionaryPresenter(displayLogic: holder)
            let interactor = SoundDictionaryInteractor(
                audioWorker: PhonemeAudioWorker(),
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = SoundDictionaryRouter(dismissAction: { dismiss() })
        }
        await interactor?.load(request: .init())
    }

    private func selectPhoneme(id: String) async {
        await interactor?.selectPhoneme(request: .init(phonemeId: id))
        showDetailSheet = true
    }

    private func playAudio() async {
        guard let id = currentSelectedId else { return }
        await interactor?.playAudio(request: .init(phonemeId: id))
    }

    private func practice() async {
        guard let id = currentSelectedId else { return }
        await interactor?.practicePhoneme(request: .init(phonemeId: id))
        showDetailSheet = false
        router?.routeToPractice(phonemeId: id)
    }

    private var currentSelectedId: String? {
        interactor?.selectedPhoneme?.id
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SoundDictionary / loaded") {
    SoundDictionaryView()
        .environment(AppContainer.preview())
}
#endif
