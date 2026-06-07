import Foundation

// MARK: - PalindromeHunterModels

/// Компактный VIP-модуль (@Observable Interactor + View) — реализация полная.
enum PalindromeHunterModels {

    struct Round: Identifiable, Hashable {
        let id: Int
        let words: [String]
        let palindrome: String

        var isPalindrome: (String) -> Bool {
            { candidate in
                let clean = candidate.lowercased()
                return clean == String(clean.reversed())
            }
        }
    }

    struct ViewState: Equatable {
        var rounds: [Round]
        var currentRoundIndex: Int
        var correctCount: Int

        var currentRound: Round? {
            rounds.indices.contains(currentRoundIndex) ? rounds[currentRoundIndex] : nil
        }

        var progress: Double {
            guard !rounds.isEmpty else { return 0 }
            return Double(currentRoundIndex) / Double(rounds.count)
        }

        static let initial = ViewState(
            rounds: [
                Round(id: 0, words: ["шалаш", "забор", "мост"], palindrome: "шалаш"),
                Round(id: 1, words: ["казак", "лента", "стол"], palindrome: "казак"),
                Round(id: 2, words: ["лето", "потоп", "ветка"], palindrome: "потоп"),
                Round(id: 3, words: ["доход", "роща", "пчела"], palindrome: "доход"),
                Round(id: 4, words: ["заказ", "груша", "слон"], palindrome: "заказ"),
                Round(id: 5, words: ["топот", "роза", "лиса"], palindrome: "топот"),
                Round(id: 6, words: ["волна", "комок", "лужа"], palindrome: "комок"),
                Round(id: 7, words: ["роза", "наган", "слива"], palindrome: "наган"),
                Round(id: 8, words: ["месса", "лужа", "куст"], palindrome: "месса"),
                Round(id: 9, words: ["доход", "пушка", "молоко"], palindrome: "доход")
            ],
            currentRoundIndex: 0,
            correctCount: 0
        )
    }
}
