import Foundation

// MARK: - Permissions VIP Models
//
// Универсальная state machine для последовательного запроса разрешений
// (микрофон → камера → уведомления). Используется и из Onboarding,
// и из Settings (deep-link к одному permission). FaceTracking — часть
// Camera permission, отдельно не запрашивается (iOS ограничение).

enum PermissionsModels {

    // MARK: - Start

    enum Start {
        struct Request: Sendable {
            /// Если задан — экран показывает только этот шаг (deep-link из Settings).
            /// Если nil — последовательный flow всех разрешений из Onboarding.
            let single: PermissionType?
        }

        struct Response: Sendable {
            let steps: [PermissionStep]
            let currentIndex: Int
            let isSingleMode: Bool
        }

        struct ViewModel: Sendable {
            let steps: [PermissionStepCard]
            let currentIndex: Int
            let progressLabel: String
            let isSingleMode: Bool
        }
    }

    // MARK: - Request (system permission dialog)

    enum RequestPermission {
        struct Request: Sendable {
            let type: PermissionType
        }

        struct Response: Sendable {
            let type: PermissionType
            let resultState: PermissionState
            let updatedSteps: [PermissionStep]
            let nextIndex: Int?
            let isFinished: Bool
        }

        struct ViewModel: Sendable {
            let steps: [PermissionStepCard]
            let currentIndex: Int
            let toastMessage: String?
            let isFinished: Bool
            /// Заполняется только когда `isFinished == true` и поток не single-mode.
            let allDoneCard: PermissionsAllDoneCard?
        }
    }

    // MARK: - Skip

    enum Skip {
        struct Request: Sendable {
            let type: PermissionType
        }

        struct Response: Sendable {
            let updatedSteps: [PermissionStep]
            let nextIndex: Int?
            let isFinished: Bool
        }

        struct ViewModel: Sendable {
            let steps: [PermissionStepCard]
            let currentIndex: Int
            let isFinished: Bool
            /// Заполняется только когда `isFinished == true` и поток не single-mode.
            let allDoneCard: PermissionsAllDoneCard?
        }
    }

    // MARK: - OpenSettings

    enum OpenSettings {
        struct Request: Sendable {}
        struct Response: Sendable {
            let url: URL?
        }
        struct ViewModel: Sendable {
            let url: URL?
            let toastMessage: String?
        }
    }

    // MARK: - CheckAllPermissions

    /// Проверяет текущее состояние всех разрешений без системного prompt.
    /// Используется на экране обзора разрешений (Settings → Разрешения).
    enum CheckAllPermissions {
        struct Request: Sendable {}

        struct Response: Sendable {
            let statuses: [PermissionType: PermissionState]
        }

        struct ViewModel: Sendable {
            let cards: [PermissionOverviewCard]
            let allGranted: Bool
            let grantedCount: Int
            let totalCount: Int
            let summaryLabel: String
        }
    }

    // MARK: - Failure

    enum Failure {
        struct Response: Sendable { let message: String }
        struct ViewModel: Sendable { let toastMessage: String }
    }
}

// MARK: - PermissionOverviewCard

/// Карточка обзора разрешения на экране Settings → Разрешения.
/// Отличается от `PermissionStepCard` — более компактная, без onboarding-логики.
struct PermissionOverviewCard: Sendable, Identifiable, Equatable {
    let id: PermissionType
    let icon: String
    let title: String
    let description: String
    let state: PermissionState
    /// Цветовой акцент карточки. Конвертацию в `Color` производить на стороне View.
    let accent: PermissionAccent
    let statusLabel: String
    let canRequest: Bool
    let showSettingsButton: Bool
    let accessibilityLabel: String
    let accessibilityHint: String
}

// MARK: - Domain types

/// `PermissionType` уже определён в App/AppCoordinator.swift
/// (microphone, camera, notifications).
/// Локальный реестр всех типов в порядке onboarding-flow.
enum PermissionTypeRegistry {
    static let onboardingOrder: [PermissionType] = [.microphone, .camera, .notifications, .faceTracking]
    /// Разрешения для экрана настроек (overview).
    static let settingsOrder: [PermissionType] = [.microphone, .camera, .notifications, .faceTracking]
}

enum PermissionState: Sendable, Equatable {
    case notDetermined
    case granted
    case denied
    case restricted
    case skipped
}

/// Доменная модель шага в state machine.
struct PermissionStep: Sendable, Identifiable, Equatable {
    let id: PermissionType
    let icon: String
    let title: String
    let description: String
    let allowTitle: String
    let privacyNote: String?
    let accentColor: PermissionAccent
    var state: PermissionState
}

/// Цветовой тон шага (соответствует `ColorTokens.Brand.*`).
/// Конвертацию в SwiftUI `Color` производить на стороне View через `.color`.
enum PermissionAccent: String, Sendable, Equatable {
    case primary
    case lilac
    case butter
    case mint
}

/// View-ready карточка одного шага. Все строки — уже локализованные.
struct PermissionStepCard: Sendable, Identifiable, Equatable {
    let id: PermissionType
    let icon: String
    let title: String
    let description: String
    let allowTitle: String
    let skipTitle: String
    let privacyNote: String?
    /// Цветовой акцент карточки. Конвертацию в `Color` производить на стороне View.
    let accent: PermissionAccent
    let state: PermissionState
    let showSettingsButton: Bool
    let isCompleted: Bool
    let accessibilityLabel: String
    let lyalyaState: LyalyaState
}

/// Финальный экран после прохождения всех шагов (sequential flow).
struct PermissionsAllDoneCard: Sendable, Equatable {
    let title: String
    let subtitle: String
    let ctaTitle: String
    let lyalyaState: LyalyaState
    let grantedCount: Int
    let totalCount: Int
}
