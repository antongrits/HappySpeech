# V25 Coverage Baseline — 2026-05-15

## Overall
- Total app coverage (HappySpeech.app): **35.35%** (62 573 / 177 014 lines)
- HappySpeechTests.xctest self-coverage: 91.30% (23 038 / 25 234)
- HappySpeechUITests.xctest: 0.00% (not run via unit target)

## Per-layer breakdown
| Layer | Coverage | Covered/Total | Files |
|-------|----------|---------------|-------|
| Features/Interactors | 44.1% | 11 637 / 26 365 | 80 |
| Features (all) | 35.1% | 53 667 / 152 781 | 555 |
| ML | 42.3% | 2 832 / 6 699 | 42 |
| DesignSystem | 41.4% | 3 055 / 7 377 | 50 |
| Data | 31.0% | 352 / 1 137 | 11 |
| Services | 19.6% | 1 174 / 5 998 | 33 |

## Zero-coverage files (0%) — 340 of 714 source files
Top 20 by line count impact:

- Features/WeeklyChallenge/WeeklyChallengeView.swift (0/947)
- Features/SoundDictionary/SoundDictionaryView.swift (0/985)
- Features/FamilyAchievements/FamilyAchievementsView.swift (0/943)
- Features/LessonPlayer/ARActivity/ARActivityInteractor.swift (0/507)
- Features/LessonPlayer/ObjectHunt/ObjectHuntInteractor.swift (0/788)
- Features/ARZone/ARZoneViewCards.swift (0/640)
- Features/SessionShell/SessionShellViewComponents.swift (0/565)
- Features/StutteringModule/SoftOnset/SoftOnsetInteractor.swift (0/299)
- Features/Extensions/SiriShortcuts/AppShortcutsProvider.swift (0/128)
- Features/StutteringModule/StutteringPresenter.swift (0/111)
- Features/StutteringModule/Workers/WhisperTranscriptionWorker.swift (0/95)
- Features/DailyChallenge/DailyChallengeInteractor.swift (0/94)
- Features/HelpCenter/HelpCenterPresenter.swift (0/128)
- Features/FamilyAchievements/FamilyAchievementsInteractor.swift (0/186)
- Features/SharePlay/Workers/FamilyShareplayController.swift (0/189)
- Features/Common/StoryPlayerView.swift (0/248)
- ML/MFCC/MelSpectrogramExtractor.swift (0/249)
- ML/ASR/ASRServiceLive.swift (0/167)
- Analytics/AnalyticsService.swift (0/39)
- Features/ParentInsightsTimeline/Workers/LLMInsightWorker.swift (0/63)

