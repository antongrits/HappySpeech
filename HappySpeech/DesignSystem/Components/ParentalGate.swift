import OSLog
import SwiftUI

// MARK: - ParentalGate
//
// Parental Gate sheet — блокирует доступ детям к external links и admin actions.
// Apple Kids Category guidelines (App Review 1.3, 5.1.4):
// внешние ссылки, управление аккаунтом, покупки требуют parental verification
// через math problem (недоступно для детей 5–8 лет без помощи взрослых).
//
// Block O (v12): Biometric pre-check.
// При открытии sheet автоматически запрашивается Face ID / Touch ID.
// Если биометрия проходит → math-вопрос не показывается, вызывается onSuccess.
// Если биометрия недоступна / отказ / cancel → показывается math-вопрос (прежний flow).
// Поведение контролируется UserDefaults "BiometricGate.useFaceID" (default: true).
//
// Использование:
//   .sheet(isPresented: $showGate) {
//       ParentalGate(isPresented: $showGate) { openURL(url) }
//   }
//   // С явным сервисом (тесты / Preview):
//   ParentalGate(isPresented: $showGate, biometricService: MockBiometricGateService()) { ... }

// MARK: - MathProblem

struct MathProblem: Sendable {
    let question: String
    let answer: Int

    static func random() -> MathProblem {
        let operation = Int.random(in: 0...1)
        if operation == 0 {
            let a = Int.random(in: 12...49)
            let b = Int.random(in: 12...49)
            return MathProblem(question: "\(a) + \(b)", answer: a + b)
        } else {
            let a = Int.random(in: 3...9)
            let b = Int.random(in: 3...9)
            return MathProblem(question: "\(a) × \(b)", answer: a * b)
        }
    }
}

// MARK: - ParentalGate

public struct ParentalGate: View {

    // MARK: - Bindings / Callbacks

    @Binding var isPresented: Bool
    let onSuccess: () -> Void

    // MARK: - State

    @State private var problem: MathProblem = MathProblem.random()
    @State private var userAnswer: String = ""
    @State private var attempts: Int = 0
    /// false — показываем биометрический статус-баннер; true — показываем math UI
    @State private var showMathQuestion: Bool = false
    @State private var biometricChecking: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let biometricService: any BiometricGateService
    private let logger = Logger(subsystem: "ru.happyspeech", category: "ParentalGate")

    /// Читаем настройку пользователя: включён ли Face ID gate.
    private var faceIDEnabled: Bool {
        // Если ключ не задан — по умолчанию true (использовать Face ID).
        if UserDefaults.standard.object(forKey: "BiometricGate.useFaceID") == nil { return true }
        return UserDefaults.standard.bool(forKey: "BiometricGate.useFaceID")
    }

    // MARK: - Init

    public init(
        isPresented: Binding<Bool>,
        biometricService: (any BiometricGateService)? = nil,
        onSuccess: @escaping () -> Void
    ) {
        self._isPresented = isPresented
        self.biometricService = biometricService ?? LiveBiometricGateService()
        self.onSuccess = onSuccess
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if showMathQuestion {
                mathView
            } else {
                biometricStatusView
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .background(ColorTokens.Parent.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "parental_gate.accessibility_label"))
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .task {
            await runBiometricPreCheck()
        }
    }

    // MARK: - Biometric Status View

    /// Экран-заглушка, пока идёт запрос Face ID.
    /// Показывается только доли секунды до появления системного диалога.
    @ViewBuilder
    private var biometricStatusView: some View {
        VStack(spacing: SpacingTokens.large) {
            Image(systemName: "faceid")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(ColorTokens.Brand.primary)
                .padding(.top, SpacingTokens.xLarge)
                .accessibilityHidden(true)

            Text(String(localized: "parental_gate.biometric.title"))
                .font(TypographyTokens.title(20))
                .foregroundStyle(ColorTokens.Parent.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)

            if biometricChecking {
                ProgressView()
                    .tint(ColorTokens.Brand.primary)
                    .accessibilityLabel(String(localized: "parental_gate.biometric.title"))
            }

            Text(String(localized: "parental_gate.biometric.fallback_hint"))
                .font(TypographyTokens.caption(14))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .padding(.horizontal, SpacingTokens.xLarge)

            Spacer(minLength: SpacingTokens.regular)

            Button {
                logger.info("ParentalGate: biometric status — dismissed by user")
                isPresented = false
            } label: {
                Text(String(localized: "parental_gate.cancel"))
                    .font(TypographyTokens.body(16))
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.bordered)
            .tint(ColorTokens.Parent.accent)
            .accessibilityLabel(String(localized: "parental_gate.cancel"))
            .padding(.bottom, SpacingTokens.large)
        }
    }

    // MARK: - Math View

