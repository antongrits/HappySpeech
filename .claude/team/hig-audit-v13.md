# HIG Audit v13 — HappySpeech Apple HIG Final Audit

**Дата:** 2026-05-01
**Агент:** designer-ui (Plan v13, Iteration 5, Block N)
**Проверено экранов:** 25
**Статус:** DONE — P0 fixes applied, P1 fixes applied, P2 documented

## Summary

| Priority | Found | Fixed | Documented |
|---|---|---|---|
| P0 (blocking) | 2 | 2 | — |
| P1 (high) | 6 | 2 | 4 |
| P2 (medium polish) | 8 | 0 | 8 |

## Audited Screens

1. ChildHomeView
2. ParentHomeView
3. RepeatAfterModelView
4. ARMirrorView
5. ObjectHuntView
6. LetterTracingView
7. SpectrogramVisualizerView
8. LyalyaRealityView
9. SettingsView
10. FamilyHomeView
11. OnboardingFlowView (10 шагов)
12. AchievementsView
13. RewardsView
14. SessionCompleteView
15. ARActivityView
16. ListenAndChooseView
17. DragAndMatchView
18. SortingView
19. BreathingView
20. NarrativeQuestView
21. WorldMapView + WorldMapIslandsCanvas
22. ProgressDashboardView
23. SoftOnsetView
24. MetronomeView
25. FluencyDiaryView

## P0 Violations — FIXED

### P0-1: ARGameHUD touch target < 56pt
Файл: Features/AR/Shared/ARFaceViewContainer.swift
Fix: .frame(minWidth: 56, minHeight: 56) + .contentShape(Rectangle()) на Button закрытия.

### P0-2: UIKit haptics вне HapticService (4 файла)
Файлы: SoftOnsetInteractor, FluencyDiaryInteractor, MetronomeInteractor, GrammarFeedbackWorker
Fix: hapticService: any HapticService = LiveHapticService() добавлен в init. UIKit заменён на hapticService.play(.X). import UIKit убран из 3 Interactor-файлов.
Маппинг: .medium impact->buttonTap, .success->perfectRound/celebration, .light->buttonTap, syllable detect->cardSelect, error->errorBuzz, selection->cardSelect.

## P1 — FIXED / ACCEPTABLE

### P1-1: LyalyaRealityView — нет accessibility label (FIXED)
Файл: Features/AR/Mascot3D/LyalyaRealityView.swift
Fix: .accessibilityLabel + .accessibilityHint добавлены.

### P1-2 до P1-6: ACCEPTABLE
easeInOut toast/fade (не вестибулярные), linear progress bar, ParentHome tap gestures с accessibilityAddTraits(.isButton), SOS font 14pt с корректным 56pt target — всё приемлемо по HIG.

## P2 Polish — DOCUMENTED (8 items)

1. SpectrogramVisualizerView: cornerRadius/height/padding захардкожены
2. ARMirrorView attentionIndicator 5pt -> рекомендуется 8pt
3. ChildHomeView sectionHeader uppercase в kid-контуре
4. AchievementsView: нет haptic при swipe между табами
5. WorldMapIslandsCanvas: hint= для 5 элементов
6. FamilyHomeView: longPress без .accessibilityAction(.longPress)
7. RewardsView: HSConfettiView без reduceMotion guard
8. LetterTracingView: implicit HSButton height

## DesignSystem Compliance

ColorTokens: 0 hardcoded hex. TypographyTokens: OK. SpacingTokens: OK (исключение P2-1). MotionTokens: linear() только для прогресс-баров. RadiusTokens: OK.

## Fixed Files

1. Features/AR/Shared/ARFaceViewContainer.swift
2. Features/StutteringModule/SoftOnset/SoftOnsetInteractor.swift
3. Features/StutteringModule/FluencyDiary/FluencyDiaryInteractor.swift
4. Features/StutteringModule/Metronome/MetronomeInteractor.swift
5. Features/GrammarGame/Workers/GrammarFeedbackWorker.swift
6. Features/AR/Mascot3D/LyalyaRealityView.swift
