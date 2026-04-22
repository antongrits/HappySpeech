#!/usr/bin/env python3
"""
generate_lyalya_voice.py — HappySpeech Lyalya Mascot Voice Generator
Sprint 12 / B-075

Генерирует 100+ голосовых фраз маскота «Ляли» через edge-tts
(Microsoft Edge TTS, royalty-free для коммерческого использования).
Сохраняет в HappySpeech/Resources/Audio/Lyalya/ как .m4a.
Нормализует через numpy/soundfile.
Не требует API-ключей.

Зависимости: edge-tts, numpy, soundfile
pip install edge-tts numpy soundfile
"""

import asyncio
import os
import subprocess
import sys
import tempfile
import numpy as np
import soundfile as sf

VOICE = "ru-RU-SvetlanaNeural"   # Тёплый женский голос, оптимален для детей

OUTPUT_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..",
    "HappySpeech",
    "Resources",
    "Audio",
    "Lyalya",
)

TARGET_RMS = 10 ** (-16.0 / 20.0)  # -16 LUFS approximation

# ---------------------------------------------------------------------------
# 100+ фраз Ляли, разбитые по категориям
# ---------------------------------------------------------------------------

LYALYA_PHRASES = {
    # -----------------------------------------------------------------------
    # Приветствия (15)
    # -----------------------------------------------------------------------
    "greeting_01": "Привет!",
    "greeting_02": "С возвращением!",
    "greeting_03": "Как хорошо, что ты пришёл!",
    "greeting_04": "Рада тебя видеть!",
    "greeting_05": "Начнём занятие?",
    "greeting_06": "Ты готов?",
    "greeting_07": "Сегодня мы будем тренироваться!",
    "greeting_08": "Отличный день для упражнений!",
    "greeting_09": "Я так рада тебя видеть!",
    "greeting_10": "Погнали!",
    "greeting_11": "Сегодня ты молодец!",
    "greeting_12": "Привет, мой друг!",
    "greeting_13": "Добро пожаловать!",
    "greeting_14": "Вот и ты!",
    "greeting_15": "Ура, ты пришёл!",

    # -----------------------------------------------------------------------
    # Поощрения (20)
    # -----------------------------------------------------------------------
    "praise_01": "Молодец!",
    "praise_02": "Отлично!",
    "praise_03": "Супер!",
    "praise_04": "Великолепно!",
    "praise_05": "Так держать!",
    "praise_06": "Ты справился!",
    "praise_07": "Умница!",
    "praise_08": "Блестяще!",
    "praise_09": "Прекрасно!",
    "praise_10": "Ты лучший!",
    "praise_11": "Здорово получилось!",
    "praise_12": "Я горжусь тобой!",
    "praise_13": "Ты очень старался!",
    "praise_14": "Великолепная работа!",
    "praise_15": "Превосходно!",
    "praise_16": "Класс!",
    "praise_17": "Ты меня удивил!",
    "praise_18": "Это было замечательно!",
    "praise_19": "Ты настоящий герой!",
    "praise_20": "Фантастика!",

    # -----------------------------------------------------------------------
    # Подсказки и инструкции (25)
    # -----------------------------------------------------------------------
    "hint_01": "Слушай внимательно.",
    "hint_02": "Повтори за мной.",
    "hint_03": "Выбери картинку.",
    "hint_04": "Найди правильный ответ.",
    "hint_05": "Смотри на картинку.",
    "hint_06": "Попробуй ещё раз.",
    "hint_07": "Не торопись.",
    "hint_08": "Думай внимательно.",
    "hint_09": "Ты можешь это!",
    "hint_10": "Давай попробуем вместе.",
    "hint_11": "Послушай ещё раз.",
    "hint_12": "Выбери правильное слово.",
    "hint_13": "Назови картинку.",
    "hint_14": "Что ты видишь?",
    "hint_15": "Какой звук ты слышишь?",
    "hint_16": "Покажи мне!",
    "hint_17": "Двигай язычок.",
    "hint_18": "Язычок вверх!",
    "hint_19": "Губки в трубочку.",
    "hint_20": "Выдыхай медленно.",
    "hint_21": "Улыбнись широко.",
    "hint_22": "Открой рот шире.",
    "hint_23": "Тяни звук!",
    "hint_24": "Послушай ещё разок.",
    "hint_25": "Попробуй вместе со мной.",

    # -----------------------------------------------------------------------
    # Завершение сессии (15)
    # -----------------------------------------------------------------------
    "session_end_01": "Отличное занятие!",
    "session_end_02": "До встречи!",
    "session_end_03": "До завтра!",
    "session_end_04": "Ты очень постарался!",
    "session_end_05": "Вот это тренировка!",
    "session_end_06": "Ты сегодня был молодцом!",
    "session_end_07": "Хорошо поработали!",
    "session_end_08": "Заслуженный отдых!",
    "session_end_09": "Возвращайся скорее!",
    "session_end_10": "Жду тебя снова!",
    "session_end_11": "Ты справился с заданием!",
    "session_end_12": "Занятие закончено!",
    "session_end_13": "Увидимся!",
    "session_end_14": "Отдыхай хорошо!",
    "session_end_15": "До новых встреч!",

    # -----------------------------------------------------------------------
    # Истории и нарративы (15)
    # -----------------------------------------------------------------------
    "story_01": "Жил-был маленький котёнок...",
    "story_02": "В далёком лесу...",
    "story_03": "Однажды...",
    "story_04": "Расскажи мне историю!",
    "story_05": "Продолжаем нашу сказку...",
    "story_06": "Что было дальше?",
    "story_07": "Герой отправился в путь...",
    "story_08": "Вдруг произошло что-то удивительное...",
    "story_09": "Они встретились в лесу...",
    "story_10": "Конец истории!",
    "story_11": "А теперь твоя очередь!",
    "story_12": "Придумай продолжение!",
    "story_13": "Что ты видишь на картинке?",
    "story_14": "Опиши что происходит!",
    "story_15": "Сочини свою историю!",

    # -----------------------------------------------------------------------
    # Переходы между упражнениями (10)
    # -----------------------------------------------------------------------
    "transition_01": "Следующее задание!",
    "transition_02": "Давай попробуем другое!",
    "transition_03": "Теперь новое упражнение!",
    "transition_04": "Отлично! Дальше!",
    "transition_05": "Переходим к следующему!",
    "transition_06": "Готов к следующему?",
    "transition_07": "Это было здорово! Продолжаем!",
    "transition_08": "Ещё одно задание!",
    "transition_09": "Вперёд!",
    "transition_10": "Почти готово!",

    # -----------------------------------------------------------------------
    # Артикуляционные инструкции (10)
    # -----------------------------------------------------------------------
    "artic_01": "Поднимай язычок вверх, к бугоркам за зубами!",
    "artic_02": "Улыбнись широко и держи язык внизу!",
    "artic_03": "Губки трубочкой! Тяни вперёд!",
    "artic_04": "Подуй тихонько, как будто остужаешь чай!",
    "artic_05": "Кончик языка упирается в нижние зубки!",
    "artic_06": "Щёки надуть, как воздушный шарик!",
    "artic_07": "Покусай кончик языка тихонько.",
    "artic_08": "Язычок — лопаточка, плоский и широкий!",
    "artic_09": "Открой рот и нарисуй языком кружочек!",
    "artic_10": "Спрячь язычок за зубками!",

    # -----------------------------------------------------------------------
    # Подбадривание при ошибке (10)
    # -----------------------------------------------------------------------
    "encourage_01": "Почти! Попробуй ещё разочек!",
    "encourage_02": "Послушай ещё раз и повтори!",
    "encourage_03": "Не торопись, говори медленно!",
    "encourage_04": "Сначала сделай глубокий вдох!",
    "encourage_05": "Это трудный звук — и это нормально!",
    "encourage_06": "Ты уже так близко!",
    "encourage_07": "Каждый раз получается лучше!",
    "encourage_08": "Не сдавайся, ты сможешь!",
    "encourage_09": "Давай вместе, шаг за шагом!",
    "encourage_10": "Ошибаться — это нормально. Пробуем снова!",
}

