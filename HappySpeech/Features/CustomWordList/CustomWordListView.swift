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
    @State private var showEditor: Bool = false
    @State private var pendingDeleteId: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "CustomWordList.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Spec.bg.ignoresSafeArea()

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
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Spec.inkMuted)
                    }
                    .accessibilityLabel(Text("customWordList.close.a11y"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingDraft = WordListDraft()
                        showEditor = true
                    } label: {
                        Label(String(localized: "customWordList.new"), systemImage: "plus")
                    }
                    .accessibilityIdentifier("customWordList.newButton")
                }
            }
            .task { await setupAndLoad() }
            .sheet(isPresented: $showEditor, onDismiss: {
                editingDraft = nil
                holder.saveError = nil
                holder.previewText = nil
            }) {
                if let draft = editingDraft {
                    editorSheet(draft: draft)
                }
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
            ForEach(holder.rows) { row in
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
                .lineLimit(2)
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
        VStack(spacing: SpacingTokens.sp3) {
            Image(systemName: "list.bullet.rectangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(ColorTokens.Spec.accent.opacity(0.6))
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
                showEditor = true
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
        .padding(.horizontal, SpacingTokens.screenEdge)
    }

    // MARK: - Editor sheet

    private func editorSheet(draft: WordListDraft) -> some View {
        CustomWordListEditorView(
            initialDraft: draft,
            previewText: holder.previewText,
            previewCount: holder.previewCount,
            errorMessage: holder.saveError,
            onPreview: { current in
                Task {
                    await interactor?.preview(request: .init(draft: current))
                }
            },
            onSave: { current in
                editingDraft = current
                Task {
                    await interactor?.save(
                        request: .init(specialistId: specialistId, draft: current)
                    )
                    if holder.didJustSave {
                        holder.didJustSave = false
                        showEditor = false
                    }
                }
            },
            onCancel: {
                showEditor = false
            }
        )
        .presentationDetents([.large])
    }

    // MARK: - Wiring

    private func editRow(_ id: String) {
        guard let data = interactor?.lists.first(where: { $0.id == id }) else { return }
        editingDraft = WordListDraft.from(data)
        showEditor = true
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
            self.router = CustomWordListRouter(dismissAction: { dismiss() })
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
