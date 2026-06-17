// swiftlint:disable file_length
// AppCoordinator owns the entire AppRoute switch (140+ routes) and route
// build closures — keeping it as a single file is intentional because the
// switch must stay exhaustive in one place. Refactor planned post-v33.

import os.signpost
import OSLog
import SwiftUI

// MARK: - AppRoute

/// Top-level navigation routes.
enum AppRoute: Hashable {
    case splash
    case onboarding
    case roleSelect
    case childHome(childId: String)
    case parentHome
    case specialistHome
    case auth
    case signUp
    case forgotPassword
    case verifyEmail
    case settings
    case customization
    case offlineState
    case permissionFlow(PermissionType)
    case demoMode
    /// Итоги завершённой сессии. Несёт РЕАЛЬНЫЙ результат (childId/score/attempts/
    /// duration) — экран строит live-интерактор с включённой персистенцией
    /// (стикеры/стрик/ачивки пишутся в Realm). Демо-данные (`.sample`) — только
    /// для скриншот-тура / preview.
    case sessionComplete(result: SessionResult)
    /// Запуск шаблонного урока. `targetSound` — реальный звук активного ребёнка
    /// (из `ChildProfile.targetSounds` / daily-mission). Пустая строка означает
    /// «резолвить из профиля» — `SessionShellInteractor` подставит первый
    /// `targetSound` активного ребёнка. Раньше звук был захардкожен в «Р» на
    /// рендере, из-за чего ВСЕ быстрые входы тренировали Р независимо от ребёнка.
    case lessonPlayer(templateType: String, childId: String, targetSound: String = "")
    case worldMap(childId: String, targetSound: String)
    case arZone
    case rewards(childId: String)
    case progressDashboard(childId: String)
    case sessionHistory(childId: String)
    case homeTasks
    /// M6.16: Повторный скрининг из ParentHome.
    /// `age` — реальный возраст ребёнка (`ChildProfile.age`); возрастные нормы —
    /// ядро скоринга скрининга. Дефолт 6 — back-compat для вызовов без возраста
    /// (deep-link / Siri). Раньше возраст был захардкожен 6 на рендере → нормы
    /// были неверны для 5/7/8-летних.
    case screening(childId: String, age: Int = 6)
    case familyCalendar
    case familyVoice
    case familyVoiceSplit
    case familyVoiceLibrary
    case stutteringHome
    case fluencyDiaryParent
    case siblingMultiplayer(childId: String)
    case achievements(childId: String)
    // Block N: Family features
    case familyHome
    case comparisonDashboard
    case profileEditor(childId: String)
    // Block P: SharePlay — родитель запускает, COPPA-safe
    case sharePlay
    // Block T v17: новые экраны (T.1, T.3, T.4)
    case voiceCloning(childId: String)
    case pronunciationLeaderboard(parentId: String)
    case neurolinguistInsights(childId: String)
    // Block AE v21: extension screens (110+ target)
    case soundDictionary
    case helpCenter
    // Block AE batch 2 v21: gamification + parent insights + 3D cabinet
    case dailyChallenge(childId: String)
    case parentInsightsTimeline(childId: String)
    case familyAwardsCabinet(parentId: String)
    // v25 6.2: new features (F-301 / F-302 / F-303)
    case weeklyReport(childId: String, weekOffset: Int)
    case articulationGym(soundGroup: ArticulationSoundGroup)
    case wordBank(childId: String)
    // v26 2.1: ранее не подключённые экраны (полный VIP, недостижимы из навигации)
    case grammarGame(childId: String)
    case guidedTour
    case speechVisualization(word: String, targetSound: String)
    case arFaceFilter
    case dialectAdaptation(childId: String)
    case logopedistChat(parentId: String, specialistId: String)
    case culturalContent(childId: String)
    case weeklyChallenge(childId: String)
    // v29 Фаза 8: новые функции (Волна 1)
    case plainProgress(childId: String)
    case parentGuide(childId: String)
    case soundTrafficLight(childId: String)
    // v29 Фаза 8: новые функции (Волна 2)
    case phonemicListening(childId: String)
    case speechTempo(childId: String)
    case breatheAndSpeak(childId: String)
    // v29 Фаза 8: новые функции (Волна 3)
    case prosody(childId: String)
    case retelling(childId: String)
    case lexicalThemes(childId: String)
    case storytelling(childId: String)
    case coPlay(childId: String)
    case assignedHomework(specialistId: String)
    // v31 Волна A: новые методически-ценные функции
    case speechNormsEncyclopedia
    case dailyRitualsLyalya(kind: RitualKind)
    // v31 Волна B Ф.1: новый методически-ценный экран.
    case syllableConstructor(childId: String)
    // v31 Волна B Ф.2: импрессивная речь, понимание инструкции по Левиной.
    case comprehensionDetective(childId: String)
    // v31 Волна B Ф.3: спокойный вечерний поток — дыхание + история.
    case bedtimeMode(childId: String)
    // v31 Волна B Ф.4: родительские голосовые записки «Мамин голос».
    case parentVoiceNote(childId: String)

    // MARK: - v31 Волна C
    case rewardShop(childId: String)
    case letterTrace(childId: String)
    case customWordList(specialistId: String)

    // MARK: - v31 Волна D
    /// Ф.1 (kid): Read-aloud + comprehension quiz («Слушай и понимай»).
    case readAloudStory(childId: String)
    /// Ф.3 (specialist): 10-Q анкета первичной оценки ребёнка.
    case specialistAssessment(childId: String, specialistId: String)

    // MARK: - v31 Wave E (research F-02 / G-06, methodology Ф6 / Ф9)
    /// Wave E Ф.1 (kid): Karaoke pitch-контур — real-time pitch vs модель.
    case karaokePitch(childId: String)
    /// Wave E Ф.2 (kid): Пальчики-говоруны — Vision Hand Pose.
    case fingerPlay(childId: String)
    /// Wave E Ф.3 (kid): Oral story creator — 3 картинки → запись → ASR/TTR.
    case oralStoryCreator(childId: String)
    /// Wave E Ф.4 (parent): Speech growth diary — шифрованные видеоклипы.
    case speechGrowthDiary(childId: String)

    // MARK: - v31 Wave F (Object Description Map, методология Ткаченко)
    /// Wave F Ф.2 (kid): План-схема описания объекта (Ткаченко) —
    /// ребёнок описывает объект по 6–8 пиктограммам, ASR + анализ
    /// покрытия пунктов плана → 0…3 ★.
    case objectDescriptionMap(childId: String)
    /// Wave F Ф.7 (kid): Логоритмика (Картушина / Волкова) —
    /// chant-метроном, CMMotionManager детектит тапы по вертикальному
    /// ускорению, BeatScorer считает F1 совпадения с expected beats.
    case logorhythmics(childId: String)

    // MARK: - v31 Wave F F-05 (Daily Time Cap, NO Family Controls)
    /// Wave F F-05 (parent): дневной лимит времени в HappySpeech.
    /// Per-device cap + UserDefaults accounting; нет ScreenTime entitlement.
    case dailyTimeCap

    // MARK: - v31 Wave F Ф.11 (Bilingual Mode, методология Глухов/Цейтлин)
    /// Wave F Ф.11 (kid): двуязычный режим — словарик из 30+ слов с
    /// переводами на белорусский / английский, + tap-практика 10 раундов.
    /// Persistence выбора языка — UserDefaults("bilingualMode.secondLanguage").
    case bilingualMode(childId: String)

    // MARK: - v32 Sprint 12 (3 новых фичи end-to-end)

    /// B-028 (kid): «Грамота-старт» — мост от логопедии к чтению.
    /// Показывает кириллическую букву, 3 стартовых слова и переход
    /// к прописям (`letterTrace`).
    case literacyStart(targetSound: String)

    /// SoundOfTheDay (kid): сфокусированный звук дня + 3 быстрых
    /// активности. Снижает выбор-перегрузку перед сессией.
    case soundOfTheDay(childId: String)

    /// VoiceJournal (parent): дневник голоса ребёнка с локальными
    /// .m4a записями. Полностью offline / on-device.
    case voiceJournal(childId: String)

    // MARK: - v32 Family-engagement screens (FamilyChallenge / LyalyaMail / AchievementWall)

    /// FamilyChallenge (parent): еженедельный челлендж всей семьи —
    /// общая цель + вклад каждого + streak-индикатор.
    case familyChallenge(parentId: String)

    /// LyalyaMail (kid): «Письма от Ляли» — почтовый ящик с
    /// ежедневными мотивационными сообщениями.
    case lyalyaMail(childId: String)

    /// AchievementWall (kid): большая mosaic-стена со всеми
    /// достижениями + share стены через UIActivityViewController.
    case achievementWall(childId: String)

    // MARK: - v32 Batch B (12 lightweight modules)

