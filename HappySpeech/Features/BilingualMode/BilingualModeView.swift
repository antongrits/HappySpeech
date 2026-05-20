import OSLog
import SwiftUI

// MARK: - Holder

@MainActor
@Observable
final class BilingualModeViewModelHolder: BilingualModeDisplayLogic {

    var loadVM: BilingualModeModels.LoadVocabulary.ViewModel?
    var practiceStartVM: BilingualModeModels.StartPractice.ViewModel?
    var answerVM: BilingualModeModels.SubmitAnswer.ViewModel?
    var finishVM: BilingualModeModels.FinishPractice.ViewModel?

    func displayLoadVocabulary(viewModel: BilingualModeModels.LoadVocabulary.ViewModel) async {
        self.loadVM = viewModel
    }

    func displayStartPractice(viewModel: BilingualModeModels.StartPractice.ViewModel) async {
        self.practiceStartVM = viewModel
    }

    func displaySubmitAnswer(viewModel: BilingualModeModels.SubmitAnswer.ViewModel) async {
        self.answerVM = viewModel
    }

    func displayFinishPractice(viewModel: BilingualModeModels.FinishPractice.ViewModel) async {
        self.finishVM = viewModel
    }
}

// MARK: - View

struct BilingualModeView: View {

    let childId: String

    @State private var holder = BilingualModeViewModelHolder()
    @State private var interactor: BilingualModeInteractor?
    @State private var presenter: BilingualModePresenter?
    @State private var router: BilingualModeRouter?
    @State private var ttsWorker: BilingualTTSWorker?

    @State private var didBootstrap = false
    @State private var showPractice = false

    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "BilingualMode.View"
    )

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                content
            }
            .navigationTitle(Text("Билингвальный режим"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await bootstrap() }
            .sheet(isPresented: $showPractice) {
                if let interactor, let worker = ttsWorker, let language = currentLanguage {
                    BilingualPracticeView(
                        interactor: interactor,
                        ttsWorker: worker,
                        language: language,
                        holder: holder,
                        onClose: { showPractice = false }
                    )
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
                introCard
                languagePickerCard
                if currentLanguage == .off {
                    offHintCard
                } else {
                    practiceCard
                    vocabularySection
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp3)
            .padding(.bottom, SpacingTokens.sp10)
        }
    }

    // MARK: - Intro

    private var introCard: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "character.bubble.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(ColorTokens.Brand.lilac)
                    .accessibilityHidden(true)
                Text("Два языка — два богатства")
                    .font(TypographyTokens.headline(18))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            Text("Учимся называть одни и те же предметы и на русском, и на втором языке.")
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Brand.lilac.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .strokeBorder(ColorTokens.Brand.lilac.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Picker

    private var languagePickerCard: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            Text("Выбери второй язык")
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Kid.ink)
            Picker("Второй язык", selection: languageBinding) {
                ForEach(BilingualSecondLanguage.allCases, id: \.self) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(Text("Выбор второго языка"))
            .accessibilityValue(Text(currentLanguage?.displayName ?? ""))
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Kid.surface)
        )
    }

    // MARK: - Off-state hint

    private var offHintCard: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
            Text("Режим выключен")
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Kid.ink)
            Text("Включи второй язык, чтобы увидеть словарик и поиграть в перевод.")
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Kid.surfaceAlt)
        )
    }

    // MARK: - Practice CTA

    private var practiceCard: some View {
        Button {
            Task { await startPractice() }
        } label: {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(ColorTokens.Brand.lilac))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Угадай перевод")
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Kid.ink)
                    Text("10 раундов • выбери правильный ответ")
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(TypographyTokens.caption(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.sp3)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .strokeBorder(ColorTokens.Brand.lilac.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .tapFeedback()
        .accessibilityLabel(Text("Начать тренировку: угадай перевод"))
        .accessibilityHint(Text("10 раундов с тремя вариантами ответа"))
    }

    // MARK: - Vocabulary section

    @ViewBuilder
    private var vocabularySection: some View {
        if let load = holder.loadVM, !load.categoriesInOrder.isEmpty {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                Text("Словарик")
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Kid.ink)
                ForEach(load.categoriesInOrder, id: \.self) { category in
                    categorySection(
                        title: load.categoryTitles[category] ?? category.capitalized,
                        words: load.grouped[category] ?? [],
                        language: load.secondLanguage
                    )
                }
            }
        } else {
            ProgressView().frame(maxWidth: .infinity)
        }
    }

    private func categorySection(
        title: String,
        words: [BilingualWord],
        language: BilingualSecondLanguage
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            Text(title)
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
            LazyVStack(spacing: SpacingTokens.sp1) {
                ForEach(words) { word in
                    wordCard(word, language: language)
                }
            }
        }
    }

    private func wordCard(
        _ word: BilingualWord,
        language: BilingualSecondLanguage
    ) -> some View {
        let translation = word.translation(for: language) ?? "—"
        return HStack(spacing: SpacingTokens.sp3) {
            Image(systemName: word.symbol)
                .font(.system(size: 28))
                .foregroundStyle(ColorTokens.Brand.lilac)
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(word.russian)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Text(translation)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            Spacer()
            Button {
                Task { await speak(translation, language: language) }
            } label: {
                Image(systemName: "speaker.wave.2.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(ColorTokens.Brand.lilac)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Послушать \(translation)"))
            .accessibilityHint(Text("Произносит слово на втором языке"))
        }
        .padding(SpacingTokens.sp2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.sm)
                .fill(ColorTokens.Kid.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.sm)
                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(word.russian) — \(translation)"))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
            }
            .accessibilityLabel(Text("Закрыть"))
        }
    }

    // MARK: - Bindings

    private var currentLanguage: BilingualSecondLanguage? {
        interactor?.secondLanguage
    }

    private var languageBinding: Binding<BilingualSecondLanguage> {
        Binding(
            get: { interactor?.secondLanguage ?? .off },
            set: { newValue in
                Task { await interactor?.setSecondLanguage(newValue) }
            }
        )
    }

    // MARK: - Lifecycle

    private func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        let presenter = BilingualModePresenter(displayLogic: holder)
        let interactor = BilingualModeInteractor(presenter: presenter)
        let router = BilingualModeRouter()
        router.coordinator = coordinator
        let worker = BilingualTTSWorker()
        self.presenter = presenter
        self.interactor = interactor
        self.router = router
        self.ttsWorker = worker
        await interactor.loadVocabulary()
        Self.logger.info(
            "Bootstrapped childId=\(childId, privacy: .private(mask: .hash))"
        )
    }

    private func speak(_ text: String, language: BilingualSecondLanguage) async {
        guard let worker = ttsWorker else { return }
        await worker.speak(text, language: language)
    }

    private func startPractice() async {
        guard let interactor, interactor.secondLanguage != .off else { return }
        await interactor.startPractice()
        showPractice = true
    }
}

// MARK: - Preview

#Preview("BilingualMode — Light") {
    BilingualModeView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("BilingualMode — Dark") {
    BilingualModeView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
