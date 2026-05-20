import Foundation
import OSLog

// MARK: - DailyRitualsLyalyaBusinessLogic

@MainActor
protocol DailyRitualsLyalyaBusinessLogic: AnyObject {
    func load(request: DailyRitualsLyalyaModels.Load.Request) async
    func toggleReminder(request: DailyRitualsLyalyaModels.ToggleReminder.Request) async
    func updateTime(request: DailyRitualsLyalyaModels.UpdateTime.Request) async
    func requestPermission(request: DailyRitualsLyalyaModels.RequestPermission.Request) async
}

// MARK: - DailyRitualsLyalyaInteractor (Clean Swift: Interactor)
//
// v31 Волна A, Функция Ф8 «Утро и вечер с Лялей».
//
// Бизнес-логика: компонует шаги ритуала, управляет включением/выключением
// и временем локального напоминания.

@MainActor
final class DailyRitualsLyalyaInteractor: DailyRitualsLyalyaBusinessLogic {

    var presenter: (any DailyRitualsLyalyaPresentationLogic)?

    private let worker: any DailyRitualsLyalyaWorkerProtocol

    private var currentKind: RitualKind = .morning

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "DailyRituals.Interactor"
    )

    init(worker: any DailyRitualsLyalyaWorkerProtocol) {
        self.worker = worker
    }

    func load(request: DailyRitualsLyalyaModels.Load.Request) async {
        currentKind = request.kind
        let authorized = await worker.notificationAuthorizationStatus()
        let response = DailyRitualsLyalyaModels.Load.Response(
            kind: request.kind,
            steps: worker.steps(for: request.kind),
            reminderEnabled: worker.reminderEnabled(for: request.kind),
            reminderTime: worker.reminderTime(for: request.kind),
            notificationsAuthorized: authorized
        )
        await presenter?.presentLoad(response: response)
    }

    func toggleReminder(request: DailyRitualsLyalyaModels.ToggleReminder.Request) async {
        let authorized = await worker.notificationAuthorizationStatus()
        if request.isEnabled && !authorized {
            // Нужно получить разрешение — отдаём наверх флаг.
            await presenter?.presentToggleReminder(
                response: .init(kind: request.kind,
                                isEnabled: false,
                                authorizationNeeded: true)
            )
            return
        }

        worker.setReminderEnabled(request.isEnabled, for: request.kind)
        if request.isEnabled {
            let time = worker.reminderTime(for: request.kind)
            await worker.scheduleReminder(for: request.kind, time: time)
        } else {
            await worker.cancelReminder(for: request.kind)
        }
        await presenter?.presentToggleReminder(
            response: .init(kind: request.kind,
                            isEnabled: request.isEnabled,
                            authorizationNeeded: false)
        )
        // Перезагрузить экран — обновить лейблы.
        await load(request: .init(kind: request.kind))
    }

    func updateTime(request: DailyRitualsLyalyaModels.UpdateTime.Request) async {
        worker.setReminderTime(request.time, for: request.kind)
        if worker.reminderEnabled(for: request.kind) {
            await worker.scheduleReminder(for: request.kind, time: request.time)
        }
        await presenter?.presentUpdateTime(
            response: .init(kind: request.kind, time: request.time)
        )
        await load(request: .init(kind: request.kind))
    }

    func requestPermission(request: DailyRitualsLyalyaModels.RequestPermission.Request) async {
        let granted = await worker.requestNotificationAuthorization()
        await presenter?.presentPermissionResult(
            response: .init(granted: granted)
        )
        if granted {
            // Авто-включить ритуал после получения прав.
            await toggleReminder(request: .init(kind: request.kind, isEnabled: true))
        }
    }
}
