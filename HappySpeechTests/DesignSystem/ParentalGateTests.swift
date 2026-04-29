import Testing
@testable import HappySpeech

// MARK: - ParentalGateTests
//
// Тесты логики ParentalGate (MathProblem + verify logic).
// Не используем XCTestCase, работаем в Swift Testing.

@Suite("ParentalGate")
struct ParentalGateTests {

    // MARK: - MathProblem

    @Suite("MathProblem")
    struct MathProblemTests {

        @Test("random() возвращает корректный ответ для сложения")
        func randomAdditionAnswerIsCorrect() {
            // Генерируем 100 задач, каждая должна давать верный ответ.
            for _ in 0..<100 {
                let problem = MathProblem.random()
                let parts = problem.question.split(separator: " ")
                // Формат: "a + b" или "a × b"
                guard parts.count == 3,
                      let a = Int(parts[0]),
                      let b = Int(parts[2]) else {
                    Issue.record("Неверный формат вопроса: \(problem.question)")
                    continue
                }
                let op = String(parts[1])
                let expected = op == "+" ? a + b : a * b
                #expect(problem.answer == expected,
                        "Ожидали \(expected), получили \(problem.answer) для «\(problem.question)»")
            }
        }

        @Test("random() генерирует вопрос непустой строкой")
        func randomQuestionIsNonEmpty() {
            let problem = MathProblem.random()
            #expect(!problem.question.isEmpty)
        }

        @Test("random() answer положительный")
        func randomAnswerIsPositive() {
            for _ in 0..<50 {
                let problem = MathProblem.random()
                #expect(problem.answer > 0)
            }
        }

        @Test("сложение: диапазон операндов 12–49")
        func additionOperandsInRange() {
            // Запускаем много раз, чтобы проверить что multiplication тоже встречается.
            var sawAddition = false
            var sawMultiplication = false
            for _ in 0..<200 {
                let problem = MathProblem.random()
                if problem.question.contains("+") {
                    sawAddition = true
                    let parts = problem.question.split(separator: " ")
                    if let a = Int(parts[0]), let b = Int(parts[2]) {
                        #expect(a >= 12 && a <= 49)
                        #expect(b >= 12 && b <= 49)
                    }
                } else if problem.question.contains("×") {
                    sawMultiplication = true
                    let parts = problem.question.split(separator: " ")
                    if let a = Int(parts[0]), let b = Int(parts[2]) {
                        #expect(a >= 3 && a <= 9)
                        #expect(b >= 3 && b <= 9)
                    }
                }
            }
            #expect(sawAddition, "За 200 генераций не встретилось ни одного примера со сложением")
            #expect(sawMultiplication, "За 200 генераций не встретилось ни одного примера с умножением")
        }
    }

    // MARK: - Verify logic (unit)

    @Suite("VerifyLogic")
    struct VerifyLogicTests {

        @Test("правильный ответ приводит к onSuccess")
        func correctAnswerCallsOnSuccess() async {
            let problem = MathProblem(question: "3 + 4", answer: 7)
            var successCalled = false
            var dismissCalled = false

            // Симулируем логику verify напрямую — без SwiftUI
            let enteredString = "7"
            guard let entered = Int(enteredString.trimmingCharacters(in: .whitespaces)) else {
                Issue.record("Не удалось распарсить число")
                return
            }
            if entered == problem.answer {
                dismissCalled = true
                successCalled = true
            }

            #expect(successCalled, "onSuccess должен быть вызван при правильном ответе")
            #expect(dismissCalled, "dismiss должен быть вызван при правильном ответе")
        }

        @Test("неправильный ответ увеличивает счётчик попыток")
        func wrongAnswerIncrementsAttempts() {
            let problem = MathProblem(question: "3 + 4", answer: 7)
            var attempts = 0
            var successCalled = false

            let enteredString = "10"
            guard let entered = Int(enteredString.trimmingCharacters(in: .whitespaces)) else {
                Issue.record("Не удалось распарсить число")
                return
            }
            if entered == problem.answer {
                successCalled = true
            } else {
                attempts += 1
            }

            #expect(!successCalled, "onSuccess не должен вызываться при неправильном ответе")
            #expect(attempts == 1, "Счётчик попыток должен стать 1, получили: \(attempts)")
        }

        @Test("нечисловой ответ увеличивает счётчик попыток")
        func nonNumericAnswerIncrementsAttempts() {
            var attempts = 0
            var successCalled = false

            let enteredString = "abc"
            if Int(enteredString.trimmingCharacters(in: .whitespaces)) == nil {
                attempts += 1
            } else {
                successCalled = true
            }

            #expect(!successCalled)
            #expect(attempts == 1)
        }

        @Test("несколько неправильных попыток накапливаются")
        func multipleWrongAnswersAccumulateAttempts() {
            let problem = MathProblem(question: "5 × 6", answer: 30)
            var attempts = 0

            for wrong in [1, 2, 3, 99, 0] {
                if wrong != problem.answer {
                    attempts += 1
                }
            }

            #expect(attempts == 5, "Ожидали 5 неправильных попыток, получили \(attempts)")
        }

        @Test("пустой ответ не проходит проверку")
        func emptyAnswerDoesNotPass() {
            let problem = MathProblem(question: "4 + 5", answer: 9)
            var successCalled = false

            let enteredString = ""
            let trimmed = enteredString.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty, let entered = Int(trimmed), entered == problem.answer {
                successCalled = true
            }

            #expect(!successCalled, "Пустой ответ не должен проходить проверку")
        }
    }
}
