# Audio Sample Audit v16 (Block R)

**Дата:** 2026-05-07
**Аудитор:** qa-engineer (Block R plan v16)
**Random seed:** 42

---

## Summary

- Всего .m4a файлов в репозитории: **13 344**
- Размер выборки: **1 334 (10%)**
- Подвыборка для LUFS: **20 файлов**
- Инструменты: `afinfo` (Apple), `ffmpeg 8.1` с фильтром `loudnorm`

---

## Sections

### Format check (1334 файла)

| Параметр | Результат | OK |
|---|---|---|
| Формат AAC (m4a) | 1334/1334 | 100% |
| Sample rate 16 kHz | 1160/1334 | **87.0%** |
| Mono (1 ch) | 1334/1334 | 100% |
| Длительность ≤8 сек | 1331/1334 | **99.8%** |
| Размер ≤50 KB | 1334/1334 | 100% |

**Статистика размеров файлов:**
- Минимум: 4 KB
- Максимум: 49 KB
- Среднее: 14 KB
- Медиана: 13 KB

---

### LUFS check (20 файлов)

| Параметр | Результат |
|---|---|
| -16 LUFS ±1.0 | **17/20 (85%)** |
| Mean integrated loudness | **-16.4 LUFS** |
| Standard deviation | **0.79** |

**Детальные измерения:**

| Файл | LUFS | Статус |
|---|---|---|
| on_stoit_oni_stoyat.m4a | -17.0 | OK |
| ag-005.m4a | -16.0 | OK |
| phon-vc-16.m4a | -16.8 | OK |
| lyalya_breathing_ar_breathe_out.m4a | -15.1 | OK |
| s-prep-12.m4a | -16.1 | OK |
| z-wi-19.m4a | -18.8 | **FAIL** |
| narr-d-11.m4a | -16.0 | OK |
| shch-ph-40.m4a | -16.0 | OK |
| lyalya_waving_bye_05.m4a | -16.6 | OK |
| lex-syn-10.m4a | -15.6 | OK |
| lyalya_hint_nq_3.m4a | -16.2 | OK |
| lyalya_breathing_ar_listen_up.m4a | -16.2 | OK |
| lyalya_gen_b2_colour_01.m4a | -17.6 | **FAIL** |
| lex-pr-18.m4a | -16.2 | OK |
| lyalya_speccomp_08.m4a | -15.8 | OK |
| lyalya_set_i1_specialist_01.m4a | -16.7 | OK |
| phon-pg-12.m4a | -16.2 | OK |
| phon-re-4.m4a | -16.1 | OK |
| lex-cs-24.m4a | -17.1 | **FAIL** |
| narr-d-8.m4a | -16.3 | OK |

Файлы вне допуска: `-18.8 LUFS` (дельта 2.8), `-17.6 LUFS` (дельта 1.6), `-17.1 LUFS` (дельта 1.1).
Все три — тихие (undervolume), не перегруженные.

---

## Issues found

### P1 — Sample rate не 16 kHz: 174/1334 файлов (13%)

Экстраполяция на весь датасет: ~**1 740 файлов** могут иметь неверный sample rate.

**Распределение по частотам:**

| Sample rate | Кол-во в выборке | Категория |
|---|---|---|
| 32 000 Hz | 148 | Lyalya voice (все) |
| 22 050 Hz | 17 | Content/Grammar (15) + Lyalya (2) |
| 44 100 Hz | 9 | Lyalya voice |

**Детали по категориям:**

**32 kHz — 148 файлов (только Lyalya):**
Все 148 файлов с 32 kHz принадлежат `Lyalya/` — голосовой маскот.
Примеры:
- `lyalya_gen_b2_colour_01.m4a`
- `lyalya_gen_b2_extra_10.m4a`
- `lyalya_hint_ram_detail_09.m4a`
- `lyalya_celebration_b3_32.m4a`
- `lyalya_acc_instruction_01.m4a`

**22 kHz — 17 файлов (Grammar + Lyalya):**
Почти весь Grammar-пак записан на 22 050 Hz.
Grammar файлы:
- `gr-prep-4.m4a`, `gr-prep-21.m4a`
- `gr-pl-10.m4a`, `gr-pl-15.m4a`, `gr-pl-4.m4a`
- `gr-case-9.m4a`, `gr-case-10.m4a`
- `gr-sen-12.m4a`, `gr-sen-6.m4a`
- `gr-adj-6.m4a`
- `gr-wc-6.m4a`, `gr-wc-7.m4a`, `gr-wc-9.m4a`, `gr-wc-22.m4a`
- `gr-vb-18.m4a`

