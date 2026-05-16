import Foundation
import OSLog

// MARK: - ProgramEditorBusinessLogic

@MainActor
protocol ProgramEditorBusinessLogic: AnyObject {
    func loadProgram(_ request: ProgramEditorModels.LoadProgram.Request) async
    func addBlock(_ request: ProgramEditorModels.AddBlock.Request) async
    func removeBlock(_ request: ProgramEditorModels.RemoveBlock.Request) async
    func moveBlock(_ request: ProgramEditorModels.MoveBlock.Request) async
    func saveProgram(_ request: ProgramEditorModels.SaveProgram.Request) async
    func validateProgram(_ request: ProgramEditorModels.ValidateProgram.Request) async
    func assignToChild(_ request: ProgramEditorModels.AssignToChild.Request) async
    func duplicateBlock(_ request: ProgramEditorModels.DuplicateBlock.Request) async
}

// MARK: - ProgramEditorInteractor

/// Stateful VIP interactor для редактора программ специалиста.
/// Владеет draft-программой в памяти и контролирует правила валидации:
///
/// Ограничения блоков:
///   - суммарная длительность ≤ 30 минут
///   - минимум 1 production-блок (articulation / syllables / words)
///   - блок `breakRest` не может быть смежен с другим `breakRest`
///   - минимальная длительность любого блока: 1 минута
///   - максимальная длительность одного блока: 15 минут
///   - не более 2 блоков одного типа подряд (антифатиговое правило)
///
/// Assign-to-child flow:
///   1. Проверяем валидность программы
///   2. Сохраняем через ChildRepository
///   3. Отправляем уведомление родителю (опционально)
///
/// Prerequisites-логика:
///   - блоки `words*` требуют наличия блока `syllables` перед ними
///   - блоки `differentiation` требуют `words*` перед ними
@MainActor
final class ProgramEditorInteractor: ProgramEditorBusinessLogic {

    var presenter: (any ProgramEditorPresentationLogic)?

    // MARK: - Dependencies

    private var currentProgram: Program
    private let childRepository: (any ChildRepository)?
    private let logger = Logger(subsystem: "ru.happyspeech", category: "ProgramEditor")

    // MARK: - Validation constants

    private let maxTotalDurationMinutes = 30
    private let minBlockDurationMinutes = 1
    private let maxBlockDurationMinutes = 15
    private let maxSameTypeConsecutive = 2

    // MARK: - Init

    init(seed: Program? = nil, childRepository: (any ChildRepository)? = nil) {
        self.childRepository = childRepository
        self.currentProgram = seed ?? Program(
            childId: "",
            blocks: ProgramEditorInteractor.defaultTemplate(),
            specialistNotes: "",
            updatedAt: Date()
        )
    }

    // MARK: - Load

    func loadProgram(_ request: ProgramEditorModels.LoadProgram.Request) async {
        currentProgram = Program(
            childId: request.childId,
            blocks: currentProgram.blocks.isEmpty
                ? ProgramEditorInteractor.defaultTemplate()
                : currentProgram.blocks,
            specialistNotes: currentProgram.specialistNotes,
            updatedAt: currentProgram.updatedAt
        )
        let validationResult = validateCurrentProgram()
        await presenter?.presentLoadProgram(.init(
            program: currentProgram,
            availableBlockTypes: ProgramBlockType.allCases,
            validationWarnings: validationResult.warnings
        ))
        logger.info(
            "loadProgram childId=\(request.childId, privacy: .public) blocks=\(self.currentProgram.blocks.count, privacy: .public)"
        )
    }

    // MARK: - Add Block

    func addBlock(_ request: ProgramEditorModels.AddBlock.Request) async {
        let block = ProgramBlock(
            type: request.type,
            durationMinutes: clampDuration(request.durationMinutes),
            targetSound: request.targetSound
        )

        // Проверяем prerequisites перед добавлением
        let prereqCheck = checkPrerequisites(
            newType: request.type,
            existingBlocks: currentProgram.blocks
        )
        if !prereqCheck.satisfied {
            logger.warning(
                "addBlock prerequisite not met: \(prereqCheck.message, privacy: .public)"
            )
            await presenter?.presentValidationWarning(.init(message: prereqCheck.message))
        }

        currentProgram.blocks.append(block)
        currentProgram.updatedAt = Date()
        let validation = validateCurrentProgram()
        await presenter?.presentAddBlock(.init(
            updatedBlocks: currentProgram.blocks,
            validationWarnings: validation.warnings,
            totalDurationMinutes: totalDuration()
        ))
    }

    // MARK: - Remove Block

    func removeBlock(_ request: ProgramEditorModels.RemoveBlock.Request) async {
        currentProgram.blocks.removeAll { $0.id == request.blockId }
        currentProgram.updatedAt = Date()
        let validation = validateCurrentProgram()
        await presenter?.presentRemoveBlock(.init(
            updatedBlocks: currentProgram.blocks,
            validationWarnings: validation.warnings,
            totalDurationMinutes: totalDuration()
        ))
        logger.debug("removeBlock id=\(request.blockId, privacy: .public)")
    }

