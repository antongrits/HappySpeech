import SwiftUI

// MARK: - ProgramEditorView
//
// Specialist-facing screen for building a child's daily program.
// Layout (top → bottom):
//   1. Header — child id, total minutes, save/cancel.
//   2. Block list — reorderable via drag, swipe-to-delete.
//   3. Block palette — tap to append a new block of given type.
//
// Uses the parent circuit palette (cooler neutral tones) since the specialist
// is not the child.

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

    @Environment(\.circuitContext) private var circuit

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                summary
                Divider()
                blockList
                palette
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
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "program.editor.cancel"), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "program.editor.save"), action: save)
                        .disabled(!isValid)
                }
            }
            .task { await bootstrap() }
            .environment(\.circuitContext, .specialist)
            .accessibilityIdentifier("ProgramEditorRoot")
            .safeAreaInset(edge: .bottom) {
                if let confirmation {
                    Text(confirmation)
                        .font(TypographyTokens.caption())
                        .foregroundStyle(ColorTokens.Parent.accent)
                        .padding(SpacingTokens.small)
                }
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
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text("\(totalMinutes) " + String(localized: "program.editor.minutes"))
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(isValid ? ColorTokens.Kid.ink : ColorTokens.Semantic.error)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
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

    private var blockList: some View {
        List {
            ForEach(blocks) { block in
                ProgramBlockRow(block: block)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let id = blocks[index].id
                    Task { await interactor?.removeBlock(.init(blockId: id)) }
                }
            }
            .onMove { sources, target in
                guard let source = sources.first else { return }
                let id = blocks[source].id
                Task { await interactor?.moveBlock(.init(blockId: id, targetIndex: target)) }
            }
        }
        .listStyle(.plain)
    }

    private var palette: some View {
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
                        Text(String(localized: String.LocalizationValue(type.titleKey)))
                            .font(TypographyTokens.caption(13))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .padding(.horizontal, SpacingTokens.medium)
                            .padding(.vertical, SpacingTokens.small)
                            .background(Capsule().fill(ColorTokens.Parent.surface))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: String.LocalizationValue(type.titleKey)))
                }
            }
            .padding(.horizontal, SpacingTokens.medium)
            .padding(.vertical, SpacingTokens.small)
        }
        .background(ColorTokens.Parent.bg)
    }

    // MARK: - Helpers

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
            onSave: { message in confirmation = message }
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

// MARK: - Row

private struct ProgramBlockRow: View {
    let block: ProgramBlock
    var body: some View {
        HStack {
            Image(systemName: symbol(for: block.type))
                .foregroundStyle(ColorTokens.Parent.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: String.LocalizationValue(block.type.titleKey)))
                    .font(TypographyTokens.body(15))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                if let sound = block.targetSound {
                    Text(String(localized: "program.editor.sound.\(sound)"))
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            Spacer(minLength: SpacingTokens.tiny)
            Text("\(block.durationMinutes) " + String(localized: "program.editor.min"))
                .font(TypographyTokens.mono(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
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

// MARK: - Bridge

@MainActor
private final class ProgramEditorDisplayBridge: ProgramEditorDisplayLogic {
    let onLoad: (ProgramEditorModels.LoadProgram.ViewModel) -> Void
    let onUpdate: ([ProgramBlock], Int) -> Void
    let onSave: (String) -> Void

    init(onLoad: @escaping (ProgramEditorModels.LoadProgram.ViewModel) -> Void,
         onUpdate: @escaping ([ProgramBlock], Int) -> Void,
         onSave: @escaping (String) -> Void) {
        self.onLoad = onLoad
        self.onUpdate = onUpdate
        self.onSave = onSave
    }

    func displayLoadProgram(_ vm: ProgramEditorModels.LoadProgram.ViewModel) { onLoad(vm) }
    func displayAddBlock(_ vm: ProgramEditorModels.AddBlock.ViewModel) { onUpdate(vm.blocks, vm.totalDurationMinutes) }
    func displayRemoveBlock(_ vm: ProgramEditorModels.RemoveBlock.ViewModel) { onUpdate(vm.blocks, vm.totalDurationMinutes) }
    func displayMoveBlock(_ vm: ProgramEditorModels.MoveBlock.ViewModel) { onUpdate(vm.blocks, vm.blocks.map(\.durationMinutes).reduce(0, +)) }
    func displaySaveProgram(_ vm: ProgramEditorModels.SaveProgram.ViewModel) { onSave(vm.confirmationMessage) }
    func displayValidation(_ vm: ProgramEditorModels.ValidateProgram.ViewModel) {}
    func displayValidationWarning(_ message: String) {}
    func displayAssignToChild(_ vm: ProgramEditorModels.AssignToChild.ViewModel) {}
}
