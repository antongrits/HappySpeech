import SwiftUI
import UniformTypeIdentifiers

// MARK: - ProgramEditorView
//
// Specialist-facing screen for building a child's daily program.
// Layout (top → bottom):
//   1. Header — child id, total minutes, save/cancel.
//   2. Block list — reorderable via drag handle (always-active edit mode),
//                   swipe-to-delete.
//   3. Block palette — tap to append a new block of given type.
//
// Drag-drop reorder: the List is kept in `.active` edit mode so three-line
// drag handles are always visible. `.onMove` delegates to the interactor via
// MoveBlock.Request → Interactor → Presenter → displayMoveBlock.
//
// Import/Export: toolbar menu offers "Экспортировать шаблон" and
// "Импортировать шаблон". Export encodes the current program to a
// versioned JSON (.happyspeech) and opens UIActivityViewController.
// Import uses SwiftUI .fileImporter to pick a .happyspeech or .json file
// and loads it via ImportTemplate.Request → Interactor.

struct ProgramEditorView: View {

    let childId: String
    let onSaved: (Program) -> Void
    let onCancel: () -> Void

    @State private var interactor: ProgramEditorInteractor?
    @State private var presenter: ProgramEditorPresenter?
    @State private var router: ProgramEditorRouter?
    // Strong reference: presenter.display — weak, без strong-владельца bridge освободится
    // моментально и callbacks никогда не сработают.
    @State private var displayBridge: ProgramEditorDisplayBridge?

    @State private var blocks: [ProgramBlock] = []
    @State private var totalMinutes: Int = 0
    @State private var isValid: Bool = false
    @State private var notes: String = ""
    @State private var confirmation: String?
    @State private var importError: String?

    // Export sheet
    @State private var exportURL: URL?
    @State private var isShareSheetPresented: Bool = false

    // Import file picker
    @State private var isFileImporterPresented: Bool = false

    // Import error alert
    @State private var isImportErrorPresented: Bool = false

    @Environment(\.circuitContext) private var circuit

