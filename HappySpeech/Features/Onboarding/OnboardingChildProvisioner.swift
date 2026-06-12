import Foundation
import OSLog

// MARK: - OnboardingChildProvisioning

/// Создаёт реальный ``ChildProfileDTO`` в Realm по итогам онбординга и помечает
/// его активным. Закрывает gap: фреш-онбординг собирал имя/возраст/пол/звуки/
/// нарушение ребёнка, но сохранял их только в `OnboardingState` (UserDefaults) —
/// в Realm профиля не появлялось. У нового пользователя не было реального
/// ребёнка, а единственная «создающая» точка (ParentHome → ProfileEditor) умела
/// лишь *редактировать* уже существующий профиль (`profileNotLoaded` иначе).
///
/// Протокол изолирует `OnboardingInteractor` от Data-слоя (Features импортируют
/// Data только через протоколы) и делает шаг провижининга mock-friendly для
/// юнит-тестов.
@MainActor
protocol OnboardingChildProvisioning: AnyObject {
    /// Идемпотентно создаёт профиль ребёнка из данных онбординга и делает его
    /// активным. Если эквивалентный профиль уже существует (то же имя+возраст) —
    /// дубликат не создаётся, активным помечается найденный.
    ///
    /// - Returns: id профиля (созданного или уже существовавшего), либо `nil`,
    ///   если роль не предполагает профиль ребёнка (специалист) или данные пусты.
    @discardableResult
    func provisionChild(from profile: OnboardingProfile) async -> String?
}

// MARK: - LiveOnboardingChildProvisioner

/// Боевая реализация: пишет ``ChildProfileDTO`` через ``ChildRepository``,
/// `parentId` берёт из ``AuthService`` (uid вошедшего родителя) либо
/// local-fallback для offline-first; активного ребёнка фиксирует через
/// инъецируемый сеттер (`ActiveChildStore` в проде).
@MainActor
final class LiveOnboardingChildProvisioner: OnboardingChildProvisioning {

    // MARK: - Collaborators

    private let childRepository: any ChildRepository
    private let authService: (any AuthService)?
    private let setActiveChild: @MainActor (String) -> Void
    private let logger = Logger(subsystem: "ru.happyspeech", category: "OnboardingChildProvisioner")

    /// Offline-first fallback: до входа родителя профиль принадлежит локальному
    /// «родителю». Совпадает с конвенцией остального оффлайн-кода (`local-parent`).
    private static let localParentId = "local-parent"

    // MARK: - Init

    init(
        childRepository: any ChildRepository,
        authService: (any AuthService)? = nil,
        setActiveChild: @escaping @MainActor (String) -> Void
    ) {
        self.childRepository = childRepository
        self.authService = authService
        self.setActiveChild = setActiveChild
    }

    // MARK: - Provisioning

    @discardableResult
    func provisionChild(from profile: OnboardingProfile) async -> String? {
        // Профиль ребёнка нужен только в родительском и детском контурах.
        // Специалист работает с чужими детьми — собственного профиля не создаём.
        guard profile.role == .parent || profile.role == .child else {
            logger.info("provisionChild skipped: role=\(profile.role.rawValue, privacy: .public)")
            return nil
        }

        let name = profile.childName.trimmingCharacters(in: .whitespacesAndNewlines)
        // Без имени профиль не создаём — иначе получим безымянного «ребёнка-сироту».
        guard name.count >= 2 else {
            logger.info("provisionChild skipped: name too short")
            return nil
        }

        let parentId = resolveParentId()

        do {
            // Идемпотентность: если родитель уже создал такого ребёнка (или
            // онбординг переигрывается), не плодим дубликаты.
            let existing = (try? await childRepository.fetchAll()) ?? []
            if let match = existing.first(where: {
                $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
                    && $0.age == clampedAge(profile.childAge)
                    && !$0.isArchived
            }) {
                SpeechDisorderStore.save(profile.disorder, childId: match.id)
                setActiveChild(match.id)
                logger.info("provisionChild: reused existing profile, marked active")
                return match.id
            }

            let dto = ChildProfileDTO(
                name: name,
                age: clampedAge(profile.childAge),
                targetSounds: mapSounds(profile.difficultSounds),
                parentId: parentId,
                avatarStyle: profile.childAvatar,
                colorTheme: colorTheme(for: profile.lyalyaPreset)
            )

            try await childRepository.save(dto)
            // Нарушение хранится вне Realm (per-child ключ) — как в ProfileEditor.
            SpeechDisorderStore.save(profile.disorder, childId: dto.id)
            setActiveChild(dto.id)
            logger.info("provisionChild: created real ChildProfile, marked active")
            return dto.id
        } catch {
            logger.error("provisionChild failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Private helpers

    /// Возраст из онбординга уже клампится (3...12), но дублируем границу здесь,
    /// чтобы провижинер был корректен при любом источнике профиля.
    private func clampedAge(_ age: Int) -> Int {
        max(3, min(12, age))
    }

    /// `parentId` — uid вошедшего НЕ-анонимного родителя, иначе offline-fallback.
    private func resolveParentId() -> String {
        guard let user = authService?.currentUser,
              !user.isAnonymous,
              !user.uid.isEmpty else {
            return Self.localParentId
        }
        return user.uid
    }

    /// Онбординг хранит трудные звуки как латинские id (`R`, `Sh`, ...), а
    /// ``ChildProfileDTO.targetSounds`` и весь контентный слой — как кириллические
    /// буквы (`Р`, `Ш`, ...). Маппим через каноничный список онбординга;
    /// неизвестные id отбрасываем (вместо записи мусорного таргета).
    private func mapSounds(_ ids: Set<String>) -> [String] {
        let lookup = Dictionary(
            OnboardingProfile.availableSounds.map { ($0.id, $0.label) },
            uniquingKeysWith: { first, _ in first }
        )
        return ids.compactMap { lookup[$0] }.sorted()
    }

    /// Пресет Ляли → цветовая тема профиля. Темы — из палитры приложения,
    /// валидны для `ProfileEditor` (`coral`/`blue`/`green`/`yellow`/`purple`).
    private func colorTheme(for preset: LyalyaPreset) -> String {
        switch preset {
        case .default: return "coral"
        case .sunny:   return "yellow"
        case .ocean:   return "blue"
        case .forest:  return "green"
        }
    }
}
