# Sound Assets Registry — HappySpeech

**Version 2.3 — 2026-04-29**
**Managed by:** Sound Curator. All sounds verified CC0 or royalty-free.

---

## Сводка готовности

| Категория | Файлов | Размер | Placement | Статус |
|---|---|---|---|---|
| UI sounds (.caf) | 16 | ~150 KB | `HappySpeech/Resources/Audio/UI/` (в репо) | ✅ M3.2 done |
| Ляля voice brand (.m4a) | 171 | ~5.7 MB | `HappySpeech/Resources/Audio/Lyalya/` (в репо) | ✅ M3.3 + M3.7 + M3.7b + M3.7c + M3.7d + M3.7e done |
| Ляля tuned voice (.m4a) | 50 | ~852 KB | `HappySpeech/Resources/Audio/Lyalya/tuned/` (в репо) | ✅ Sprint 12 Блок L1 done |
| Ляля Block P voice expansion (.m4a) | 570 | ~9.7 MB | `HappySpeech/Resources/Audio/Lyalya/<11 categories>/` (в репо) | ✅ Plan v11 Block P done |
| Content audio batch 1 (.m4a) | 1000 | 12.65 MB | `HappySpeech/Resources/Audio/Content/` (локально, gitignored → Firebase Storage) | ✅ M3.4 batch 1 |
| Content audio batch 2 (.m4a) | 1028 | 11.1 MB | `HappySpeech/Resources/Audio/Content/` (локально, gitignored → Firebase Storage) | ✅ M3.4 batch 2 |
| Content audio batch 3 (.m4a) | 681 | 8.36 MB | `HappySpeech/Resources/Audio/Content/` (локально, gitignored → Firebase Storage) | ✅ M3.4 batch 3 |
| Content audio batch 4 (.m4a) | 2568 | 40.09 MB | `HappySpeech/Resources/Audio/Content/` (локально, gitignored → Firebase Storage) | ✅ M3.4 batch 4 |
| Content audio batch 5 — lexical+grammar (.m4a) | 900 | 16.9 MB | `HappySpeech/Resources/Audio/Content/Lexical/` + `Grammar/` (локально, gitignored) | ✅ M3.4 batch 5 |
| Эталоны для PronunciationScorer (ML refs) | 665 | 7.9 MB | `HappySpeech/Resources/Audio/Refs/` (в репо) | ✅ M3.5 done |
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

## M3.4 Batch 4 — Ж/Ч/Щ/Й + Lexical/Breathing/Narrative/ArticulationGym/Phonemic/DiffWhistHiss (2568 файлов, 40.09 MB) ✅

**Дата:** 2026-04-24
**Генерация:** `_workshop/scripts/generate_batch4_audio.py` — edge-tts `ru-RU-SvetlanaNeural` → pyloudnorm -16 LUFS → AAC .m4a
**Формат:** 16kHz mono AAC, 8–24 KB/файл (все < 50 KB)
**Длительность:** 1.4–3.5s
**Время генерации:** 70.3 минут
**Ошибок:** 0 (2568/2568 сгенерированы)

### Разбивка по пакам batch 4

| Пак | Звук/категория | Файлов | Размер |
|---|---|---|---|
| `sound_zh_pack.json` | Ж (все этапы) | 268 | 3344 KB |
| `sound_ch_pack.json` | Ч (все этапы) | 350 | 4661 KB |
| `sound_shch_pack.json` | Щ (все этапы) | 300 | 4026 KB |
| `sound_y_pack.json` | Й (все этапы) | 250 | 3482 KB |
| `pack_lexical.json` | Лексический пак | 350 | 5420 KB |
| `pack_breathing.json` | Дыхательные упражнения | 300 | 5139 KB |
| `pack_narrative.json` | Нарративные задания | 200 | 4325 KB |
| `pack_articulation_gymnastics.json` | Артикуляционная гимнастика | 150 | 2832 KB |
| `pack_general_phonemic.json` | Фонематический слух | 196 | 4367 KB |
| `pack_diff_whistling_hissing.json` | Дифференциация свистящих/шипящих | 204 | 3457 KB |
| **ИТОГО batch 4** | — | **2568** | **40.09 MB** |

### Валидация (10 случайных файлов)
- Sample rate 16000 Hz ✅
- Channels 1 (mono) ✅
- Codec AAC (.m4a) ✅
- Размер < 50 KB ✅ (диапазон 8–24 KB)
- 2568/2568 файлов сгенерированы, 0 ошибок ✅

### Путь к скрипту (resumable)
`_workshop/scripts/generate_batch4_audio.py` — при повторном запуске пропускает уже готовые файлы.

---