Lyalya 22 kHz:
- `lyalya_hometasks_reminder.m4a`
- `lyalya_childhome_play.m4a`

**44.1 kHz — 9 файлов (Lyalya):**
- `lyalya_praise_16.m4a`
- `lyalya_transition_03.m4a`
- `lyalya_hint_14.m4a`
- `lyalya_artic_10.m4a`
- `lyalya_hint_09.m4a`
- (ещё 4 файла)

**Важно:** Все файлы — mono, формат AAC корректный. Проблема только в sample rate.
Для ASR-пайплайна (WhisperKit, Silero VAD) критично именно 16 kHz.
AVAudioEngine при воспроизведении выполнит ресамплинг автоматически, но для ML-инференса это P1.

---

### P1 — Длительность >8 сек: 3/1334 файлов (0.22%)

Файлы из `Lyalya/lessons/` — длинные инструкции с полными предложениями:

| Файл | Длительность |
|---|---|
| `chto_pokazyvaet_vremya_naydi_slovo_so_zvukom_ch_zerkalo_chas.m4a` | 11.3 сек |
| `kto_samyy_vysokiy_naydi_slovo_so_zvukom_zh_slon_zhiraf_zebra.m4a` | 10.7 сек |
| `kak_zvuchit_tigr_naydi_slovo_so_zvukom_r_rychit_khryukaet_my.m4a` | 11.5 сек |

Все три — полные фразы упражнений с длинным контекстом. Превышение незначительное (≤3.5 сек), критичность зависит от UX-требований (timeout буфера в AudioService).

---

### P2 — LUFS undervolume: 3/20 (15%)

Три файла тихее нормы на >1.0 LUFS:

| Файл | LUFS | Дельта |
|---|---|---|
| `z-wi-19.m4a` | -18.8 | -2.8 |
| `lyalya_gen_b2_colour_01.m4a` | -17.6 | -1.6 |
| `lex-cs-24.m4a` | -17.1 | -1.1 |

Стандартное отклонение по выборке (0.79 LUFS) — в пределах нормы. Mean (-16.4 LUFS) близок к цели. Вероятно, единичные выбросы, не системная проблема.

---

## Recommendations

### P1 — Ресамплинг Lyalya-голоса и Grammar-пака к 16 kHz

**Задача для sound-curator:**
Перекодировать все файлы в `Lyalya/` с 32 kHz и 44.1 kHz → 16 kHz mono AAC ~32 kbps.
Перекодировать `Content/Grammar/` с 22 050 Hz → 16 kHz mono AAC ~32 kbps.

Команда для пакетной обработки (только конвертация, оригиналы сохранить):
```bash
for f in HappySpeech/Resources/Audio/Lyalya/**/*.m4a; do
  ffmpeg -i "$f" -ar 16000 -ac 1 -b:a 32k "${f%.m4a}_16k.m4a"
done
```

Проверить масштаб: в выборке 148+9=157 Lyalya-файлов на 1334 = 11.8% Lyalya от выборки.
Экстраполяция: ~1600 Lyalya-файлов во всём датасете могут требовать ресамплинга.

### P1 — Проверить AudioService на hardcoded sample rate

Убедиться, что `AudioService` не предполагает 16 kHz без явного ресамплинга при загрузке. Если `AVAudioPlayerNode` используется без `AVAudioConverter` — всё ок для плейбека, но Silero VAD и WhisperKit требуют 16 kHz строго.

### P2 — LUFS нормализация для undervolume файлов

3 файла из 20 выборки (экстраполяция ~1000 по датасету) немного тише нормы. Рекомендуется loudnorm pass при финальном экспорте. Не блокирует релиз.

### Не требует действий

- Формат AAC: 100% OK
- Mono: 100% OK
- Размер файлов: 100% OK (max 49 KB)
- Mean LUFS (-16.4): в пределах нормы
- LUFS stdev (0.79): хорошая консистентность

---

## Scope для sound-curator

Создать задачу: **SC-R01 — Ресамплинг 32kHz/22kHz/44.1kHz файлов к 16 kHz**
- Затронутые директории: `Lyalya/` (все поддиректории), `Content/Grammar/`
- Примерный масштаб: ~1 700 файлов (13% от 13 344)
- Приоритет: P1 (блокирует корректный ML-инференс)
- Срок: до TestFlight build Sprint 12
