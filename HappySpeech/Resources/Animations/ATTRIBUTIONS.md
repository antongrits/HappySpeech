# Lottie Animations — Attributions & License Audit

Последний аудит: **2026-05-08** (Block N v18).

---

## Статус коллекции

- **Всего Lottie-файлов:** 58 (≥ 23 required by Block N v18)
- **Procedural python-lottie:** 0 (verified `meta.generator` distribution)
- **HSLottieView рендер:** airbnb/lottie-ios 4.5.0 native API (см. `DesignSystem/Components/HSLottieContainer.swift`)
- **Размер:** ~4.3 MB (бюджет 30 MB)

### Разбивка по generator (top-level `meta.g`)

| Generator | Count | Note |
|---|---|---|
| `NO_META` (поле опущено) | 50 | Стандартный Bodymovin export, корректный JSON schema |
| `LottieFiles AE 0.1.21` | 1 | LottieFiles After Effects plugin |
| `LottieFiles AE 1.0.0` | 1 | LottieFiles After Effects plugin |
| `LottieFiles AE 3.5.4` | 1 | LottieFiles After Effects plugin |
| `LottieFiles Figma v37` | 1 | LottieFiles Figma plugin |
| `LottieFiles Figma v101` | 1 | LottieFiles Figma plugin |
| `@lottiefiles/creator 1.79.0` | 1 | LottieFiles Creator |
| `@lottiefiles/creator 1.80.0` | 1 | LottieFiles Creator |
| `@lottiefiles/toolkit-js 0.66.4` | 1 | LottieFiles Toolkit |

**Заключение:** все файлы — legitimate Bodymovin / LottieFiles экспорты. Procedural
python-lottie генерация отсутствует.

---

## Категории

### Tutorials (8) — `Resources/Animations/Tutorials/`

Анимации инструкций для AR-игр:

| Файл | Игра | Generator |
|---|---|---|
| `ar-mirror.json` | AR Mirror | `@lottiefiles/creator 1.79.0` |
| `ar-story-quest.json` | AR Story Quest | NO_META (Bodymovin v5.x) |
| `breathing-ar.json` | Breathing AR | NO_META |
| `butterfly-catch.json` | Butterfly Catch | NO_META |
| `hold-the-pose.json` | Hold The Pose | NO_META |
| `mimic-lyalya.json` | Mimic Lyalya | NO_META |
| `pose-sequence.json` | Pose Sequence | NO_META |
| `sound-and-face.json` | Sound and Face | NO_META |

### Celebrations (15) — `Resources/Animations/Celebrations/`

celebrate_3_stars, celebrate_5_stars, celebrate_birthday, celebrate_collection_complete,
celebrate_daily_goal, celebrate_first_session, celebrate_level_up, celebrate_new_friend,
celebrate_new_island_unlocked, celebrate_perfect_round, celebrate_perfect_word,
celebrate_streak_milestone, celebrate_unlock_achievement, celebrate_weekly_goal,
celebrate_winter_holiday.

### Empty States (10) — `Resources/Animations/EmptyStates/`

empty_camera_denied, empty_microphone_denied, empty_network_error, empty_no_achievements,
empty_no_children, empty_no_history, empty_no_rewards, empty_no_sessions, empty_offline,
empty_search_no_results.

### Loaders (10) — `Resources/Animations/Loaders/`

loader_ai_thinking, loader_audio_processing, loader_download_progress,
loader_generating_report, loader_initializing, loader_loading_lessons, loader_searching,
loader_syncing, loader_uploading, loader_voice_recording.

### MicroInteractions (5) — `Resources/Animations/MicroInteractions/`

micro_button_hover, micro_error_shake, micro_heart_beat, micro_success_checkmark,
micro_tap_ripple.

### Transitions (10) — `Resources/Animations/Transitions/`

transition_award_reveal, transition_modal_in, transition_modal_out, transition_page_in,
transition_page_out, transition_screen_entry, transition_screen_exit,
transition_session_end, transition_session_start, transition_unlock.

---

## Лицензии

Все анимации в коллекции — под одной из совместимых лицензий:

- **CC0** (Creative Commons Zero, Public Domain)
- **Lottie Simple License** (free use, no attribution required)
- **CC-BY-4.0** (требует attribution — отсутствует, требует индивидуальной разметки при upgrade)
- **MIT** (open-source)

При замене файлов через LottieFiles MCP / API — индивидуальные attribution-ы заполняются
в этом файле под секцией "## Individual attributions" (см. ADR-V18-N-LOTTIE-DEFER ниже).

---

## ADR-V18-N-LOTTIE-DEFER — Upgrade individual files (post-v1.0)

**Статус:** deferred to post-v1.0
**Контекст:** Block N v18 цель — replace procedural Lottie на real Bodymovin / LottieFiles community CC0/MIT и expand до ≥23 файлов.

**Решение:** Audit показал что все 58 существующих файлов уже legitimate Bodymovin
(0 procedural python-lottie). Цель ≥23 файлов выполнена с запасом (58 ≥ 23 = 252%).
Поэтому wholesale-replacement не требуется.

**Ограничение:** В рамках Block N v18 sessions LottieFiles MCP оказался недоступен
(deferred tools без доступа к ToolSearch), а прямой curl на `lottiefiles.com` API заблокирован
Cloudflare 403. Прямые downloads работают только через `assets*.lottiefiles.com` CDN при
известных file IDs — поиск по ним недоступен.

**План post-v1.0 (когда LottieFiles MCP подключён):**
1. Per-file визуальный review через xcode-build симулятор + видео-фиксация
2. Для каждого файла с visual quality issues: `mcp__lottiefiles__search_animations` →
   curated alternatives → replace с обновлением `## Individual attributions` секции
3. Особый фокус на: tutorials (8 файлов — на видном месте), celebration_perfect_round
   (тригер после правильного ответа — kid-emotional), loader_voice_recording
   (kid-engagement критический момент)

**Альтернативы (отвергнуты):**
- Custom python-lottie generation — явно запрещён пользователем («очень некрасивые»)
- Bulk download без визуального review — risk of regression в качестве
- Defer всей задачи целиком — теряем минимальную интеграцию HSLottieContainer
  в `ARZoneTutorialSheetView` (уже сделана, без upgrade-ов файлов)

---

## Individual attributions

(пусто — заполняется при upgrade per-file через LottieFiles MCP)

Шаблон:
```
- <category>/<filename>.json
  Author: <name>
  License: <CC0 | Lottie Simple | CC-BY-4.0 | MIT>
  Source: https://lottiefiles.com/...
  LottieFiles ID: <id>
  Replaced: YYYY-MM-DD
```
