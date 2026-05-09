# HappySpeech — Content Specs (Sprint 12 / Block S v18)

**Последнее обновление:** 2026-05-09  
**Всего паков:** 22  
**Всего items:** 8055 (цель Sprint 12: ≥7459 — ВЫПОЛНЕНО; Block S v18 +500 — ВЫПОЛНЕНО)

---

## Block S v18 — Neurolinguist content expansion (2026-05-09)

Расширение контента по нейролингвистической методологии. +500 items добавлено в existing packs.

| Категория | Добавлено | Пак(и) |
|---|---|---|
| Sibilants (С, З) | +45 | sound_s_pack (+23+17), sound_z_pack (+18+4) |
| Fricatives (Ш, Ж) | +38 | sound_sh_pack (+20), sound_zh_pack (+18) |
| Affricates (Ч, Ц) | +40 | sound_ch_pack (+20), sound_c_pack (+20) |
| Sonorants (Р, Л) | +65 | sound_r_pack (+30+20), sound_l_pack (+30+15) |
| Velars (К, Г) | +30 | sound_k_pack (+15), sound_g_pack (+15) |
| Vowels (гласные) | +40 | pack_general_phonemic (+20+20) |
| Stress patterns (ударение) | +30 | pack_general_phonemic (+20+10) |
| Soft variants (Ть, Дь, Сь) | +70 | pack_grammar (+35), pack_lexical (+35) |
| Sentence-level (предложения+диалоги) | +50 | pack_narrative (+25+25) |
| Voice warmup (голосовая разминка) | +30 | pack_breathing (+30) |
| Sound substitution (замены) | +35 | pack_lexical (+35) |
| **ИТОГО** | **+500** | 11 паков расширены |

JSON schema validated: все 22 файла — валидный JSON.
G2P dict не найден — шаг S.5 пропущен (documented).

---

## Таблица паков

| Файл | ID | Items | Группа | Описание |
|---|---|---|---|---|
| pack_articulation_gymnastics.json | sound_ag_v1 | 250 | артикуляция | Артикуляционная гимнастика |
| pack_breathing.json | sound_br_v1 | 410 | дыхание | Дыхательные упражнения (+30 voice_warmup) |
| pack_diff_whistling_hissing.json | pack_diff_whistling_hissing_v1 | 246 | дифференциация | Дифференциация С/Ш, З/Ж |
| pack_general_phonemic.json | pack_general_phonemic_v1 | 331 | фонематика | Общий фонематический слух (+60 vowels+stress) |
| pack_grammar.json | pack_grammar_v1 | 285 | грамматика | Грамматические категории (+35 soft variants) |
| pack_lexical.json | pack_lexical_v1 | 845 | лексика | Лексические темы (+35 soft+70 sound_substitution) |
| pack_narrative.json | pack_narrative_v1 | 250 | связная речь | Нарративные упражнения (+50 sentences+dialogues) |
| pack_neurolinguist_advanced.json | pack_neurolinguist_advanced_v1 | 561 | нейролингвистика | Продвинутый нейролингвистический пак (Block S v18) |
| sound_c_pack.json | sound_c_v1 | 320 | аффрикаты | Звук Ц, stages 0–5 (+20) |
| sound_ch_pack.json | sound_ch_v1 | 450 | шипящие | Звук Ч, stages 0–5 (+20) |
| sound_diff_rl_pack.json | sound_diffrl_v1 | 200 | дифференциация | Дифференциация Р/Л |
| sound_g_pack.json | sound_g_v1 | 258 | заднеязычные | Звук Г, stages 0–5 (+15) |
| sound_k_pack.json | sound_k_v1 | 262 | заднеязычные | Звук К, stages 0–5 (+15) |
| sound_kh_pack.json | sound_kh_v1 | 250 | заднеязычные | Звук Х, stages 0–5 |
| sound_l_pack.json | sound_l_v1 | 413 | соноры | Звук Л/Ль, stages 0–5 (+45) |
| sound_r_pack.json | sound_r_v1 | 625 | соноры | Звук Р/Рь, stages 0–5 (+50) |
| sound_s_pack.json | sound_s_v2 | 452 | свистящие | Звук С/Сь, stages 0–5 (+40) |
| sound_sh_pack.json | sound_sh_v1 | 403 | шипящие | Звук Ш, stages 0–5 (+20) |
| sound_shch_pack.json | sound_shch_v1 | 325 | шипящие | Звук Щ, stages 0–5 |
| sound_y_pack.json | sound_y_v1 | 250 | соноры | Звук Й, stages 0–5 |
| sound_z_pack.json | sound_z_v1 | 353 | свистящие | Звук З/Зь, stages 0–5 (+22) |
| sound_zh_pack.json | sound_zh_v1 | 316 | шипящие | Звук Ж, stages 0–5 (+18) |

---

## pack_neurolinguist_advanced — детализация stages (Block S v18)

| Stage ID | Описание | Items |
|---|---|---|
| first_sound | Первый звук в слове | 10 |
| last_sound | Последний звук в слове | 10 |
| syllable_count | Слогораздел | 10 |
| rhymes_extended | Рифмы и скороговорки | 11 |
| minimal_pairs | Минимальные пары | 10 |
| sound_analysis | Звуковой анализ | 10 |
| sibilants_extended | Свистящие С/З (все позиции) | 50 |
| fricatives_extended | Фрикативные Ш/Ж/Х | 50 |
| affricates_extended | Аффрикаты Ч/Ц | 50 |
| sonorants_r | Сонор Р/Рь | 50 |
| sonorants_lmn | Соноры Л/М/Н | 50 |
| velars_extended | Заднеязычные К/Г | 30 |
| vowels_extended | Гласные А/О/У/Ы/Э/И + Я/Ё/Ю/Е | 50 |
| soft_variants | Мягкие согласные Ть/Дь/Сь/Зь/Нь/Ль/Рь | 70 |
| stress_patterns | Ударение в словах | 50 |
| sentence_level | Предложения с насыщенной фонологией | 50 |
| **ИТОГО** | | **561** |

---

## Методологическое покрытие (Block S v18)

| Нарушение / цель | Покрытые stages |
|---|---|
| Сигматизм (С/З) | sibilants_extended, diff_whistling_hissing |
| Шипящий сигматизм (Ш/Ж) | fricatives_extended, sound_sh, sound_zh |
| Аффрикаты (Ч/Ц) | affricates_extended, sound_ch, sound_c |
| Ротацизм (Р/Рь) | sonorants_r, sound_r, sound_diff_rl |
| Ламбдацизм (Л/Ль) | sonorants_lmn, sound_l, sound_diff_rl |
| Носовые М/Н | sonorants_lmn |
| Каппацизм/Гаммацизм (К/Г) | velars_extended, sound_k, sound_g |
| ОНР (гласные, гипотонус) | vowels_extended |
| ФФН (мягкие согласные) | soft_variants |
| ЗРР (ударение, ритм) | stress_patterns |
| Связная речь + фонология | sentence_level, pack_narrative |

---

## История изменений

| Версия | Дата | Изменения |
|---|---|---|
| Sprint 12 Block S v18 | 2026-05-08 | +500 items via neurolinguist methodology в pack_neurolinguist_advanced (61 → 561). Итог: 7055 → 7555 items. |
