#!/usr/bin/env python3
"""
generate_ui_sounds.py — HappySpeech UI Sound Generator
Sprint 12 / B-074

Генерирует 16 UI-звуков через numpy/scipy синтез тонов,
нормализует до -16 LUFS (RMS-метод) и конвертирует WAV → CAF
через macOS-встроенный afconvert. Без внешних API, без ffmpeg.

Зависимости: numpy, scipy, soundfile
pip install numpy scipy soundfile
"""

import os
import subprocess
import sys
import numpy as np
import soundfile as sf

SR = 44100
TARGET_RMS = 10 ** (-16.0 / 20.0)   # ≈ 0.1585 — соответствует -16 LUFS для коротких звуков
OUTPUT_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..",
    "HappySpeech",
    "Resources",
    "Audio",
    "UI",
)


# ---------------------------------------------------------------------------
# Утилиты синтеза
# ---------------------------------------------------------------------------

def t(duration: float) -> np.ndarray:
    """Временная ось длиной duration секунд при SR."""
    return np.linspace(0, duration, int(SR * duration), endpoint=False)


def sine(freq: float, duration: float, amp: float = 0.7) -> np.ndarray:
    return (amp * np.sin(2 * np.pi * freq * t(duration))).astype(np.float32)


def fade(wave: np.ndarray, fade_ms: float = 5.0) -> np.ndarray:
    """Линейный fade-in / fade-out (по умолчанию 5 мс)."""
    f = max(1, int(SR * fade_ms / 1000))
    f = min(f, len(wave) // 2)
    wave = wave.copy()
    wave[:f] *= np.linspace(0, 1, f)
    wave[-f:] *= np.linspace(1, 0, f)
    return wave


def envelope(wave: np.ndarray, decay: float = 30.0) -> np.ndarray:
    """Экспоненциальное затухание (decay — скорость)."""
    n = len(wave)
    env = np.exp(-decay * np.arange(n) / SR)
    return (wave * env).astype(np.float32)


def normalize(wave: np.ndarray) -> np.ndarray:
    """RMS-нормализация до TARGET_RMS (-16 LUFS approximation)."""
    rms = np.sqrt(np.mean(wave ** 2))
    if rms < 1e-9:
        return wave
    wave = wave * (TARGET_RMS / rms)
    peak = np.abs(wave).max()
    if peak > 0.99:
        wave = wave / peak * 0.95
    return wave.astype(np.float32)


def silence(duration: float) -> np.ndarray:
    return np.zeros(int(SR * duration), dtype=np.float32)


def hann_window(wave: np.ndarray) -> np.ndarray:
    return (wave * np.hanning(len(wave))).astype(np.float32)


# ---------------------------------------------------------------------------
# Генераторы 16 звуков
# ---------------------------------------------------------------------------

def gen_tap() -> np.ndarray:
    """Мягкий тик, 40 мс, 880 Гц + быстрое затухание."""
    dur = 0.040
    wave = sine(880, dur, amp=0.9)
    wave = envelope(wave, decay=80)
    return fade(wave, fade_ms=2)


def gen_correct() -> np.ndarray:
    """Восходящий аккорд C5→E5→G5, 200 мс общих."""
    seg = int(SR * 0.065)
    c5 = hann_window(sine(523, 0.065, amp=0.7)[:seg])
    e5 = hann_window(sine(659, 0.070, amp=0.7))
    g5 = hann_window(sine(784, 0.080, amp=0.7))
    # Мягкое перекрытие: небольшой gap между нотами
    gap = silence(0.008)
    return np.concatenate([c5, gap, e5, gap, g5])


def gen_incorrect() -> np.ndarray:
    """
    Мягкий нисходящий buzz, 150 мс.
    Детский тон: wobble (вибрато) чтобы не звучать грозно.
    """
    dur = 0.150
    tt = t(dur)
    # Wobble: небольшая частотная модуляция
    freq_mod = 200 + 8 * np.sin(2 * np.pi * 6 * tt)
    wave = 0.55 * np.sin(2 * np.pi * np.cumsum(freq_mod) / SR).astype(np.float32)
    wave = envelope(wave, decay=8)
    return fade(wave, fade_ms=10)


def gen_reward() -> np.ndarray:
    """Спаркл-фанфара, 500 мс: C5+E5+G5 аккорд + верхний C6."""
    dur = 0.500
    tt = t(dur)
    env_arr = np.exp(-3 * tt)
    chord = (
        0.35 * np.sin(2 * np.pi * 523 * tt) +
        0.28 * np.sin(2 * np.pi * 659 * tt) +
        0.22 * np.sin(2 * np.pi * 784 * tt) +
        0.15 * np.sin(2 * np.pi * 1047 * tt)
    )
    wave = (chord * env_arr).astype(np.float32)
    # Добавляем sparkle: короткий высокий пик в начале
    sparkle_dur = 0.030
    sparkle = envelope(sine(2093, sparkle_dur, amp=0.4), decay=120)
    wave[:len(sparkle)] += sparkle
    return fade(wave, fade_ms=5)


def gen_streak() -> np.ndarray:
    """Восходящее арпеджио, 400 мс: C5→E5→G5→C6."""
    notes = [523, 659, 784, 1047]
    seg_dur = 0.080
    gap_dur = 0.010
    segments = []
    for i, freq in enumerate(notes):
        amp = 0.6 + 0.1 * (i / len(notes))
        seg = hann_window(sine(freq, seg_dur, amp=amp))
        segments.append(seg)
        if i < len(notes) - 1:
            segments.append(silence(gap_dur))
    # Финальное продление последней ноты
    last = fade(envelope(sine(1047, 0.120, amp=0.7), decay=6), fade_ms=10)
    segments.append(last)
    return np.concatenate(segments)


def gen_level_up() -> np.ndarray:
    """Торжественный level-up, 600 мс."""
    # Трезвучие C-мажор + быстрый взлёт
    rise = []
    for freq in [523, 659, 784, 1047]:
        rise.append(hann_window(sine(freq, 0.07, amp=0.65)))
        rise.append(silence(0.005))
    chord_dur = 0.280
    tt = t(chord_dur)
    env_arr = np.exp(-2.5 * tt)
    chord = (
        0.33 * np.sin(2 * np.pi * 523 * tt) +
        0.27 * np.sin(2 * np.pi * 784 * tt) +
        0.20 * np.sin(2 * np.pi * 1047 * tt)
    ) * env_arr
    return np.concatenate(rise + [chord.astype(np.float32)])


def gen_warmup_start() -> np.ndarray:
    """Спокойный колокол, 300 мс."""
    dur = 0.300
    tt = t(dur)
    # Колокол: основная + 2-я гармоника слегка расстроены
    wave = (
        0.5 * np.sin(2 * np.pi * 660 * tt) +
        0.25 * np.sin(2 * np.pi * 1320 * tt) +
        0.12 * np.sin(2 * np.pi * 1980 * tt)
    )
    env_arr = np.exp(-5 * tt)
    return fade((wave * env_arr).astype(np.float32), fade_ms=5)


def gen_warmup_end() -> np.ndarray:
    """Мягкий чайм, 250 мс — чуть выше warmup_start."""
    dur = 0.250
    tt = t(dur)
    wave = (
        0.5 * np.sin(2 * np.pi * 880 * tt) +
        0.22 * np.sin(2 * np.pi * 1760 * tt) +
        0.10 * np.sin(2 * np.pi * 2640 * tt)
    )
    env_arr = np.exp(-6 * tt)
    return fade((wave * env_arr).astype(np.float32), fade_ms=5)


def gen_complete() -> np.ndarray:
    """Completion jingle, 700 мс — торжественный финал."""
    # Быстрое арпеджио + финальный аккорд
    arp_notes = [523, 659, 784, 1047, 1319]
    arp_parts = []
    for freq in arp_notes:
        seg = hann_window(sine(freq, 0.055, amp=0.6))
        arp_parts.append(seg)
        arp_parts.append(silence(0.005))
    chord_dur = 0.370
    tt = t(chord_dur)
    env_arr = np.exp(-1.8 * tt)
    chord = (
        0.30 * np.sin(2 * np.pi * 523 * tt) +
        0.25 * np.sin(2 * np.pi * 784 * tt) +
        0.20 * np.sin(2 * np.pi * 1047 * tt) +
        0.15 * np.sin(2 * np.pi * 1319 * tt)
    ) * env_arr
    return np.concatenate(arp_parts + [chord.astype(np.float32)])


def gen_pause() -> np.ndarray:
    """Мягкий клик, 80 мс."""
    dur = 0.080
    wave = sine(440, dur, amp=0.6)
    return envelope(fade(wave, fade_ms=3), decay=60)


def gen_notification() -> np.ndarray:
    """Нежный пинг, 200 мс."""
    dur = 0.200
    tt = t(dur)
    wave = (
        0.55 * np.sin(2 * np.pi * 1047 * tt) +
        0.20 * np.sin(2 * np.pi * 1319 * tt)
    )
    env_arr = np.exp(-7 * tt)
    return fade((wave * env_arr).astype(np.float32), fade_ms=5)


def gen_transition_next() -> np.ndarray:
    """Whoosh вперёд, 150 мс — восходящий sweep."""
    dur = 0.150
    tt = t(dur)
    # Линейный sweep от 300 Гц до 1200 Гц
    freq_sweep = 300 + (1200 - 300) * (tt / dur)
    phase = np.cumsum(freq_sweep) / SR
    wave = 0.55 * np.sin(2 * np.pi * phase).astype(np.float32)
    env_arr = np.exp(-3 * tt / dur * tt)
    return fade((wave * np.hanning(len(wave))).astype(np.float32), fade_ms=8)


def gen_transition_back() -> np.ndarray:
    """Whoosh назад, 150 мс — нисходящий sweep."""
    dur = 0.150
    tt = t(dur)
    freq_sweep = 1200 - (1200 - 300) * (tt / dur)
    phase = np.cumsum(freq_sweep) / SR
    wave = 0.55 * np.sin(2 * np.pi * phase).astype(np.float32)
    return fade((wave * np.hanning(len(wave))).astype(np.float32), fade_ms=8)


def gen_drag_pick() -> np.ndarray:
    """Мягкий поп, 60 мс."""
    dur = 0.060
    wave = sine(600, dur, amp=0.8)
    return envelope(fade(wave, fade_ms=3), decay=100)


def gen_drag_drop() -> np.ndarray:
    """Мягкий thud, 80 мс — чуть ниже drag_pick."""
    dur = 0.080
    wave = sine(220, dur, amp=0.75)
    # Добавляем небольшой шумовой удар
    noise = 0.15 * np.random.randn(len(wave)).astype(np.float32)
    combined = wave + noise
    return envelope(fade(combined, fade_ms=4), decay=50)


def gen_error() -> np.ndarray:
    """
    Мягкий низкий buzz, 100 мс.
    Не агрессивный — детский, не пугающий.
    """
    dur = 0.100
    tt = t(dur)
    wave = 0.45 * np.sin(2 * np.pi * 180 * tt).astype(np.float32)
    # Небольшое вибрато для мягкости
    vibrato = 1 + 0.03 * np.sin(2 * np.pi * 5 * tt)
    wave = (wave * vibrato).astype(np.float32)
    env_arr = np.exp(-5 * tt)
    return fade((wave * env_arr).astype(np.float32), fade_ms=8)


# ---------------------------------------------------------------------------
# Реестр звуков
# ---------------------------------------------------------------------------

SOUNDS = {
    "tap":              (gen_tap,             0.040, "Мягкий тик на нажатие"),
    "correct":          (gen_correct,         0.200, "Восходящий аккорд C5→E5→G5"),
    "incorrect":        (gen_incorrect,       0.150, "Мягкий нисходящий wobble-buzz"),
    "reward":           (gen_reward,          0.500, "Спаркл-фанфара за правильный ответ"),
    "streak":           (gen_streak,          0.400, "Восходящее арпеджио серии"),
    "level_up":         (gen_level_up,        0.600, "Торжественный переход уровня"),
    "warmup_start":     (gen_warmup_start,    0.300, "Спокойный колокол начала разминки"),
    "warmup_end":       (gen_warmup_end,      0.250, "Мягкий чайм конца разминки"),
    "complete":         (gen_complete,        0.700, "Completion jingle завершения сессии"),
    "pause":            (gen_pause,           0.080, "Мягкий клик паузы"),
    "notification":     (gen_notification,    0.200, "Нежный пинг уведомления"),
    "transition_next":  (gen_transition_next, 0.150, "Whoosh вперёд"),
    "transition_back":  (gen_transition_back, 0.150, "Whoosh назад"),
    "drag_pick":        (gen_drag_pick,       0.060, "Мягкий поп захвата"),
    "drag_drop":        (gen_drag_drop,       0.080, "Мягкий thud отпускания"),
    "error":            (gen_error,           0.100, "Мягкий низкий buzz ошибки"),
}


# ---------------------------------------------------------------------------
# WAV → CAF через afconvert (macOS built-in)
# ---------------------------------------------------------------------------

def wav_to_caf(wav_path: str, caf_path: str) -> bool:
    """Конвертирует WAV в CAF через afconvert (без ffmpeg)."""
    result = subprocess.run(
        ["afconvert", "-f", "caff", "-d", "LEF32@44100", wav_path, caf_path],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"  [WARN] afconvert failed: {result.stderr.strip()}")
        return False
    return True


# ---------------------------------------------------------------------------
# Основной цикл
# ---------------------------------------------------------------------------

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"Output directory: {OUTPUT_DIR}\n")

    results = []

    for name, (gen_fn, expected_dur, description) in SOUNDS.items():
        wav_path = os.path.join(OUTPUT_DIR, f"{name}.wav")
        caf_path = os.path.join(OUTPUT_DIR, f"{name}.caf")

        # Генерация
        wave = gen_fn()

        # Нормализация
        wave = normalize(wave)

        # Запись WAV
        sf.write(wav_path, wave, SR, subtype="PCM_16")

        actual_dur_ms = int(len(wave) / SR * 1000)

        # Конвертация WAV → CAF
        caf_ok = wav_to_caf(wav_path, caf_path)

        # Удаляем промежуточный WAV если CAF успешен
        if caf_ok and os.path.exists(caf_path):
            os.remove(wav_path)
            final_path = caf_path
            fmt = "CAF"
        else:
            final_path = wav_path
            fmt = "WAV"

        peak_db = 20 * np.log10(np.abs(wave).max() + 1e-9)
        rms_lufs = 20 * np.log10(np.sqrt(np.mean(wave ** 2)) + 1e-9)

        status = "OK" if np.abs(wave).max() < 1.0 else "CLIP"
        print(
            f"  [{status}] {name}.{fmt.lower()} — {actual_dur_ms}ms | "
            f"peak={peak_db:.1f}dBFS | ~{rms_lufs:.1f}LUFS"
        )

        results.append({
            "name": name,
            "file": os.path.basename(final_path),
            "format": fmt,
            "duration_ms": actual_dur_ms,
            "lufs_approx": round(rms_lufs, 1),
            "peak_dbfs": round(peak_db, 1),
            "description": description,
            "status": "Ready",
        })

    print(f"\nDone. Generated {len(results)}/16 UI sounds.")
    print(f"Path: {OUTPUT_DIR}")

    # Краткий отчёт
    print("\n--- Registry summary (for sound-assets.md) ---")
    for r in results:
        print(
            f"| {r['name']}.caf | {r['description']} | {r['format']} | "
            f"{r['duration_ms']}ms | {r['lufs_approx']} LUFS | synthesized/CC0 | Ready |"
        )


if __name__ == "__main__":
    # Проверка зависимостей
    try:
        import numpy  # noqa: F401
        import soundfile  # noqa: F401
    except ImportError as e:
        print(f"Missing dependency: {e}")
        print("Install: pip install numpy soundfile")
        sys.exit(1)

    # Фиксируем seed для воспроизводимости шума в drag_drop
    np.random.seed(42)
    main()
