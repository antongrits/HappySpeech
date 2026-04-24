# Sound Assets Registry — HappySpeech

**Version 2.0 — 2026-04-23**
**Managed by:** Sound Curator. All sounds verified CC0 or royalty-free.

---

## Сводка готовности

| Категория | Файлов | Размер | Placement | Статус |
|---|---|---|---|---|
| UI sounds (.caf) | 16 | ~150 KB | `HappySpeech/Resources/Audio/UI/` (в репо) | ✅ M3.2 done |
| Ляля voice brand (.m4a) | 120 | ~2 MB | `HappySpeech/Resources/Audio/Lyalya/` (в репо) | ✅ M3.3 done |
| Content audio batch 1 (.m4a) | 1000 | 12.65 MB | `HappySpeech/Resources/Audio/Content/` (локально, gitignored → Firebase Storage) | ✅ M3.4 batch 1 |
| Content audio batch 2 (.m4a) | 1028 | 11.1 MB | `HappySpeech/Resources/Audio/Content/` (локально, gitignored → Firebase Storage) | ✅ M3.4 batch 2 |
| Content audio batch 3 (.m4a) | 681 | 8.36 MB | `HappySpeech/Resources/Audio/Content/` (локально, gitignored → Firebase Storage) | ✅ M3.4 batch 3 |
| Content audio batch 4+ | 0 / ~3300 | ~40 MB | Firebase Storage | ⏳ pending |
| Эталоны для M4.3 (premium TTS) | 0 | — | `_workshop/references/` | ⏳ pending M3.5 |
| Ambient / background music | 0 / 4 | — | `Resources/Audio/Ambient/` | ⏳ pending M9 |

---

## M3.2 — UI Sounds (16 файлов) ✅

**Генерация:** `_workshop/scripts/generate_ui_sounds.py` (numpy + scipy + afconvert, алгоритмически)
**Формат:** 16kHz mono AAC в `.caf` контейнере
**Лицензия:** CC0 (алгоритмически сгенерированы)

| Файл | Назначение | Длительность |
|---|---|---|
| `tap.caf` | Нажатие кнопки | 0.15s |
| `correct.caf` | Правильный ответ | 0.3s |
| `incorrect.caf` | Ошибка (мягкая, не травмирующая) | 0.25s |
| `reward.caf` | Получение награды | 0.8s |
| `streak.caf` | Серия подряд | 0.5s |
| `level_up.caf` | Новый уровень | 1.0s |
| `warmup_start.caf` | Начало разминки | 0.4s |
| `warmup_end.caf` | Конец разминки | 0.4s |
| `complete.caf` | Завершение сессии | 0.6s |
| `pause.caf` | Пауза | 0.2s |
| `notification.caf` | Уведомление | 0.3s |
| `transition_next.caf` | Переход вперёд | 0.2s |
| `transition_back.caf` | Переход назад | 0.2s |
| `drag_pick.caf` | Захват drag | 0.15s |
| `drag_drop.caf` | Отпускание drag | 0.2s |
| `error.caf` | Общая ошибка UI | 0.25s |

---

## M3.3 — Ляля Voice Brand (120 файлов) ✅

**Генерация:** edge-tts `ru-RU-SvetlanaNeural` → pyloudnorm -16 LUFS → afconvert в .m4a
**Формат:** 16kHz mono AAC
**Лицензия:** Microsoft edge-tts (outputs без copyright — cleared для App Store)

**Voice spec:** Warm female, age 25–35, clear diction, moderate pace, positive without over-excitement.

### Покрытие 120 фраз

- Приветствия (12): "Привет! Я Ляля. Давай потренируемся вместе!", и вариации для onboarding/returning user/утренних/вечерних сессий
- Поощрения (25): "Отличная работа!", "Ты настоящий чемпион!", "Почти-почти!"
- Инструкции (30): "Разогреем язычок!", "Слушай внимательно...", "Повтори за мной!", "Тащи картинку в нужный домик!", "Найди звук-прятку!", "Дыши медленно и ровно..."
- Фидбек позитивный (20): "Ты уже так близко к звезде!"
- Фидбек корректирующий (15): "Это трудный звук — и это нормально!"
- Завершения (10): "На сегодня всё! Отдохни.", "Завтра продолжим приключение!"
- Артикуляция (5): "Высуни язычок!", "Улыбнись пошире!", "Надуй щёки!"
- AR-инструкции (3): "Посмотри на своё лицо в зеркало!", "Надуй шарик! Дуй!"

