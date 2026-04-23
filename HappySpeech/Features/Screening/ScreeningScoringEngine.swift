import Foundation

// MARK: - ScreeningScoringEngine
//
// Pure aggregation: turns 20 per-prompt scores into `ScreeningOutcome`.
// Deterministic and stateless so it can be unit-tested in isolation.
//
// Verdict thresholds (calibrated against Фомичёва age norms):
//   average score >= 0.80  →  .normal
//   average score >= 0.55  →  .monitor
//   otherwise              →  .intervention
//
// Session duration recommendation:
//   5 years → 8 min
//   6 years → 10 min
//   7 years → 12 min
//   8 years → 15 min
// + 2 minutes per intervention-flagged sound (cap at 20).

enum ScreeningScoringEngine {

    /// Groups per-prompt scores by `targetSound` and averages to produce a per-sound
    /// verdict; derives priority targets & session duration.
    static func evaluate(
        childId: String,
        childAge: Int,
        scores: [String: Float],                 // promptId → score
        prompts: [ScreeningPrompt],
        now: Date = Date()
    ) -> ScreeningOutcome {

        // 1. Aggregate per-sound averages (excluding minimal-pairs — they're
        //    discrimination, not production — and breathing which has its own
        //    scoring path).
        var perSound: [String: [Float]] = [:]
        var perSoundPromptExample: [String: String] = [:]
        for prompt in prompts {
            guard prompt.block == .articulationImitation || prompt.block == .wordPronunciation
            else { continue }
            let score = scores[prompt.id] ?? 0
            perSound[prompt.targetSound, default: []].append(score)
            if perSoundPromptExample[prompt.targetSound] == nil {
                perSoundPromptExample[prompt.targetSound] = prompt.stimulus
            }
        }

        var verdicts: [String: SoundVerdict] = [:]
        var priorities: [(sound: String, avg: Float)] = []
        for (sound, soundScores) in perSound {
            let avg = soundScores.reduce(0, +) / Float(soundScores.count)
            let verdict = Self.verdict(for: avg)
            verdicts[sound] = verdict
            if verdict == .intervention {
                priorities.append((sound, avg))
            }
        }

        // 2. Sort priorities: lowest avg first (most severe → highest priority).
        let priorityTargets = priorities
            .sorted { $0.avg < $1.avg }
            .map(\.sound)

        // 3. Recommended session length.
        let baseMinutes: Int
        switch childAge {
        case ..<6:          baseMinutes = 8
        case 6:             baseMinutes = 10
        case 7:             baseMinutes = 12
        default:            baseMinutes = 15
        }
        let interventionCount = priorityTargets.count
        let totalMinutes = min(20, baseMinutes + 2 * interventionCount)

        // 4. Suggest starting stage per intervention sound — conservative start
        //    if discrimination (minimal-pair) also failed, kid should begin at
        //    the earliest production stage (`isolated`), else `syllable`.
        let pairScoresByTargets = Dictionary(
            uniqueKeysWithValues: prompts
                .filter { $0.block == .minimalPairs }
                .map { ($0.targetSound, scores[$0.id] ?? 0) }
        )
        var initialStage: [String: String] = [:]
        for sound in priorityTargets {
            let discrimFailed = pairScoresByTargets.contains { pair, score in
                pair.split(separator: "/").contains(Substring(sound)) && score < 0.6
            }
            initialStage[sound] = discrimFailed ? "isolated" : "syllable"
        }

        return ScreeningOutcome(
            childId: childId,
            completedAt: now,
            perSound: verdicts,
            priorityTargetSounds: priorityTargets,
            recommendedSessionDurationSec: totalMinutes * 60,
            initialStagePerSound: initialStage
        )
    }

    // MARK: - Private

    private static func verdict(for averageScore: Float) -> SoundVerdict {
        switch averageScore {
        case 0.80...:     return .normal
        case 0.55..<0.80: return .monitor
        default:          return .intervention
        }
    }
}
