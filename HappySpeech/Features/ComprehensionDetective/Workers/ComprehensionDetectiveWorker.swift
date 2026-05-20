import Foundation

// MARK: - ComprehensionDetectiveWorkerProtocol

@MainActor
public protocol ComprehensionDetectiveWorkerProtocol: AnyObject {
    func nextItem(for tier: GrammarTier, exclude playedIds: Set<String>) -> DetectiveItem?
    func availableTiers() -> [GrammarTier]
    func count(for tier: GrammarTier) -> Int
    func shuffle(_ pictures: [DetectivePicture]) -> [DetectivePicture]
    func voiceInstruction(_ text: String) async
}

// MARK: - ComprehensionDetectiveWorker (Clean Swift: Worker)

@MainActor
final class ComprehensionDetectiveWorker: ComprehensionDetectiveWorkerProtocol {

    private let randomSource: () -> Double

    init(randomSource: @escaping () -> Double = { Double.random(in: 0..<1) }) {
        self.randomSource = randomSource
    }

    func nextItem(for tier: GrammarTier, exclude playedIds: Set<String>) -> DetectiveItem? {
        let pool = ComprehensionDetectiveCorpus.items(for: tier)
        let remaining = pool.filter { !playedIds.contains($0.id) }
        if let pick = remaining.randomElement() { return pick }
        return pool.randomElement()
    }

    func availableTiers() -> [GrammarTier] {
        ComprehensionDetectiveCorpus.availableTiers
    }

    func count(for tier: GrammarTier) -> Int {
        ComprehensionDetectiveCorpus.items(for: tier).count
    }

    func shuffle(_ pictures: [DetectivePicture]) -> [DetectivePicture] {
        var array = pictures
        guard array.count > 1 else { return array }
        for index in stride(from: array.count - 1, through: 1, by: -1) {
            let randIndex = Int(randomSource() * Double(index + 1))
            let clamped = max(0, min(index, randIndex))
            array.swapAt(index, clamped)
        }
        return array
    }

    func voiceInstruction(_ text: String) async {
        await LessonVoiceWorker.shared.speak(
            text,
            lessonType: "comprehension-detective",
            rate: 0.95,
            enableSystemTTSFallback: true
        )
    }
}