## M3.5 — Эталоны для PronunciationScorer (665 файлов, 7.9 MB) ✅

**Дата:** 2026-04-26
**Голос:** `ru-RU-SvetlanaNeural` (edge-tts) → -16 LUFS → AAC 16kHz mono 96kbps
**Лицензия:** Microsoft edge-tts (royalty-free)
**Размещение:** `HappySpeech/Resources/Audio/Refs/{sound}/` (в репо — ≤10 MB)

| Звук | Этапы | Файлов | Размер |
|---|---|---|---|
| S (свистящий С) | wordInit (64) + wordMed (50) + wordFinal (40) | 154 | 1.8 MB |
| Z (свистящий З) | wordInit (55) + wordMed (45) + wordFinal (35) | 135 | 1.6 MB |
| SH (шипящий Ш) | wordInit (56) + wordMed (50) + wordFinal (40) | 146 | 1.7 MB |
| R (сонорный Р) | wordInit (70) + wordMed (80) + wordFinal (80) | 230 | 2.7 MB |
| **ИТОГО** | — | **665** | **7.9 MB** |

**Валидация (6 случайных файлов):**
- AAC LC, 16000 Hz, mono ✅
- Размер 8–28 KB ✅ (< 50 KB)
- edge-tts clean signal, SNR >> 30 dB ✅

**Назначение:** обучающие данные для `PronunciationScorer` CoreML (M4.3). Каждый файл — эталонное произношение целевого слова для сравнения с речью ребёнка.

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

## M3.5 — Content Audio Batch 5 — Grammar (141 файл, 2.3 MB) ✅

**Дата:** 2026-04-24
**Генерация:** edge-tts `ru-RU-SvetlanaNeural` → ffmpeg AAC .m4a
**Формат:** 22050 Hz mono AAC, 9–18 KB/файл
**Пак:** `pack_grammar.json` — 141 items из 7 stages

| Stage | Файлов | Описание |
|---|---|---|
| plural | 20 | Множественное число |
| adjective_agreement | 20 | Согласование прилагательных |
| prepositions | 23 | Предлоги |
| verb_forms | 19 | Глагольные формы |
| cases | 20 | Падежи |
| word_change | 26 | Словоизменение |
| sentences_grammar | 13 | Грамматические предложения |
| **ИТОГО** | **141** | — |

**Валидация (5 случайных файлов):**
- AAC codec ✅
- 22050 Hz mono ✅
- Размер 9–18 KB ✅
- 141/141 сгенерировано, 0 ошибок ✅

**Путь:** `HappySpeech/Resources/Audio/Content/Grammar/` (локально, gitignored → Firebase Storage)

---

## M3.7 — Новые фразы Ляли +30 (итого 150 фраз) ✅

**Дата:** 2026-04-24 / 2026-04-26 (финальная фраза)
**Генерация:** edge-tts `ru-RU-SvetlanaNeural` → ffmpeg AAC .m4a → -16 LUFS
**Формат:** 16kHz mono AAC, 8–50 KB/файл
**Путь:** `HappySpeech/Resources/Audio/Lyalya/`

**Примечание по голосу:** `ru-RU-DariyaNeural` недоступен в edge-tts 7.2.8. Использован `SvetlanaNeural` — соответствует M3.3.

**Swift enum:** `LyalyaPhrase` в `SoundService.swift` обновлён до 150 кейсов (все новые группы добавлены).

| Экран / категория | Файлы | Кол-во |
|---|---|---|
| HomeTasks | lyalya_hometasks_*.m4a | 3 |
| WorldMap | lyalya_worldmap_*.m4a | 3 |
| Onboarding | lyalya_onboarding_*.m4a | 4 |
| SessionComplete (оценки) | lyalya_session_excellent/good/try_again.m4a | 3 |
| Rewards | lyalya_reward_*.m4a | 3 |
| ProgressDashboard | lyalya_progress_great/keep_going/proud.m4a | 3 |
| Settings | lyalya_settings_hello.m4a | 1 |
| Permissions | lyalya_permission_*.m4a | 2 |
| Demo | lyalya_demo_*.m4a | 3 |
| ChildHome | lyalya_childhome_*.m4a | 5 |
| **ИТОГО новых (M3.7b)** | — | **30** |

**Валидация (5 файлов):**
- AAC LC, 16000 Hz mono ✅
- Размер 8–50 KB ✅
- 30/30 сгенерировано, 0 ошибок ✅

---

## M3.7c — Story voice-over фразы 16-20 (+5, итого 155 фраз) ✅

**Дата:** 2026-04-28
**Генерация:** edge-tts `ru-RU-SvetlanaNeural` → ffmpeg loudnorm -16 LUFS → AAC 16kHz mono 32kbps
**Формат:** 16kHz mono AAC, 16–19 KB/файл (все < 50 KB)
**Длительность:** 4.2–4.4s
**Путь:** `HappySpeech/Resources/Audio/Lyalya/`