    case morningRoutine(childId: String)
    case eveningReflection(childId: String)
    case dailyMissionsHub(childId: String)
    case soundExplorerMap(childId: String)
    case wordOfTheDay(childId: String)
    case speechHomeworkPlanner
    case parentMoodCheckIn
    case lyalyaPersonalCoach(childId: String)
    case weeklyRecap
    case childAchievementShare
    case audioMemoryGame(childId: String)
    case visualVocabularyFlip(childId: String)

    // MARK: - v32 Batch C wave 4 (15 lightweight modules)

    case goalTrackerKid(childId: String)
    case habitStreakDashboard(childId: String)
    case phonemeJourneyMap(childId: String)
    case tongueTwisterArena(childId: String)
    case storyEndingMaker(childId: String)
    case speechRiddles(childId: String)
    case animalSoundsBingo(childId: String)
    case letterPaintingFun(childId: String)
    case wordRhymeGame(childId: String)
    case sentenceBuilderKid(childId: String)
    case conversationStartersParent
    case weeklyParentTip
    case childLanguageMilestones
    case specialistCaseNotes(childId: String, specialistId: String)
    case specialistQuickAssessment(childId: String, specialistId: String)

    // MARK: - Wave 2 mechanics (F2-009 Звуковой детектив)

    /// F2-009 (kid): «Звуковой детектив» — позиционный фонематический анализ.
    /// Ребёнок ищет, где в слове прячется целевой звук (начало / середина /
    /// конец / нет). Уровни binary → ternary → withAbsent.
    case soundDetective(childId: String)

    /// F2-003 (kid): «Слоговая улитка» — слоговая структура слова по Марковой.
    /// Три режима: прохлопай (анализ) / выложи (синтез) / почини (коррекция
    /// перестановок и пропусков слогов). Уровни tier 1 → 4.
    case syllableSnail(childId: String)

    /// F2-005 (kid): «Четвёртый лишний» — классификация и обобщение. Из 4
    /// картинок убрать «лишнюю»: семантический (по категории/функции/среде)
    /// или фонетический (3 слова с целевым звуком + 1 без).
    case fourthExtra(childId: String)

    /// F2-007 (kid): «Назови ласково / Один-много-нет» — словообразование
    /// (уменьш.-ласк. суффиксы) + словоизменение (число, родительный множ.).
    /// Под-типы: diminutive / oneMany / manyOf. Выбор нормативной формы среди
    /// опций «норма vs ошибка-дистрактор».
    case wordFormation(childId: String)

    /// F2-006 (kid): «Чей хвост / чей домик» — словообразование прилагательных:
    /// притяжательные (лисий хвост, медвежья лапа), притяжательно-локативные
    /// (лисья нора) и относительные (деревянный стол). Под-типы: possessiveTail /
    /// animalHome / relativeMaterial. Сопоставление улики со зверем/материалом +
    /// озвучка целевой формы на hit (закрепление по слуху).
    case whoseTail(childId: String)

    /// F2-004 (kid): «Конструктор предложения» — синтаксис (порядок слов,
    /// согласование род/число, предлоги). ЕДИНСТВЕННАЯ механика с
    /// последовательной сборкой ленты слов-карточек (а не выбором одного
    /// ответа). Под-типы: wordOrder / agreement / preposition. Частичная оценка
    /// `matchesPartially` (точное совпадение → hit; ≥60% соседних пар или
    /// перепутан только предлог → almost) + озвучка фразы на hit.
    /// Имя `sentenceConstructor` — чтобы не конфликтовать с MVP
    /// `sentenceBuilderKid`.
    case sentenceConstructor(childId: String)

    // MARK: - v32 Batch D wave 5 (17 lightweight modules)

    case soundJournalKid(childId: String)
    case practiceReminderKid(childId: String)
    case storyRetellingPro(childId: String)
    case imitationLab(childId: String)
    case whisperGame(childId: String)
    case colorAndSound(childId: String)
    case musicalSoundDrums(childId: String)
    case palindromeHunter(childId: String)
    case phonemeFamilyMatcher(childId: String)
    case soundDoctorKid(childId: String)
    case parentDailyDigest
    case parentInspirationBoard
    case achievementCalendar(childId: String)
    case specialistSchedule(specialistId: String)
    case specialistResourcesLibrary(specialistId: String)
    case familyVoiceMessageHub

    // MARK: - Cad-task-1: Methodology Assistant (Vertex AI Search)

    /// Помощник по методике логопедии (parent / specialist за parental gate).
    /// Текстовые методические вопросы взрослого → обоснованный ответ + источники.
    /// COPPA: НИКОГДА из детского контура.
    case methodologyAssistant

    // MARK: - AR Sound Hunter (Vision room object hunting)

    /// «Звуковой охотник по комнате» (kid): задняя камера + Apple Vision
    /// (`ClassifyImageRequest`, iOS 18+) распознаёт предмет в комнате → ребёнок
    /// находит и называет предмет с целевым звуком → on-device скоринг. Фоллбэк
    /// на фото-карточки без камеры / на iOS 17. COPPA: всё on-device.
    case arSoundHunter(childId: String)

    // MARK: - A-09: Детальный пофонемный отчёт (specialist, паритет SpeechLP)

    /// Карта точности по целевым звукам ребёнка с историей по сессиям.
    /// Только реальные данные из истории сессий (`SessionRepository`); звуки
    /// без сессий помечаются «нет данных». COPPA: только из контура специалиста.
    case phonemeReport(childId: String)

    // MARK: - Stories: каталог анимированных историй («Сказки Ляли»)

    /// StoryLibrary (kid): каталог из 20 анимированных историй
    /// (`StoryLibrary.shared`). Тап по обложке проигрывает
    /// `AnimatedStoryPlayerView` (MP4 из `Videos/stories/<id>.mp4`).
    case storyLibrary(childId: String)

    // MARK: - п.26: Еженедельный видео-отчёт (Remotion)

    /// Анимированный видео-отчёт о прогрессе ребёнка за неделю (parent).
    /// Видео-фон — пред-рендеренный Remotion-шаблон, поверх — оверлей с
    /// реальными числами ребёнка из недельной агрегации `SessionRepository`.
    case weeklyVideoReport(childId: String)

    // MARK: - Акустическое зеркало (kid, on-device акустика сибилянтов)

    /// «Акустическое зеркало» (kid): ребёнок тянет С-С-С/Ш-Ш-Ш, vDSP-анализ
    /// спектрального центра тяжести показывает позицию его звука на континууме
    /// «Ш ↔ С» (биообратная связь). Без ML-моделей и сети — COPPA-safe.
    case acousticMirror(childId: String)

    /// «Скороговорка-ракета» (kid): ребёнок быстро/ровно повторяет слоговой ряд
    /// (па-та-ка), vDSP-детекция слоговых ядер по огибающей энергии измеряет темп
    /// диадохокинеза и ровность ритма (оромоторная разминка). Без ML и сети.
    case syllableRace(childId: String)

    // MARK: - Послушай себя (kid, слуховой самоконтроль)

    /// «Послушай себя» (kid): ребёнок записывает СВОЁ слово дважды, слушает оба
    /// дубля и САМ выбирает лучший, затем сравнивает с эталоном Ляли (A/B) и сам
    /// оценивает похожесть (эмодзи, без цифр). Опциональный «секретный совет»
    /// (ASR) — подсказка, не оценка, после выбора. Формирование слухового
    /// самоконтроля (Волкова/Левина). COPPA: запись локальна, on-device, не
    /// выгружается.
    case listenYourself(childId: String)

    // MARK: - Звуковая мастерская (kid, эльконинский звуковой анализ-синтез)

    /// «Звуковая мастерская» (kid): эльконинский звуковой анализ-синтез слова —
    /// картинка-схема + «домик» клеток по числу звуков, раскладка цветных фишек
    /// (гласный/твёрдый/мягкий) и синтез-слияние с бонус-цепочкой замены первого
    /// звука (мак→рак→лак). On-device, без сети.
    case soundComposition(childId: String)

    // MARK: - Карта звонкости и мягкости (kid, дифференциация фонем)

    /// «Карта звонкости и мягкости» (kid): сортировка слов/слогов по парам
    /// звонкий↔глухой и твёрдый↔мягкий + слова-ловушки. Дифференциация
    /// смешиваемых фонем (по Левиной / Ткаченко). On-device, без сети.
    case voicingSoftness(childId: String)

    // MARK: - Голосовые краски (kid, просодика: интонация/ударение/эмоция)

    /// «Голосовые краски» (kid): три просодических режима — типы интонации
    /// (вопрос/восклицание/спокойно) с дорожкой мелодии, логическое ударение
    /// (выделить главное слово голосом, RMS) и эмоциональная окраска голоса
    /// (весело/грустно/удивлённо, EmotionDetection). On-device, без штрафов.
    case voiceColors(childId: String)