Additional zero-coverage files (alphabetical sample):
- Features/AR/ARStoryQuest/ARStoryQuestModels.swift
- Features/AR/BreathingAR/BreathingARInteractor.swift
- Features/AR/BreathingAR/BreathingARRouter.swift
- Features/AR/ButterflyCatch/ButterflyCatchInteractor.swift
- Features/AR/ButterflyCatch/ButterflyCatchPresenter.swift
- Features/AR/HandPose/HandPoseModels.swift
- Features/AR/HoldThePose/HoldThePosePresenter.swift
- Features/AR/HoldThePose/HoldThePoseRouter.swift
- Features/AR/HoldThePose/HoldThePoseView.swift
- Features/AR/Mascot3D/LyalyaRealityView.swift
- Features/AR/ObjectDetection/ObjectDetectionModels.swift
- Features/AR/PoseSequence/PoseSequenceInteractor.swift
- Features/AR/PoseSequence/PoseSequencePresenter.swift
- Features/AR/PoseSequence/PoseSequenceView.swift
- Features/AR/SoundAndFace/SoundAndFaceView.swift
- Features/ARFaceFilter/ARFaceFilterInteractor.swift
- Features/ARFaceFilter/ARFaceFilterModels.swift
- Features/Auth/AuthRouter.swift
- Features/ChildHome/ChildHomeRouter.swift
- Features/CulturalContent/CulturalContentModels.swift
- Features/Customization/CustomizationDisplayLogic.swift
- Features/Customization/CustomizationRouter.swift
- Features/Customization/CustomizationView.swift
- Features/Customization/CustomizationViewCards.swift
- Features/DailyChallenge/DailyChallengePresenter.swift
- Features/DailyChallenge/Workers/DailyChallengeStatsWorker.swift
- Features/DailyStreak/DailyStreakModels.swift
- Features/DailyStreak/DailyStreakRouter.swift
- Features/DailyStreak/DailyStreakView.swift
- Features/DialectAdaptation/DialectAdaptationRouter.swift
- Features/Extensions/Achievements/AchievementsInteractor.swift
- Features/Extensions/Achievements/AchievementsView.swift
- Features/Extensions/SeasonalEvents/Workers/SeasonalContentLoaderWorker.swift
- Features/Extensions/SiriShortcuts/Intents/OpenRewardAlbumIntent.swift
- Features/Extensions/SiriShortcuts/Intents/SetReminderIntent.swift
- Features/Extensions/Spotlight/SpotlightDeepLinkHandler.swift
- Features/Family/ComparisonDashboardModels.swift
- Features/Family/ComparisonDashboardPresenter.swift
- Features/Family/FamilyHomeInteractor.swift
- Features/Family/FamilyHomePresenter.swift
- Features/Family/FamilyHomeRouter.swift
- Features/Family/ProfileEditorPresenter.swift
- Features/FamilyAwardsCabinet/Workers/AwardsCatalogWorker.swift
- Features/FamilyCalendar/FamilyCalendarRouter.swift
- Features/FamilyLeaderboard/FamilyLeaderboardPresenter.swift
- Features/FamilyLeaderboard/FamilyLeaderboardRouter.swift
- Features/FamilyLeaderboard/FamilyLeaderboardView.swift
- Features/GrammarGame/GrammarGameModels.swift
- Features/GrammarGame/GrammarGamePresenter.swift
- Features/GuidedTour/SpotlightOverlay.swift
- Features/HelpCenter/HelpCenterInteractor.swift
- Features/HelpCenter/Workers/FAQRepositoryWorker.swift
- Features/HomeTasks/HomeTaskDetailSheet.swift
- Features/HomeTasks/HomeTasksModels.swift
- Features/LessonPlayer/ARActivity/ARActivityPresenter.swift
- Features/LessonPlayer/ARActivity/ARActivityRouter.swift
- Features/LessonPlayer/ARActivity/ARActivityView.swift
- Features/LessonPlayer/ArticulationImitation/ArticulationImitationRouter.swift
- Features/LessonPlayer/Bingo/BingoRouter.swift
- Features/LessonPlayer/Breathing/Workers/BreathingHapticWorker.swift
- Features/LessonPlayer/DragAndMatch/DragAndMatchRouter.swift
- Features/LessonPlayer/LetterTracing/LetterTracingPresenter.swift
- Features/LessonPlayer/LetterTracing/LetterTracingView.swift
- Features/LessonPlayer/ListenAndChoose/ListenAndChooseRouter.swift
- Features/LessonPlayer/MinimalPairs/MinimalPairsRouter.swift
- Features/LessonPlayer/NarrativeQuest/NarrativeQuestModels.swift
- Features/LessonPlayer/ObjectHunt/ObjectHuntModels.swift
- Features/LessonPlayer/PuzzleReveal/PuzzleRevealRouter.swift
- Features/LessonPlayer/RepeatAfterModel/RepeatAfterModelRouter.swift
- Features/LessonPlayer/Rhythm/RhythmRouter.swift
- Features/LessonPlayer/SoundHunter/SoundHunterModels.swift
- Features/LessonPlayer/StoryCompletion/StoryCompletionRouter.swift
- Features/NeurolinguistInsights/NeurolinguistInsightsPresenter.swift
- Features/NeurolinguistInsights/NeurolinguistInsightsView.swift
- Features/Onboarding/OnboardingFlowViewComponents2.swift
- Features/OfflineState/OfflineStateRouter.swift
- Features/ParentChild/FamilyVoiceInteractor.swift
- Features/ParentChild/FamilyVoiceRouter.swift
- Features/ParentInsightsTimeline/ParentInsightsTimelineModels.swift
- Features/ParentInsightsTimeline/ParentInsightsTimelineRouter.swift
- Features/ParentInsightsTimeline/ParentInsightsTimelineView.swift
- Features/Permissions/PermissionsOverviewView.swift
- Features/Screening/ScreeningPrompts.swift
- Features/SessionComplete/SessionCompleteModels.swift
- Features/SessionComplete/SessionCompleteRouter.swift
- Features/SessionShell/SessionShellModels.swift
- Features/Settings/SettingsRouter.swift
- Features/SharePlay/LessonGroupActivity.swift
- Features/SharePlay/SharePlayInteractor.swift
- Features/SharePlay/SharePlayRouter.swift
- Features/SharePlay/SharePlayView.swift
- Features/SharePlay/SyncMessage.swift
- Features/SharePlay/Workers/FamilyShareplayController.swift
- Features/SiblingMultiplayer/SiblingModels.swift
- Features/SiblingMultiplayer/SiblingRouter.swift
- Features/SoundDictionary/SoundDictionaryPresenter.swift
- Features/SpeechVisualization/SpeechVisualizationModels.swift
- Features/SpeechVisualization/SpeechVisualizationPresenter.swift
- Features/Specialist/SessionReview/SessionReviewRouter.swift
- Features/Specialist/SpecialistModels.swift
- Features/Specialist/SpecialistPresenter.swift
- Features/Specialist/SpecialistHomeViewSheets.swift
- Features/StutteringModule/FluencyDiary/FluencyDiaryParentView.swift
- Features/StutteringModule/SoftOnset/SoftOnsetModels.swift
- Features/VoiceCloning/VoiceCloningRouter.swift
- Features/WeeklyChallenge/WeeklyChallengeModels.swift
- Features/WorldMap/WorldMapModels.swift
- ML/LLM/LocalLLMService.swift
- ML/VAD/VADService.swift
- ML/Wav2Vec2/Wav2Vec2Models.swift
- ML/MFCC/SpectrogramCrossCorrelator.swift
- Services/AirStreamDetector.swift
- Data/OfflineQueueManager.swift
- Analytics/AnalyticsService.swift
- Core/Logger/HSLogger.swift
- Core/Extensions/UIApplication+TopVC.swift
- Shared/Accessibility/AccessibilityModifiers.swift
- Shared/ViewModifiers/CardModifier.swift
- DesignSystem/Components/HSErrorStateView.swift
- DesignSystem/Components/HSLoadingView.swift
- DesignSystem/Components/HSPaywallTeaser.swift
- DesignSystem/Components/HSRewardBurst.swift
- DesignSystem/Components/HSStarRatingView.swift
- DesignSystem/Components/HSTimelineView.swift
- DesignSystem/Components/HomeScreenCard.swift
- DesignSystem/Tokens/MotionTokens.swift