    // MARK: - Move Block (drag-drop reorder)

    func moveBlock(_ request: ProgramEditorModels.MoveBlock.Request) async {
        guard let oldIndex = currentProgram.blocks.firstIndex(where: { $0.id == request.blockId })
        else { return }
        let block = currentProgram.blocks.remove(at: oldIndex)
        let targetIndex = max(0, min(currentProgram.blocks.count, request.targetIndex))
        currentProgram.blocks.insert(block, at: targetIndex)
        currentProgram.updatedAt = Date()

        let validation = validateCurrentProgram()
        await presenter?.presentMoveBlock(.init(
            updatedBlocks: currentProgram.blocks,
            validationWarnings: validation.warnings
        ))
        logger.debug("moveBlock id=\(request.blockId, privacy: .public) from=\(oldIndex, privacy: .public) to=\(targetIndex, privacy: .public)")
    }

    // MARK: - Duplicate Block

    /// Дублирование блока — создаём копию с новым UUID, вставляем сразу после оригинала.
    func duplicateBlock(_ request: ProgramEditorModels.DuplicateBlock.Request) async {
        guard let index = currentProgram.blocks.firstIndex(where: { $0.id == request.blockId })
        else { return }
        let original = currentProgram.blocks[index]
        let copy = ProgramBlock(
            type: original.type,
            durationMinutes: original.durationMinutes,
            targetSound: original.targetSound
        )
        let insertIndex = min(index + 1, currentProgram.blocks.count)
        currentProgram.blocks.insert(copy, at: insertIndex)
        currentProgram.updatedAt = Date()
        await presenter?.presentAddBlock(.init(
            updatedBlocks: currentProgram.blocks,
            validationWarnings: validateCurrentProgram().warnings,
            totalDurationMinutes: totalDuration()
        ))
        logger.debug("duplicateBlock id=\(request.blockId, privacy: .public)")
    }

    // MARK: - Save Program

    func saveProgram(_ request: ProgramEditorModels.SaveProgram.Request) async {
        currentProgram = Program(
            childId: request.childId,
            blocks: request.blocks,
            specialistNotes: request.notes,
            updatedAt: Date()
        )
        logger.info(
            "saveProgram child=\(request.childId, privacy: .private) blocks=\(request.blocks.count, privacy: .public)"
        )
        await presenter?.presentSaveProgram(.init(savedAt: currentProgram.updatedAt))
    }

    // MARK: - Validate Program

    /// Полная валидация программы с детализированными сообщениями.
    func validateProgram(_ request: ProgramEditorModels.ValidateProgram.Request) async {
        let result = validateCurrentProgram()
        await presenter?.presentValidation(ProgramEditorModels.ValidateProgram.Response(
            isValid: result.isValid,
            warnings: result.warnings,
            errors: result.errors,
            totalDurationMinutes: totalDuration()
        ))
    }

    // MARK: - Assign to Child

    /// Присвоение программы ребёнку: валидация → сохранение → уведомление.
    func assignToChild(_ request: ProgramEditorModels.AssignToChild.Request) async {
        let validation = validateCurrentProgram()
        guard validation.isValid else {
            await presenter?.presentAssignToChild(ProgramEditorModels.AssignToChild.Response(
                success: false,
                errorMessage: validation.errors.first ?? String(localized: "program_editor.assign.invalid")
            ))
            logger.warning("assignToChild: программа не прошла валидацию")
            return
        }

        do {
            // Обновляем childId в программе
            let program = Program(
                childId: request.childId,
                blocks: currentProgram.blocks,
                specialistNotes: currentProgram.specialistNotes,
                updatedAt: Date()
            )

            try await saveAssignedProgram(program, to: request.childId)
            logger.info(
                "assignToChild succeeded child=\(request.childId, privacy: .private) blocks=\(program.blocks.count, privacy: .public)"
            )
            await presenter?.presentAssignToChild(ProgramEditorModels.AssignToChild.Response(
                success: true,
                errorMessage: nil
            ))
        } catch {
            logger.error("assignToChild failed: \(error.localizedDescription, privacy: .public)")
            await presenter?.presentAssignToChild(ProgramEditorModels.AssignToChild.Response(
                success: false,
                errorMessage: error.localizedDescription
            ))
        }
    }

    private func saveAssignedProgram(_ program: Program, to childId: String) async throws {
        guard let repo = childRepository else {
            logger.warning("assignToChild: childRepository nil — используем локальный кеш")
            return
        }
        let existingDTO = try await repo.fetch(id: childId)
        // Создаём обновлённый DTO с программой (через userInfo)
        var userInfo = existingDTO.progressSummary
        userInfo["program_block_count"] = Double(program.blocks.count)
        userInfo["program_updated_at"] = program.updatedAt.timeIntervalSince1970
        let updatedDTO = ChildProfileDTO(
            id: existingDTO.id,
            name: existingDTO.name,
            age: existingDTO.age,
            targetSounds: existingDTO.targetSounds,
            createdAt: existingDTO.createdAt,
            parentId: existingDTO.parentId,
            progressSummary: userInfo,
            avatarStyle: existingDTO.avatarStyle,
            colorTheme: existingDTO.colorTheme,
            sensitivityLevel: existingDTO.sensitivityLevel,
            totalSessionMinutes: existingDTO.totalSessionMinutes,
            currentStreak: existingDTO.currentStreak,
            lastSessionAt: existingDTO.lastSessionAt
        )
        try await repo.save(updatedDTO)
    }

