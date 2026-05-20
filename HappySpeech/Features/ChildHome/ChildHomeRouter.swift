import SwiftUI

// MARK: - ChildHomeRoutingLogic

@MainActor
protocol ChildHomeRoutingLogic {
    func routeToParentHome()
    func routeToWorldMap(childId: String, sound: String)
    func routeToARZone()
    func routeToRewards(childId: String)
    func routeToLesson(childId: String, template: String)
    func routeToSessionHistory(childId: String)
    func routeToHomeTasks()
    func routeToSiblingMultiplayer(childId: String)
    func routeToSeasonalLesson(event: SeasonalEvent, childId: String)
    func routeToAchievements(childId: String)
    func routeToVoiceCloning(childId: String)
    func routeToArticulationGym()
    func routeToWordBank(childId: String)
    func routeToGrammarGame(childId: String)
    func routeToPhonemicListening(childId: String)
    func routeToSpeechTempo(childId: String)
    func routeToBreatheAndSpeak(childId: String)
    func routeToProsody(childId: String)
    func routeToRetelling(childId: String)
    func routeToLexicalThemes(childId: String)
    func routeToStorytelling(childId: String)
    func routeToCoPlay(childId: String)
    func routeToSyllableConstructor(childId: String)
    func routeToComprehensionDetective(childId: String)
    func routeToBedtimeMode(childId: String)
}

// MARK: - ChildHomeRouter

@MainActor
final class ChildHomeRouter: ChildHomeRoutingLogic {

    weak var coordinator: AppCoordinator?

    /// Опциональные коллбэки (M8.7) — позволяют вьюшке/тестам перехватывать
    /// навигацию без модификации `AppCoordinator`. Если коллбэк задан —
    /// он используется вместо стандартного маршрута.
    var onStartGame: ((_ childId: String, _ template: String) -> Void)?
    var onOpenHistory: ((_ childId: String) -> Void)?

    func routeToParentHome() {
        coordinator?.navigate(to: .parentHome)
    }

    func routeToWorldMap(childId: String, sound: String) {
        coordinator?.navigate(to: .worldMap(childId: childId, targetSound: sound))
    }

    func routeToARZone() {
        coordinator?.navigate(to: .arZone)
    }

    func routeToRewards(childId: String) {
        coordinator?.navigate(to: .rewards(childId: childId))
    }

    func routeToLesson(childId: String, template: String) {
        if let onStartGame {
            onStartGame(childId, template)
            return
        }
        coordinator?.navigate(to: .lessonPlayer(templateType: template, childId: childId))
    }

    func routeToSessionHistory(childId: String) {
        if let onOpenHistory {
            onOpenHistory(childId)
            return
        }
        coordinator?.navigate(to: .sessionHistory(childId: childId))
    }

    func routeToHomeTasks() {
        coordinator?.navigate(to: .homeTasks)
    }

    func routeToSiblingMultiplayer(childId: String) {
        coordinator?.navigate(to: .siblingMultiplayer(childId: childId))
    }

    func routeToSeasonalLesson(event: SeasonalEvent, childId: String) {
        coordinator?.navigate(to: .lessonPlayer(templateType: "repeat-after-model", childId: childId))
    }

    func routeToAchievements(childId: String) {
        coordinator?.navigate(to: .achievements(childId: childId))
    }

    /// Block T v17 — VoiceCloning «Голосовой архив».
    func routeToVoiceCloning(childId: String) {
        coordinator?.navigate(to: .voiceCloning(childId: childId))
    }

    /// F-302 v25 — ArticulationGym «Зарядка для язычка».
    func routeToArticulationGym() {
        coordinator?.navigate(to: .articulationGym(soundGroup: .hissing))
    }

    /// F-303 v25 — WordBank «Копилка слов».
    func routeToWordBank(childId: String) {
        coordinator?.navigate(to: .wordBank(childId: childId))
    }

    /// v26 2.1 — GrammarGame «Грамматика-игра».
    func routeToGrammarGame(childId: String) {
        coordinator?.navigate(to: .grammarGame(childId: childId))
    }

    /// v29 Фаза 8 Ф.5 — SoundTrafficLight «Звуковой светофор».
    func routeToSoundTrafficLight(childId: String) {
        coordinator?.navigate(to: .soundTrafficLight(childId: childId))
    }

    /// v29 Фаза 8 Ф.12 — PhonemicListening «Слушай внимательно».
    func routeToPhonemicListening(childId: String) {
        coordinator?.navigate(to: .phonemicListening(childId: childId))
    }

    /// v29 Фаза 8 Ф.6 — SpeechTempo «Темп-дорожка».
    func routeToSpeechTempo(childId: String) {
        coordinator?.navigate(to: .speechTempo(childId: childId))
    }

    /// v29 Фаза 8 Ф.10 — BreatheAndSpeak «Дыши и говори».
    func routeToBreatheAndSpeak(childId: String) {
        coordinator?.navigate(to: .breatheAndSpeak(childId: childId))
    }

    /// v29 Фаза 8 Ф.1 — Prosody «Голосовые краски».
    func routeToProsody(childId: String) {
        coordinator?.navigate(to: .prosody(childId: childId))
    }

    /// v29 Фаза 8 Ф.2 — Retelling «Расскажи по-настоящему».
    func routeToRetelling(childId: String) {
        coordinator?.navigate(to: .retelling(childId: childId))
    }

    /// v29 Фаза 8 Ф.7 — LexicalThemes «Мир слов».
    func routeToLexicalThemes(childId: String) {
        coordinator?.navigate(to: .lexicalThemes(childId: childId))
    }

    /// v29 Фаза 8 Ф.11 — Storytelling «Я расскажу историю».
    func routeToStorytelling(childId: String) {
        coordinator?.navigate(to: .storytelling(childId: childId))
    }

    /// v29 Фаза 8 Ф.8 — CoPlay «Занятие вместе».
    func routeToCoPlay(childId: String) {
        coordinator?.navigate(to: .coPlay(childId: childId))
    }

    /// v31 Волна B Ф.1 — SyllableConstructor «Слог-конструктор».
    func routeToSyllableConstructor(childId: String) {
        coordinator?.navigate(to: .syllableConstructor(childId: childId))
    }

    /// v31 Волна B Ф.2 — ComprehensionDetective «Понимание-детектив».
    func routeToComprehensionDetective(childId: String) {
        coordinator?.navigate(to: .comprehensionDetective(childId: childId))
    }

    /// v31 Волна B Ф.3 — BedtimeMode «Перед сном».
    func routeToBedtimeMode(childId: String) {
        coordinator?.navigate(to: .bedtimeMode(childId: childId))
    }
}
