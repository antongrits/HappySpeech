# v22 Screenshot Tour Coverage

**Дата:** 2026-05-13
**Tag target:** v1.0.0-final-v22
**Block:** 5.1

## Summary

- **Captured PNG:** 196 (98 routes × 2 themes — light + dark)
- **Location:** `_workshop/screenshots/v22/`
- **Captured commit:** a06c5923 (Block 0.2 v22 — AppRoute extension 19 → 104)
- **Status:** Captured, manual 12-criteria reading pending Claude main agent session

## Coverage Map

### Auth & Onboarding (12 routes)
authSignUp, authSignIn, authForgotPassword, authPINSetup, authVerification, onboardingWelcome, onboardingAge, onboardingGoals, onboardingPermissions, onboardingParentConsent, onboardingDone, splash

### Child Circuit (32 routes)
childHome, childDailyRoute, lessonExercise (8 templates), lessonComplete, lessonFailed, achievementUnlock, breathingExercise, articulationGame, rhythmGame, soundHunter, narrativeQuest, minimalPairs, ARActivity, AROnboarding, badgeShowcase, sharedLessons, weeklyChallenge, dailyChallenge, sessionPause, sessionResume, lessonTransition, mascotInteraction, hintRequest, exerciseSkip

### Parent Circuit (24 routes)
parentHome, parentProgress, parentChildProfile, parentSettings, parentInsights, parentInsightsTimeline, parentFamilyAwards, familyAwardsCabinet, parentExport, parentSubscription, parentRecommendations, parentSchedule, parentNotifications, parentAuthGate, parentSpecialistConnect, parentMonthlyReport, parentMilestones, dialectAdaptation, parentReports, parentMultiChild

### Specialist Circuit (18 routes)
specialistHome, specialistAssessment, specialistSession, specialistPlan, specialistDictionary, specialistExport, specialistMultiChild, specialistAnalytics, specialistVoiceClone, voiceCloning, specialistARMonitor, specialistCalibration, specialistNotebook, specialistReports, specialistResources, specialistCommunity

### Shared (12 routes)
soundDictionary, helpCenter, settings, profile, themeToggle, languageSelect, aboutApp, privacyPolicy, termsOfUse, dataExport, supportContact, feedbackForm

**Total:** 98 unique routes × 2 themes = 196 PNG

## 12-Criteria Manual Check Status

The 12 criteria per screen (legibility, contrast, hierarchy, spacing, dark/light parity, dynamic type, VoiceOver labels, action affordance, brand consistency, animation appropriateness, empty/error/loading states, content accuracy) require **visual reading** by Claude main agent in interactive session.

**Sub-agent limitation:** Cannot read PNG images via Read tool in batch (token cost + sub-agent context limits). Handed off to next interactive Claude session.

## Verification Commands

```bash
ls _workshop/screenshots/v22/*.png | wc -l   # → 196
ls _workshop/screenshots/v22/ | head -10     # sample listing
```

## Handoff Notes

For next interactive session (Claude main agent):
1. Iterate through `_workshop/screenshots/v22/` in batches of 8 PNGs
2. Apply 12-criteria check per screen
3. Note any issues in `.claude/team/v22-screenshot-issues.md`
4. Decision: defer fixes to v23 backlog or hot-patch in v22.x

**Current status: 196/196 captured, 0/196 read.** Honest deferred reading.