    @ViewBuilder
    private var mathView: some View {
        VStack(spacing: SpacingTokens.large) {

            // Icon
            Image(systemName: "person.2.fill")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(ColorTokens.Brand.primary)
                .padding(.top, SpacingTokens.large)
                .accessibilityHidden(true)

            // Title
            Text(String(localized: "parental_gate.title"))
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Parent.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)

            // Subtitle
            Text(String(localized: "parental_gate.subtitle"))
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .padding(.horizontal, SpacingTokens.xLarge)

            // Math problem
            HStack(spacing: SpacingTokens.regular) {
                Text(problem.question)
                    .font(TypographyTokens.title(26))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .accessibilityLabel(
                        String(localized: "parental_gate.problem.accessibility_prefix") + " " + problem.question
                    )

                Text("=")
                    .font(TypographyTokens.title(26))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .accessibilityHidden(true)

                TextField(
                    String(localized: "parental_gate.answer_placeholder"),
                    text: $userAnswer
                )
                .keyboardType(.numberPad)
                .font(TypographyTokens.title(26))
                .foregroundStyle(ColorTokens.Parent.ink)
                .frame(width: 88, height: 56)
                .multilineTextAlignment(.center)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.md)
                        .fill(ColorTokens.Parent.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.md)
                        .strokeBorder(
                            attempts > 0 ? ColorTokens.Semantic.error : ColorTokens.Parent.line,
                            lineWidth: attempts > 0 ? 2 : 1
                        )
                )
                .accessibilityLabel(String(localized: "parental_gate.answer_placeholder"))
            }
            .padding(.vertical, SpacingTokens.small)

            // Error hint (no heavy animation — Reduced Motion safe)
            if attempts > 0 {
                HStack(spacing: SpacingTokens.tiny) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(ColorTokens.Semantic.warning)
                        .accessibilityHidden(true)
                    Text(String(localized: "parental_gate.try_again"))
                        .font(TypographyTokens.caption(14))
                        .foregroundStyle(ColorTokens.Semantic.warning)
                }
                .transition(reduceMotion ? .identity : .opacity)
                .accessibilityLabel(String(localized: "parental_gate.try_again"))
            }

            Spacer(minLength: SpacingTokens.small)

            // Buttons
            HStack(spacing: SpacingTokens.regular) {
                Button {
                    logger.info("ParentalGate: dismissed by user")
                    isPresented = false
                } label: {
                    Text(String(localized: "parental_gate.cancel"))
                        .font(TypographyTokens.body(16))
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.bordered)
                .tint(ColorTokens.Parent.accent)
                .accessibilityLabel(String(localized: "parental_gate.cancel"))

                Button {
                    verify()
                } label: {
                    Text(String(localized: "parental_gate.continue"))
                        .font(TypographyTokens.body(16).weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(ColorTokens.Brand.primary)
                .disabled(userAnswer.isEmpty)
                .accessibilityLabel(String(localized: "parental_gate.continue"))
                .accessibilityHint(String(localized: "parental_gate.continue_hint"))
            }
            .padding(.bottom, SpacingTokens.large)
        }
    }

    // MARK: - Private: Biometric Pre-Check

    @MainActor
    private func runBiometricPreCheck() async {
        // Если пользователь отключил Face ID в настройках — сразу показываем math
        guard faceIDEnabled else {
            logger.info("ParentalGate: Face ID disabled in settings — showing math gate")
            showMathQuestion = true
            return
        }

        let canUse = await biometricService.canUseBiometric()
        guard canUse else {
            logger.info("ParentalGate: biometric unavailable — falling back to math gate")
            showMathQuestion = true
            return
        }

        biometricChecking = true
        let result = await biometricService.authenticate(
            reason: String(localized: "parental_gate.biometric.reason")
        )
        biometricChecking = false

        switch result {
        case .success:
            logger.info("ParentalGate: biometric success — granting access without math")
            isPresented = false
            onSuccess()
        case .fallback, .cancelled, .denied:
            // .fallback: lockout / не enrolled / недоступна
            // .cancelled: пользователь нажал «Отмена» в Face ID диалоге
            // .denied: неверный биометрический образец
            logger.info("ParentalGate: biometric result=\(String(describing: result)) — showing math gate")
            showMathQuestion = true
        }
    }

    // MARK: - Private: Math Verify

    private func verify() {
        guard let entered = Int(userAnswer.trimmingCharacters(in: .whitespaces)) else {
            attempts += 1
            problem = MathProblem.random()
            userAnswer = ""
            logger.info("ParentalGate: non-numeric answer, attempt \(attempts)")
            return
        }

        if entered == problem.answer {
            logger.info("ParentalGate: correct answer, granting access")
            isPresented = false
            onSuccess()
        } else {
            attempts += 1
            problem = MathProblem.random()
            userAnswer = ""
            logger.info("ParentalGate: wrong answer, attempt \(attempts)")
        }
    }
}

// MARK: - Preview

#Preview("ParentalGate — math (biometric fallback)") {
    Color.gray.opacity(0.2).ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            ParentalGate(
                isPresented: .constant(true),
                biometricService: MockBiometricGateService(available: true, result: .fallback)
            ) {}
        }
}

#Preview("ParentalGate — biometric pending") {
    Color.gray.opacity(0.2).ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            ParentalGate(
                isPresented: .constant(true),
                biometricService: MockBiometricGateService(available: false, result: .fallback)
            ) {}
        }
}