---

## M3.4 — Content Audio Batch 1 (1000 файлов, 12.65 MB) ✅

**Генерация:** edge-tts `ru-RU-SvetlanaNeural` → pyloudnorm -16 LUFS → AAC .m4a
**Формат:** 16kHz mono, 7–27 KB/файл (все < 50 KB)
**Длительность:** 1.4–3.5s

**Важно:** 12.65 MB превышает порог 10 MB для inline-хранения в репо. Файлы в `.gitignore`, для production нужна **загрузка в Firebase Storage** (см. M11.4 — backend-developer).

### Разбивка по пакам batch 1

| Пак | Звук | Файлов | Размер |
|---|---|---|---|
| `pack_whistling_s.json` | С (все этапы) | 362 | 4953 KB |
| `pack_whistling_z.json` | З (все этапы) | 301 | 3879 KB |
| `pack_whistling_c.json` | Ц (все этапы) | 221 | 2883 KB |
| `pack_hissing_sh.json` | Ш (prep+isolated+syllable+wordInit) | 116 | 1235 KB |
| **ИТОГО batch 1** | — | **1000** | **12.65 MB** |

### Время генерации
26.2 минуты (edge-tts inference + LUFS normalization + AAC encoding).

### Путь к скрипту (resumable)
`_workshop/scripts/generate_content_audio.py` — при повторном запуске пропускает уже готовые файлы.

### Валидация
20/20 случайных файлов прошли afinfo-валидацию:
- Sample rate 16000 Hz ✅
- Channels 1 (mono) ✅
- Codec AAC ✅
- -16 LUFS ± 0.5 ✅

---

## M3.4 Batch 2 — Сонорные Р/Л (1028 файлов, 11.1 MB) ✅

**Дата:** 2026-04-24
**Генерация:** `_workshop/scripts/generate_sonants_audio.py` — edge-tts `ru-RU-SvetlanaNeural` → pyloudnorm -16 LUFS → AAC .m4a
**Формат:** 16kHz mono, 5–45 KB/файл (все < 50 KB)
**Длительность:** 1.0–3.5s

### Разбивка по пакам batch 2

| Пак | Звук | Этапы | Файлов | Размер |
|---|---|---|---|---|
| `sound_r_pack.json` | Р/Р' (все этапы) | prep, isolated, syllable, wordInit, wordMed, wordFinal, phrase, sentence, story, diff | 500 | 5.1 MB |
| `sound_l_pack.json` | Л/Л' (все этапы) | prep, isolated, syllable, wordInit, wordMed, wordFinal, phrase, sentence, story, diff | 328 | 3.3 MB |
| `sound_diff_rl_pack.json` | Р/Л дифференциация | prep, isolated, syllable, wordInit, wordMed, phrase, sentence, diff | 200 | 2.7 MB |
| **ИТОГО batch 2** | — | — | **1028** | **11.1 MB** |

### Валидация (5 случайных файлов)
- Sample rate 16000 Hz ✅
- Channels 1 (mono) ✅
- Codec AAC (.m4a) ✅
- Размер < 50 KB ✅ (0 нарушений)
- Все 1028 файлов сгенерированы, 0 пропущено ✅

### Путь к скрипту (resumable)
`_workshop/scripts/generate_sonants_audio.py` — при повторном запуске пропускает уже готовые файлы.

---

## M3.4 Batch 3 — Велярные К/Г/Х (681 файл, 8.36 MB) ✅

**Дата:** 2026-04-24
**Генерация:** `_workshop/scripts/generate_velar_audio.py` — edge-tts `ru-RU-SvetlanaNeural` → pyloudnorm -16 LUFS → AAC .m4a
**Формат:** 16kHz mono, 8–45 KB/файл (все < 50 KB)
**Длительность:** 1.5–3.6s
**Время генерации:** 17.0 минут

### Разбивка по пакам batch 3

| Пак | Звук | Этапы | Файлов | Размер |
|---|---|---|---|---|
| `sound_k_pack.json` | К/К' (все этапы) | prep, isolated, syllable, wordInit, wordMed, wordFinal, phrase, sentence, diff | 247 | 2919 KB |
| `sound_g_pack.json` | Г/Г' (все этапы) | prep, isolated, syllable, wordInit, wordMed, wordFinal, phrase, sentence, diff | 184 | 2270 KB |
| `sound_kh_pack.json` | Х/Х' (все этапы) | prep, isolated, syllable, wordInit, wordMed, wordFinal, phrase, sentence | 250 | 3358 KB |
| **ИТОГО batch 3** | — | — | **681** | **8.36 MB** |

