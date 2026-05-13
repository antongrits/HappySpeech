//
//  L10n.swift
//  HappySpeech
//
//  Plan v22 Block 2.4 — typed L10n accessors (manual stub).
//
//  ABOUT
//  -----
//  This file provides typed accessors for `Localizable.xcstrings` keys.
//  Каждый property возвращает локализованную строку через `String(localized:)`.
//
//  RATIONALE
//  ---------
//  - Predictable refactoring: changing key here breaks compilation, не runtime.
//  - Domain-aware grouping (Auth, ChildHome, etc.) против flat string lookup.
//  - Bridge для будущей миграции на SwiftGen auto-generated `L10n.swift`.
//
//  CURRENT SCOPE
//  -------------
//  Sample typed coverage (~30 keys) для critical paths: Auth, ChildHome,
//  ParentHome, Achievements, Demo, Onboarding. Production migration к
//  full coverage (4170+ keys) tracked в ADR-V22-L10N-SWIFTGEN-DEFER.
//
//  USAGE
//  -----
//  Replace:
//      Text(String(localized: "auth.sign_in"))
//  With:
//      Text(L10n.Auth.signIn)
//
//  Тип-safe, compile-time checked, IDE auto-complete enabled.

import Foundation

// MARK: - L10n

/// Typed L10n accessor namespace. Manual stub (v22 Block 2.4).
/// Full SwiftGen integration deferred to v23+ per
/// ADR-V22-L10N-SWIFTGEN-DEFER.
public enum L10n {

    // MARK: - Auth

    public enum Auth {
        public static var signIn: String {
            String(localized: "auth.sign_in", defaultValue: "Войти")
        }
        public static var signUp: String {
            String(localized: "auth.sign_up", defaultValue: "Зарегистрироваться")
        }
        public static var forgotPassword: String {
            String(localized: "auth.forgot_password", defaultValue: "Забыли пароль?")
        }
        public static var emailPlaceholder: String {
            String(localized: "auth.email.placeholder", defaultValue: "Email")
        }
        public static var passwordPlaceholder: String {
            String(localized: "auth.password.placeholder", defaultValue: "Пароль")
        }
    }

    // MARK: - ChildHome

    public enum ChildHome {
        public static var greeting: String {
            String(localized: "child_home.greeting", defaultValue: "Привет!")
        }
        public static var startLesson: String {
            String(localized: "child_home.start_lesson", defaultValue: "Начать урок")
        }
        public static var continueLesson: String {
            String(localized: "child_home.continue_lesson", defaultValue: "Продолжить")
        }
        public static var todayProgress: String {
            String(localized: "child_home.today_progress", defaultValue: "Прогресс сегодня")
        }
    }

    // MARK: - ParentHome

    public enum ParentHome {
        public static var dashboardTitle: String {
            String(localized: "parent_home.dashboard.title", defaultValue: "Прогресс ребёнка")
        }
        public static var weeklySummary: String {
            String(localized: "parent_home.weekly_summary", defaultValue: "За неделю")
        }
        public static var settings: String {
            String(localized: "parent_home.settings", defaultValue: "Настройки")
        }
    }

    // MARK: - Onboarding

    public enum Onboarding {
        public static var welcome: String {
            String(localized: "onboarding.welcome", defaultValue: "Добро пожаловать")
        }
        public static var next: String {
            String(localized: "onboarding.next", defaultValue: "Далее")
        }
        public static var skip: String {
            String(localized: "onboarding.skip", defaultValue: "Пропустить")
        }
        public static var done: String {
            String(localized: "onboarding.done", defaultValue: "Готово")
        }
    }

    // MARK: - Achievements

    public enum Achievements {
        public static var unlocked: String {
            String(localized: "achievements.unlocked", defaultValue: "Открыто")
        }
        public static var locked: String {
            String(localized: "achievements.locked", defaultValue: "Закрыто")
        }
        public static var firstSoundMastered: String {
            String(
                localized: "achievement.title.firstSoundMastered",
                defaultValue: "Первый освоенный звук"
            )
        }
    }

    // MARK: - Demo

    public enum Demo {
        public static var title: String {
            String(localized: "demo.title", defaultValue: "Демо")
        }
        public static var next: String {
            String(localized: "demo.next", defaultValue: "Дальше")
        }
        public static var back: String {
            String(localized: "demo.back", defaultValue: "Назад")
        }
        public static var skip: String {
            String(localized: "demo.skip", defaultValue: "Пропустить")
        }
    }

    // MARK: - Common Actions

    public enum Action {
        public static var ok: String {
            String(localized: "action.ok", defaultValue: "OK")
        }
        public static var cancel: String {
            String(localized: "action.cancel", defaultValue: "Отмена")
        }
        public static var save: String {
            String(localized: "action.save", defaultValue: "Сохранить")
        }
        public static var delete: String {
            String(localized: "action.delete", defaultValue: "Удалить")
        }
        public static var retry: String {
            String(localized: "action.retry", defaultValue: "Повторить")
        }
        public static var close: String {
            String(localized: "action.close", defaultValue: "Закрыть")
        }
    }

    // MARK: - Errors

    public enum ErrorMessage {
        public static var generic: String {
            String(localized: "error.generic", defaultValue: "Что-то пошло не так")
        }
        public static var network: String {
            String(localized: "error.network", defaultValue: "Нет соединения")
        }
        public static var microphonePermission: String {
            String(
                localized: "error.microphone_permission",
                defaultValue: "Нужно разрешение на микрофон"
            )
        }
    }
}