    // MARK: - Рассказ по серии картинок (kid, связная речь)

    /// «Рассказ по серии картинок» (kid): связная речь по сюжетной серии
    /// (Глухов / Ткаченко) — drag-упорядочивание перемешанных кадров, запись
    /// рассказа по каждому кадру (AudioService + ASRService) с отметкой
    /// смысловых звеньев, плеер «мультика» + радар полноты завязка→действие→
    /// развязка. On-device, без сети. «Показать маме» — через parental gate.
    case storyPictures(childId: String)
}

enum PermissionType: Hashable {
    case microphone
    case camera
    case notifications
    /// ARKit Face Tracking — требует camera + ARKit, запрашивается через AVCaptureDevice.
    /// На устройствах без TrueDepth считается недоступным (ограничен до .camera).
    case faceTracking
}

// MARK: - AppCoordinator

/// Root coordinator — manages top-level navigation stack.
/// Features navigate by calling coordinator methods, not by direct routing.
@Observable
@MainActor
final class AppCoordinator {

    // MARK: - State

    var currentRoute: AppRoute = .splash
    var navigationPath = NavigationPath()
    var presentedSheet: AppSheet?
    var isShowingOfflineBanner: Bool = false
    var offlinePendingCount: Int = 0

    /// Latest auth snapshot. Updated by `bindAuthState(_:)`.
    private(set) var authUser: AuthUser?
    private var authHandle: Any?
    private weak var boundAuthService: (any AuthService)?

    // MARK: - Auth wiring

    /// Attaches an auth-state listener. Call once at app bootstrap.
    /// When the user signs in/out, root route is switched between `.auth` and role-select / home.
    func bindAuthState(_ service: any AuthService) {
        // Plan v22 Block 0.5 — AuthInit interval (Instruments Points of Interest).
        // Замеряет время на удаление прошлой подписки + установку нового listener'а.
        os_signpost(.begin,
                    log: HSSignpost.pointsOfInterest,
                    name: "AuthInit")
        defer {
            os_signpost(.end,
                        log: HSSignpost.pointsOfInterest,
                        name: "AuthInit")
        }

        // Remove previous binding if any.
        if let previousHandle = authHandle, let previousService = boundAuthService {
            previousService.removeAuthStateListener(previousHandle)
        }
        boundAuthService = service
        authHandle = service.addAuthStateListener { [weak self] user in
            Task { @MainActor [weak self] in
                self?.handleAuthChange(user)
            }
        }
    }

    private func handleAuthChange(_ user: AuthUser?) {
        authUser = user
        let uidLabel = user.map { "uid=\($0.uid)" } ?? "nil"
        HSLogger.auth.info("authState changed: \(uidLabel, privacy: .private)")

        // Don't interrupt splash transition or in-progress onboarding.
        switch currentRoute {
        case .splash, .onboarding, .permissionFlow:
            return
        default:
            break
        }

        if user == nil {
            // Signed out — go back to auth screen.
            navigate(to: .auth)
        }
        // Note: successful sign-in transitions are driven explicitly by Auth feature
        // (coordinator.navigate(to: .roleSelect)) so that verify-email flow can intervene.
    }

    // MARK: - Navigation

    func navigate(to route: AppRoute) {
        HSLogger.navigation.info("Navigate → \(String(describing: route))")
        withAnimation(MotionTokens.page) {
            currentRoute = route
        }
    }

    func push(_ route: AppRoute) {
        navigationPath.append(route)
    }

    func pop() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }

    func popToRoot() {
        navigationPath = NavigationPath()
    }

    func present(sheet: AppSheet) {
        presentedSheet = sheet
    }

    func dismissSheet() {
        presentedSheet = nil
    }

    func showOfflineBanner(pendingCount: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            isShowingOfflineBanner = true
            offlinePendingCount = pendingCount
        }
    }

    func hideOfflineBanner() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isShowingOfflineBanner = false
        }
    }

    /// P2-4: реальный дренаж offline-очереди по кнопке «Повторить» на баннере.
    /// Раньше `onRetry` был пустышкой `{ Task { } }` — нажатие ничего не делало,
    /// сессии, записанные офлайн, не уезжали в облако по запросу пользователя.
    /// Теперь дёргаем `syncService.drainQueue()`, обновляем счётчик pending и
    /// прячем баннер, если очередь опустела. Ошибку дренажа логируем и оставляем
    /// баннер — пользователь сможет повторить позже.
    func retryOfflineSync(using syncService: any SyncService) {
        Task { @MainActor [weak self] in
            do {
                try await syncService.drainQueue()
            } catch {
                HSLogger.sync.error("retryOfflineSync: drainQueue failed: \(error.localizedDescription, privacy: .public)")
            }
            let remaining = await syncService.pendingCount()
            guard let self else { return }
            self.offlinePendingCount = remaining
            if remaining == 0 {
                self.hideOfflineBanner()
            }
        }
    }

    // MARK: - v31 Wave F F-05 — Daily time cap gate

    /// Helper для child-экранов: проверяет, превышен ли дневной лимит,
    /// и если да — показывает `.capReached` sheet.
    /// Tracker — `DailyUsageTracking` из `AppContainer`. Безопасно вызывать
    /// многократно (sheet будет показан только если не показан ранее).
    func checkDailyCap(using tracker: any DailyUsageTracking) {
        guard tracker.isOverCap() else { return }
        if case .capReached = presentedSheet { return }
        HSLogger.navigation.info("Daily cap reached → presenting CapReached sheet")
        present(sheet: .capReached)
    }
}

// MARK: - AppSheet

enum AppSheet: Identifiable, Hashable {
    /// v31 Wave F F-05 — превышен дневной лимит, ребёнок видит «время вышло».
    case capReached

    var id: String {
        switch self {
        case .capReached: return "capReached"
        }
    }
}

// MARK: - AppCoordinatorView

/// Root view wired to AppCoordinator — switches between top-level screens.
struct AppCoordinatorView: View {
    @Bindable var coordinator: AppCoordinator
    @Environment(AppContainer.self) private var container

