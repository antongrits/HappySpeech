import OSLog
import SwiftUI

// MARK: - CustomWordListViewModelHolder

@MainActor
@Observable
final class CustomWordListViewModelHolder: CustomWordListDisplayLogic {

    var rows: [CustomWordListModels.Load.RowViewModel] = []
    var isEmpty: Bool = true
    var saveError: String?
    var previewText: String?
    var previewCount: Int = 0
    var didJustSave: Bool = false

    // AutoPick
    var autoPickResult: CustomWordListModels.AutoPick.ViewModel?
    var isAutoPickLoading: Bool = false

    func displayLoad(viewModel: CustomWordListModels.Load.ViewModel) async {
        rows = viewModel.lists
        isEmpty = viewModel.isEmpty
    }

    func displaySaveSuccess(viewModel: CustomWordListModels.Save.ViewModel) async {
        saveError = nil
        didJustSave = true
    }

    func displaySaveFailure(viewModel: CustomWordListModels.Save.FailureViewModel) async {
        saveError = viewModel.message
        didJustSave = false
    }

    func displayDelete(removedId: String) async {
        rows.removeAll { $0.id == removedId }
        isEmpty = rows.isEmpty
    }

    func displayPreview(viewModel: CustomWordListModels.Preview.ViewModel) async {
        previewText = viewModel.text
        previewCount = viewModel.exercisesCount
    }

    func displayAutoPick(viewModel: CustomWordListModels.AutoPick.ViewModel) async {
        autoPickResult = viewModel
        isAutoPickLoading = false
    }

    func displayAutoPickLoading(_ isLoading: Bool) async {
        isAutoPickLoading = isLoading
        if isLoading {
            autoPickResult = nil
        }
    }
}

// MARK: - CustomWordListView (Clean Swift: View)
//
// v31 Волна C, Функция Ф.4 «Списки слов специалиста».
//
// Специалистский контур: спокойный список созданных списков с возможностью
// создать новый. Editor — sheet с полями имени, целевого звука, динамическим
// набором слов и предпросмотром генерируемых упражнений.

struct CustomWordListView: View {

    let specialistId: String

    @State private var holder = CustomWordListViewModelHolder()
    @State private var interactor: CustomWordListInteractor?
    @State private var presenter: CustomWordListPresenter?
    @State private var router: CustomWordListRouter?
    @State private var editingDraft: WordListDraft?
    @State private var pendingDeleteId: String?

