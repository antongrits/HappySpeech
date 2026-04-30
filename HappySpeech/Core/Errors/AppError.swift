import Foundation

// MARK: - AppError

/// Единый тип ошибок приложения с локализованными описаниями на русском языке.
///
/// `AppError` — единственный тип ошибок, который пересекает границу сервис/интерактор.
/// Все сервисы бросают `AppError`; Interactor перехватывает и передаёт Presenter,
/// который формирует `ViewModel.ErrorState` для отображения пользователю.
///
/// ### Группы ошибок
/// - **Auth**: ошибки входа/выхода, токены, Google
/// - **Network**: недоступность сети, таймауты, серверные ошибки
/// - **Circuit/COPPA**: попытка вызова запрещённого API из детского контура
/// - **Realm/Data**: ошибки чтения/записи в локальную БД
/// - **Sync**: конфликты и сбои синхронизации с Firestore
/// - **Audio**: запись, воспроизведение, формат
/// - **ASR**: WhisperKit — модель не загружена, ошибка транскрипции
/// - **AR**: ARKit — нет поддержки, потеря трекинга
/// - **ML**: Core ML модели — не найдены, ошибка инференса
/// - **Content**: контент-паки — не найдены, битый JSON
///
/// ## Пример
/// ```swift
/// // В сервисе:
/// guard isNetworkAvailable else {
///     throw AppError.networkUnavailable
/// }
///
/// // В Interactor:
/// do {
///     let result = try await service.fetch()
///     presenter.presentResult(.init(result: result))
/// } catch let error as AppError {
///     presenter.presentError(.init(error: error))
/// }
/// ```
///
/// ## See Also
/// - ``HSLogger``
/// - ``RealmActor``
public enum AppError: LocalizedError, Equatable {

    // MARK: - Auth
    case authSignInFailed(String)
    case authSignOutFailed
    case authUserNotFound
    case authTokenExpired
    case authEmailAlreadyInUse
    case authWeakPassword
    case authNetworkError
    case authGoogleCancelled
    case authEmailNotVerified
    case authInvalidCredential
    case authConfigurationMissing

    // MARK: - Network
    case networkUnavailable
    case networkTimeout
    case networkServerError(Int)
    case networkTransient(String)
    case networkPermanent(String)

    // MARK: - Circuit / COPPA
    case notAllowedInChildCircuit

    // MARK: - Realm / Data
    case realmWriteFailed(String)
    case realmReadFailed(String)
    case realmMigrationFailed(String)
    case entityNotFound(String)

    // MARK: - Sync
    case syncQueueFull
    case syncConflict(String)
    case syncUploadFailed(String)

    // MARK: - Audio
    case audioPermissionDenied
    case audioRecordingFailed(String)
    case audioPlaybackFailed(String)
    case audioFormatUnsupported

    // MARK: - ASR
    case asrModelNotLoaded
    case asrTranscriptionFailed(String)
    case asrLanguageNotSupported

    // MARK: - AR
    case arNotSupported
    case arTrackingFailed
    case arCameraPermissionDenied

    // MARK: - ML
    case mlModelNotFound(String)
    case mlInferenceFailed(String)
    case mlModelCorrupted(String)

    // MARK: - LLM
    case llmNotDownloaded
    case llmInvalidJSON(String)
    case llmTimeout
    case llmContextTooLong

    // MARK: - Content
    case contentPackNotFound(String)
    case contentPackCorrupted(String)
    case contentPackVersionMismatch

    // MARK: - General
    case unknown(String)
    case cancelled

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .authSignInFailed(let msg):
            return "Не удалось войти: \(msg)"
        case .authSignOutFailed:
            return "Не удалось выйти из аккаунта."
        case .authUserNotFound:
            return "Пользователь не найден."
        case .authTokenExpired:
            return "Сессия истекла. Войдите снова."
        case .authEmailAlreadyInUse:
            return "Пользователь с такой почтой уже существует."
        case .authWeakPassword:
            return "Пароль слишком простой. Минимум 6 символов."
        case .authNetworkError:
            return "Проблемы с сетью. Проверьте подключение и повторите."
        case .authGoogleCancelled:
            return "Вход через Google отменён."
        case .authEmailNotVerified:
            return "Почта не подтверждена. Проверьте входящие письма."
        case .authInvalidCredential:
            return "Неверный email или пароль."
        case .authConfigurationMissing:
            return "Сервис аутентификации не настроен."