# ---------------------------------------------------------------------------
# Нормализация (без ffmpeg)
# ---------------------------------------------------------------------------

def normalize_wav(data: np.ndarray) -> np.ndarray:
    """RMS-нормализация до -16 LUFS (approx)."""
    if data.ndim > 1:
        mono = data.mean(axis=1)
    else:
        mono = data
    rms = np.sqrt(np.mean(mono ** 2))
    if rms < 1e-9:
        return data
    gain = TARGET_RMS / rms
    result = data * gain
    peak = np.abs(result).max()
    if peak > 0.99:
        result = result / peak * 0.95
    return result.astype(np.float32)


# ---------------------------------------------------------------------------
# MP3 → M4A через afconvert (macOS built-in)
# ---------------------------------------------------------------------------

def mp3_to_m4a(mp3_path: str, m4a_path: str) -> bool:
    """Конвертирует MP3 в M4A (AAC) через macOS afconvert."""
    # Сначала MP3 → WAV (PCM), потом WAV → M4A
    wav_path = mp3_path.replace(".mp3", "_tmp.wav")
    try:
        r1 = subprocess.run(
            ["afconvert", "-f", "WAVE", "-d", "LEF32@44100", mp3_path, wav_path],
            capture_output=True, text=True,
        )
        if r1.returncode != 0:
            return False

        # Нормализуем WAV перед финальной конвертацией
        data, sr = sf.read(wav_path)
        data = normalize_wav(data)
        sf.write(wav_path, data, sr, subtype="PCM_16")

        r2 = subprocess.run(
            ["afconvert", "-f", "m4af", "-d", "aac", "-b", "128000", wav_path, m4a_path],
            capture_output=True, text=True,
        )
        return r2.returncode == 0
    finally:
        if os.path.exists(wav_path):
            os.remove(wav_path)


