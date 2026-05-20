import OSLog
import SwiftUI

// MARK: - Holder
//
// `@Observable` ViewModel-Holder — единственное состояние View. Реализует
// `ObjectDescriptionMapDisplayLogic`, чтобы Presenter мог пушить ViewModel
// напрямую через async-метод.

@MainActor
@Observable
final class ObjectDescriptionMapViewModelHolder: ObjectDescriptionMapDisplayLogic {

    var loadVM: ObjectDescriptionMapModels.LoadObjects.ViewModel?
    var selectVM: ObjectDescriptionMapModels.SelectObject.ViewModel?
    var resultVM: ObjectDescriptionMapModels.RecordResult.ViewModel?
    var phase: Phase = .picking
    var isRecording: Bool = false
    var highlightedSlotIndex: Int = 0

    enum Phase: Equatable {
        case picking
        case planning   // показываем план-схему, ждём «Записать»
        case recording
        case result
    }

    func displayLoadObjects(viewModel: ObjectDescriptionMapModels.LoadObjects.ViewModel) async {
        self.loadVM = viewModel
        self.phase = .picking
    }

    func displaySelectObject(viewModel: ObjectDescriptionMapModels.SelectObject.ViewModel) async {
        self.selectVM = viewModel
        self.phase = .planning
        self.highlightedSlotIndex = 0
    }

    func displayRecordResult(viewModel: ObjectDescriptionMapModels.RecordResult.ViewModel) async {
        self.resultVM = viewModel
        self.phase = .result
        self.isRecording = false
    }
}

// MARK: - View

struct ObjectDescriptionMapView: View {

    let childId: String

    @State private var holder = ObjectDescriptionMapViewModelHolder()
    @State private var interactor: ObjectDescriptionMapInteractor?
    @State private var presenter: ObjectDescriptionMapPresenter?
    @State private var router: ObjectDescriptionMapRouter?
    @State private var didBootstrap = false
    @State private var recordCountdown: Int = 90

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator

