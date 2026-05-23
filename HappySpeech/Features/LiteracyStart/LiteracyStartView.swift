import OSLog
import SwiftUI

// MARK: - Holder

@MainActor
@Observable
final class LiteracyStartViewModelHolder: LiteracyStartDisplayLogic {

    var loadVM: LiteracyStartModels.LoadLetter.ViewModel?
    var isUnsupported: Bool = false
    var unsupportedSound: String = ""

    func displayLoadLetter(viewModel: LiteracyStartModels.LoadLetter.ViewModel) async {
        self.loadVM = viewModel
        self.isUnsupported = false
    }

    func displayUnsupportedSound(targetSound: String) async {
        self.isUnsupported = true
        self.unsupportedSound = targetSound
        self.loadVM = nil
    }
}

// MARK: - View

struct LiteracyStartView: View {

    let targetSound: String
    let childId: String

    @State private var holder = LiteracyStartViewModelHolder()
    @State private var interactor: LiteracyStartInteractor?
    @State private var presenter: LiteracyStartPresenter?
    @State private var router: LiteracyStartRouter?
    @State private var didBootstrap = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "LiteracyStart.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                if let vm = holder.loadVM {
                    content(vm)
                } else if holder.isUnsupported {
                    unsupportedView
                } else {
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .animation(reduceMotion ? .none : MotionTokens.spring, value: holder.loadVM?.letter)
            .navigationTitle(Text("literacy.start.nav.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await bootstrap() }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ vm: LiteracyStartModels.LoadLetter.ViewModel) -> some View {
        ScrollView {
            VStack(spacing: SpacingTokens.sp4) {
                heroSection(vm)
                letterCard(vm)
                wordsSection(vm.words)
                Spacer(minLength: SpacingTokens.sp3)
                actionButtons(vm)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp3)
            .padding(.bottom, SpacingTokens.sp4)
        }
        .accessibilityElement(children: .contain)
    }

    private func heroSection(_ vm: LiteracyStartModels.LoadLetter.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            LyalyaMascotView(state: .explaining, size: 100)
                .accessibilityHidden(true)
            Text(vm.titleText)
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .accessibilityLabel(Text(vm.accessibilityLabel))
        }
        .frame(maxWidth: .infinity)
    }

    private func letterCard(_ vm: LiteracyStartModels.LoadLetter.ViewModel) -> some View {
        HSLiquidGlassCard(style: .primary, padding: SpacingTokens.sp4) {
            Text(vm.letter)
                .font(TypographyTokens.kidHero(140))
                .foregroundStyle(ColorTokens.Brand.primary)
                .frame(maxWidth: .infinity, minHeight: 180)
                .accessibilityHidden(true)
        }
    }

    private func wordsSection(_ words: [WordSample]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            Text("literacy.start.words.section.title")
                .font(TypographyTokens.headline(17))
                .foregroundStyle(ColorTokens.Kid.ink)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100), spacing: SpacingTokens.sp2)],
                spacing: SpacingTokens.sp2
            ) {
                ForEach(words) { word in
                    wordTile(word)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func wordTile(_ word: WordSample) -> some View {
        VStack(spacing: SpacingTokens.sp1) {
            HSContentSymbol(word.assetName, size: 48, tint: ColorTokens.Brand.primary)
            Text(word.text)
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 110)
        .padding(SpacingTokens.sp2)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Kid.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(word.text))
    }

    private func actionButtons(_ vm: LiteracyStartModels.LoadLetter.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            HSButton(
                vm.traceButtonTitle,
                style: .primary,
                size: .large,
                icon: "pencil.and.outline"
            ) {
                Task { await startTracing(letter: vm.letter) }
            }
            HSButton(
                vm.listenButtonTitle,
                style: .secondary,
                size: .large,
                icon: "speaker.wave.2.fill"
            ) {
                Task { await playSound() }
            }
        }
    }

    // MARK: - Unsupported

    private var unsupportedView: some View {
        VStack(spacing: SpacingTokens.sp3) {
            LyalyaMascotView(state: .thinking, size: 100)
                .accessibilityHidden(true)
            Text("literacy.start.unsupported.title")
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
            Text(String(
                format: String(localized: "literacy.start.unsupported.body.format"),
                holder.unsupportedSound
            ))
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
            HSButton(
                String(localized: "common.close"),
                style: .secondary,
                size: .large
            ) {
                dismiss()
            }
        }
        .padding(SpacingTokens.screenEdge)
        .frame(maxWidth: .infinity)
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
            .accessibilityLabel(Text("common.close"))
        }
    }

    // MARK: - Lifecycle

    private func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        let presenter = LiteracyStartPresenter(displayLogic: holder)
        let router = LiteracyStartRouter()
        router.coordinator = coordinator
        let interactor = LiteracyStartInteractor(
            presenter: presenter,
            router: router,
            audioService: container.audioService,
            childId: childId
        )
        self.presenter = presenter
        self.router = router
        self.interactor = interactor
        await interactor.loadLetter(.init(targetSound: targetSound))
    }

    private func startTracing(letter: String) async {
        interactor?.startTracing(.init(letter: letter))
    }

    private func playSound() async {
        await interactor?.playSound(.init(targetSound: targetSound))
    }
}

// MARK: - Preview

#Preview("LiteracyStart — Light (Р)") {
    LiteracyStartView(targetSound: "Р", childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("LiteracyStart — Dark (Ш)") {
    LiteracyStartView(targetSound: "Ш", childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