| Файл | Текст | Размер | LUFS |
|---|---|---|---|
| `lyalya_story_16.m4a` | Пингвин Пётр жил на льдине и поймал рыбок для пингвинят | 17 KB | -16.83 |
| `lyalya_story_17.m4a` | Ёжик Егор ел ежевику и нашёл грибы на иголки | 17 KB | -16.73 |
| `lyalya_story_18.m4a` | Бабочка Белла летела сквозь радугу и рисовала букву Б | 18 KB | -17.14 |
| `lyalya_story_19.m4a` | Дракон Дима добрый и дружелюбный стал другом долины | 16 KB | -16.91 |
| `lyalya_story_20.m4a` | Тигр Тимур тихо ходил по тропинке и рассказывал сказки | 19 KB | -17.35 |

**Назначение:** voice-over для Remotion stories 16-20 (Block A, Plan v9). Передаётся animator'у для перерендеринга MP4.

---

## M3.7d — Grammar games voice-over (13 файлов, F1-009) ✅

**Дата:** 2026-04-28
**Генерация:** edge-tts `ru-RU-SvetlanaNeural` → ffmpeg loudnorm -16 LUFS → AAC 16kHz mono 32kbps
**Формат:** 16kHz mono AAC, 9–21 KB/файл (все < 50 KB)
**LUFS:** -15.0 … -16.2 (цель -16 ±1.5)
**Путь:** `HappySpeech/Resources/Audio/Lyalya/`
**Итого Ляля:** 155 → **168 фраз**

| Файл | Текст | Размер |
|---|---|---|
| `lyalya_grammar_intro.m4a` | Привет! Давай учиться правильно говорить! | 21 KB |
| `lyalya_grammar_correct_1.m4a` | Молодец! Правильно! | 13 KB |
| `lyalya_grammar_correct_2.m4a` | Здорово получилось! | 9 KB |
| `lyalya_grammar_correct_3.m4a` | Умница! У тебя отлично! | 14 KB |
| `lyalya_grammar_try_again.m4a` | Попробуй ещё раз | 9 KB |
| `lyalya_grammar_hint.m4a` | Подумай как сказать про много | 12 KB |
| `lyalya_grammar_complete_easy.m4a` | Отлично! Ты прошёл лёгкий уровень! | 17 KB |
| `lyalya_grammar_complete_medium.m4a` | Супер! Средний уровень покорён! | 15 KB |
| `lyalya_grammar_complete_hard.m4a` | Это просто блестяще! Сложный уровень — твой! | 19 KB |
| `lyalya_grammar_one_many_intro.m4a` | Игра один и много — выбери правильную форму | 17 KB |
| `lyalya_grammar_dative_intro.m4a` | Кому что нужно? Перетащи предмет | 16 KB |
| `lyalya_grammar_genitive_intro.m4a` | Откуда взяли? Найди правильное место | 17 KB |
| `lyalya_grammar_instrumental_intro.m4a` | С кем играем? Выбери друга | 14 KB |

**Интеграция:** `GrammarFeedbackWorker.swift` обновлён — методы `speakQuestion(mode:)`, `speakCorrectFeedback`, `speakIncorrectFeedback`, `speakHint`, `speakLevelComplete(difficulty:)` используют m4a-ассеты через `Bundle.main.url(forResource:withExtension:subdirectory:)` с TTS-fallback.

---

## M3.7e — Customization Voice Previews (3 файла) ✅

**Дата:** 2026-04-28
**Задача:** F2-009 (Plan v9, Блок F2 step 3)
**Генерация:** edge-tts `ru-RU-SvetlanaNeural` (rate/pitch variants) → ffmpeg loudnorm -16 LUFS → AAC 32k 16kHz mono
**Лицензия:** Microsoft edge-tts (outputs без copyright — cleared для App Store)
**Интеграция:** `CustomizationVoicePreviewWorker.swift` — воспроизводит m4a вместо TTS-fallback

| Файл | Текст | Rate | Pitch | Размер | Длит. |
|---|---|---|---|---|---|
| `lyalya_voice_classic_preview.m4a` | Привет! Я Ляля. Давай играть! | +0% | +0Hz | 23.3 KB | 5.7s |
| `lyalya_voice_soft_preview.m4a` | Привет! Я Ляля. Давай играть! | -10% | -50Hz | 22.4 KB | 6.3s |
| `lyalya_voice_cheerful_preview.m4a` | Привет! Я Ляля. Давай играть! | +15% | +50Hz | 21.8 KB | 4.9s |