    private static let logger = Logger(
        subsystem: "ru.happyspeech", category: "ObjectDescriptionMap.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                switch holder.phase {
                case .picking:    pickingSection
                case .planning:   planningSection
                case .recording:  recordingSection
                case .result:     resultSection
                }
            }
            .navigationTitle(Text("Описательная карта")) // L10n
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await bootstrap() }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Picking

    private var pickingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: SpacingTokens.sp4) {
                    if let load = holder.loadVM {
                        ForEach(load.categoriesInOrder, id: \.self) { category in
                            categorySection(
                                name: category,
                                items: load.grouped[category] ?? []
                            )
                        }
                    } else {
                        ProgressView().padding()
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
            }
            instructionBar
        }
    }

    private func categorySection(name: String, items: [DescriptionObject]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            Text(name.capitalized)
                .font(TypographyTokens.headline(17))
                .foregroundStyle(ColorTokens.Kid.ink)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 110), spacing: SpacingTokens.sp2)],
                spacing: SpacingTokens.sp2
            ) {
                ForEach(items) { object in
                    objectButton(object)
                }
            }
        }
    }

    private func objectButton(_ object: DescriptionObject) -> some View {
        Button {
            Task { await selectObject(object.id) }
        } label: {
            VStack(spacing: SpacingTokens.sp1) {
                Image(systemName: object.symbol)
                    .font(.system(size: 40))
                    .foregroundStyle(ColorTokens.Brand.rose)
                Text(object.title)
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
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
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(object.title))
        .accessibilityHint(Text("Категория \(object.category). Нажми, чтобы открыть план."))
    }

    private var instructionBar: some View {
        Text("Выбери, о чём расскажешь.") // L10n
            .font(TypographyTokens.body(14))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp3)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Planning (показ план-схемы)

    private var planningSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            if let select = holder.selectVM {
                planObjectHeader(select)
                planList(select.planItems)
                Spacer(minLength: 0)
                planCTA(select)
            } else {
                ProgressView().padding()
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.sp3)
    }

    private func planObjectHeader(_ vm: ObjectDescriptionMapModels.SelectObject.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp1) {
            Image(systemName: vm.object.symbol)
                .font(.system(size: 72))
                .foregroundStyle(ColorTokens.Brand.rose)
            Text(vm.object.title)
                .font(TypographyTokens.title(28))
                .foregroundStyle(ColorTokens.Kid.ink)
            Text(vm.hintMessage)
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Kid.surface)
        )
    }

    private func planList(_ items: [DescriptionPlanItem]) -> some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: SpacingTokens.sp2)],
                spacing: SpacingTokens.sp2
            ) {
                ForEach(items) { item in
                    planItemCard(item)
                }
            }
        }
    }

    private func planItemCard(_ item: DescriptionPlanItem) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            Image(systemName: item.icon)
                .font(.system(size: 24))
                .foregroundStyle(ColorTokens.Brand.lilac)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.slotTitle)
                    .font(TypographyTokens.headline(14))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Text(item.prompt)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.sp2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.sm)
                .fill(ColorTokens.Kid.surfaceAlt)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.sm)
                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(item.slotTitle). \(item.prompt)"))
    }

    private func planCTA(_ vm: ObjectDescriptionMapModels.SelectObject.ViewModel) -> some View {
        Button {
            Task { await beginRecording() }
        } label: {
            Label("Начать рассказ", systemImage: "mic.fill") // L10n
                .font(TypographyTokens.headline(17))
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(ColorTokens.Brand.primary)
                )
                .foregroundStyle(ColorTokens.Overlay.onAccent)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Нажми и расскажи о \(vm.object.title) по плану."))
    }

    // MARK: - Recording

    private var recordingSection: some View {
        VStack(spacing: SpacingTokens.sp4) {
            if let vm = holder.selectVM {
                Image(systemName: vm.object.symbol)
                    .font(.system(size: 80))
                    .foregroundStyle(ColorTokens.Brand.rose)
                Text(vm.object.title)
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Kid.ink)
            }
            Image(systemName: "mic.fill")
                .font(.system(size: 56))
                .foregroundStyle(ColorTokens.Semantic.error)
                .scaleEffect(holder.isRecording && !reduceMotion ? 1.08 : 1.0)
                .animation(
                    reduceMotion
                        ? .none
                        : .easeInOut(duration: 0.85).repeatForever(autoreverses: true),
                    value: holder.isRecording
                )
            Text("Рассказываю…") // L10n
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Kid.ink)
            Text("\(recordCountdown)")
                .font(TypographyTokens.title(36).monospacedDigit())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .accessibilityLabel(Text("Осталось секунд: \(recordCountdown)"))
            Button {
                Task { await stopRecording() }
            } label: {
                Text("Готово") // L10n
                    .font(TypographyTokens.headline(18))
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .fill(ColorTokens.Semantic.error)
                    )
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .padding(SpacingTokens.screenEdge)
        .task { await runRecordCountdown() }
    }

    private func runRecordCountdown() async {
        recordCountdown = 90
        while recordCountdown > 0, holder.phase == .recording {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            recordCountdown -= 1
        }
        if holder.phase == .recording {
            await stopRecording()
        }
    }

    // MARK: - Result

    private var resultSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                if let vm = holder.resultVM {
                    resultHeader(vm)
                    resultStars(vm)
                    coverageBar(vm)
                    coverageList(vm)
                    feedbackCard(vm)
                    if !vm.transcript.isEmpty {
                        transcriptCard(vm)
                    }
                    actionButtons
                }
            }
            .padding(SpacingTokens.screenEdge)
        }
        .accessibilityElement(children: .contain)
    }

    private func resultHeader(_ vm: ObjectDescriptionMapModels.RecordResult.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp1) {
            Image(systemName: vm.object.symbol)
                .font(.system(size: 56))
                .foregroundStyle(ColorTokens.Brand.rose)
            Text("Ты рассказал о \(vm.object.title.lowercased())")
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
            Text(vm.durationLabel)
                .font(TypographyTokens.caption(13).monospacedDigit())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func resultStars(_ vm: ObjectDescriptionMapModels.RecordResult.ViewModel) -> some View {
        HStack(spacing: SpacingTokens.sp1) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < vm.stars ? "star.fill" : "star")
                    .font(.system(size: 36))
                    .foregroundStyle(index < vm.stars
                                     ? ColorTokens.Brand.gold
                                     : ColorTokens.Kid.inkSoft)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(Text("\(vm.stars) из 3 звёзд"))
    }

    private func coverageBar(_ vm: ObjectDescriptionMapModels.RecordResult.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
            HStack {
                Text("Раскрыто пунктов")
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                Spacer()
                Text("\(vm.coveragePercent)%")
                    .font(TypographyTokens.headline(14).monospacedDigit())
                    .foregroundStyle(ColorTokens.Kid.ink)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(ColorTokens.Kid.surfaceAlt)
                    Capsule()
                        .fill(ColorTokens.Brand.mint)
                        .frame(width: proxy.size.width * vm.coverageRatio)
                }
            }
            .frame(height: 12)
        }
        .padding(SpacingTokens.sp3)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Kid.surface)
        )
    }

    private func coverageList(_ vm: ObjectDescriptionMapModels.RecordResult.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
            Text("План:")
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Kid.ink)
            ForEach(vm.planDecorated) { decorated in
                planRow(decorated)
            }
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Kid.surface)
        )
    }

    private func planRow(_ decorated: DecoratedPlanItem) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            Image(systemName: decorated.isCovered
                  ? "checkmark.circle.fill"
                  : "circle.dashed")
                .font(.system(size: 22))
                .foregroundStyle(decorated.isCovered
                                 ? ColorTokens.Brand.mint
                                 : ColorTokens.Kid.inkSoft)
            VStack(alignment: .leading, spacing: 1) {
                Text(decorated.item.slotTitle)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.ink)
                if !decorated.matchedKeywords.isEmpty {
                    Text(decorated.matchedKeywords.prefix(3).joined(separator: ", "))
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(
            decorated.isCovered
                ? "\(decorated.item.slotTitle) — раскрыто"
                : "\(decorated.item.slotTitle) — пропущено"
        ))
    }

    private func feedbackCard(_ vm: ObjectDescriptionMapModels.RecordResult.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
            Text(vm.feedbackTitle)
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Kid.ink)
            Text(vm.feedbackBody)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(vm.accessibilityLabel))
    }

    private func transcriptCard(_ vm: ObjectDescriptionMapModels.RecordResult.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
            Text("Что услышала Ляля:")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
            Text(vm.transcript)
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Kid.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
        )
    }

    private var actionButtons: some View {
        HStack(spacing: SpacingTokens.sp2) {
            Button {
                Task { await restartFlow() }
            } label: {
                Text("Ещё объект") // L10n
                    .font(TypographyTokens.headline(16))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .fill(ColorTokens.Kid.surfaceAlt)
                    )
                    .foregroundStyle(ColorTokens.Kid.ink)
            }
            .buttonStyle(.plain)
            Button {
                dismiss()
            } label: {
                Text("Готово") // L10n
                    .font(TypographyTokens.headline(16))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .fill(ColorTokens.Brand.primary)
                    )
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if holder.phase == .planning {
                Button {
                    Task { await backToPicking() }
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title3)
                        .foregroundStyle(ColorTokens.Kid.inkSoft)
                }
                .accessibilityLabel(Text("Назад к списку"))
            }
        }
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

    // MARK: - Lifecycle

    private func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        let presenter = ObjectDescriptionMapPresenter(displayLogic: holder)
        let interactor = ObjectDescriptionMapInteractor(
            presenter: presenter,
            audioService: container.audioService,
            asrService: container.asrService
        )
        let router = ObjectDescriptionMapRouter()
        router.coordinator = coordinator
        self.presenter = presenter
        self.interactor = interactor
        self.router = router
        await interactor.loadObjects()
    }

    private func selectObject(_ id: String) async {
        guard let interactor else { return }
        await interactor.selectObject(id: id)
    }

    private func backToPicking() async {
        interactor?.clearSelection()
        holder.selectVM = nil
        holder.phase = .picking
    }

    private func beginRecording() async {
        guard let interactor else { return }
        await interactor.startRecording()
        holder.phase = .recording
        holder.isRecording = true
    }

    private func stopRecording() async {
        guard let interactor, holder.phase == .recording else { return }
        holder.isRecording = false
        await interactor.stopRecordingAndProcess()
    }

    private func restartFlow() async {
        interactor?.clearSelection()
        holder.selectVM = nil
        holder.resultVM = nil
        holder.phase = .picking
    }
}

// MARK: - Preview

#Preview("ObjectDescriptionMap — Light") {
    ObjectDescriptionMapView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("ObjectDescriptionMap — Dark") {
    ObjectDescriptionMapView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
