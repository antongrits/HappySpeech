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

    /// Returns a focused 10-sound screening set — one word per phoneme target.
    /// Used in the deep VIP flow (S12-007 / Plan v14 Block A.7).
    ///
    /// Phonemes: С, Ш, З, Ж, Р, Л, Ч, Щ, Ц, К — the 10 most clinically
    /// significant sounds in Russian for ages 5–8.
    ///
    /// Adaptive stop rule: if 2 consecutive scores < 0.40 → interrupt.
    static func tenSoundPrompts(for childAge: Int) -> [ScreeningPrompt] {
        [
            ScreeningPrompt(
                id: "ten_s",
                block: .wordPronunciation,
                targetSound: "С",
                stimulus: "собака",
                imageAsset: "word_dog",
                referenceAudio: "ref_sobaka",
                acceptableHoldSeconds: nil
            ),
            ScreeningPrompt(
                id: "ten_sh",
                block: .wordPronunciation,
                targetSound: "Ш",
                stimulus: "шапка",
                imageAsset: nil,
                referenceAudio: "ref_shapka",
                acceptableHoldSeconds: nil
            ),
            ScreeningPrompt(
                id: "ten_z",
                block: .wordPronunciation,
                targetSound: "З",
                stimulus: "зайка",
                imageAsset: "word_hare",
                referenceAudio: "ref_zayka",
                acceptableHoldSeconds: nil
            ),
            ScreeningPrompt(
                id: "ten_zh",
                block: .wordPronunciation,
                targetSound: "Ж",
                stimulus: "жираф",
                imageAsset: nil,
                referenceAudio: "ref_zhiraf",
                acceptableHoldSeconds: nil
            ),
            ScreeningPrompt(
                id: "ten_r",
                block: .wordPronunciation,
                targetSound: "Р",
                stimulus: "рыба",
                imageAsset: "word_fish",
                referenceAudio: "ref_ryba",
                acceptableHoldSeconds: nil
            ),
            ScreeningPrompt(
                id: "ten_l",
                block: .wordPronunciation,
                targetSound: "Л",
                stimulus: "луна",
                imageAsset: "word_moon",
                referenceAudio: "ref_luna",
                acceptableHoldSeconds: nil
            ),
            ScreeningPrompt(
                id: "ten_ch",
                block: .wordPronunciation,
                targetSound: "Ч",
                stimulus: "чашка",
                imageAsset: "word_cup",
                referenceAudio: "ref_chashka",
                acceptableHoldSeconds: nil
            ),
            ScreeningPrompt(
                id: "ten_sch",
                block: .wordPronunciation,
                targetSound: "Щ",
                stimulus: "щётка",
                imageAsset: nil,
                referenceAudio: "ref_shjotka",
                acceptableHoldSeconds: nil
            ),
            ScreeningPrompt(
                id: "ten_ts",
                block: .wordPronunciation,
                targetSound: "Ц",
                stimulus: "цапля",
                imageAsset: "word_bird",
                referenceAudio: "ref_tsaplya",
                acceptableHoldSeconds: nil
            ),
            ScreeningPrompt(
                id: "ten_k",
                block: .wordPronunciation,
                targetSound: "К",
                stimulus: "кот",
                imageAsset: "word_cat",
                referenceAudio: "ref_kot",
                acceptableHoldSeconds: nil
            )
        ]
    }

    // MARK: - Blocks

    private static func articulationBlock() -> [ScreeningPrompt] {
        // 8 articulation imitations — one per sound group.
        [
            ScreeningPrompt(id: "art_s", block: .articulationImitation, targetSound: "С",
                            stimulus: "улыбнись и подуй на язычок",
                            imageAsset: nil, referenceAudio: "ref_art_s",
                            acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "art_z", block: .articulationImitation, targetSound: "З",
                            stimulus: "тот же звук, но звонкий",
                            imageAsset: nil, referenceAudio: "ref_art_z",
                            acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "art_sh", block: .articulationImitation, targetSound: "Ш",
                            stimulus: "язык наверх, «чашечка»",
                            imageAsset: nil, referenceAudio: "ref_art_sh",
                            acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "art_zh", block: .articulationImitation, targetSound: "Ж",
                            stimulus: "как «Ш», но с голосом",
                            imageAsset: nil, referenceAudio: "ref_art_zh",
                            acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "art_r", block: .articulationImitation, targetSound: "Р",
                            stimulus: "вибрируй язычком у нёба",
                            imageAsset: nil, referenceAudio: "ref_art_r",
                            acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "art_l", block: .articulationImitation, targetSound: "Л",
                            stimulus: "язык к зубам, гудим",
                            imageAsset: nil, referenceAudio: "ref_art_l",
                            acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "art_k", block: .articulationImitation, targetSound: "К",
                            stimulus: "язык к нёбу сзади, кашляем",
                            imageAsset: nil, referenceAudio: "ref_art_k",
                            acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "art_g", block: .articulationImitation, targetSound: "Г",
                            stimulus: "как «К», но с голосом",
                            imageAsset: nil, referenceAudio: "ref_art_g",
                            acceptableHoldSeconds: nil)
        ]
    }

    private static func wordBlock() -> [ScreeningPrompt] {
        // 8 words — two per key sound with different position.
        [
            ScreeningPrompt(id: "word_s_init", block: .wordPronunciation, targetSound: "С",
                            stimulus: "санки", imageAsset: nil, referenceAudio: "ref_sanki", acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "word_s_med", block: .wordPronunciation, targetSound: "С",
                            stimulus: "косы", imageAsset: nil, referenceAudio: "ref_kosy", acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "word_sh_init", block: .wordPronunciation, targetSound: "Ш",
                            stimulus: "шапка", imageAsset: nil, referenceAudio: "ref_shapka", acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "word_sh_med", block: .wordPronunciation, targetSound: "Ш",
                            stimulus: "кошка", imageAsset: "word_cat", referenceAudio: "ref_koshka", acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "word_r_init", block: .wordPronunciation, targetSound: "Р",
                            stimulus: "рыба", imageAsset: "word_fish", referenceAudio: "ref_ryba", acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "word_r_med", block: .wordPronunciation, targetSound: "Р",
                            stimulus: "корова", imageAsset: "word_cow", referenceAudio: "ref_korova", acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "word_l_init", block: .wordPronunciation, targetSound: "Л",
                            stimulus: "луна", imageAsset: "word_moon", referenceAudio: "ref_luna", acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "word_l_final", block: .wordPronunciation, targetSound: "Л",
                            stimulus: "стол", imageAsset: "word_table", referenceAudio: "ref_stol", acceptableHoldSeconds: nil)
        ]
    }

    private static func minimalPairsBlock() -> [ScreeningPrompt] {
        // 3 minimal-pair discrimination prompts.
        [
            ScreeningPrompt(id: "pair_s_sh", block: .minimalPairs, targetSound: "С/Ш",
                            stimulus: "миска — мишка", imageAsset: nil,
                            referenceAudio: "ref_miska_mishka", acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "pair_r_l", block: .minimalPairs, targetSound: "Р/Л",
                            stimulus: "рак — лак", imageAsset: nil,
                            referenceAudio: "ref_rak_lak", acceptableHoldSeconds: nil),
            ScreeningPrompt(id: "pair_k_g", block: .minimalPairs, targetSound: "К/Г",
                            stimulus: "кот — год", imageAsset: nil,
                            referenceAudio: "ref_kot_god", acceptableHoldSeconds: nil)
        ]
    }

    private static func breathingBlock(age: Int) -> [ScreeningPrompt] {
        // 1 breathing prompt, duration scales with age (5y → 5s … 8y → 12s).
        let hold = max(5, min(12, age + 2))
        return [
            ScreeningPrompt(id: "breathing_hold", block: .breathingDuration, targetSound: "—",
                            stimulus: "дуй ровно на шарик \(hold) секунд",
                            imageAsset: nil, referenceAudio: nil,
                            acceptableHoldSeconds: Double(hold))
        ]
    }
}
