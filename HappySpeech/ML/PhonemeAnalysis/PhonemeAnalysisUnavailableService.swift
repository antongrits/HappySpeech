import Foundation
import OSLog

// MARK: - PhonemeAnalysisUnavailableService

/// Честная реализация ``PhonemeAnalysisService`` для случая, когда модель не
/// смогла инициализироваться в продакшн-окружении.
///
/// ## Назначение
///
/// Заменяет прежний prod-fallback на `MockPhonemeAnalysisService`, который
/// возвращал фиктивный score (0.85 hardcoded). Теперь при сбое загрузки
/// RussianPhonemeClassifier (например, повреждённый бандл, нехватка памяти)
/// все вызовы `analyze` бросают ``PhonemeAnalysisError/modelNotLoaded``.
///
/// Вызывающий код (Interactor/Presenter) получает ошибку и показывает
/// честный unavailable-state в UI, а не искусственно высокий score.
///
/// > Note: Эта реализация НИКОГДА не попадает в Preview/Test — там
/// > `AppContainer.preview` инжектирует `MockPhonemeAnalysisService` напрямую
/// > через `container._phonemeAnalysisService = Mock*`.
public actor PhonemeAnalysisUnavailableService: PhonemeAnalysisService {

    private let logger = Logger(subsystem: "ru.happyspeech.ml", category: "PhonemeAnalysisUnavailable")
    private let underlyingError: Error

    public init(reason: Error) {
        self.underlyingError = reason
    }

    public func analyze(audio: Data, expectedWord: String) async throws -> PhonemeAnalysisResult {
        logger.error(
            "PhonemeAnalysisService недоступен — модель не была загружена: \(self.underlyingError.localizedDescription)"
        )
        throw PhonemeAnalysisError.modelNotLoaded
    }
}