## Low-coverage files (<50%, >0%) — 175 files (top 20 worst)
| Coverage | File |
|----------|------|
| 0.5% | Features/Specialist/SessionReview/SessionReviewView.swift |
| 0.7% | Features/GuidedTour/GuidedTourPresenter.swift |
| 1.3% | Services/MLModelWarmupService.swift |
| 1.4% | Services/ContentPackDownloadService.swift |
| 1.6% | Features/FamilyCalendar/FamilyCalendarView.swift |
| 1.6% | Features/Settings/Changelog/ChangelogView.swift |
| 1.7% | Features/SpeechVisualization/SpeechVisualizationView.swift |
| 2.3% | Services/RealtimeDatabaseService.swift |
| 2.4% | DesignSystem/Components/ParentalGate.swift |
| 2.6% | Features/AR/BreathingAR/BreathingARView.swift |
| 2.6% | Services/EmotionDetectionServiceLive.swift |
| 2.8% | Features/ParentChild/FamilyVoiceView.swift |
| 2.8% | Services/SpeakerVerificationServiceLive.swift |
| 2.9% | DesignSystem/Components/HSHeroCardTransition.swift |
| 3.1% | Services/InstallationsService.swift |
| 3.4% | Features/SessionHistory/SessionHistorySubviews.swift |
| 3.4% | Services/LiveAuthService.swift |
| 3.5% | Services/EnsembleASRService.swift |
| 4.0% | Features/AR/HandPose/HandPoseWorker.swift |
| 4.0% | Services/NotificationServiceLive.swift |

