import SwiftUI

// MARK: - ChildHomeRoutingLogic

@MainActor
protocol ChildHomeRoutingLogic {
    func routeToParentHome()
    func routeToWorldMap(childId: String, sound: String)
    func routeToARZone()
    func routeToRewards(childId: String)
    func routeToLesson(childId: String, template: String, targetSound: String)
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
    func routeToRewardShop(childId: String)
    func routeToLetterTrace(childId: String)
    // v31 Wave E
    func routeToKaraokePitch(childId: String)
    func routeToFingerPlay(childId: String)
    func routeToOralStoryCreator(childId: String)
    // v31 Wave F
    func routeToObjectDescriptionMap(childId: String)
    func routeToLogorhythmics(childId: String)
    // Wave 2 mechanics
    func routeToSoundDetective(childId: String)
    func routeToSyllableSnail(childId: String)
    func routeToFourthExtra(childId: String)
    func routeToWordFormation(childId: String)
    func routeToWhoseTail(childId: String)
    func routeToStoryLibrary(childId: String)
    // v32 Sprint 12 — 3 новые методически-ценные фичи
    func routeToSoundComposition(childId: String)
    func routeToVoicingSoftness(childId: String)
    func routeToListenYourself(childId: String)
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

    /// P0-2: `targetSound` — реальный звук активного ребёнка (из daily-mission).
    /// Пустая строка → `SessionShellInteractor` резолвит звук из профиля. Раньше
    /// маршрут не нёс звук вовсе и SessionShell хардкодил «Р».
    func routeToLesson(childId: String, template: String, targetSound: String = "") {
        if let onStartGame {
            onStartGame(childId, template)
            return
        }
        coordinator?.navigate(to: .lessonPlayer(
            templateType: template,
            childId: childId,
            targetSound: targetSound
        ))
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

    /// Открывает тематическую сессию активного сезонного события. `event` несёт
    /// методически обоснованную группу звуков (`event.targetSound`), которая реально
    /// наполнена словами с картинками в `word_manifest`; шаблон `listen-and-choose`
    /// строит word-picture сессию по этому звуку через стандартный игровой конвейер.
    /// Раньше `event` отбрасывался и хардкодился `repeat-after-model` без целевого
    /// звука — сезонный баннер вёл в нетематический урок чужого звука.
    func routeToSeasonalLesson(event: SeasonalEvent, childId: String) {
        coordinator?.navigate(to: .lessonPlayer(
            templateType: "listen-and-choose",
            childId: childId,
            targetSound: event.targetSound
        ))
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

    /// v31 Волна C Ф.1 — RewardShop «Магазин наград».
    func routeToRewardShop(childId: String) {
        coordinator?.navigate(to: .rewardShop(childId: childId))
    }

    /// v31 Волна C Ф.2 — LetterTrace «Пиши пальчиком/пером».
    func routeToLetterTrace(childId: String) {
        coordinator?.navigate(to: .letterTrace(childId: childId))
    }

    /// v31 Волна D Ф.1 — ReadAloudStory «Слушай и понимай».
    /// Khan Academy Kids gap (G-03): короткая история с озвучкой + 3-Q квиз.
    func routeToReadAloudStory(childId: String) {
        coordinator?.navigate(to: .readAloudStory(childId: childId))
    }

    /// v31 Wave E Ф.1 — Karaoke с pitch-контуром.
    func routeToKaraokePitch(childId: String) {
        coordinator?.navigate(to: .karaokePitch(childId: childId))
    }

    /// v31 Wave E Ф.2 — Пальчики-говоруны (Vision Hand Pose).
    func routeToFingerPlay(childId: String) {
        coordinator?.navigate(to: .fingerPlay(childId: childId))
    }

    /// v31 Wave E Ф.3 — Oral story creator.
    func routeToOralStoryCreator(childId: String) {
        coordinator?.navigate(to: .oralStoryCreator(childId: childId))
    }

    /// v31 Wave F Ф.2 — «Описательная карта» (план-схема Ткаченко).
    func routeToObjectDescriptionMap(childId: String) {
        coordinator?.navigate(to: .objectDescriptionMap(childId: childId))
    }

    /// v31 Wave F Ф.7 — «Логоритмика» (Картушина / Волкова).
    func routeToLogorhythmics(childId: String) {
        coordinator?.navigate(to: .logorhythmics(childId: childId))
    }

    /// v31 Wave F Ф.11 — «Билингвальный режим» (RU + BE/EN словарь + practice).
    func routeToBilingualMode(childId: String) {
        coordinator?.navigate(to: .bilingualMode(childId: childId))
    }

    /// F2-009 — «Звуковой детектив» (позиционный фонематический анализ).
    func routeToSoundDetective(childId: String) {
        coordinator?.navigate(to: .soundDetective(childId: childId))
    }

    /// F2-003 — «Слоговая улитка» (слоговая структура слова по Марковой).
    func routeToSyllableSnail(childId: String) {
        coordinator?.navigate(to: .syllableSnail(childId: childId))
    }

    /// F2-005 — «Четвёртый лишний» (классификация / обобщение).
    func routeToFourthExtra(childId: String) {
        coordinator?.navigate(to: .fourthExtra(childId: childId))
    }

    /// F2-007 — «Назови ласково / Один-много-нет» (словообразование +
    /// словоизменение: уменьш.-ласк. / число / родительный множ.).
    func routeToWordFormation(childId: String) {
        coordinator?.navigate(to: .wordFormation(childId: childId))
    }

    /// F2-006 — «Чей хвост / чей домик» (словообразование прилагательных:
    /// притяжательные / притяжательно-локативные / относительные).
    func routeToWhoseTail(childId: String) {
        coordinator?.navigate(to: .whoseTail(childId: childId))
    }

    /// F2-004 — «Конструктор предложения» (синтаксис: порядок слов, согласование,
    /// предлоги; последовательная сборка ленты слов-карточек).
    func routeToSentenceConstructor(childId: String) {
        coordinator?.navigate(to: .sentenceConstructor(childId: childId))
    }

    /// Stories — «Сказки Ляли» (каталог 20 анимированных историй).
    func routeToStoryLibrary(childId: String) {
        coordinator?.navigate(to: .storyLibrary(childId: childId))
    }

    /// v32 Sprint 12 — «Звуковая мастерская» (эльконинский звуковой
    /// анализ-синтез слова: схема-домик, цветные фишки, синтез-слияние).
    func routeToSoundComposition(childId: String) {
        coordinator?.navigate(to: .soundComposition(childId: childId))
    }

    /// v32 Sprint 12 — «Карта звонкости и мягкости» (дифференциация фонем:
    /// звонкий↔глухой, твёрдый↔мягкий + слова-ловушки).
    func routeToVoicingSoftness(childId: String) {
        coordinator?.navigate(to: .voicingSoftness(childId: childId))
    }

    /// v32 Sprint 12 — «Послушай себя» (слуховой самоконтроль: два дубля +
    /// A/B-сравнение с эталоном Ляли).
    func routeToListenYourself(childId: String) {
        coordinator?.navigate(to: .listenYourself(childId: childId))
    }
}