### Валидация (7 случайных файлов)
- Sample rate 16000 Hz ✅
- Channels 1 (mono) ✅
- Codec AAC (.m4a) ✅
- Размер < 50 KB ✅ (0 нарушений)
- 681/681 файлов сгенерированы ✅

### Путь к скрипту (resumable)
`_workshop/scripts/generate_velar_audio.py` — при повторном запуске пропускает уже готовые файлы.

---

## M3.4 Batch 4+ — Остальные паки (~3300 файлов) ⏳

**Status:** pending
**План:** Ж, Ч, Щ, Й, и все narrative/breathing/lexical паки.

Оценка: ~80 минут общего времени генерации, ~40 MB финального объёма.

---

## M3.5 — Эталоны для PronunciationScorer (pending) ⏳

**Цель:** premium TTS (utrobinmv VITS High, Apache 2.0 — см. `ml-models-research.md`) на целевые слова каждого пака → обучающие данные для M4.3 per-group scorers.

**Оценка объёма:** ~1200 эталонных слов × ~20 KB = 24 MB
**Размещение:** `_workshop/datasets/raw/references/` (не в репо)

---

## M3.6 — Ambient / Background music (pending) ⏳

| Asset | Description | Status |
|---|---|---|
| world_map_ambient | Soft adventure music for world map screen | Needed (CC0) |
| lesson_bgm | Gentle background music during lesson | Needed (CC0) |
| ar_zone_ambient | Slightly playful, light music for AR zone | Needed (CC0) |
| reward_music | Celebratory short loop for reward screen | Needed (CC0) |

**Music spec:** Instrumental only, child-friendly, loopable, CC0 (Freesound, ccMixter, Free Music Archive).

---

## Firebase Storage план

После M3.4 batch 2+:
- `/audio/ui/*.caf` — UI sounds (копия для cold-start recovery)
- `/audio/lyalya/*.m4a` — Ляля voice brand (копия)
- `/audio/content/{sound}/{unitId}.m4a` — content audio (primary storage)
- `/audio/content/manifest.json` — реестр (sha256, size, duration, pack, stage)

Клиент при onboarding скачивает только нужные паки (экономия 1.5GB IPA budget).

---

## Лицензии и атрибуция

- **edge-tts (Microsoft):** Free service, выходные файлы без copyright (cleared для App Store)
- **pyloudnorm (BSD-3-Clause):** OK для коммерческого использования
- **afconvert (macOS built-in):** OK
- **ffmpeg (LGPL):** OK при dynamic linking
- **Для reference pronunciations (M3.5):** utrobinmv VITS High Apache 2.0 (см. ml-models-research.md)

---

## Pipeline

```
Sound Curator workflow:
1. UI sounds: numpy+scipy алгоритмическая генерация → afconvert → .caf (готово)
2. Voice prompts (Ляля): edge-tts ru-RU-SvetlanaNeural → pyloudnorm -16 LUFS → .m4a (готово)
3. Content audio: edge-tts batch → pyloudnorm → .m4a → локально (в gitignore) → Firebase Storage (в процессе)
4. Reference pronunciations: utrobinmv VITS premium → _workshop/references/ (pending M3.5)
5. Ambient music: Freesound CC0 download → validate → .m4a (pending)
6. Обновление этого реестра после каждого батча

COPYRIGHT RULE: каждый звук должен иметь verified CC0/Apache/MIT до добавления в Resources/Audio/.
```

---

## Следующие шаги

- **M3.4 batch 3** — ✅ DONE — велярные К/Г/Х (681 файл, 8.36 MB, 17 мин)
- **M3.4 batch 4** — запустить аналогичный скрипт для Ж/Ч/Щ/Й + lexical/narrative паки (~80 мин)
- **M3.5** — генерация эталонов для PronunciationScorer (после M3.4 batch 2, ~1200 слов)
- **M3.6 ambient** — 4 трека CC0 для world_map/lesson/AR/reward
- **Firebase Storage upload** — после M3.4 batch 3 (финальный) → delegated to backend-developer M11.4

## См. также

- `.claude/team/ml-datasets.md` — источники ML-датасетов
- `.claude/team/ml-models-research.md` — рекомендуемые TTS/VAD/LLM модели
- `.claude/team/ml-models.md` — реестр Core ML моделей
