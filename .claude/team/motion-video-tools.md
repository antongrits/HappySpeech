# Free Motion Video Generation Tools для HappySpeech

> Инструменты для создания обучающих видео, анимаций, README hero и промо-материалов.
> Последнее обновление: 2026-04-23

---

## 1. Remotion (РЕКОМЕНДОВАН #1)

**Описание:** React-based фреймворк для программной генерации видео. Пишешь JSX+CSS → рендеришь MP4.
**GitHub:** https://github.com/remotion-dev/remotion
**Сайт:** https://www.remotion.dev/
**Лицензия:**
- Свободно для физических лиц, компаний до 3 сотрудников, некоммерческих организаций
- Для нашего случая — полностью бесплатно
- Детали: https://www.remotion.dev/docs/license

**Установка на Mac Apple Silicon:**
```bash
npm init video
# или
npx create-video@latest
cd my-animation
npm install
npm run dev      # preview в браузере http://localhost:3000
npm run build    # рендер MP4
```

**Технология:** React + Webpack + Babel + FFmpeg (скрыт за абстракцией)
**Вывод:** MP4, WebM, GIF, PNG-sequence
**Рендеринг:** локальный (нет облака, нет API-ключей)

**Применение для HappySpeech:**
- App intro video (5 сек splash loop)
- Demo trailer (30 сек для README)
- Lesson transition videos (1–2 сек)
- AR tutorial clips (10 сек)
- Reward celebration videos (3 сек)
- 20+ animated stories (мультики при milestones)

**Совместимость с Mac Apple Silicon:** да
**Особенность:** Для Claude Code есть skill `remotion-best-practices` — можно генерировать видео через агентов

---

## 2. Motion Canvas

**Описание:** TypeScript-based фреймворк для программных векторных анимаций.
**GitHub:** https://github.com/motion-canvas/motion-canvas
**Сайт:** https://motioncanvas.io/
**Лицензия:** MIT

**Установка на Mac:**
```bash
npm init @motion-canvas@latest
cd my-animation
npm install
npm run serve    # live preview
```

**Технология:** TypeScript + Canvas API
**Преимущества перед Remotion:**
- MIT лицензия без оговорок
- Встроенный GUI для редактирования параметров
- Инструменты синхронизации с аудио
- Встроенный LaTeX и code block анимации

**Применение для HappySpeech:**
- Анимации артикуляционных упражнений (положение языка, губ)
- Дидактические видео-инструкции для родителей
- Визуализация прогресса ребёнка

---

## 3. Manim Community Edition

**Описание:** Python-библиотека для математических и дидактических анимаций.
**GitHub:** https://github.com/ManimCommunity/manim
**Сайт:** https://www.manim.community/
**Лицензия:** MIT

**Установка на Mac Apple Silicon:**
```bash
brew install cairo pkg-config
pip3 install manim
```
Подробно: https://docs.manim.community/en/stable/installation/macos.html

**Технология:** Python + Cairo + FFmpeg
**Вывод:** MP4, GIF, WebM, PNG-sequence

**Применение для HappySpeech:**
- Визуализация методики (схемы артикуляции, анатомические рисунки)
- Диаграммы прогресса для специалистского контура
- Обучающие видео по произношению звуков

**Пример:**
```python
from manim import *
class MouthAnimation(Scene):
    def construct(self):
        circle = Circle(radius=1.5, color=PINK)
        self.play(Create(circle))
        self.play(circle.animate.stretch(0.5, 1))  # «открыть рот»
```

---

## 4. FFmpeg (базовый инструмент)

**Сайт:** https://ffmpeg.org/
**Лицензия:** LGPL 2.1+ (или GPL 2+ в зависимости от опций сборки)

**Установка на Mac:**
```bash
brew install ffmpeg
```

**Базовые команды:**
```bash
# Из PNG → MP4
ffmpeg -framerate 25 -i image-%04d.png -c:v libx264 -pix_fmt yuv420p output.mp4

# Добавить аудио
ffmpeg -i video.mp4 -i audio.mp3 -c:v copy -c:a aac output_with_audio.mp4
```

---

## 5. Lottie (in-app анимации)

**iOS библиотека:** https://github.com/airbnb/lottie-ios (MIT)
**Создание анимаций (бесплатно):**
- SVGator: https://www.svgator.com/ — неограниченный экспорт Lottie бесплатно
- LottieFiles Creator: https://lottiefiles.com/lottie-creator
- Jitter: https://jitter.video/

**Лицензия Lottie Simple License:** коммерческое использование разрешено без обязательной атрибуции

**Применение для HappySpeech:**
- Анимации маскота «Ляля» (радость, похвала, задумчивость)
- Индикаторы прогресса, переходы между экранами
- Анимации наград и достижений
- Артикуляционные анимации (движение губ, языка)

---

## Сравнительная таблица

| Инструмент | Лицензия | Язык | Выходной формат | Mac M-chip | Лучшее применение |
|---|---|---|---|---|---|
| Remotion | Бесплатно | React/TS | MP4, WebM, GIF | Да | App intro, demo trailer, мультики |
| Motion Canvas | MIT | TypeScript | MP4, PNG | Да | Дидактические анимации |
| Manim | MIT | Python | MP4, GIF, WebM | Да | Схемы, методика |
| FFmpeg | LGPL/GPL | CLI | Любой | Да | Базовая сборка/конвертация |
| Lottie + SVGator | MIT / Lottie Simple | Нет кода | .lottie, JSON | Да | In-app анимации |

---

## Рекомендации для HappySpeech

**App intro + demo trailer + мультики (анимированные истории):** Remotion — самый мощный, есть skill для Claude Code.

**In-app анимации маскота и UI:** Lottie + SVGator (бесплатный экспорт без ограничений).

**Методические материалы:** Manim — академический стандарт.

**Быстрая склейка промо из скриншотов:** FFmpeg — одна команда.

---

## Источники
- https://www.remotion.dev/docs/compare/motion-canvas
- https://www.remotion.dev/docs/license
- https://github.com/remotion-dev/remotion
- https://motioncanvas.io/docs/quickstart/
- https://github.com/motion-canvas/motion-canvas
- https://docs.manim.community/en/stable/installation/macos.html
- https://github.com/ManimCommunity/manim
- https://ffmpeg.org/
- https://www.svgator.com/
- https://lottiefiles.com/page/license
- https://github.com/airbnb/lottie-web