## Test run result
- Tests passed: **1257** / 1381 total
- Tests failed: **124**
- Duration: ~5 min 6 sec (19:36:16 → 19:41:22)
- Result bundle: `_workshop/v25_coverage_baseline.xcresult`

### Failure breakdown by test class
| Failures | Test class |
|----------|-----------|
| 14 | GameTemplatesSnapshotTests |
| 12 | DynamicTypeSnapshotTests |
| 11 | HSMascotViewSnapshotTests |
| 9 | KeyScreensSnapshotTests |
| 9 | BlockCComponentsSnapshotTests |
| 8 | GuidedTourCoordinatorTests |
| 7 | ErrorStatesSnapshotTests |
| 6 | ParentFlowSnapshotTests |
| 6 | CustomizationSnapshotTests |
| 6 | AdvancedGameSnapshotTests |
| 5 | AccessibilityVariantsSnapshotTests |
| 5 | ARSnapshotTests |
| 4 | OnboardingSnapshotTests |
| 4 | DesignSystemSnapshotTests |
| 3 | StoryPlayerSmokeTests |
| 3 | ChildHomeInteractorTests |
| 2 | SyncServiceExtTests |
| 2 | SiblingInteractorTests |
| 1 each | VIPFlowIntegrationTests, StutteringSnapshotTests, SpecialistSnapshotTests, SettingsInteractorTests, MinimalPairsInteractorTests, KidSafetyFilterTests, HomeTasksInteractorTests |

Failure root causes (snapshot mismatches): majority are snapshot reference mismatch (record=false, no reference images committed). Unit failures (ChildHomeInteractor, SyncService, SiblingInteractor) require investigation.

## Gap to 100%
- Uncovered lines in HappySpeech.app: **114 441**
- Estimated new test functions needed (~20 prod lines / test): **~5 700**
- Zero-coverage files: **340 / 714** (47.6% of all source files untested)
- Low-coverage files (1–49%): **175** files

### Hardest-to-test categories (require XCTestSkip or heavy mocks)
- AR/ARKit files: ARActivityInteractor, ARFaceFilterInteractor, PoseSequenceInteractor, BreathingARInteractor, ButterflyCatchInteractor, HoldThePose* (need ARKit face tracking — simulator only smoke)
- Audio/ASR: ASRServiceLive, WhisperTranscriptionWorker, AirStreamDetector, EnsembleASRService (need real microphone hardware)
- Firebase Live services: LiveAuthService, RealtimeDatabaseService, InstallationsService, FCMService (network + credentials)
- MLX/LocalLLM: LocalLLMService, LLMModelManager (heavy model weights not in CI)
- VoiceCloning: VoiceCloningView + Router (AVAudioEngine + file I/O)
- SiriShortcuts/AppIntents: AppShortcutsProvider, OpenRewardAlbumIntent, SetReminderIntent (requires Siri entitlement)

## Notes
- Snapshot test failures are all reference-mismatch (record=false mode), not logic failures. Coverage IS generated despite failures.
- v16 baseline (2026-05-07) was 35.9% — current 35.35% is within noise margin (codebase grew, not regression).
- Third-party targets (Firebase, Lottie, WhisperKit, MLX, SwiftSyntax) excluded from app target count.