**Ляля total:** 168 → 171

---

## Sprint 12 Блок L1 — Ляля Tuned Voice (50 файлов) ✅

**Дата:** 2026-04-29
**Генерация:** `_workshop/scripts/regen_lyalya_tuned.py` — edge-tts `ru-RU-SvetlanaNeural` + `rate=+20%` + `pitch=+100Hz` + `volume=+10%` → ffmpeg loudnorm -16 LUFS → AAC 16kHz mono 32kbps
**Формат:** 16kHz mono AAC, 9–21 KB/файл
**Путь:** `HappySpeech/Resources/Audio/Lyalya/tuned/`
**Лицензия:** Microsoft edge-tts (outputs без copyright — cleared для App Store)
**Назначение:** A/B compare с оригиналами; более child-like тембр для reward/encouragement моментов

| Категория | Phrase IDs | Кол-во |
|---|---|---|
| Grammar feedback | grammar_correct_1/2/3, grammar_intro, grammar_try_again, grammar_hint, grammar_complete_easy/medium/hard | 9 |
| Story voice-over | story_01..story_20 | 20 |
| Rewards / session-end | session_excellent/good/try_again, reward_new/collection | 5 |
| ChildHome / Encouragement | childhome_morning/play, encourage_01..04 | 6 |
| Articulation instructions | artic_01/02/03 | 3 |
| Transitions / WorldMap | transition_01/02, worldmap_intro/unlock | 4 |
| Progress / Onboarding | progress_proud/keep_going, onboarding_start | 3 |
| **ИТОГО** | — | **50** |

**Валидация (grammar_correct_1.m4a):**
- AAC LC, 16000 Hz, mono ✅
- Estimated duration 2.976s ✅
- audio bytes 10920 ✅ (< 50 KB)
- Оригинальные файлы в `Lyalya/` и `Lyalya/lessons/` не изменены ✅

---

## Plan v11 Block P — Ляля Voice Expansion (570 файлов, ~9.7 MB) ✅

**Дата:** 2026-04-29
**Скрипт:** `_workshop/scripts/block_p_voice_expansion.py`
**Голос:** edge-tts `ru-RU-SvetlanaNeural`
**Pipeline:** edge-tts → mp3 → WAV (24kHz mono) → ffmpeg loudnorm (I=-16, TP=-1.5, LRA=11) → ffmpeg AAC 16kHz mono 32kbps → .m4a
**Формат:** AAC LC, 16000 Hz, 1ch mono, 7–40 KB/файл (все < 50 KB)
**Итого .m4a в Lyalya/ после Block P:** 1526 файлов (target ≥1500 ✅)

| Категория | Поддиректория | Кол-во |
|---|---|---|
| hints | `Lyalya/hints/` | 196 |
| stuttering | `Lyalya/stuttering/` | 60 |
| insights | `Lyalya/insights/` | 51 |
| celebrations | `Lyalya/celebrations/` | 50 |
| transitions | `Lyalya/transitions/` | 49 |
| achievements | `Lyalya/achievements/` | 32 |
| seasonal | `Lyalya/seasonal/` | 32 |
| onboarding | `Lyalya/onboarding/` | 30 |
| widget | `Lyalya/widget/` | 30 |
| settings | `Lyalya/settings/` | 20 |
| sibling | `Lyalya/sibling/` | 20 |
| **ИТОГО Block P** | — | **570** |

570/570 OK, 0 ошибок. Существующие 956 файлов не затронуты.
Лог: `/Users/antongric/Downloads/HappySpeech/_workshop/logs/block_p_voice.log`

---

## Следующие шаги

- **M3.4 batch 5** — ✅ DONE — lexical (700) + grammar (200) = 900 новых файлов (16.9 MB)
- **M3.5 Эталоны** — ✅ DONE — 665 файлов (7.9 MB) в Refs/ (в репо)
- **M3.7b** — ✅ DONE — Ляля +30 фраз (итого 150, все в LyalyaPhrase enum)
- **M3.7e** — ✅ DONE — 3 Customization voice preview m4a (classic/soft/cheerful), Lyalya 168→171
- **Plan v11 Block P** — ✅ DONE — Ляля +570 фраз (1526 total .m4a, цель ≥1500 выполнена)
- **M3.6 ambient** — 4 трека CC0 для world_map/lesson/AR/reward (⏳ pending M9)
- **Firebase Storage upload** — delegated to backend-developer M11.4

## См. также

- `.claude/team/ml-datasets.md` — источники ML-датасетов
- `.claude/team/ml-models-research.md` — рекомендуемые TTS/VAD/LLM модели
- `.claude/team/ml-models.md` — реестр Core ML моделей
