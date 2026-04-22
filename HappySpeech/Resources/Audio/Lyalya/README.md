# Lyalya Voice Assets — HappySpeech

**Маскот:** Ляля  
**Голос TTS:** Microsoft Edge TTS — `ru-RU-SvetlanaNeural`  
**Формат:** M4A (AAC 128kbps, 44.1kHz)  
**Нормализация:** -16 LUFS  
**Лицензия:** Microsoft Edge TTS — royalty-free для коммерческого использования  

## Генерация

```bash
pip install edge-tts numpy soundfile
python3 scripts/generate_lyalya_voice.py
```

Скрипт:
1. Генерирует MP3 через edge-tts (требует интернет, без API-ключа)
2. Конвертирует MP3 → M4A через macOS `afconvert`
3. Нормализует до -16 LUFS
4. Пропускает уже существующие файлы (idempotent)

---

## Категории и фразы (100 фраз)

### Приветствия (15 фраз)

| Файл | Текст |
|------|-------|
| lyalya_greeting_01.m4a | Привет! |
| lyalya_greeting_02.m4a | С возвращением! |
| lyalya_greeting_03.m4a | Как хорошо, что ты пришёл! |
| lyalya_greeting_04.m4a | Рада тебя видеть! |
| lyalya_greeting_05.m4a | Начнём занятие? |
| lyalya_greeting_06.m4a | Ты готов? |
| lyalya_greeting_07.m4a | Сегодня мы будем тренироваться! |
| lyalya_greeting_08.m4a | Отличный день для упражнений! |
| lyalya_greeting_09.m4a | Я так рада тебя видеть! |
| lyalya_greeting_10.m4a | Погнали! |
| lyalya_greeting_11.m4a | Сегодня ты молодец! |
| lyalya_greeting_12.m4a | Привет, мой друг! |
| lyalya_greeting_13.m4a | Добро пожаловать! |
| lyalya_greeting_14.m4a | Вот и ты! |
| lyalya_greeting_15.m4a | Ура, ты пришёл! |

### Поощрения (20 фраз)

| Файл | Текст |
|------|-------|
| lyalya_praise_01.m4a | Молодец! |
| lyalya_praise_02.m4a | Отлично! |
| lyalya_praise_03.m4a | Супер! |
| lyalya_praise_04.m4a | Великолепно! |
| lyalya_praise_05.m4a | Так держать! |
| lyalya_praise_06.m4a | Ты справился! |
| lyalya_praise_07.m4a | Умница! |
| lyalya_praise_08.m4a | Блестяще! |
| lyalya_praise_09.m4a | Прекрасно! |
| lyalya_praise_10.m4a | Ты лучший! |
| lyalya_praise_11.m4a | Здорово получилось! |
| lyalya_praise_12.m4a | Я горжусь тобой! |
| lyalya_praise_13.m4a | Ты очень старался! |
| lyalya_praise_14.m4a | Великолепная работа! |
| lyalya_praise_15.m4a | Превосходно! |
| lyalya_praise_16.m4a | Класс! |
| lyalya_praise_17.m4a | Ты меня удивил! |
| lyalya_praise_18.m4a | Это было замечательно! |
| lyalya_praise_19.m4a | Ты настоящий герой! |
| lyalya_praise_20.m4a | Фантастика! |

### Подсказки и инструкции (25 фраз)

| Файл | Текст |
|------|-------|
| lyalya_hint_01.m4a | Слушай внимательно. |
| lyalya_hint_02.m4a | Повтори за мной. |
| lyalya_hint_03.m4a | Выбери картинку. |
| lyalya_hint_04.m4a | Найди правильный ответ. |
| lyalya_hint_05.m4a | Смотри на картинку. |
| lyalya_hint_06.m4a | Попробуй ещё раз. |
| lyalya_hint_07.m4a | Не торопись. |
| lyalya_hint_08.m4a | Думай внимательно. |
| lyalya_hint_09.m4a | Ты можешь это! |
| lyalya_hint_10.m4a | Давай попробуем вместе. |
| lyalya_hint_11.m4a | Послушай ещё раз. |
| lyalya_hint_12.m4a | Выбери правильное слово. |
| lyalya_hint_13.m4a | Назови картинку. |
| lyalya_hint_14.m4a | Что ты видишь? |
| lyalya_hint_15.m4a | Какой звук ты слышишь? |
| lyalya_hint_16.m4a | Покажи мне! |
| lyalya_hint_17.m4a | Двигай язычок. |
| lyalya_hint_18.m4a | Язычок вверх! |
| lyalya_hint_19.m4a | Губки в трубочку. |
| lyalya_hint_20.m4a | Выдыхай медленно. |
| lyalya_hint_21.m4a | Улыбнись широко. |
| lyalya_hint_22.m4a | Открой рот шире. |
| lyalya_hint_23.m4a | Тяни звук! |
| lyalya_hint_24.m4a | Послушай ещё разок. |
| lyalya_hint_25.m4a | Попробуй вместе со мной. |

### Завершение сессии (15 фраз)

