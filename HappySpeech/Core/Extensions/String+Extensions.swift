import Foundation

public extension String {
    /// Returns true if string contains any of the specified Russian sounds.
    func containsRussianSound(_ sound: String) -> Bool {
        let lower = lowercased()
        let soundLower = sound.lowercased()
        return lower.contains(soundLower)
    }

    /// Trims whitespace and newlines.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns nil if empty after trimming.
    var nilIfEmpty: String? {
        let t = trimmed
        return t.isEmpty ? nil : t
    }

    /// Capitalises only the first letter, leaves the rest unchanged.
    var sentenceCased: String {
        guard !isEmpty else { return self }
        return prefix(1).uppercased() + dropFirst()
    }
}

public extension String {
    /// Validates that string is a non-empty child name (letters and spaces only, ≤30 chars).
    var isValidChildName: Bool {
        let trimmed = self.trimmed
        guard !trimmed.isEmpty, trimmed.count <= 30 else { return false }
        let allowed = CharacterSet.letters.union(.whitespaces)
        return trimmed.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    /// Simple email validation.
    var isValidEmail: Bool {
        let pattern = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return range(of: pattern, options: .regularExpression) != nil
    }
}