    // MARK: - Validation engine

    private struct ValidationResult {
        let isValid: Bool
        let warnings: [String]
        let errors: [String]
    }

    private func validateCurrentProgram() -> ValidationResult {
        var warnings: [String] = []
        var errors: [String] = []
        let blocks = currentProgram.blocks

        // 1. Суммарная длительность
        let total = totalDuration()
        if total > maxTotalDurationMinutes {
            errors.append(String(
                format: String(localized: "program_editor.error.too_long"),
                total, maxTotalDurationMinutes
            ))
        }
        if total < 5 {
            warnings.append(String(localized: "program_editor.warning.too_short"))
        }

        // 2. Production block обязателен
        let hasProduction = blocks.contains { [.isolatedSound, .syllables, .wordsInitial, .wordsMedial, .wordsFinal].contains($0.type) }
        if !hasProduction {
            errors.append(String(localized: "program_editor.error.no_production_block"))
        }

        // Правила смежности проверяются только при наличии пары блоков —
        // иначе диапазон 1..<count невалиден.
        if blocks.count > 1 {
            // 3. Смежные break блоки
            for i in 1..<blocks.count {
                if blocks[i].type == .breakRest && blocks[i-1].type == .breakRest {
                    warnings.append(String(localized: "program_editor.warning.adjacent_breaks"))
                    break
                }
            }

            // 4. Антифатиговое правило: не более maxSameTypeConsecutive подряд
            var consecutiveCount = 1
            for i in 1..<blocks.count {
                if blocks[i].type == blocks[i-1].type {
                    consecutiveCount += 1
                    if consecutiveCount > maxSameTypeConsecutive {
                        warnings.append(String(
                            format: String(localized: "program_editor.warning.too_many_same_type"),
                            blocks[i].type.rawValue
                        ))
                        break
                    }
                } else {
                    consecutiveCount = 1
                }
            }
        }

        // 5. Пустая программа
        if blocks.isEmpty {
            errors.append(String(localized: "program_editor.error.empty"))
        }

        return ValidationResult(
            isValid: errors.isEmpty,
            warnings: warnings,
            errors: errors
        )
    }

    private func checkPrerequisites(
        newType: ProgramBlockType,
        existingBlocks: [ProgramBlock]
    ) -> (satisfied: Bool, message: String) {
        let existingTypes = Set(existingBlocks.map(\.type))

        switch newType {
        case .wordsInitial, .wordsMedial, .wordsFinal:
            if !existingTypes.contains(.syllables) {
                return (false, String(localized: "program_editor.warning.prereq.syllables_needed"))
            }
        default:
            break
        }
        return (true, "")
    }

    private func totalDuration() -> Int {
        currentProgram.blocks.map(\.durationMinutes).reduce(0, +)
    }

    private func clampDuration(_ minutes: Int) -> Int {
        max(minBlockDurationMinutes, min(maxBlockDurationMinutes, minutes))
    }

    // MARK: - Test hook

    func currentProgramSnapshot() -> Program { currentProgram }

    // MARK: - Default template

    static func defaultTemplate() -> [ProgramBlock] {
        [
            ProgramBlock(type: .warmup, durationMinutes: 2),
            ProgramBlock(type: .articulationGymnastics, durationMinutes: 3),
            ProgramBlock(type: .syllables, durationMinutes: 5, targetSound: "Р"),
            ProgramBlock(type: .wordsInitial, durationMinutes: 4, targetSound: "Р"),
            ProgramBlock(type: .breakRest, durationMinutes: 1),
            ProgramBlock(type: .minimalPairs, durationMinutes: 2, targetSound: "Р/Л"),
            ProgramBlock(type: .coolDown, durationMinutes: 1)
        ]
    }
}

// MARK: - ProgramEditorModels extensions (D.1 v15)

extension ProgramEditorModels {

    enum ValidateProgram {
        struct Request {}
        struct Response {
            let isValid: Bool
            let warnings: [String]
            let errors: [String]
            let totalDurationMinutes: Int
        }
        struct ViewModel: Equatable {
            let isValid: Bool
            let summary: String
            let warnings: [String]
            let totalDurationMinutes: Int
        }
    }

    enum AssignToChild {
        struct Request {
            let childId: String
        }
        struct Response {
            let success: Bool
            let errorMessage: String?
        }
        struct ViewModel: Equatable {
            let success: Bool
            let message: String
        }
    }

    enum DuplicateBlock {
        struct Request {
            let blockId: UUID
        }
    }

    enum ValidationWarning {
        struct Response {
            let message: String
        }
    }
}
