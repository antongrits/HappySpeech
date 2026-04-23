import Foundation

// MARK: - ScreeningPromptFactory
//
// Canonical 20-prompt set covering all four methodological blocks across the
// 5-most-problematic Russian phonetic groups: whistling (С), hissing (Ш),
// sonorants (Р, Л), velars (К). Expandable to 30 for deeper screening by
// adding pair-discrimination prompts.
//
// References:
//   - Fomicheva M.F. "Воспитание у детей правильного произношения"
//   - Коноваленко, "Логопедические упражнения"
// Documented in `HappySpeech/ResearchDocs/speech-methodology-full.md`.

enum ScreeningPromptFactory {

    // MARK: - Public factory

    /// Returns the canonical 20-prompt screening in the fixed order A→B→C→D.
    /// Child age may scale back the duration of the last breathing prompt.
    static func prompts(for childAge: Int) -> [ScreeningPrompt] {
        articulationBlock() + wordBlock() + minimalPairsBlock() + breathingBlock(age: childAge)
    }

    // MARK: - Blocks

    private static func articulationBlock() -> [ScreeningPrompt] {
        // 8 articulation imitations — one per sound group.
        [
            ScreeningPrompt(id: "art_s",  block: .articulationImitation, targetSound: "С",
                            stimulus: "улыбнись и подуй на язычок",
                            imageAsset: "articulation_s", referenceAudio: "ref_art_s",
                            acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "art_z",  block: .articulationImitation, targetSound: "З",
                            stimulus: "тот же звук, но звонкий",
                            imageAsset: "articulation_z", referenceAudio: "ref_art_z",
                            acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "art_sh", block: .articulationImitation, targetSound: "Ш",
                            stimulus: "язык наверх, «чашечка»",
                            imageAsset: "articulation_sh", referenceAudio: "ref_art_sh",
                            acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "art_zh", block: .articulationImitation, targetSound: "Ж",
                            stimulus: "как «Ш», но с голосом",
                            imageAsset: "articulation_zh", referenceAudio: "ref_art_zh",
                            acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "art_r",  block: .articulationImitation, targetSound: "Р",
                            stimulus: "вибрируй язычком у нёба",
                            imageAsset: "articulation_r", referenceAudio: "ref_art_r",
                            acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "art_l",  block: .articulationImitation, targetSound: "Л",
                            stimulus: "язык к зубам, гудим",
                            imageAsset: "articulation_l", referenceAudio: "ref_art_l",
                            acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "art_k",  block: .articulationImitation, targetSound: "К",
                            stimulus: "язык к нёбу сзади, кашляем",
                            imageAsset: "articulation_k", referenceAudio: "ref_art_k",
                            acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "art_g",  block: .articulationImitation, targetSound: "Г",
                            stimulus: "как «К», но с голосом",
                            imageAsset: "articulation_g", referenceAudio: "ref_art_g",
                            acceptableHoldSeconds: nil),
        ]
    }

    private static func wordBlock() -> [ScreeningPrompt] {
        // 8 words — two per key sound with different position.
        [
            ScreeningPrompt(id: "word_s_init",  block: .wordPronunciation, targetSound: "С",
                            stimulus: "санки", imageAsset: "word_sled", referenceAudio: "ref_sanki", acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "word_s_med",   block: .wordPronunciation, targetSound: "С",
                            stimulus: "косы", imageAsset: "word_scythe", referenceAudio: "ref_kosy", acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "word_sh_init", block: .wordPronunciation, targetSound: "Ш",
                            stimulus: "шапка", imageAsset: "word_hat", referenceAudio: "ref_shapka", acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "word_sh_med",  block: .wordPronunciation, targetSound: "Ш",
                            stimulus: "кошка", imageAsset: "word_cat", referenceAudio: "ref_koshka", acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "word_r_init",  block: .wordPronunciation, targetSound: "Р",
                            stimulus: "рыба", imageAsset: "word_fish", referenceAudio: "ref_ryba", acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "word_r_med",   block: .wordPronunciation, targetSound: "Р",
                            stimulus: "корова", imageAsset: "word_cow", referenceAudio: "ref_korova", acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "word_l_init",  block: .wordPronunciation, targetSound: "Л",
                            stimulus: "луна", imageAsset: "word_moon", referenceAudio: "ref_luna", acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "word_l_final", block: .wordPronunciation, targetSound: "Л",
                            stimulus: "стол", imageAsset: "word_table", referenceAudio: "ref_stol", acceptableHoldSeconds: nil),
        ]
    }

    private static func minimalPairsBlock() -> [ScreeningPrompt] {
        // 3 minimal-pair discrimination prompts.
        [
            ScreeningPrompt(id: "pair_s_sh",  block: .minimalPairs, targetSound: "С/Ш",
                            stimulus: "миска — мишка", imageAsset: "pair_bowl_bear",
                            referenceAudio: "ref_miska_mishka", acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "pair_r_l",   block: .minimalPairs, targetSound: "Р/Л",
                            stimulus: "рак — лак", imageAsset: "pair_crab_lacquer",
                            referenceAudio: "ref_rak_lak", acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "pair_k_g",   block: .minimalPairs, targetSound: "К/Г",
                            stimulus: "кот — год", imageAsset: "pair_cat_year",
                            referenceAudio: "ref_kot_god", acceptableHoldSeconds: nil),
        ]
    }

    private static func breathingBlock(age: Int) -> [ScreeningPrompt] {
        // 1 breathing prompt, duration scales with age (5y → 5s … 8y → 12s).
        let hold = max(5, min(12, age + 2))
        return [
            ScreeningPrompt(id: "breathing_hold", block: .breathingDuration, targetSound: "—",
                            stimulus: "дуй ровно на шарик \(hold) секунд",
                            imageAsset: "breathing_balloon", referenceAudio: nil,
                            acceptableHoldSeconds: Double(hold)),
        ]
    }
}
