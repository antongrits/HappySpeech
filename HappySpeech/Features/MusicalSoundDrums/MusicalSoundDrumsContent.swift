import Foundation

// MARK: - MusicalSoundDrumsContent

/// Генератор ритмических рисунков из слогов рабочего звука.
///
/// Для каждого звука берём гласные-партнёры (А, О, У, И…) и собираем открытые
/// слоги (СА, СО, СУ). Рисунок — последовательность слогов с распределением
/// громкости (барабанов): это методическая логоритмика — слогоритм закрепляет
/// автоматизацию звука в слоге через движение/ритм.
enum MusicalSoundDrumsContent {

    /// Гласные для открытых слогов в детской логоритмике.
    private static let vowels = ["А", "О", "У", "И", "Ы"]

    /// Согласная-буква для слога по группе звука. Берём первую букву звука
    /// («Сь» → «С»), приводим к заглавной — для отображаемого слога.
    static func consonant(for sound: String) -> String {
        String(sound.prefix(1)).uppercased()
    }

    /// Строит рисунок заданной длины для звука: чередует гласные и громкости.
    /// Детерминированно по индексу слога (без random), чтобы рисунок можно было
    /// показать, озвучить и повторить.
    static func pattern(
        for sound: String,
        length: Int
    ) -> [MusicalSoundDrumsModels.Syllable] {
        let cons = consonant(for: sound)
        let drums: [MusicalSoundDrumsModels.DrumId] = [.high, .low, .mid]
        let clamped = max(2, min(length, 5))
        return (0..<clamped).map { idx in
            let vowel = vowels[idx % vowels.count]
            let drum = drums[idx % drums.count]
            // Ударный слог — заглавными, безударный — строчными (визуальный акцент).
            let syllable = cons + vowel
            let syllableText = drum == .high ? syllable.uppercased() : syllable.lowercased()
            return MusicalSoundDrumsModels.Syllable(text: syllableText, drum: drum)
        }
    }

    /// Длина рисунка по номеру раунда (постепенное усложнение, без таймеров).
    static func length(forRound round: Int) -> Int {
        switch round {
        case 0, 1: return 3
        case 2: return 4
        default: return 5
        }
    }
}