# ---------------------------------------------------------------------------
# Генерация через edge-tts
# ---------------------------------------------------------------------------

async def generate_phrase(phrase_id: str, text: str) -> bool:
    """Генерирует одну фразу через edge-tts и сохраняет как .m4a."""
    import edge_tts  # noqa: PLC0415

    m4a_path = os.path.join(OUTPUT_DIR, f"lyalya_{phrase_id}.m4a")
    if os.path.exists(m4a_path):
        print(f"  [SKIP] {phrase_id} — уже существует")
        return True

    with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tmp:
        tmp_mp3 = tmp.name

    try:
        communicate = edge_tts.Communicate(text, VOICE)
        await communicate.save(tmp_mp3)

        ok = mp3_to_m4a(tmp_mp3, m4a_path)
        if ok:
            size = os.path.getsize(m4a_path)
            print(f"  [OK]   lyalya_{phrase_id}.m4a — {size // 1024}KB — {text[:45]}")
        else:
            # Fallback: оставляем MP3 с переименованием в .m4a (совместимо с AVPlayer)
            import shutil
            shutil.copy(tmp_mp3, m4a_path)
            print(f"  [MP3→M4A fallback] {phrase_id}")
        return ok
    except Exception as exc:
        print(f"  [ERROR] {phrase_id}: {exc}")
        return False
    finally:
        if os.path.exists(tmp_mp3):
            os.remove(tmp_mp3)


async def generate_all():
    """Запускает генерацию всех фраз (батчами по 5 для контроля нагрузки)."""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"Voice: {VOICE}")
    print(f"Output: {OUTPUT_DIR}")
    print(f"Total phrases: {len(LYALYA_PHRASES)}\n")

    items = list(LYALYA_PHRASES.items())
    batch_size = 5
    success = 0

    for i in range(0, len(items), batch_size):
        batch = items[i:i + batch_size]
        tasks = [generate_phrase(pid, text) for pid, text in batch]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        success += sum(1 for r in results if r is True)

    total = len(LYALYA_PHRASES)
    print(f"\nDone: {success}/{total} phrases generated.")
    print(f"Path: {OUTPUT_DIR}")

    if success < total:
        print(f"\n[WARN] {total - success} phrases failed.")
        print("Проверь подключение к интернету — edge-tts требует сеть.")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    try:
        import edge_tts  # noqa: F401
    except ImportError:
        print("edge-tts не установлен.")
        print("Установи: pip install edge-tts")
        sys.exit(1)

    asyncio.run(generate_all())


if __name__ == "__main__":
    main()
