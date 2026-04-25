import Foundation
import SwiftUI

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

    // MARK: - Failure

    enum Failure {
        struct Response: Sendable { let message: String }
        struct ViewModel: Sendable { let toastMessage: String }
    }
}

// MARK: - Domain types

/// `PermissionType` уже определён в App/AppCoordinator.swift
/// (microphone, camera, notifications).
/// Локальный реестр всех типов в порядке onboarding-flow.
enum PermissionTypeRegistry {
    static let onboardingOrder: [PermissionType] = [.microphone, .camera, .notifications]
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

/// Цветовой тон шага (соответствует ColorTokens.Brand.*).
enum PermissionAccent: String, Sendable, Equatable {
    case primary
    case lilac
    case butter

    var color: Color {
        switch self {
        case .primary: return ColorTokens.Brand.primary
        case .lilac:   return ColorTokens.Brand.lilac
        case .butter:  return ColorTokens.Brand.butter
        }
    }
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
    let accentColor: Color
    let state: PermissionState
    let showSettingsButton: Bool
    let isCompleted: Bool
    let accessibilityLabel: String
}