| Файл | Текст |
|------|-------|
| lyalya_session_end_01.m4a | Отличное занятие! |
| lyalya_session_end_02.m4a | До встречи! |
| lyalya_session_end_03.m4a | До завтра! |
| lyalya_session_end_04.m4a | Ты очень постарался! |
| lyalya_session_end_05.m4a | Вот это тренировка! |
| lyalya_session_end_06.m4a | Ты сегодня был молодцом! |
| lyalya_session_end_07.m4a | Хорошо поработали! |
| lyalya_session_end_08.m4a | Заслуженный отдых! |
| lyalya_session_end_09.m4a | Возвращайся скорее! |
| lyalya_session_end_10.m4a | Жду тебя снова! |
| lyalya_session_end_11.m4a | Ты справился с заданием! |
| lyalya_session_end_12.m4a | Занятие закончено! |
| lyalya_session_end_13.m4a | Увидимся! |
| lyalya_session_end_14.m4a | Отдыхай хорошо! |
| lyalya_session_end_15.m4a | До новых встреч! |

### Истории и нарративы (15 фраз)

| Файл | Текст |
|------|-------|
| lyalya_story_01.m4a | Жил-был маленький котёнок... |
| lyalya_story_02.m4a | В далёком лесу... |
| lyalya_story_03.m4a | Однажды... |
| lyalya_story_04.m4a | Расскажи мне историю! |
| lyalya_story_05.m4a | Продолжаем нашу сказку... |
| lyalya_story_06.m4a | Что было дальше? |
| lyalya_story_07.m4a | Герой отправился в путь... |
| lyalya_story_08.m4a | Вдруг произошло что-то удивительное... |
| lyalya_story_09.m4a | Они встретились в лесу... |
| lyalya_story_10.m4a | Конец истории! |
| lyalya_story_11.m4a | А теперь твоя очередь! |
| lyalya_story_12.m4a | Придумай продолжение! |
| lyalya_story_13.m4a | Что ты видишь на картинке? |
| lyalya_story_14.m4a | Опиши что происходит! |
| lyalya_story_15.m4a | Сочини свою историю! |

### Переходы между упражнениями (10 фраз)

| Файл | Текст |
|------|-------|
| lyalya_transition_01.m4a | Следующее задание! |
| lyalya_transition_02.m4a | Давай попробуем другое! |
| lyalya_transition_03.m4a | Теперь новое упражнение! |
| lyalya_transition_04.m4a | Отлично! Дальше! |
| lyalya_transition_05.m4a | Переходим к следующему! |
| lyalya_transition_06.m4a | Готов к следующему? |
| lyalya_transition_07.m4a | Это было здорово! Продолжаем! |
| lyalya_transition_08.m4a | Ещё одно задание! |
| lyalya_transition_09.m4a | Вперёд! |
| lyalya_transition_10.m4a | Почти готово! |

### Артикуляционные инструкции (10 фраз)

| Файл | Текст |
|------|-------|
| lyalya_artic_01.m4a | Поднимай язычок вверх, к бугоркам за зубами! |
| lyalya_artic_02.m4a | Улыбнись широко и держи язык внизу! |
| lyalya_artic_03.m4a | Губки трубочкой! Тяни вперёд! |
| lyalya_artic_04.m4a | Подуй тихонько, как будто остужаешь чай! |
| lyalya_artic_05.m4a | Кончик языка упирается в нижние зубки! |
| lyalya_artic_06.m4a | Щёки надуть, как воздушный шарик! |
| lyalya_artic_07.m4a | Покусай кончик языка тихонько. |
| lyalya_artic_08.m4a | Язычок — лопаточка, плоский и широкий! |
| lyalya_artic_09.m4a | Открой рот и нарисуй языком кружочек! |
| lyalya_artic_10.m4a | Спрячь язычок за зубками! |

### Подбадривание при ошибке (10 фраз)

| Файл | Текст |
|------|-------|
| lyalya_encourage_01.m4a | Почти! Попробуй ещё разочек! |
| lyalya_encourage_02.m4a | Послушай ещё раз и повтори! |
| lyalya_encourage_03.m4a | Не торопись, говори медленно! |
| lyalya_encourage_04.m4a | Сначала сделай глубокий вдох! |
| lyalya_encourage_05.m4a | Это трудный звук — и это нормально! |
| lyalya_encourage_06.m4a | Ты уже так близко! |
| lyalya_encourage_07.m4a | Каждый раз получается лучше! |
| lyalya_encourage_08.m4a | Не сдавайся, ты сможешь! |
| lyalya_encourage_09.m4a | Давай вместе, шаг за шагом! |
| lyalya_encourage_10.m4a | Ошибаться — это нормально. Пробуем снова! |

---

## Технические требования

- Формат: M4A (AAC 128kbps, 44.1kHz, стерео)
- Нормализация: -16 LUFS (RMS-метод)
- Пиковый уровень: не более -1 dBFS
- Голос: ru-RU-SvetlanaNeural (тёплый, женский)
- Лицензия: Microsoft Edge TTS — royalty-free для коммерческого использования

## Добавление новых фраз

1. Добавь запись в `LYALYA_PHRASES` в `scripts/generate_lyalya_voice.py`
2. Добавь case в `LyalyaPhrase` enum в `HappySpeech/Services/SoundService.swift`
3. Запусти скрипт — он сгенерирует только новые файлы
4. Обнови `sound-assets.md`
