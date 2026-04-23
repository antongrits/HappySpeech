import Foundation

// MARK: - ProgramEditorModels
//
// VIP models for the specialist's "Daily program" editor. A program is a
// composable list of `ProgramBlock`s that the adaptive planner uses as a
// hard constraint when building the child's daily route.
//
// Example program:
//   [warmup 2 min → articulation «Р» syllables 5 min → break 1 min →
//    words initial 4 min → minimal pair R/L 2 min → cool-down 1 min]
//
// Blocks are methodologically typed (`ProgramBlockType`) so the planner can
// diversify durations and templates while the specialist keeps authority.

enum ProgramEditorModels {

    // MARK: LoadProgram

    enum LoadProgram {
        struct Request { let childId: String }
        struct Response {
            let program: Program
            let availableBlockTypes: [ProgramBlockType]
        }
        struct ViewModel: Equatable {
            let blocks: [ProgramBlock]
            let totalDurationMinutes: Int
            let isValid: Bool
        }
    }

    // MARK: AddBlock

    enum AddBlock {
        struct Request {
            let type: ProgramBlockType
            let durationMinutes: Int
            let targetSound: String?
        }
        struct Response { let updatedBlocks: [ProgramBlock] }
        struct ViewModel: Equatable {
            let blocks: [ProgramBlock]
            let totalDurationMinutes: Int
        }
    }

    // MARK: RemoveBlock

    enum RemoveBlock {
        struct Request { let blockId: UUID }
        struct Response { let updatedBlocks: [ProgramBlock] }
        struct ViewModel: Equatable {
            let blocks: [ProgramBlock]
            let totalDurationMinutes: Int
        }
    }

    // MARK: MoveBlock

    enum MoveBlock {
        struct Request { let blockId: UUID; let targetIndex: Int }
        struct Response { let updatedBlocks: [ProgramBlock] }
        struct ViewModel: Equatable {
            let blocks: [ProgramBlock]
        }
    }

    // MARK: SaveProgram

    enum SaveProgram {
        struct Request { let childId: String; let blocks: [ProgramBlock]; let notes: String }
        struct Response { let savedAt: Date }
        struct ViewModel: Equatable {
            let confirmationMessage: String
        }
    }
}

// MARK: - Program / Block

struct Program: Sendable, Codable, Equatable {
    let childId: String
    var blocks: [ProgramBlock]
    var specialistNotes: String
    var updatedAt: Date
}

struct ProgramBlock: Identifiable, Sendable, Codable, Equatable, Hashable {
    let id: UUID
    let type: ProgramBlockType
    var durationMinutes: Int
    var targetSound: String?

    init(id: UUID = UUID(), type: ProgramBlockType, durationMinutes: Int, targetSound: String? = nil) {
        self.id = id
        self.type = type
        self.durationMinutes = durationMinutes
        self.targetSound = targetSound
    }
}

enum ProgramBlockType: String, Sendable, Codable, CaseIterable {
    case warmup
    case articulationGymnastics
    case breathing
    case isolatedSound
    case syllables
    case wordsInitial
    case wordsMedial
    case wordsFinal
    case minimalPairs
    case phrases
    case narrativeQuest
    case phonemic
    case breakRest
    case coolDown

    /// Локализованное название типа (читается специалистом).
    var titleKey: String { "program.block.\(self.rawValue)" }
}
