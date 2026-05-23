import OSLog
import SwiftUI
import TipKit

// MARK: - HSTips
//
// v31 Волна A — TipKit feature-discovery.
//
// Лёгкие подсказки для ключевых разделов:
//   • ParentDashboardTip — на ParentHome, объясняет, что здесь живёт прогресс ребёнка.
//   • SettingsThemeTip — на Settings, подсказывает, что можно сменить тему/настроить
//     уведомления.
//   • SpecialistAssignmentsTip — на SpecialistChildList, обращает внимание на
//     раздел домашних заданий.
//
// Тип контента: справочный (нет внешних трекеров). Через TipKit подсказки
// показываются один раз и могут быть скрыты пользователем (HIG-friendly).

@available(iOS 17.0, *)
public struct ParentDashboardTip: Tip {
    public var title: Text {
        Text("tips.parentDashboard.title")
    }
    public var message: Text? {
        Text("tips.parentDashboard.message")
    }
    public var image: Image? {
        Image(systemName: "chart.bar.fill")
    }
    public init() {}
}

@available(iOS 17.0, *)
public struct SettingsThemeTip: Tip {
    public var title: Text {
        Text("tips.settings.title")
    }
    public var message: Text? {
        Text("tips.settings.message")
    }
    public var image: Image? {
        Image(systemName: "gearshape.fill")
    }
    public init() {}
}

@available(iOS 17.0, *)
public struct SpecialistAssignmentsTip: Tip {
    public var title: Text {
        Text("tips.specialistAssignments.title")
    }
    public var message: Text? {
        Text("tips.specialistAssignments.message")
    }
    public var image: Image? {
        Image(systemName: "person.text.rectangle.fill")
    }
    public init() {}
}

// MARK: - View modifiers (iOS-17-gated)

/// Безопасный обёрточный modifier для popoverTip — на iOS 17+ показывает Tip,
/// на ранних версиях возвращает контент без изменений. Используется, чтобы
/// не разбрасывать `if #available` по фичам.
public struct ParentDashboardTipModifier: ViewModifier {
    public init() {}
    public func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.popoverTip(ParentDashboardTip())
        } else {
            content
        }
    }
}

public struct SettingsThemeTipModifier: ViewModifier {
    public init() {}
    public func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.popoverTip(SettingsThemeTip())
        } else {
            content
        }
    }
}

public struct SpecialistAssignmentsTipModifier: ViewModifier {
    public init() {}
    public func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.popoverTip(SpecialistAssignmentsTip())
        } else {
            content
        }
    }
}

// MARK: - HSTipsBootstrap

/// Помощник по настройке TipKit при старте приложения. Вызывается из
/// `bootstrapApp()` сразу после `Realm.open()` — один раз за процесс.
public enum HSTipsBootstrap {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "Tips.Bootstrap"
    )

    public static func configure() {
        guard #available(iOS 17.0, *) else { return }
        // Не падать в XCTest — TipKit-конфигурация требует disk-store,
        // и при многократной инициализации (UI tests) лучше делать noop.
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if isTesting {
            logger.info("Skipping TipKit configure under XCTest")
            return
        }
        // Screenshot-tour / UI-test mode: подавляем все TipKit-подсказки
        // ТОЛЬКО при явном `-HSSuppressCoachmarks` — при обычных HSStartRoute
        // подсказки показываются нормально (пользователь dismiss'ит вручную).
        let args = ProcessInfo.processInfo.arguments
        let suppressed = args.contains("-HSSuppressCoachmarks")
        do {
            if suppressed {
                try Tips.configure([
                    .displayFrequency(.daily),  // фактически не покажет подряд
                    .datastoreLocation(.applicationDefault)
                ])
                // Invalidate известных tip-инстансов, чтобы они не появились в этой сессии.
                ParentDashboardTip().invalidate(reason: .actionPerformed)
                SettingsThemeTip().invalidate(reason: .actionPerformed)
                SpecialistAssignmentsTip().invalidate(reason: .actionPerformed)
                logger.info("TipKit suppressed (screenshot/UI-test mode)")
                return
            }
            // .daily вместо .immediate — иначе TipKit показывает tip каждый раз
            // при появлении триггера, игнорируя пользовательский dismiss.
            // С .daily после закрытия tip не появится повторно в этот день.
            try Tips.configure([
                .displayFrequency(.daily),
                .datastoreLocation(.applicationDefault)
            ])
            logger.info("TipKit configured")
        } catch {
            logger.error(
                "TipKit configure failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