    var body: some View {
        // Wrap the entire navigation stack in the guided-tour container so the
        // spotlight + coach-mark overlay renders on top of whichever screen is
        // currently active. Individual screens register spotlight anchors via
        // `.spotlightAnchor(key:)` at strategic points (mascot, daily mission,
        // quick actions, etc).
        GuidedTourContainer(coordinator: container.guidedTourCoordinator) {
            ZStack(alignment: .top) {
                // Main content
                mainContent
                    .animation(MotionTokens.page, value: coordinator.currentRoute)
                    // Единый выход из детских мини-игр: игры запускаются через
                    // navigate(to:) (замена currentRoute), поэтому @Environment(\.dismiss)
                    // в них — no-op. exitGame восстанавливает корень детской главной.
                    // P1: выход из мини-игры восстанавливает дом РЕАЛЬНОГО активного
                    // ребёнка (из ActiveChildStore через container.currentChildId),
                    // а не пустой childId → пустой дом «Дружок» без данных.
                    .environment(\.exitGame, KidGameExitAction {
                        coordinator.navigate(to: .childHome(childId: container.currentChildId))
                    })
                    // Единый выход из полноэкранных parent/specialist-маршрутов:
                    // они тоже запускаются через navigate(to:), поэтому корневой
                    // @Environment(\.dismiss) — no-op. Эти действия восстанавливают
                    // корень соответствующей взрослой главной.
                    .environment(\.exitToParentHome, CircuitExitAction {
                        coordinator.navigate(to: .parentHome)
                    })
                    .environment(\.exitToSpecialistHome, CircuitExitAction {
                        coordinator.navigate(to: .specialistHome)
                    })

                // Offline banner (global)
                if coordinator.isShowingOfflineBanner {
                    HSOfflineBanner(
                        pendingCount: coordinator.offlinePendingCount,
                        onRetry: { coordinator.retryOfflineSync(using: container.syncService) }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
                }
            }
            .sheet(item: $coordinator.presentedSheet) { sheet in
                sheetContent(for: sheet)
            }
            // Нарративные кат-сцены «Путешествие Ляли» — fullScreen-overlay
            // поверх навигации и offline-banner. НЕ AppRoute (не раздуваем
            // back-stack). pending != nil → показываем CutscenePlayerView.
            .fullScreenCover(isPresented: Binding(
                get: { container.cutsceneService.pending != nil },
                set: { isPresented in
                    if !isPresented { container.cutsceneService.pop() }
                }
            )) {
                if let cutscene = container.cutsceneService.pending {
                    CutscenePlayerView(
                        cutscene: cutscene,
                        onFinish: { container.cutsceneService.pop() }
                    )
                    .environment(\.circuitContext, .kid)
                }
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch coordinator.currentRoute {
        case .splash:
            SplashView()
                .onAppear { launchSplash() }

        case .onboarding:
            OnboardingFlowView()
                .environment(\.circuitContext, .parent)

        case .roleSelect:
            RoleSelectView()

        case .childHome(let childId):
            ChildHomeView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .parentHome:
            ParentHomeView()
                .environment(\.circuitContext, .parent)

        case .specialistHome:
            SpecialistHomeView()
                .environment(\.circuitContext, .specialist)

        case .auth:
            AuthSignInView()

        case .signUp:
            AuthSignUpView()

        case .forgotPassword:
            AuthForgotPasswordView()

        case .verifyEmail:
            AuthVerifyEmailView()

        case .settings:
            SettingsView()

        case .customization:
            // P0-2 fix: customization route registered for HSStartRoute support
            // (Plan v32 design audit). Раньше CustomizationView был достижим
            // только из Settings → "Наряд Ляли", без deep-link для скриншот-тура.
            NavigationStack { CustomizationView() }

        case .offlineState:
            OfflineStateView()

        case .permissionFlow(let type):
            PermissionFlowView(type: type)

        case .demoMode:
            DemoModeView()

        case .sessionComplete(let result):
            // Реальный результат сессии → live SessionComplete с включённой
            // персистенцией (стикеры/стрик/ачивки пишутся в Realm). Возврат —
            // на главную реального ребёнка (childId из результата), а не в пустую.
            SessionCompleteView(
                result: result,
                onContinue: { coordinator.navigate(to: .childHome(childId: result.childId)) },
                onReplay: { coordinator.navigate(to: .childHome(childId: result.childId)) }
            )

        case .lessonPlayer(let templateType, let childId, let targetSound):
            // P0-2: звук берётся из маршрута (реальный звук ребёнка из daily-mission/
            // профиля), а не хардкодится «Р». Если маршрут пришёл с пустым звуком
            // (старые вызовы / Siri / Spotlight), `SessionShellInteractor`
            // резолвит первый `targetSound` активного ребёнка из профиля.
            SessionShellView(
                childId: childId.isEmpty ? container.currentChildId : childId,
                targetSoundId: targetSound,
                sessionType: templateType.isEmpty ? .adaptive : .quickPractice,
                forcedGameType: GameType.fromTemplateRoute(templateType),
                container: container,
                coordinator: coordinator
            )
            .environment(\.circuitContext, .kid)

        case .worldMap(let childId, let targetSound):
            WorldMapView(childId: childId, targetSound: targetSound)
                .environment(\.circuitContext, .kid)

        case .arZone:
            ARZoneView()
                .environment(\.circuitContext, .kid)

        case .rewards(let childId):
            RewardsView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .progressDashboard(let childId):
            ProgressDashboardView(childId: childId)
                .environment(\.circuitContext, .parent)

        case .sessionHistory(let childId):
            SessionHistoryView(childId: childId)
                .environment(\.circuitContext, .parent)

        case .homeTasks:
            HomeTasksView(
                onStartGame: { exerciseType, targetSound in
                    // P0-2: прокидываем реальный звук задания (из HomeTask.targetSound),
                    // а не теряем его — иначе урок тренировал бы хардкод-звук.
                    coordinator.navigate(to: .lessonPlayer(
                        templateType: exerciseType,
                        childId: container.currentChildId,
                        targetSound: targetSound
                    ))
                }
            )
            .environment(\.circuitContext, .parent)

        case .screening(let childId, let age):
            // P1: возрастные нормы скрининга берутся из реального возраста ребёнка
            // (передаётся вызывающей стороной из профиля), а не хардкод 6.
            ScreeningView(
                childId: childId,
                childAge: age,
                onFinish: { _ in coordinator.navigate(to: .parentHome) },
                onCancel: { coordinator.navigate(to: .parentHome) }
            )
            .environment(\.circuitContext, .parent)

        case .familyCalendar:
            NavigationStack {
                FamilyCalendarView()
            }
            .environment(\.circuitContext, .parent)

        case .familyVoice:
            NavigationStack {
                FamilyVoiceView(parentId: "local-parent")
            }
            .environment(\.circuitContext, .parent)

        case .familyVoiceSplit:
            NavigationStack {
                FamilyVoiceSplitView(
                    recordings: [],
                    parentId: "local-parent",
                    realmActor: container.realmActor
                )
            }
            .environment(\.circuitContext, .parent)

        case .familyVoiceLibrary:
            NavigationStack {
                FamilyVoiceLibraryView(parentId: "local-parent")
            }
            .environment(\.circuitContext, .parent)

        case .stutteringHome:
            NavigationStack {
                StutteringView()
            }
            .environment(\.circuitContext, .kid)

        case .fluencyDiaryParent:
            NavigationStack {
                FluencyDiaryParentView()
            }
            .environment(\.circuitContext, .parent)

        case .siblingMultiplayer(let childId):
            SiblingMultiplayerView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .achievements(let childId):
            NavigationStack {
                AchievementsView(childId: childId)
            }
            .environment(\.circuitContext, .kid)

        case .familyHome:
            FamilyHomeView()
                .environment(\.circuitContext, .parent)

        case .comparisonDashboard:
            ComparisonDashboardView()
                .environment(\.circuitContext, .parent)

        case .profileEditor(let childId):
            ProfileEditorView(
                childId: childId,
                onClose: { coordinator.navigate(to: .parentHome) }
            )
            .environment(\.circuitContext, .parent)

        case .sharePlay:
            SharePlayView()
                .environment(\.circuitContext, .parent)

        // MARK: - Block T v17

        case .voiceCloning(let childId):
            NavigationStack {
                VoiceCloningView(childId: childId)
            }
            .environment(\.circuitContext, .kid)

        case .pronunciationLeaderboard(let parentId):
            NavigationStack {
                PronunciationLeaderboardView(parentId: parentId)
            }
            .environment(\.circuitContext, .parent)

        case .neurolinguistInsights(let childId):
            NavigationStack {
                NeurolinguistInsightsView(childId: childId)
            }
            .environment(\.circuitContext, .parent)

        // MARK: - Block AE v21

        case .soundDictionary:
            SoundDictionaryView()
                .environment(\.circuitContext, .parent)

        case .helpCenter:
            HelpCenterView()
                .environment(\.circuitContext, .parent)

        // MARK: - Block AE batch 2 v21

        case .dailyChallenge(let childId):
            DailyChallengeView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .parentInsightsTimeline(let childId):
            ParentInsightsTimelineView(childId: childId)
                .environment(\.circuitContext, .parent)

        case .familyAwardsCabinet(let parentId):
            FamilyAwardsCabinetView(parentId: parentId)
                .environment(\.circuitContext, .parent)

        // MARK: - v25 6.2: F-301 / F-302 / F-303

        case .weeklyReport(let childId, let weekOffset):
            WeeklySoundReportView(childId: childId, weekOffset: weekOffset)
                .environment(\.circuitContext, .parent)

        case .articulationGym(let soundGroup):
            ArticulationGymView(
                childId: container.currentChildId,
                soundGroup: soundGroup
            )
            .environment(\.circuitContext, .kid)

        case .wordBank(let childId):
            WordBankView(childId: childId)
                .environment(\.circuitContext, .kid)

        // MARK: - v26 2.1: ранее не подключённые экраны

        case .grammarGame(let childId):
            GrammarGameScene(childId: childId)
                .environment(\.circuitContext, .kid)

        case .guidedTour:
            GuidedTourLaunchView()
                .environment(\.circuitContext, .kid)

        case .speechVisualization(let word, let targetSound):
            NavigationStack {
                SpeechVisualizationView(word: word, targetSound: targetSound)
            }
            .environment(\.circuitContext, .parent)

        case .arFaceFilter:
            ARFaceFilterView()
                .environment(\.circuitContext, .kid)

        case .dialectAdaptation(let childId):
            NavigationStack {
                DialectAdaptationView(childId: childId)
            }
            .environment(\.circuitContext, .parent)

        case .logopedistChat(let parentId, let specialistId):
            NavigationStack {
                LogopedistChatView(parentId: parentId, specialistId: specialistId)
            }
            .environment(\.circuitContext, .parent)

        case .culturalContent(let childId):
            NavigationStack {
                CulturalContentView(childId: childId)
            }
            .environment(\.circuitContext, .kid)

        case .weeklyChallenge(let childId):
            NavigationStack {
                WeeklyChallengeView(childId: childId)
            }
            .environment(\.circuitContext, .kid)

        // MARK: - v29 Фаза 8: Волна 1

        case .plainProgress(let childId):
            PlainProgressView(childId: childId)
                .environment(\.circuitContext, .parent)

        case .parentGuide(let childId):
            ParentGuideView(childId: childId)
                .environment(\.circuitContext, .parent)

        case .soundTrafficLight(let childId):
            SoundTrafficLightView(childId: childId)
                .environment(\.circuitContext, .kid)

        // MARK: - v29 Фаза 8: Волна 2

        case .phonemicListening(let childId):
            PhonemicListeningView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .speechTempo(let childId):
            SpeechTempoView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .breatheAndSpeak(let childId):
            BreatheAndSpeakView(childId: childId)
                .environment(\.circuitContext, .kid)

        // MARK: - v29 Фаза 8: Волна 3

        case .prosody(let childId):
            ProsodyView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .retelling(let childId):
            RetellingView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .lexicalThemes(let childId):
            LexicalThemesView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .storytelling(let childId):
            StorytellingView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .coPlay(let childId):
            CoPlayView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .assignedHomework(let specialistId):
            AssignedHomeworkView(specialistId: specialistId)
                .environment(\.circuitContext, .specialist)

        // MARK: - v31 Волна A

        case .speechNormsEncyclopedia:
            SpeechNormsEncyclopediaView()
                .environment(\.circuitContext, .parent)

        case .dailyRitualsLyalya(let kind):
            DailyRitualsLyalyaView(kind: kind)
                .environment(\.circuitContext, .parent)

        // MARK: - v31 Волна B Ф.1

        case .syllableConstructor(let childId):
            SyllableConstructorView(childId: childId)
                .environment(\.circuitContext, .kid)

        // MARK: - v31 Волна B Ф.2

        case .comprehensionDetective(let childId):
            ComprehensionDetectiveView(childId: childId)
                .environment(\.circuitContext, .kid)

        // MARK: - v31 Волна B Ф.3

        case .bedtimeMode(let childId):
            BedtimeModeView(childId: childId)
                .environment(\.circuitContext, .kid)

        // MARK: - v31 Волна B Ф.4

        case .parentVoiceNote(let childId):
            ParentVoiceNoteView(childId: childId)
                .environment(\.circuitContext, .parent)

        // MARK: - v31 Волна C

        case .rewardShop(let childId):
            RewardShopView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .letterTrace(let childId):
            LetterTraceView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .customWordList(let specialistId):
            CustomWordListView(specialistId: specialistId)
                .environment(\.circuitContext, .specialist)

        // MARK: - v31 Волна D

        case .readAloudStory(let childId):
            ReadAloudStoryView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .specialistAssessment(let childId, let specialistId):
            SpecialistAssessmentView(childId: childId, specialistId: specialistId)
                .environment(\.circuitContext, .specialist)

        // MARK: - v31 Wave E

        case .karaokePitch(let childId):
            KaraokePitchView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .fingerPlay(let childId):
            FingerPlayView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .oralStoryCreator(let childId):
            OralStoryCreatorView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .speechGrowthDiary(let childId):
            SpeechGrowthDiaryView(childId: childId)
                .environment(\.circuitContext, .parent)

        // MARK: - v31 Wave F Ф.2

        case .objectDescriptionMap(let childId):
            ObjectDescriptionMapView(childId: childId)
                .environment(\.circuitContext, .kid)

        // MARK: - v31 Wave F Ф.7

        case .logorhythmics(let childId):
            LogorhythmicsView(childId: childId)
                .environment(\.circuitContext, .kid)

        // MARK: - v31 Wave F F-05

        case .dailyTimeCap:
            DailyTimeCapView()
                .environment(\.circuitContext, .parent)

        // MARK: - v31 Wave F Ф.11

        case .bilingualMode(let childId):
            BilingualModeView(childId: childId)
                .environment(\.circuitContext, .kid)

        // MARK: - v32 Sprint 12

        case .literacyStart(let targetSound):
            LiteracyStartView(
                targetSound: targetSound,
                childId: container.currentChildId
            )
            .environment(\.circuitContext, .kid)

        case .soundOfTheDay(let childId):
            SoundOfTheDayView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .voiceJournal(let childId):
            VoiceJournalView(childId: childId)
                .environment(\.circuitContext, .parent)

        // MARK: - v32 Family-engagement screens

        case .familyChallenge(let parentId):
            FamilyChallengeView(parentId: parentId)
                .environment(\.circuitContext, .parent)

        case .lyalyaMail(let childId):
            LyalyaMailView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .achievementWall(let childId):
            AchievementWallView(childId: childId)
                .environment(\.circuitContext, .kid)

        // MARK: - v32 Batch B (12 lightweight modules)

        case .morningRoutine(let childId):
            MorningRoutineView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .eveningReflection(let childId):
            EveningReflectionView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .dailyMissionsHub(let childId):
            DailyMissionsHubView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .soundExplorerMap(let childId):
            SoundExplorerMapView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .wordOfTheDay(let childId):
            WordOfTheDayView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .speechHomeworkPlanner:
            SpeechHomeworkPlannerView()
                .environment(\.circuitContext, .parent)

        case .parentMoodCheckIn:
            ParentMoodCheckInView()
                .environment(\.circuitContext, .parent)

        case .lyalyaPersonalCoach(let childId):
            LyalyaPersonalCoachView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .weeklyRecap:
            WeeklyRecapView()
                .environment(\.circuitContext, .parent)

        case .childAchievementShare:
            ChildAchievementShareView()
                .environment(\.circuitContext, .parent)

        case .audioMemoryGame(let childId):
            AudioMemoryGameView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .visualVocabularyFlip(let childId):
            VisualVocabularyFlipView(childId: childId)
                .environment(\.circuitContext, .kid)

        // MARK: - v32 Batch C wave 4 (15 lightweight modules)

        case .goalTrackerKid(let childId):
            GoalTrackerKidView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .habitStreakDashboard(let childId):
            HabitStreakDashboardView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .phonemeJourneyMap(let childId):
            PhonemeJourneyMapView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .tongueTwisterArena(let childId):
            TongueTwisterArenaView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .storyEndingMaker(let childId):
            StoryEndingMakerView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .speechRiddles(let childId):
            SpeechRiddlesView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .animalSoundsBingo(let childId):
            AnimalSoundsBingoView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .letterPaintingFun(let childId):
            LetterPaintingFunView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .wordRhymeGame(let childId):
            WordRhymeGameView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .sentenceBuilderKid(let childId):
            SentenceBuilderKidView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .conversationStartersParent:
            ConversationStartersParentView()
                .environment(\.circuitContext, .parent)

        case .weeklyParentTip:
            WeeklyParentTipView()
                .environment(\.circuitContext, .parent)

        case .childLanguageMilestones:
            ChildLanguageMilestonesView()
                .environment(\.circuitContext, .parent)

        case .specialistCaseNotes(let childId, let specialistId):
            SpecialistCaseNotesView(childId: childId, specialistId: specialistId)
                .environment(\.circuitContext, .specialist)

        case .specialistQuickAssessment(let childId, let specialistId):
            SpecialistQuickAssessmentView(childId: childId, specialistId: specialistId)
                .environment(\.circuitContext, .specialist)

        // MARK: - Wave 2 mechanics (F2-009 Звуковой детектив)

        case .soundDetective(let childId):
            SoundDetectiveView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .syllableSnail(let childId):
            SyllableSnailView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .fourthExtra(let childId):
            FourthExtraView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .wordFormation(let childId):
            WordFormationView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .whoseTail(let childId):
            WhoseTailView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .sentenceConstructor(let childId):
            SentenceBuilderView(childId: childId)
                .environment(\.circuitContext, .kid)

        // MARK: - v32 Batch D wave 5 (17 lightweight modules)

        case .soundJournalKid(let childId):
            SoundJournalKidView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .practiceReminderKid(let childId):
            PracticeReminderKidView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .storyRetellingPro(let childId):
            StoryRetellingProView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .imitationLab(let childId):
            ImitationLabView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .whisperGame(let childId):
            WhisperGameView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .colorAndSound(let childId):
            ColorAndSoundView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .musicalSoundDrums(let childId):
            MusicalSoundDrumsView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .palindromeHunter(let childId):
            PalindromeHunterView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .phonemeFamilyMatcher(let childId):
            PhonemeFamilyMatcherView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .soundDoctorKid(let childId):
            SoundDoctorKidView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .parentDailyDigest:
            ParentDailyDigestView()
                .environment(\.circuitContext, .parent)

        case .parentInspirationBoard:
            ParentInspirationBoardView()
                .environment(\.circuitContext, .parent)

        case .achievementCalendar(let childId):
            AchievementCalendarView(childId: childId)
                .environment(\.circuitContext, .parent)

        case .specialistSchedule(let specialistId):
            SpecialistScheduleView(specialistId: specialistId)
                .environment(\.circuitContext, .specialist)

        case .specialistResourcesLibrary(let specialistId):
            SpecialistResourcesLibraryView(specialistId: specialistId)
                .environment(\.circuitContext, .specialist)

        case .familyVoiceMessageHub:
            FamilyVoiceMessageHubView()
                .environment(\.circuitContext, .parent)

        // MARK: - Cad-task-1: Methodology Assistant

        case .methodologyAssistant:
            MethodologyAssistantView()
                .environment(\.circuitContext, .parent)

        // MARK: - AR Sound Hunter

        case .arSoundHunter(let childId):
            NavigationStack {
                ARSoundHunterView(childId: childId)
            }
            .environment(\.circuitContext, .kid)

        // MARK: - A-09: Детальный пофонемный отчёт

        case .phonemeReport(let childId):
            PhonemeReportView(childId: childId)
                .environment(\.circuitContext, .specialist)

        // MARK: - Stories: каталог анимированных историй

        case .storyLibrary(let childId):
            StoryLibraryView(childId: childId)
                .environment(\.circuitContext, .kid)

        // MARK: - п.26: Еженедельный видео-отчёт (Remotion)

        case .weeklyVideoReport(let childId):
            WeeklyVideoReportView(childId: childId)
                .environment(\.circuitContext, .parent)

        // MARK: - Акустическое зеркало

        case .acousticMirror(let childId):
            AcousticMirrorView(childId: childId)
                .environment(\.circuitContext, .kid)

        // MARK: - Скороговорка-ракета (диадохокинез)

        case .syllableRace(let childId):
            SyllableRaceView(childId: childId.isEmpty ? container.currentChildId : childId)
                .environment(\.circuitContext, .kid)

        // MARK: - Послушай себя (слуховой самоконтроль)

        case .listenYourself(let childId):
            ListenYourselfView(childId: childId.isEmpty ? container.currentChildId : childId)
                .environment(\.circuitContext, .kid)

        // MARK: - Звуковая мастерская (эльконинский звуковой анализ-синтез)

        case .soundComposition(let childId):
            SoundCompositionView(childId: childId.isEmpty ? container.currentChildId : childId)
                .environment(\.circuitContext, .kid)

        // MARK: - Карта звонкости и мягкости (дифференциация фонем)

        case .voicingSoftness(let childId):
            VoicingSoftnessView(childId: childId.isEmpty ? container.currentChildId : childId)
                .environment(\.circuitContext, .kid)

        // MARK: - Голосовые краски (просодика: интонация/ударение/эмоция)

        case .voiceColors(let childId):
            VoiceColorsView(childId: childId.isEmpty ? container.currentChildId : childId)
                .environment(\.circuitContext, .kid)

        // MARK: - Рассказ по серии картинок (связная речь, серия сюжетов)

        case .storyPictures(let childId):
            StoryPicturesView(childId: childId.isEmpty ? container.currentChildId : childId)
                .environment(\.circuitContext, .kid)
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: AppSheet) -> some View {
        switch sheet {
        case .capReached:
            CapReachedView()
                .interactiveDismissDisabled(true)
        }
    }

    private func launchSplash() {
        // Debug screenshot-tour shortcut: launch with -HSStartRoute <route> to skip splash.
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-HSStartRoute"), idx + 1 < args.count {
            let route = args[idx + 1]
            // Для скриншот-тура самого splash не навигируем — иначе содержимое
            // splash не успевает отрисоваться, screenshot ловит пустой экран.
            if route == "splash" { return }
            let target = Self.resolveStartRoute(route)
            coordinator.navigate(to: target)
            return
        }
        // UI-test: при -UITestOffline сразу открываем OfflineStateView — NetworkMonitor
        // уже выставлен в isConnected=false в AppContainer.makeContainer().
        if ProcessInfo.processInfo.arguments.contains("-UITestOffline") {
            coordinator.navigate(to: .offlineState)
            return
        }

        // Auto-transition from splash after delay.
        // First launch (онбординг не пройден) → показываем 10-шаговый онбординг.
        // В противном случае идём в auth — пользователь либо войдёт, либо
        // зарегистрируется и попадёт в roleSelect.
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            await MainActor.run {
                let target: AppRoute = OnboardingState.isCompleted ? .auth : .onboarding
                coordinator.navigate(to: target)
            }
        }
    }
}

// MARK: - HSStartRoute mapping (v22 Block 0.2)

extension AppCoordinatorView {

    /// Maps a `-HSStartRoute <name>` debug argument to an `AppRoute`.
    ///
    /// Block 0.2 v22 expansion (104 entries): existing 19 base routes + 85 new
    /// routes spanning auth, onboarding (10), lesson templates (16), AR (9),
    /// session (8), settings sub (10), demo (4), family (6), specialist (5),
    /// stuttering (5), misc (11), R+AE (11).
    ///
    /// Strategy:
    /// - Lesson templates → `.lessonPlayer(templateType:)` with kebab-case
    ///   slug matching `GameType.fromTemplateRoute` (16 distinct screenshots).
    /// - Sub-screens of single-root features (onboarding, AR, settings, demo)
    ///   fall back to root `AppRoute` — capture serves as baseline.
    /// - Aliases for already-supported routes (anonymousAuth → .auth,
    ///   authSignUp → .signUp, etc.).
    /// - Unknown / unimplemented routes return `.auth` (default fallback).
    ///
    /// This helper is intentionally side-effect-free and pure to keep the
    /// `launchSplash` flow simple and unit-testable.
    static func resolveStartRoute(_ route: String) -> AppRoute {
        // swiftlint:disable:previous cyclomatic_complexity function_body_length

        let previewChild = "preview-child-1"
        let previewChild2 = "preview-child-2"
        let previewParent = "local-parent"

        switch route {
        // MARK: Base 19 routes (unchanged from pre-v22 behaviour)
        case "demoMode":            return .demoMode
        case "parentHome":          return .parentHome
        case "roleSelect":          return .roleSelect
        case "onboarding":          return .onboarding
        case "settings":            return .settings
        case "customization":       return .customization
        case "offlineState":        return .offlineState
        case "childHome":           return .childHome(childId: previewChild)
        case "progressDashboard":   return .progressDashboard(childId: previewChild)
        case "rewards":             return .rewards(childId: previewChild)
        case "worldMap":            return .worldMap(childId: previewChild, targetSound: "Р")
        case "sessionHistory":      return .sessionHistory(childId: previewChild)
        case "sessionComplete":     return .sessionComplete(result: .sample)
        case "arZone":              return .arZone
        case "lessonPlayer":        return .lessonPlayer(templateType: "bingo", childId: previewChild)
        case "familyVoice":         return .familyVoice
        case "stuttering":          return .stutteringHome
        case "fluencyDiary":        return .fluencyDiaryParent
        case "siblingMultiplayer":  return .siblingMultiplayer(childId: previewChild)
        case "auth":                return .auth

        // MARK: Tier 1 — Auth + Onboarding 10 + role/home (20)
        case "authSignUp":          return .signUp
        case "authForgotPassword":  return .forgotPassword
        case "authVerifyEmail":     return .verifyEmail
        case "anonymousAuth":       return .auth
        case "splash":              return .splash
        case "specialistHome":      return .specialistHome
        case "childHome2":          return .childHome(childId: previewChild2)
        case "onboarding1",
             "onboarding2",
             "onboarding3",
             "onboarding4",
             "onboarding5",
             "onboarding6",
             "onboarding7",
             "onboarding8",
             "onboarding9",
             "onboarding10":
            return .onboarding

        // MARK: Tier 2 — LessonPlayer 16 templates
        case "lessonListenAndChoose":
            return .lessonPlayer(templateType: "listen-and-choose", childId: previewChild)
        case "lessonRepeatAfterModel":
            return .lessonPlayer(templateType: "repeat-after-model", childId: previewChild)
        case "lessonDragAndMatch":
            return .lessonPlayer(templateType: "drag-and-match", childId: previewChild)
        case "lessonStoryCompletion":
            return .lessonPlayer(templateType: "story-completion", childId: previewChild)
        case "lessonPuzzleReveal":
            return .lessonPlayer(templateType: "puzzle-reveal", childId: previewChild)
        case "lessonSorting":
            return .lessonPlayer(templateType: "sorting", childId: previewChild)
        case "lessonMemory":
            return .lessonPlayer(templateType: "memory", childId: previewChild)
        case "lessonBingo":
            return .lessonPlayer(templateType: "bingo", childId: previewChild)
        case "lessonSoundHunter":
            return .lessonPlayer(templateType: "sound-hunter", childId: previewChild)
        case "lessonArticulationImitation":
            return .lessonPlayer(templateType: "articulation-imitation", childId: previewChild)
        case "lessonARActivity":
            return .lessonPlayer(templateType: "ar-activity", childId: previewChild)
        case "lessonVisualAcoustic":
            return .lessonPlayer(templateType: "visual-acoustic", childId: previewChild)
        case "lessonBreathingExercise":
            return .lessonPlayer(templateType: "breathing", childId: previewChild)
        case "lessonRhythm":
            return .lessonPlayer(templateType: "rhythm", childId: previewChild)
        case "lessonNarrativeQuest":
            return .lessonPlayer(templateType: "narrative-quest", childId: previewChild)
        case "lessonMinimalPairs":
            return .lessonPlayer(templateType: "minimal-pairs", childId: previewChild)

        // MARK: Tier 3 — AR sub-screens 9 (fallback to .arZone)
        case "arMirror",
             "arStoryQuest",
             "breathingAR",
             "butterflyCatch",
             "holdThePose",
             "mascot3D",
             "mimicLyalya",
             "poseSequence",
             "soundAndFace":
            return .arZone

        // MARK: Tier 4 — Session 5 (fallback to .sessionComplete / .rewards)
        case "sessionShell":
            return .lessonPlayer(templateType: "bingo", childId: previewChild)
        case "sessionDetail":
            return .sessionHistory(childId: previewChild)
        case "celebrationOverlay":
            return .sessionComplete(result: .sample)
        case "rewardDetail",
             "rewardAlbum":
            return .rewards(childId: previewChild)

        // MARK: Tier 5 — Settings sub-screens 9 (fallback to .settings)
        case "settingsTheme",
             "settingsNotifications",
             "settingsModelPacks",
             "settingsPrivacy",
             "settingsGDPR",
             "settingsAbout",
             "settingsVoice",
             "settingsLanguage",
             "settingsAccessibility":
            return .settings

        // MARK: Tier 6 — Demo/Misc 7
        case "demoStep1",
             "demoStep5",
             "demoStep10",
             "demoStep15":
            return .demoMode
        case "homeTasks":
            return .homeTasks
        case "rewardCollection",
             "dailyStreak":
            return .rewards(childId: previewChild)

        // MARK: Tier 7 — Family 6
        case "familyHome":
            return .familyHome
        case "profileEditor":
            return .profileEditor(childId: previewChild)
        case "comparisonDashboard":
            return .comparisonDashboard
        case "familyCalendar":
            return .familyCalendar
        case "familyLeaderboard":
            return .pronunciationLeaderboard(parentId: previewParent)
        case "familyAchievements",
             "achievements":
            return .achievements(childId: previewChild)
        case "screening":
            return .screening(childId: previewChild)

        // MARK: Tier 8 — Specialist 5 (fallback to .specialistHome / .auth)
        case "specialistLogin":
            return .auth
        case "studentsList",
             "programEditor",
             "sessionReview",
             "reports":
            return .specialistHome
        case "phonemeReport":
            return .phonemeReport(childId: previewChild)

        // MARK: Tier 9 — Stuttering 5
        case "stutteringHome":
            return .stutteringHome
        case "breathingTree",
             "metronome",
             "softOnset":
            return .stutteringHome
        case "fluencyDiaryHome":
            return .fluencyDiaryParent

        // MARK: Tier 10 — Misc 9 (most fall back to .auth — no view yet)
        case "neurolinguistInsights":
            return .neurolinguistInsights(childId: previewChild)
        case "speechVisualization":
            return .speechVisualization(word: "сова", targetSound: "С")
        case "arFaceFilter":
            return .arFaceFilter
        case "guidedTour":
            return .guidedTour
        case "grammarGame":
            return .grammarGame(childId: previewChild)
        case "offlineMiniGame":
            return .auth
        case "siblingMultiplayerDiscovery",
             "siblingMultiplayerLobby",
             "siblingMultiplayerGame":
            return .siblingMultiplayer(childId: previewChild)

        // MARK: Tier 11 — R-screens + AE 11
        case "dialectAdaptation":
            return .dialectAdaptation(childId: previewChild)
        case "logopedistChat":
            return .logopedistChat(parentId: previewParent, specialistId: "specialist-default")
        case "weeklyChallenge":
            return .weeklyChallenge(childId: previewChild)
        case "plainProgress":
            return .plainProgress(childId: previewChild)
        case "parentGuide":
            return .parentGuide(childId: previewChild)
        case "soundTrafficLight":
            return .soundTrafficLight(childId: previewChild)
        case "phonemicListening":
            return .phonemicListening(childId: previewChild)
        case "speechTempo":
            return .speechTempo(childId: previewChild)
        case "breatheAndSpeak":
            return .breatheAndSpeak(childId: previewChild)
        case "prosody":
            return .prosody(childId: previewChild)
        case "retelling":
            return .retelling(childId: previewChild)
        case "lexicalThemes":
            return .lexicalThemes(childId: previewChild)
        case "storytelling":
            return .storytelling(childId: previewChild)
        case "coPlay":
            return .coPlay(childId: previewChild)
        case "assignedHomework":
            return .assignedHomework(specialistId: "specialist-default")
        case "culturalContent":
            return .culturalContent(childId: previewChild)
        case "pronunciationLeaderboard":
            return .pronunciationLeaderboard(parentId: previewParent)
        case "soundDictionary":
            return .soundDictionary
        case "helpCenter":
            return .helpCenter
        case "dailyChallenge":
            return .dailyChallenge(childId: previewChild)
        case "parentInsightsTimeline":
            return .parentInsightsTimeline(childId: previewChild)
        case "familyAwardsCabinet":
            return .familyAwardsCabinet(parentId: previewParent)
        case "voiceCloning":
            return .voiceCloning(childId: previewChild)

        // MARK: v25 6.2 — F-301 / F-302 / F-303
        case "weeklyReport":
            return .weeklyReport(childId: previewChild, weekOffset: 0)
        case "articulationGym":
            return .articulationGym(soundGroup: .hissing)
        case "wordBank":
            return .wordBank(childId: previewChild)

        // MARK: v28 Фаза 2 — ранее недостижимые маршруты (4)
        case "permissionFlow":
            return .permissionFlow(.microphone)
        case "sharePlay":
            return .sharePlay
        case "familyVoiceSplit":
            return .familyVoiceSplit
        case "familyVoiceLibrary":
            return .familyVoiceLibrary

        // MARK: v31 Волна A — методически-ценные функции
        case "speechNormsEncyclopedia",
             "speechNorms":
            return .speechNormsEncyclopedia
        case "dailyRitualsMorning",
             "dailyRituals":
            return .dailyRitualsLyalya(kind: .morning)
        case "dailyRitualsEvening":
            return .dailyRitualsLyalya(kind: .evening)

        // MARK: v31 Волна B Ф.1
        case "syllableConstructor",
             "syllable":
            return .syllableConstructor(childId: previewChild)

        // MARK: v31 Волна B Ф.2
        case "comprehensionDetective",
             "detective":
            return .comprehensionDetective(childId: previewChild)

        // MARK: v31 Волна B Ф.3
        case "bedtimeMode",
             "bedtime":
            return .bedtimeMode(childId: previewChild)

        // MARK: v31 Волна B Ф.4
        case "parentVoiceNote",
             "voiceNote":
            return .parentVoiceNote(childId: previewChild)

        // MARK: v31 Волна C Ф.1
        case "rewardShop",
             "stickerShop":
            return .rewardShop(childId: previewChild)

        // MARK: v31 Волна C Ф.2
        case "letterTrace",
             "trace":
            return .letterTrace(childId: previewChild)

        // MARK: v31 Волна C Ф.4
        case "customWordList",
             "wordList":
            return .customWordList(specialistId: previewParent)

        // MARK: v31 Волна D Ф.1
        case "readAloudStory",
             "readAloud":
            return .readAloudStory(childId: previewChild)

        // MARK: v31 Волна D Ф.3
        case "specialistAssessment",
             "assessment":
            return .specialistAssessment(
                childId: previewChild,
                specialistId: previewParent
            )

        // MARK: v31 Wave E
        case "karaokePitch",
             "karaoke":
            return .karaokePitch(childId: previewChild)
        case "fingerPlay",
             "fingers":
            return .fingerPlay(childId: previewChild)
        case "oralStoryCreator",
             "storyCreator":
            return .oralStoryCreator(childId: previewChild)
        case "speechGrowthDiary",
             "growthDiary",
             "diary":
            return .speechGrowthDiary(childId: previewChild)

        // MARK: v31 Wave F Ф.2
        case "objectDescriptionMap",
             "descriptionMap",
             "tkachenkoMap":
            return .objectDescriptionMap(childId: previewChild)

        // MARK: v31 Wave F Ф.7
        case "logorhythmics",
             "rhythm",
             "kartushina":
            return .logorhythmics(childId: previewChild)

        // MARK: v31 Wave F F-05
        case "dailyTimeCap",
             "timeCap",
             "screenTime":
            return .dailyTimeCap

        // MARK: v31 Wave F Ф.11
        case "bilingualMode",
             "bilingual",
             "twoLanguages":
            return .bilingualMode(childId: previewChild)

        // MARK: v32 Sprint 12 (3 новые фичи)
        case "literacyStart",
             "literacy",
             "gramotaStart":
            return .literacyStart(targetSound: "Р")
        case "soundOfTheDay",
             "sotd",
             "dailySound":
            return .soundOfTheDay(childId: previewChild)
        case "voiceJournal",
             "voicelog",
             "voiceDiary":
            return .voiceJournal(childId: previewChild)

        // MARK: v32 Family-engagement screens
        case "familyChallenge",
             "weeklyFamily",
             "weekly":
            return .familyChallenge(parentId: previewParent)
        case "lyalyaMail",
             "mail",
             "lyalyaLetters":
            return .lyalyaMail(childId: previewChild)
        case "achievementWall",
             "wall",
             "achievementsWall":
            return .achievementWall(childId: previewChild)

        // MARK: v32 Batch B (12 lightweight modules)
        case "morningRoutine", "morning":
            return .morningRoutine(childId: previewChild)
        case "eveningReflection", "evening":
            return .eveningReflection(childId: previewChild)
        case "dailyMissionsHub", "missions":
            return .dailyMissionsHub(childId: previewChild)
        case "soundExplorerMap", "soundMap", "soundExplorer":
            return .soundExplorerMap(childId: previewChild)
        case "wordOfTheDay", "wotd":
            return .wordOfTheDay(childId: previewChild)
        case "speechHomeworkPlanner", "homeworkPlanner":
            return .speechHomeworkPlanner
        case "parentMoodCheckIn", "parentMood":
            return .parentMoodCheckIn
        case "lyalyaPersonalCoach", "personalCoach", "coach":
            return .lyalyaPersonalCoach(childId: previewChild)
        case "weeklyRecap", "recap":
            return .weeklyRecap
        case "childAchievementShare", "achievementShare", "shareAchievement":
            return .childAchievementShare
        case "audioMemoryGame", "audioMemory", "memoryGame":
            return .audioMemoryGame(childId: previewChild)
        case "visualVocabularyFlip", "vocabFlip", "vocabulary":
            return .visualVocabularyFlip(childId: previewChild)

        // MARK: v32 Batch C wave 4 (15 lightweight modules)
        case "goalTrackerKid", "goalTracker", "kidGoals":
            return .goalTrackerKid(childId: previewChild)
        case "habitStreakDashboard", "habitStreak", "streakHeatmap":
            return .habitStreakDashboard(childId: previewChild)
        case "phonemeJourneyMap", "phonemeJourney", "journeyMap":
            return .phonemeJourneyMap(childId: previewChild)
        case "tongueTwisterArena", "tongueTwister", "twister":
            return .tongueTwisterArena(childId: previewChild)
        case "storyEndingMaker", "storyEnding", "endingMaker":
            return .storyEndingMaker(childId: previewChild)
        case "speechRiddles", "riddles":
            return .speechRiddles(childId: previewChild)
        case "animalSoundsBingo", "animalBingo", "soundBingo":
            return .animalSoundsBingo(childId: previewChild)
        case "letterPaintingFun", "letterPainting", "paintLetter":
            return .letterPaintingFun(childId: previewChild)
        case "wordRhymeGame", "wordRhyme", "rhymeGame":
            return .wordRhymeGame(childId: previewChild)
        case "sentenceBuilderKid", "sentenceBuilder":
            return .sentenceBuilderKid(childId: previewChild)
        case "conversationStartersParent", "conversationStarters", "starters":
            return .conversationStartersParent
        case "weeklyParentTip", "weeklyTip", "parentTip":
            return .weeklyParentTip
        case "childLanguageMilestones", "languageMilestones", "milestones":
            return .childLanguageMilestones
        case "specialistCaseNotes", "caseNotes", "specialistNotes":
            return .specialistCaseNotes(childId: previewChild, specialistId: previewParent)
        case "specialistQuickAssessment", "quickAssessment", "specialistAssess":
            return .specialistQuickAssessment(childId: previewChild, specialistId: previewParent)

        // MARK: Wave 2 mechanics — F2-009 Звуковой детектив
        case "soundDetective", "detectiveSound", "phonemeDetective":
            return .soundDetective(childId: previewChild)
        case "syllableSnail", "snail", "syllableStructure":
            return .syllableSnail(childId: previewChild)
        case "fourthExtra", "fourth-extra", "oddOneOut":
            return .fourthExtra(childId: previewChild)
        case "wordFormation", "word-formation", "nameNicely", "oneManyNone":
            return .wordFormation(childId: previewChild)
        case "whoseTail", "whose-tail", "whoseHome", "possessiveAdjectives":
            return .whoseTail(childId: previewChild)
        case "sentenceConstructor", "sentence-constructor", "sentenceSyntax", "constructSentence":
            return .sentenceConstructor(childId: previewChild)

        // MARK: v32 Batch D wave 5 (17 lightweight modules)
        case "soundJournalKid", "soundJournal", "kidJournal":
            return .soundJournalKid(childId: previewChild)
        case "practiceReminderKid", "practiceReminder", "kidReminder":
            return .practiceReminderKid(childId: previewChild)
        case "storyRetellingPro", "storyRetelling", "retellPro":
            return .storyRetellingPro(childId: previewChild)
        case "imitationLab", "imitation", "soundLab":
            return .imitationLab(childId: previewChild)
        case "whisperGame", "whisper":
            return .whisperGame(childId: previewChild)
        case "colorAndSound", "colorSound":
            return .colorAndSound(childId: previewChild)
        case "musicalSoundDrums", "drums", "musicalDrums":
            return .musicalSoundDrums(childId: previewChild)
        case "palindromeHunter", "palindrome":
            return .palindromeHunter(childId: previewChild)
        case "phonemeFamilyMatcher", "phonemeFamily", "familyMatcher":
            return .phonemeFamilyMatcher(childId: previewChild)
        case "soundDoctorKid", "soundDoctor", "doctorKid":
            return .soundDoctorKid(childId: previewChild)
        case "parentDailyDigest", "parentDigest", "digest":
            return .parentDailyDigest
        case "parentInspirationBoard", "inspirationBoard", "inspiration":
            return .parentInspirationBoard
        case "achievementCalendar", "calendarAchievements":
            return .achievementCalendar(childId: previewChild)
        case "specialistSchedule", "schedule":
            return .specialistSchedule(specialistId: previewParent)
        case "specialistResourcesLibrary", "resourcesLibrary", "library":
            return .specialistResourcesLibrary(specialistId: previewParent)
        case "specialistReportPDFGen", "reportPDFGen", "pdfReport":
            // Real PDF/CSV export lives in the Specialist › Reports tab.
            return .specialistHome
        case "familyVoiceMessageHub", "voiceMessageHub", "voiceHub":
            return .familyVoiceMessageHub

        // MARK: Cad-task-1: Methodology Assistant
        case "methodologyAssistant", "methodology", "assistant":
            return .methodologyAssistant

        // MARK: AR Sound Hunter (Vision room object hunting)
        case "arSoundHunter", "soundHunter", "soundHunterRoom":
            return .arSoundHunter(childId: previewChild)

        // MARK: Stories — каталог анимированных историй
        case "storyLibrary", "stories", "tales", "fairyTales":
            return .storyLibrary(childId: previewChild)

        // MARK: п.26 — Еженедельный видео-отчёт (Remotion)
        case "weeklyVideoReport", "videoReport", "reportVideo":
            return .weeklyVideoReport(childId: previewChild)

        // MARK: Акустическое зеркало (сибилянты, on-device DSP)
        case "acousticMirror", "acousticmirror", "sibilantMirror":
            return .acousticMirror(childId: previewChild)

        // MARK: Скороговорка-ракета (диадохокинез, on-device DSP)
        case "syllableRace", "syllablerace", "ddk", "pataka":
            return .syllableRace(childId: previewChild)

        // MARK: Послушай себя (слуховой самоконтроль)
        case "listenYourself", "listenyourself", "selfListen", "twoTakes":
            return .listenYourself(childId: previewChild)

        // MARK: Звуковая мастерская (эльконинский звуковой анализ-синтез)
        case "soundComposition", "soundAnalysis", "elkonin":
            return .soundComposition(childId: previewChild)

        // MARK: Карта звонкости и мягкости (дифференциация фонем)
        case "voicingSoftness", "voicing", "softness":
            return .voicingSoftness(childId: previewChild)

        // MARK: Голосовые краски (просодика: интонация/ударение/эмоция)
        case "voiceColors", "voicecolors", "prosodyPlus", "intonation":
            return .voiceColors(childId: previewChild)

        // MARK: Рассказ по серии картинок (связная речь)
        case "storyPictures", "storypictures", "pictureSeries", "narrativeSeries":
            return .storyPictures(childId: previewChild)

        default:
            return .auth
        }
    }
}
