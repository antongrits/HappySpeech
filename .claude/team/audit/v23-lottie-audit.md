# v23 Lottie Audit Report (Block 3.4.1)

**Date:** 2026-05-14
**Total files:** 58

## Summary

- procedural-replace: **12**
- borderline: **30**
- professional: **16**

## Verdict criteria

- `procedural-replace`: layers <= 10 AND assets == 0 AND meta.generator missing
- `borderline`: layers 11-20 OR has 1 asset
- `professional`: layers > 20 OR has multiple assets OR Bodymovin generator

## Files

| File | Layers | Assets | meta.generator | Size (B) | Verdict |
|------|--------|--------|----------------|----------|---------|
| Celebrations/celebrate_3_stars.json | 25 | 7 | NONE | 207001 | ✅ professional |
| Celebrations/celebrate_5_stars.json | 25 | 7 | NONE | 207001 | ✅ professional |
| Celebrations/celebrate_birthday.json | 4 | 0 | NONE | 30312 | ❌ procedural-replace |
| Celebrations/celebrate_collection_complete.json | 14 | 0 | NONE | 47829 | ⚠️ borderline |
| Celebrations/celebrate_daily_goal.json | 17 | 0 | NONE | 54302 | ⚠️ borderline |
| Celebrations/celebrate_first_session.json | 9 | 0 | NONE | 24564 | ❌ procedural-replace |
| Celebrations/celebrate_level_up.json | 4 | 0 | NONE | 14227 | ❌ procedural-replace |
| Celebrations/celebrate_new_friend.json | 1 | 4 | NONE | 112686 | ⚠️ borderline |
| Celebrations/celebrate_new_island_unlocked.json | 7 | 0 | NONE | 79272 | ❌ procedural-replace |
| Celebrations/celebrate_perfect_round.json | 4 | 1 | NONE | 30515 | ⚠️ borderline |
| Celebrations/celebrate_perfect_word.json | 11 | 0 | NONE | 14445 | ⚠️ borderline |
| Celebrations/celebrate_streak_milestone.json | 14 | 1 | NONE | 105168 | ⚠️ borderline |
| Celebrations/celebrate_unlock_achievement.json | 14 | 0 | NONE | 47829 | ⚠️ borderline |
| Celebrations/celebrate_weekly_goal.json | 13 | 0 | NONE | 177770 | ⚠️ borderline |
| Celebrations/celebrate_winter_holiday.json | 9 | 0 | NONE | 21705 | ❌ procedural-replace |
| EmptyStates/empty_camera_denied.json | 34 | 4 | NONE | 89923 | ✅ professional |
| EmptyStates/empty_microphone_denied.json | 61 | 0 | NONE | 163847 | ✅ professional |
| EmptyStates/empty_network_error.json | 12 | 0 | NONE | 29799 | ⚠️ borderline |
| EmptyStates/empty_no_achievements.json | 14 | 0 | NONE | 47829 | ⚠️ borderline |
| EmptyStates/empty_no_children.json | 3 | 4 | NONE | 78362 | ⚠️ borderline |
| EmptyStates/empty_no_history.json | 2 | 2 | NONE | 28108 | ⚠️ borderline |
| EmptyStates/empty_no_rewards.json | 14 | 0 | NONE | 47829 | ⚠️ borderline |
| EmptyStates/empty_no_sessions.json | 2 | 2 | NONE | 28108 | ⚠️ borderline |
| EmptyStates/empty_offline.json | 7 | 0 | NONE | 37136 | ❌ procedural-replace |
| EmptyStates/empty_search_no_results.json | 10 | 0 | NONE | 16564 | ❌ procedural-replace |
| Loaders/loader_ai_thinking.json | 13 | 0 | NONE | 21559 | ⚠️ borderline |
| Loaders/loader_audio_processing.json | 11 | 1 | NONE | 20243 | ⚠️ borderline |
| Loaders/loader_download_progress.json | 7 | 2 | NONE | 16695 | ⚠️ borderline |
| Loaders/loader_generating_report.json | 23 | 0 | NONE | 151339 | ✅ professional |
| Loaders/loader_initializing.json | 7 | 0 | NONE | 13108 | ❌ procedural-replace |
| Loaders/loader_loading_lessons.json | 5 | 5 | NONE | 122937 | ⚠️ borderline |
| Loaders/loader_searching.json | 13 | 0 | NONE | 53639 | ⚠️ borderline |
| Loaders/loader_syncing.json | 3 | 0 | NONE | 11741 | ❌ procedural-replace |
| Loaders/loader_uploading.json | 6 | 2 | NONE | 52431 | ⚠️ borderline |
| Loaders/loader_voice_recording.json | 5 | 6 | NONE | 106477 | ⚠️ borderline |
| MicroInteractions/micro_button_hover.json | 24 | 0 | NONE | 166951 | ✅ professional |
| MicroInteractions/micro_error_shake.json | 6 | 1 | NONE | 16916 | ⚠️ borderline |
| MicroInteractions/micro_heart_beat.json | 6 | 3 | NONE | 43075 | ⚠️ borderline |
| MicroInteractions/micro_success_checkmark.json | 11 | 0 | NONE | 14445 | ⚠️ borderline |
| MicroInteractions/micro_tap_ripple.json | 24 | 2 | NONE | 87637 | ✅ professional |
| Transitions/transition_award_reveal.json | 14 | 1 | NONE | 105168 | ⚠️ borderline |
| Transitions/transition_modal_in.json | 8 | 2 | NONE | 57176 | ⚠️ borderline |
| Transitions/transition_modal_out.json | 9 | 0 | NONE | 22971 | ❌ procedural-replace |
| Transitions/transition_page_in.json | 21 | 0 | NONE | 76453 | ✅ professional |
| Transitions/transition_page_out.json | 4 | 1 | NONE | 17973 | ⚠️ borderline |
| Transitions/transition_screen_entry.json | 61 | 0 | NONE | 163847 | ✅ professional |
| Transitions/transition_screen_exit.json | 11 | 0 | NONE | 15130 | ⚠️ borderline |
| Transitions/transition_session_end.json | 7 | 6 | NONE | 22943 | ⚠️ borderline |
| Transitions/transition_session_start.json | 3 | 0 | NONE | 27711 | ❌ procedural-replace |
| Transitions/transition_unlock.json | 5 | 0 | NONE | 83357 | ❌ procedural-replace |
| Tutorials/ar-mirror.json | 30 | 0 | NONE | 52212 | ✅ professional |
| Tutorials/ar-story-quest.json | 137 | 7 | NONE | 130347 | ✅ professional |
| Tutorials/breathing-ar.json | 21 | 0 | NONE | 44087 | ✅ professional |
| Tutorials/butterfly-catch.json | 19 | 3 | NONE | 114797 | ⚠️ borderline |
| Tutorials/hold-the-pose.json | 119 | 0 | NONE | 141622 | ✅ professional |
| Tutorials/mimic-lyalya.json | 26 | 0 | NONE | 234946 | ✅ professional |
| Tutorials/pose-sequence.json | 115 | 0 | NONE | 367172 | ✅ professional |
| Tutorials/sound-and-face.json | 30 | 0 | NONE | 47326 | ✅ professional |

## Procedural files (Block 3.4.2 — replace candidates)

- `Celebrations/celebrate_birthday.json` (L=4, A=0, 30312B)
- `Celebrations/celebrate_first_session.json` (L=9, A=0, 24564B)
- `Celebrations/celebrate_level_up.json` (L=4, A=0, 14227B)
- `Celebrations/celebrate_new_island_unlocked.json` (L=7, A=0, 79272B)
- `Celebrations/celebrate_winter_holiday.json` (L=9, A=0, 21705B)
- `EmptyStates/empty_offline.json` (L=7, A=0, 37136B)
- `EmptyStates/empty_search_no_results.json` (L=10, A=0, 16564B)
- `Loaders/loader_initializing.json` (L=7, A=0, 13108B)
- `Loaders/loader_syncing.json` (L=3, A=0, 11741B)
- `Transitions/transition_modal_out.json` (L=9, A=0, 22971B)
- `Transitions/transition_session_start.json` (L=3, A=0, 27711B)
- `Transitions/transition_unlock.json` (L=5, A=0, 83357B)