    var body: some View {
        NavigationStack {
            ZStack {
                // РЕДИЗАЙН specialist-editor (2026-06-13): специалистский контур —
                // нейтрально-холодный статичный холст `Spec.bg` (эталон #ECEEF2),
                // а не голый системный фон / kid-палитра. Поверх — едва заметный
                // coral-radial в hero-зоне.
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

                VStack(spacing: 0) {
                    summary
                    Divider().background(ColorTokens.Spec.line)
                    blockList
                    palette
                }
            }
            // 3.C v23: inline title на iPhone SE 320pt мог обрезаться рядом с
            // LyalyaMascotView blob; используем кастомный principal toolbar item
            // с явным lineLimit(1) + minimumScaleFactor, чтобы title не превратился
            // в "М..." в screenshot tour.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(String(localized: "program.editor.title"))
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Spec.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "program.editor.cancel"), action: onCancel)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    importExportMenu
                    Button(String(localized: "program.editor.save"), action: save)
                        .disabled(!isValid)
                }
            }
            .task { await bootstrap() }
            .environment(\.circuitContext, .specialist)
            .accessibilityIdentifier("ProgramEditorRoot")
            .safeAreaInset(edge: .bottom) {
                bottomBanner
            }
            // Export share sheet
            .sheet(isPresented: $isShareSheetPresented) {
                if let url = exportURL {
                    ProgramEditorShareSheet(items: [url])
                        .ignoresSafeArea()
                }
            }
            // Import file picker — accepts .happyspeech (custom) and .json
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.happySpeechProgram, .json],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            // Import error alert
            .alert(
                String(localized: "program_editor.import.error.title"),
                isPresented: $isImportErrorPresented,
                presenting: importError
            ) { _ in
                Button(String(localized: "action.ok"), role: .cancel) {}
            } message: { message in
                Text(message)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    // MARK: - Subviews

    private var summary: some View {
        HStack(spacing: SpacingTokens.small) {
            LyalyaMascotView(state: isValid ? .happy : .thinking, size: 48)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "program.editor.duration"))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.sp2) {
                    Text("\(totalMinutes) " + String(localized: "program.editor.minutes"))
                        .font(TypographyTokens.title(22))
                        .foregroundStyle(isValid ? ColorTokens.Spec.ink : ColorTokens.Semantic.error)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(String(
                        format: String(localized: "program.editor.stepsCount %lld"),
                        blocks.count
                    ))
                        .font(TypographyTokens.caption(12).weight(.semibold))
                        .foregroundStyle(ColorTokens.Spec.accent)
                        .padding(.horizontal, SpacingTokens.sp2)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(ColorTokens.Spec.accent.opacity(0.14))
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            Spacer(minLength: SpacingTokens.tiny)
            if !isValid {
                Text(String(localized: "program.editor.invalid"))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Semantic.error)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(SpacingTokens.medium)
    }

    /// Block list is always in `.active` edit mode so drag handles are visible
    /// without requiring an explicit EditButton tap.
    private var blockList: some View {
        List {
            if blocks.isEmpty {
                VStack(spacing: SpacingTokens.small) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .font(.system(size: 40))
                        .foregroundStyle(ColorTokens.Spec.accent.opacity(0.55))
                        .accessibilityHidden(true)
                    Text(String(localized: "program.editor.empty.title"))
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Spec.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "program.editor.empty.message"))
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Spec.inkMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, SpacingTokens.sp8)
                .listRowBackground(Color.clear)
                .accessibilityElement(children: .combine)
            }
            ForEach(blocks) { block in
                ProgramBlockRow(block: block)
                    .listRowBackground(ColorTokens.Spec.surface)
                    .listRowSeparatorTint(ColorTokens.Spec.line)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let id = blocks[index].id
                    Task { await interactor?.removeBlock(.init(blockId: id)) }
                }
            }
            .onMove { sources, target in
                // Capture the dragged block's ID before the local reorder
                guard let source = sources.first else { return }
                let id = blocks[source].id
                // Optimistic local reorder so the list stays responsive
                blocks.move(fromOffsets: sources, toOffset: target)
                Task { await interactor?.moveBlock(.init(blockId: id, targetIndex: target)) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        // Keep edit mode always active so drag handles are visible
        .environment(\.editMode, .constant(.active))
    }

    private var palette: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
            Text(String(localized: "program.editor.palette.hint"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
                .textCase(.uppercase)
                .padding(.horizontal, SpacingTokens.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SpacingTokens.small) {
                    ForEach(ProgramBlockType.allCases, id: \.rawValue) { type in
                        Button {
                            Task {
                                await interactor?.addBlock(.init(
                                    type: type,
                                    durationMinutes: defaultMinutes(for: type),
                                    targetSound: nil
                                ))
                            }
                        } label: {
                            HStack(spacing: SpacingTokens.sp1) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                    .accessibilityHidden(true)
                                Text(String(localized: String.LocalizationValue(type.titleKey)))
                                    .font(TypographyTokens.caption(13).weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }
                            .foregroundStyle(ColorTokens.Spec.accent)
                            .padding(.horizontal, SpacingTokens.medium)
                            .padding(.vertical, SpacingTokens.small)
                            .background(Capsule().fill(ColorTokens.Spec.accent.opacity(0.14)))
                            .overlay(
                                Capsule().stroke(ColorTokens.Spec.accent.opacity(0.30), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(localized: String.LocalizationValue(type.titleKey)))
                        .accessibilityHint(String(localized: "program.editor.palette.addHint"))
                    }
                }
                .padding(.horizontal, SpacingTokens.medium)
                .padding(.vertical, SpacingTokens.small)
            }
        }
        .padding(.top, SpacingTokens.tiny)
        .background(ColorTokens.Spec.surface)
        .overlay(alignment: .top) {
            Divider().background(ColorTokens.Spec.line)
        }
    }

    @ViewBuilder
    private var bottomBanner: some View {
        VStack(spacing: SpacingTokens.tiny) {
            if let confirmation {
                Label {
                    Text(confirmation)
                        .font(TypographyTokens.caption())
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .accessibilityHidden(true)
                }
                .foregroundStyle(ColorTokens.Semantic.success)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
            // Эталон specialist-editor: крупный коралловый CTA «Сохранить программу»
            // внизу экрана. Дублирует toolbar-Save, но это основное действие.
            HSButton(
                String(localized: "program.editor.saveProgram"),
                style: .primary,
                size: .large,
                icon: "square.and.arrow.down.fill"
            ) {
                save()
            }
            .disabled(!isValid)
            .opacity(isValid ? 1 : 0.5)
        }
        .padding(.horizontal, SpacingTokens.medium)
        .padding(.top, SpacingTokens.small)
        .padding(.bottom, SpacingTokens.tiny)
        .background(.ultraThinMaterial)
    }

    // MARK: - Import/Export menu

    private var importExportMenu: some View {
        Menu {
            Button {
                exportCurrentProgram()
            } label: {
                Label(
                    String(localized: "program_editor.menu.export"),
                    systemImage: "square.and.arrow.up"
                )
            }
            .accessibilityLabel(String(localized: "program_editor.menu.export"))
            .accessibilityHint(String(localized: "program_editor.menu.export.hint"))

            Button {
                isFileImporterPresented = true
            } label: {
                Label(
                    String(localized: "program_editor.menu.import"),
                    systemImage: "square.and.arrow.down"
                )
            }
            .accessibilityLabel(String(localized: "program_editor.menu.import"))
            .accessibilityHint(String(localized: "program_editor.menu.import.hint"))
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(ColorTokens.Spec.accent)
                .accessibilityLabel(String(localized: "program_editor.menu.label"))
        }
    }

    // MARK: - Actions

    private func exportCurrentProgram() {
        Task {
            await interactor?.exportTemplate(.init(
                childId: childId,
                blocks: blocks,
                notes: notes
            ))
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            Task { await interactor?.importTemplate(.init(fileURL: url)) }
        case let .failure(error):
            importError = error.localizedDescription
            isImportErrorPresented = true
        }
    }

    private func defaultMinutes(for type: ProgramBlockType) -> Int {
        switch type {
        case .warmup, .coolDown, .breakRest:                          return 1
        case .articulationGymnastics, .breathing, .phonemic:          return 3
        case .isolatedSound, .syllables, .minimalPairs:               return 4
        case .wordsInitial, .wordsMedial, .wordsFinal, .phrases,
             .narrativeQuest:                                         return 5
        }
    }

    private func save() {
        Task {
            await interactor?.saveProgram(.init(
                childId: childId, blocks: blocks, notes: notes
            ))
            if let program = interactor?.currentProgramSnapshot() {
                onSaved(program)
            }
        }
    }

    // MARK: - Wiring

    private func bootstrap() async {
        guard interactor == nil else { return }
        let presenterInstance = ProgramEditorPresenter()
        let interactorInstance = ProgramEditorInteractor()
        let routerInstance = ProgramEditorRouter()

        interactorInstance.presenter = presenterInstance
        let bridge = ProgramEditorDisplayBridge(
            onLoad: { vm in
                blocks = vm.blocks
                totalMinutes = vm.totalDurationMinutes
                isValid = vm.isValid
            },
            onUpdate: { newBlocks, newTotal in
                blocks = newBlocks
                totalMinutes = newTotal
                isValid = ProgramEditorPresenter.isValid(newBlocks)
            },
            onSave: { message in confirmation = message },
            onExport: { vm in
                exportURL = vm.fileURL
                isShareSheetPresented = true
            },
            onImport: { vm in
                blocks = vm.blocks
                totalMinutes = vm.totalDurationMinutes
                isValid = ProgramEditorPresenter.isValid(vm.blocks)
                confirmation = String(localized: "program_editor.import.success")
            },
            onImportFailure: { vm in
                importError = vm.errorMessage
                isImportErrorPresented = true
            }
        )
        presenterInstance.display = bridge
        self.displayBridge = bridge
        routerInstance.onSaved = onSaved
        routerInstance.onCancel = onCancel

        interactor = interactorInstance
        presenter = presenterInstance
        router = routerInstance

        await interactorInstance.loadProgram(.init(childId: childId))
    }
}

// MARK: - UTType extension

extension UTType {
    /// Custom UTType for HappySpeech program template files (.happyspeech).
    /// Declared in Info.plist `UTExportedTypeDeclarations`; resolved here with
    /// `importedAs` (the app consumes the type via the picker) and a
    /// `public.json` conformance fallback so the importer recognises the
    /// extension even before the launch-time type registration completes.
    static let happySpeechProgram = UTType(
        importedAs: "ru.happyspeech.program-template",
        conformingTo: .json
    )
}

// MARK: - Row

private struct ProgramBlockRow: View {
    let block: ProgramBlock
    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            // Иконка-плитка с тёплым coral-тинтом (эталон step-icon).
            ZStack {
                RoundedRectangle(cornerRadius: RadiusTokens.sm)
                    .fill(ColorTokens.Spec.accent.opacity(0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: symbol(for: block.type))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(ColorTokens.Spec.accent)
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: String.LocalizationValue(block.type.titleKey)))
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                if let sound = block.targetSound {
                    Text(String(localized: "program.editor.sound.\(sound)"))
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Spec.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            Spacer(minLength: SpacingTokens.tiny)
            Text("\(block.durationMinutes) " + String(localized: "program.editor.min"))
                .font(TypographyTokens.caption(12).weight(.bold))
                .foregroundStyle(ColorTokens.Spec.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, SpacingTokens.sp2)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(ColorTokens.Spec.accent.opacity(0.12))
                )
        }
        .padding(.vertical, SpacingTokens.sp1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var desc = String(localized: String.LocalizationValue(block.type.titleKey))
        if let sound = block.targetSound {
            desc += ", \(sound)"
        }
        desc += ", \(block.durationMinutes) " + String(localized: "program.editor.min")
        return desc
    }

    private func symbol(for type: ProgramBlockType) -> String {
        switch type {
        case .warmup:                return "sunrise.fill"
        case .articulationGymnastics: return "mouth"
        case .breathing:             return "wind"
        case .isolatedSound:         return "speaker.wave.2"
        case .syllables:             return "text.quote"
        case .wordsInitial, .wordsMedial, .wordsFinal: return "character.book.closed.fill"
        case .minimalPairs:          return "arrow.left.arrow.right"
        case .phrases:               return "quote.opening"
        case .narrativeQuest:        return "book.fill"
        case .phonemic:              return "ear"
        case .breakRest:             return "pause.circle.fill"
        case .coolDown:              return "moon.stars.fill"
        }
    }
}

// MARK: - Share Sheet

private struct ProgramEditorShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Bridge

@MainActor
private final class ProgramEditorDisplayBridge: ProgramEditorDisplayLogic {
    let onLoad: (ProgramEditorModels.LoadProgram.ViewModel) -> Void
    let onUpdate: ([ProgramBlock], Int) -> Void
    let onSave: (String) -> Void
    let onExport: (ProgramEditorModels.ExportTemplate.ViewModel) -> Void
    let onImport: (ProgramEditorModels.ImportTemplate.ViewModel) -> Void
    let onImportFailure: (ProgramEditorModels.ImportTemplate.FailureViewModel) -> Void

    init(
        onLoad: @escaping (ProgramEditorModels.LoadProgram.ViewModel) -> Void,
        onUpdate: @escaping ([ProgramBlock], Int) -> Void,
        onSave: @escaping (String) -> Void,
        onExport: @escaping (ProgramEditorModels.ExportTemplate.ViewModel) -> Void,
        onImport: @escaping (ProgramEditorModels.ImportTemplate.ViewModel) -> Void,
        onImportFailure: @escaping (ProgramEditorModels.ImportTemplate.FailureViewModel) -> Void
    ) {
        self.onLoad = onLoad
        self.onUpdate = onUpdate
        self.onSave = onSave
        self.onExport = onExport
        self.onImport = onImport
        self.onImportFailure = onImportFailure
    }

    func displayLoadProgram(_ vm: ProgramEditorModels.LoadProgram.ViewModel) { onLoad(vm) }
    func displayAddBlock(_ vm: ProgramEditorModels.AddBlock.ViewModel) { onUpdate(vm.blocks, vm.totalDurationMinutes) }
    func displayRemoveBlock(_ vm: ProgramEditorModels.RemoveBlock.ViewModel) { onUpdate(vm.blocks, vm.totalDurationMinutes) }
    func displayMoveBlock(_ vm: ProgramEditorModels.MoveBlock.ViewModel) { onUpdate(vm.blocks, vm.blocks.map(\.durationMinutes).reduce(0, +)) }
    func displaySaveProgram(_ vm: ProgramEditorModels.SaveProgram.ViewModel) { onSave(vm.confirmationMessage) }
    func displayValidation(_ vm: ProgramEditorModels.ValidateProgram.ViewModel) {}
    func displayValidationWarning(_ message: String) {}
    func displayAssignToChild(_ vm: ProgramEditorModels.AssignToChild.ViewModel) {}
    func displayExportTemplate(_ vm: ProgramEditorModels.ExportTemplate.ViewModel) { onExport(vm) }
    func displayImportTemplate(_ vm: ProgramEditorModels.ImportTemplate.ViewModel) { onImport(vm) }
    func displayImportTemplateFailure(_ vm: ProgramEditorModels.ImportTemplate.FailureViewModel) { onImportFailure(vm) }
}

// MARK: - Preview

#Preview {
    ProgramEditorView(
        childId: "preview-child",
        onSaved: { _ in },
        onCancel: {}
    )
}
