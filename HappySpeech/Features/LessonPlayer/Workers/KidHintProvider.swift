import Foundation
import OSLog
import SwiftUI

// MARK: - KidHintProvider
// ==================================================================================
// Environment-based helper для генерации подсказок в любой игре.
// Использует KidLLMNarrationService (Block H) с fallback на PrecannedNarrations.
//
// Использование в View:
//   @Environment(KidHintProvider.self) private var hintProvider
//   ...
//   let hint = await hintProvider.getHint(gameType: "narrative_quest", step: "1")
// ==================================================================================

@Observable
@MainActor
public final class KidHintProvider {

    // MARK: - State

    public private(set) var currentHint: String = ""
    public private(set) var isLoading: Bool = false

    // MARK: - Dependencies

    private let narrationService: any KidLLMNarrationServiceProtocol
    private let logger = Logger(subsystem: "ru.happyspeech", category: "KidHintProvider")

    // MARK: - Init

    public init(narrationService: any KidLLMNarrationServiceProtocol) {
        self.narrationService = narrationService
    }

    // MARK: - Public API

    /// Загружает контекстную подсказку для игры.
    /// - Parameters:
    ///   - gameType: Тип игры ("narrative_quest", "repeat_after_model", "general").
    ///   - step: Текущий шаг или состояние в строковом формате.
    /// - Returns: Подсказка для отображения ребёнку.
    public func getHint(gameType: String, step: String) async -> String {
        isLoading = true
        defer { isLoading = false }
        let hint = await narrationService.generateHint(gameType: gameType, currentStep: step)
        currentHint = hint
        logger.debug("KidHintProvider hint loaded gameType=\(gameType, privacy: .public)")
        return hint
    }

    /// Показывает hint с анимированным появлением.
    public func loadAndShow(gameType: String, step: String) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            _ = await self.getHint(gameType: gameType, step: step)
        }
    }

    /// Очищает текущую подсказку.
    public func clear() {
        currentHint = ""
    }
}

// MARK: - HintButtonView
//
// Переиспользуемая кнопка-подсказки для любой игры.
// Показывает иконку лампочки; при нажатии загружает LLM hint и отображает
// всплывающий overlay с текстом.

struct HintButtonView: View {

    let gameType: String
    let currentStep: String

    @Environment(AppContainer.self) private var container
    @State private var isShowingHint: Bool = false
    @State private var hintText: String = ""
    @State private var isLoadingHint: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            loadHint()
        } label: {
            ZStack {
                Circle()
                    .fill(ColorTokens.Brand.butter.opacity(0.25))
                    .frame(width: 44, height: 44)
                Image(systemName: "lightbulb.fill")
                    .font(TypographyTokens.headline(20))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .opacity(isLoadingHint ? 0.5 : 1.0)
                    .animation(
                        isLoadingHint
                            ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                            : .default,
                        value: isLoadingHint
                    )
            }
        }
        .accessibilityLabel(String(localized: "Подсказка"))
        .accessibilityHint(String(localized: "Нажмите для получения подсказки от Ляли"))
        .popover(isPresented: $isShowingHint) {
            hintPopover
        }
    }

    private var hintPopover: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .accessibilityHidden(true)
                Text(String(localized: "Подсказка от Ляли"))
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Spacer()
                Button {
                    isShowingHint = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
                .accessibilityLabel(String(localized: "Закрыть подсказку"))
            }
            Text(hintText.isEmpty ? String(localized: "Загружаем подсказку…") : hintText)
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .minimumScaleFactor(0.9)
                .frame(minWidth: 200, maxWidth: 280, alignment: .leading)
        }
        .padding(SpacingTokens.medium)
        .background(ColorTokens.Kid.surface)
    }

    private func loadHint() {
        isShowingHint = true
        guard hintText.isEmpty else { return }
        isLoadingHint = true
        Task { @MainActor in
            let narrationService = LiveKidLLMNarrationService(
                llmService: container.llmDecisionService
            )
            hintText = await narrationService.generateHint(
                gameType: gameType,
                currentStep: currentStep
            )
            isLoadingHint = false
        }
    }
}