    @Environment(\.exitToSpecialistHome) private var exitToSpecialistHome
    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "CustomWordList.View"
    )

    // РЕДИЗАЙН specialist-editor (2026-06-13): нейтрально-холодный статичный
    // холст `Spec.bg` (эталон #ECEEF2) + едва заметный coral-radial в hero-зоне.
    @ViewBuilder
    private var specBackground: some View {
        ZStack(alignment: .top) {
            ColorTokens.Spec.bg
            RadialGradient(
                colors: [ColorTokens.Spec.accent.opacity(0.07), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                specBackground

                if holder.isEmpty {
                    emptyState
                } else {
                    listView
                }
            }
            .navigationTitle(Text("customWordList.screen.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        router?.dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Spec.inkMuted)
                    }
                    .accessibilityLabel(Text("customWordList.close.a11y"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingDraft = WordListDraft()
                    } label: {
                        Label(String(localized: "customWordList.new"), systemImage: "plus")
                    }
                    .accessibilityIdentifier("customWordList.newButton")
                }
            }
            .task { await setupAndLoad() }
            .sheet(item: $editingDraft, onDismiss: {
                holder.saveError = nil
                holder.previewText = nil
                holder.autoPickResult = nil
                holder.isAutoPickLoading = false
            }) { draft in
                editorSheet(draft: draft)
            }
            .confirmationDialog(
                Text("customWordList.delete"),
                isPresented: Binding(
                    get: { pendingDeleteId != nil },
                    set: { if !$0 { pendingDeleteId = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    if let id = pendingDeleteId {
                        Task { await interactor?.delete(request: .init(id: id)) }
                        pendingDeleteId = nil
                    }
                } label: {
                    Text("customWordList.delete")
                }
                Button(role: .cancel) {
                    pendingDeleteId = nil
                } label: {
                    Text("customWordList.cancel")
                }
            }
        }
        .environment(\.circuitContext, .specialist)
        .accessibilityIdentifier("CustomWordListRoot")
    }

    // MARK: - List

    private var listView: some View {
        List {
            ForEach(Array(holder.rows.enumerated()), id: \.element.id) { index, row in
                Button {
                    editRow(row.id)
                } label: {
                    rowLabel(row)
                }
                .buttonStyle(.plain)
                .listRowBackground(ColorTokens.Spec.surface)
                .swipeActions {
                    Button(role: .destructive) {
                        pendingDeleteId = row.id
                    } label: {
                        Label(String(localized: "customWordList.delete"), systemImage: "trash")
                    }
                }
                .scrollTransition(.animated(reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.85))) { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0)
                        .scaleEffect(phase.isIdentity ? 1 : 0.97)
                }
                .hsParallaxTile(factor: 0.15)
                .zIndex(Double(holder.rows.count - index))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("customWordList.list")
    }

    private func rowLabel(
        _ row: CustomWordListModels.Load.RowViewModel
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.name)
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Spec.ink)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
            HStack(spacing: SpacingTokens.sp2) {
                Text(row.targetSoundText)
                    .font(TypographyTokens.caption(12))
                    .padding(.horizontal, SpacingTokens.sp2)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(ColorTokens.Spec.accent.opacity(0.18))
                    )
                    .foregroundStyle(ColorTokens.Spec.accent)
                Text(row.wordsCountText)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
            }
        }
        .padding(.vertical, SpacingTokens.sp1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(row.accessibilityLabel))
    }

    // MARK: - Empty

    private var emptyState: some View {
        HSLiquidGlassCard(style: .elevated) {
            VStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "list.bullet.rectangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(ColorTokens.Spec.accent.opacity(0.6))
                    .hsSymbolEffect(.bounce, value: holder.isEmpty)
                    .accessibilityHidden(true)
                Text("customWordList.empty.title")
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Spec.ink)
                Text("customWordList.empty.message")
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                Button {
                    editingDraft = WordListDraft()
                } label: {
                    Label(String(localized: "customWordList.new"), systemImage: "plus.circle.fill")
                        .padding(.horizontal, SpacingTokens.sp4)
                        .padding(.vertical, SpacingTokens.sp2)
                        .background(
                            Capsule().fill(ColorTokens.Spec.accent.opacity(0.18))
                        )
                        .foregroundStyle(ColorTokens.Spec.accent)
                }
                .accessibilityIdentifier("customWordList.empty.newButton")
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
    }

    // MARK: - Editor sheet

    private func editorSheet(draft: WordListDraft) -> some View {
        CustomWordListEditorView(
            initialDraft: draft,
            previewText: holder.previewText,
            previewCount: holder.previewCount,
            errorMessage: holder.saveError,
            autoPickResult: holder.autoPickResult,
            isAutoPickLoading: holder.isAutoPickLoading,
            onPreview: { current in
                Task {
                    await interactor?.preview(request: .init(draft: current))
                }
            },
            onAutoPick: { params in
                Task {
                    await interactor?.autoPick(request: .init(params: params))
                }
            },
            onSave: { current in
                Task {
                    await interactor?.save(
                        request: .init(specialistId: specialistId, draft: current)
                    )
                    if holder.didJustSave {
                        holder.didJustSave = false
                        editingDraft = nil
                    }
                }
            },
            onCancel: {
                editingDraft = nil
            }
        )
        .presentationDetents([.large])
    }

    // MARK: - Wiring

    private func editRow(_ id: String) {
        guard let data = interactor?.lists.first(where: { $0.id == id }) else { return }
        editingDraft = WordListDraft.from(data)
    }

    private func setupAndLoad() async {
        if interactor == nil {
            let presenter = CustomWordListPresenter(displayLogic: holder)
            let worker = LiveCustomWordListWorker(realmActor: container.realmActor)
            let interactor = CustomWordListInteractor(
                specialistId: specialistId,
                worker: worker
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = CustomWordListRouter(dismissAction: { exitToSpecialistHome() })
        }
        await interactor?.load(request: .init(specialistId: specialistId))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("CustomWordList / specialist") {
    CustomWordListView(specialistId: "local-parent")
        .environment(AppContainer.preview())
}
#endif
