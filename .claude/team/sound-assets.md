# Sound Assets Registry — HappySpeech
## Version 1.0 — 2026-04-21
## Managed by Sound Curator. ALL sounds must be CC0 or royalty-free before use.

---

## Categories Needed

### Category 1: UI Sounds (Sprint 2–3)

| Asset | Description | Format | Duration | Source | License | Status |
|-------|-------------|--------|----------|--------|---------|--------|
| tap_soft | Soft tap for button press | MP3 | ~50ms | Freesound.org (CC0) | CC0 | Needed |
| tap_correct | Correct answer chime | MP3 | ~300ms | Freesound.org (CC0) | CC0 | Needed |
| tap_almost | "Almost" gentle sound | MP3 | ~300ms | Freesound.org (CC0) | CC0 | Needed |
| card_flip | Card flip (memory game) | MP3 | ~150ms | Freesound.org (CC0) | CC0 | Needed |
| drag_drop | Drag-and-drop placement | MP3 | ~200ms | Freesound.org (CC0) | CC0 | Needed |
| session_complete | Session end fanfare | MP3 | ~1.5s | ElevenLabs Sound Effects | CC0/Custom | Needed |
| sticker_unlock | Sticker unlock pop | MP3 | ~500ms | Freesound.org (CC0) | CC0 | Needed |
| star_earn | Star earned jingle | MP3 | ~400ms | Freesound.org (CC0) | CC0 | Needed |
| timer_tick | Gentle timer tick | MP3 | ~50ms | Freesound.org (CC0) | CC0 | Needed |
| error_gentle | Gentle "try again" sound (NOT harsh) | MP3 | ~300ms | ElevenLabs | Custom | Needed |
| app_startup | App startup sound | MP3 | ~1s | ElevenLabs | Custom | Needed |

### Category 2: Voice Prompts RU — Lyalya Mascot (Sprint 3–4)

**Required: 50+ phrases recorded or synthesized in child-friendly Russian voice.**

| # | Phrase | Context | Status |
|---|--------|---------|--------|
| 1 | "Привет! Я Ляля. Давай потренируемся вместе!" | Onboarding welcome | Needed |
| 2 | "Отличная работа!" | Correct answer | Needed |
| 3 | "Почти-почти! Ещё раз попробуй?" | Almost correct | Needed |
| 4 | "Давай вместе! Слушай: ..." | Hint prompt | Needed |
| 5 | "Молодец, ты очень старался!" | Session end | Needed |
| 6 | "Сегодня ты настоящий чемпион!" | High performance | Needed |
| 7 | "Разогреем язычок!" | Warm-up intro | Needed |
| 8 | "Слушай внимательно..." | Listen template intro | Needed |
| 9 | "Повтори за мной!" | Repeat template intro | Needed |
| 10 | "Тащи картинку в нужный домик!" | Drag-match intro | Needed |
| 11 | "Найди звук-прятку!" | Sound-hunter intro | Needed |
| 12 | "Дыши медленно и ровно..." | Breathing intro | Needed |
| 13 | "Посмотри на своё лицо в зеркало!" | AR intro | Needed |
| 14 | "Высуни язычок!" | tongueOut AR prompt | Needed |
| 15 | "Улыбнись пошире!" | smile AR prompt | Needed |
| 16 | "Надуй шарик! Дуй!" | balloon-blow AR | Needed |
| 17 | "Ты уже так близко к звезде!" | Encouragement | Needed |
| 18 | "Это трудный звук — и это нормально!" | Difficulty comfort | Needed |
| 19 | "На сегодня всё! Отдохни." | Fatigue stop | Needed |
| 20 | "Завтра продолжим приключение!" | Session end farewell | Needed |
| 21–50 | Additional game instructions, encouragements, intros for each template × 2 | Various | Needed |

**Voice spec:** Warm, female, age 25–35, clear diction, moderate pace (not too fast for children to follow), positive emotion without over-excitement.
**Production method:** Logopedist recording preferred for reference pronunciations; Silero TTS or ElevenLabs acceptable for Lyalya mascot voice (non-pedagogical prompts).

### Category 3: Reference Pronunciations — Logopedist (Sprint 3–6)

**Required: 520+ words, all with target sounds, recorded by certified Russian logopedist.**

| Sound Group | Stage | Word Count | Status |
|-------------|-------|-----------|--------|
| С (sibilant) | isolated, syllable, word (3 positions), phrase, sentence | 50 words | Needed |
| Сь | word, phrase | 20 words | Needed |
| З | word, phrase | 20 words | Needed |
| Ц | word, phrase | 20 words | Needed |
| Ш (shibilant) | full set | 50 words | Needed |
| Ж | word, phrase | 25 words | Needed |
| Ч | word, phrase | 25 words | Needed |
| Щ | word, phrase | 20 words | Needed |
| Л (sonor) | full set | 40 words | Needed |
| Ль | word, phrase | 20 words | Needed |
| Р (sonor) | full set | 60 words | Needed |
| Рь | word, phrase | 25 words | Needed |
| К (dorsal) | word, phrase | 30 words | Needed |
| Г, Х | word, phrase | 20 words | Needed |
| Contrast pairs (С–Ш, Р–Л, etc.) | minimal pairs | 50+ pairs | Needed |

**Recording spec:** 
- Format: WAV 16-bit 44.1kHz (will be normalized to 16kHz mono by script 10)
- Environment: quiet room, no background noise
- Pace: slow-clear for stages 0–2, normal for stages 3+
- Each word: 3 takes (best selected by curator)

### Category 4: Ambient / Background (Sprint 8–10)

| Asset | Description | Status |
|-------|-------------|--------|
| world_map_ambient | Soft adventure music for world map screen | Needed (CC0) |
| lesson_bgm | Gentle background music during lesson (non-distracting) | Needed (CC0) |
| ar_zone_ambient | Slightly playful, light music for AR zone | Needed (CC0) |
| reward_music | Celebratory short loop for reward screen | Needed (CC0) |

**Music spec:** Instrumental only, child-friendly, loopable, CC0 licensed (Freesound, ccMixter, Free Music Archive).

---

## Pipeline

```
Sound Curator workflow:
1. For UI sounds: search Freesound.org with CC0 filter → download → validate quality (no clipping, correct duration)
2. For voice prompts: either (a) record with logopedist, or (b) generate via ElevenLabs Sound Effects
3. For reference pronunciations: logopedist records → Sound Curator processes (normalize, trim, verify)
4. All processed files → _workshop/datasets/references/ (audio only, not in repo)
5. Final processed MP3 64kbps → HappySpeech/Resources/Audio/ (in repo, bundled)
6. Update this registry with: file name, source URL, license verification date

COPYRIGHT RULE: Every sound must have verified CC0 or royalty-free license before adding to Resources/Audio/.
```

---

## Processed Files (to be filled as sounds are added)

| File | Category | Source | License | Verified Date |
|------|----------|--------|---------|---------------|
| _(empty)_ | — | — | — | — |