        case .networkUnavailable:
            return "Нет интернета. Данные сохранены и будут синхронизированы позже."
        case .networkTimeout:
            return "Сервер не отвечает. Проверьте подключение."
        case .networkServerError(let code):
            return "Ошибка сервера (\(code)). Попробуйте позже."
        case .networkTransient(let details):
            return "Временная сетевая ошибка: \(details). Повторим попытку автоматически."
        case .networkPermanent(let details):
            return "Сетевая ошибка: \(details)."

        case .notAllowedInChildCircuit:
            return "Эта функция недоступна в детском режиме."

        case .realmWriteFailed(let msg):
            return "Ошибка сохранения: \(msg)"
        case .realmReadFailed(let msg):
            return "Ошибка чтения данных: \(msg)"
        case .realmMigrationFailed(let msg):
            return "Ошибка обновления базы данных: \(msg)"
        case .entityNotFound(let name):
            return "Запись «\(name)» не найдена."

        case .syncQueueFull:
            return "Очередь синхронизации переполнена. Освободите место на устройстве."
        case .syncConflict(let info):
            return "Конфликт синхронизации: \(info)"
        case .syncUploadFailed(let msg):
            return "Не удалось загрузить данные: \(msg)"

        case .audioPermissionDenied:
            return "Доступ к микрофону запрещён. Разрешите в Настройках."
        case .audioRecordingFailed(let msg):
            return "Ошибка записи: \(msg)"
        case .audioPlaybackFailed(let msg):
            return "Ошибка воспроизведения: \(msg)"
        case .audioFormatUnsupported:
            return "Формат аудио не поддерживается."

        case .asrModelNotLoaded:
            return "Модель распознавания речи не загружена."
        case .asrTranscriptionFailed(let msg):
            return "Ошибка распознавания: \(msg)"
        case .asrLanguageNotSupported:
            return "Язык не поддерживается."

        case .arNotSupported:
            return "AR не поддерживается на этом устройстве."
        case .arTrackingFailed:
            return "Потеряно отслеживание лица. Убедитесь, что лицо в кадре."
        case .arCameraPermissionDenied:
            return "Доступ к камере запрещён. Разрешите в Настройках."

        case .mlModelNotFound(let name):
            return "Модель «\(name)» не найдена."
        case .mlInferenceFailed(let msg):
            return "Ошибка анализа: \(msg)"
        case .mlModelCorrupted(let name):
            return "Файл модели «\(name)» повреждён."

        case .llmNotDownloaded:
            return "Языковая модель не загружена. Подключитесь к Wi-Fi для загрузки."
        case .llmInvalidJSON(let details):
            return "Неверный формат ответа ИИ: \(details)"
        case .llmTimeout:
            return "ИИ не успел ответить. Попробуйте ещё раз."
        case .llmContextTooLong:
            return "Слишком много данных для анализа."

        case .contentPackNotFound(let id):
            return "Набор заданий «\(id)» не найден."
        case .contentPackCorrupted(let id):
            return "Набор заданий «\(id)» повреждён. Попробуйте скачать снова."
        case .contentPackVersionMismatch:
            return "Версия набора заданий устарела. Обновите приложение."

        case .unknown(let msg):
            return "Неизвестная ошибка: \(msg)"
        case .cancelled:
            return "Операция отменена."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "Данные синхронизируются автоматически при подключении."
        case .audioPermissionDenied, .arCameraPermissionDenied:
            return "Откройте Настройки → HappySpeech и разрешите доступ."
        case .llmNotDownloaded:
            return "Приложение работает без ИИ-функций в режиме офлайн."
        case .mlModelNotFound, .mlModelCorrupted:
            return "Переустановите приложение для восстановления моделей."
        default:
            return nil
        }
    }
}
