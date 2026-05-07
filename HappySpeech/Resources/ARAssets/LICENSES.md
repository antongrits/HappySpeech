# AR Assets — Лицензионная атрибуция

---

## lyalya3d.usdz / lyalya3d_v2.usdz

- Описание: Маскот «Ляля» 3D-модель (v1 и v2)
- Источник: собственный ассет HappySpeech
- Лицензия: проприетарная (HappySpeech project)

---

## scene_solar_panels.usdz

- Описание: Солнечные панели (наука, экология)
- Оригинальное имя: solar_panels.usdz
- Источник: https://developer.apple.com/augmented-reality/quick-look/models/solar-panels/solar_panels.usdz
- Лицензия: Apple Sample Code License
- Использование в HappySpeech: school_classroom scene, ARActivity тема «Наука», NarrativeQuest «Энергия солнца»

---

## Логопедические объекты (Block F v16 — процедурная генерация)

Все нижеперечисленные модели сгенерированы программатически с использованием
Pixar OpenUSD Python API (pxr) — собственные ассеты HappySpeech.
Лицензия: MIT (HappySpeech project).
Геометрия: примитивы USD (Sphere, Cylinder, Cone, Cube) + UsdPreviewSurface PBR.
ARKit-совместимость: upAxis=Y, metersPerUnit=1.0.

---

### apple_red.usdz

- Описание: Красное яблоко (звук А) — тело + стебель + листик + блик
- Звуковая ассоциация: А («Яблоко» — А в начале слова)
- Использование: ARZone sound-hunter, RepeatAfterModel (А)

---

### mouse_grey.usdz

- Описание: Серая мышь (звук Ы) — тело + голова + уши + хвост
- Звуковая ассоциация: Ы («мЫшь» — Ы в середине слова)
- Использование: ARZone sound-hunter, ArticulationImitation (Ы)

---

### fox_orange.usdz

- Описание: Оранжевая лиса (звуки Ль/Ф) — тело + голова + уши + хвост
- Звуковая ассоциация: Ль («Лиса» — мягкий Л), Ф («Лиса» — Ф в слове «рыжая»)
- Использование: ARZone ArticulationImitation (Ль, Ф)

---

### snake_green.usdz

- Описание: Зелёная змея (звуки С/Ш) — свитое тело + голова + язык
- Звуковая ассоциация: С («Змея» — шипение), Ш («ШШШипит»)
- Использование: ARZone sound-hunter (С/Ш), ArticulationImitation

---

### cup_steaming.usdz

- Описание: Кружка с паром (звуки К/Ч/П) — кружка + ручка + пар
- Звуковая ассоциация: К («Кружка»), Ч («Чашка»), П («Пар»)
- Использование: ARZone sound-hunter (шипящие и взрывные), BreathingExercises

---

### bell_brass.usdz

- Описание: Латунный колокол (звуки Л/Н) — тело + обод + корона + язык
- Звуковая ассоциация: Л («Колокол»), Н («коНь звенит»)
- Использование: ARZone ArticulationImitation (Л, Н), RhythmExercises

---

### truck_red.usdz

- Описание: Красный грузовик (звуки Р/Г) — кабина + кузов + 4 колеса
- Звуковая ассоциация: Р («РРРычит мотор»), Г («Грузовик»)
- Использование: ARZone sound-hunter (Р вибрация), ArticulationImitation

---

### whale_blue.usdz

- Описание: Синий кит (звуки Х/В) — тело + плавники + фонтан
- Звуковая ассоциация: Х («Хвост», «выдох — ХХХ»), В («Волна»)
- Использование: ARZone BreathingExercises (выдох), sound-hunter (Х, В)

---

### rocket_silver.usdz

- Описание: Серебряная ракета (звуки Р/Т) — корпус + стабилизаторы + пламя
- Звуковая ассоциация: Р («РакеТа»), Т («ракеТа»)
- Использование: ARZone NarrativeQuest «Космос», sound-hunter (Р, Т)

---

### drum_wooden.usdz

- Описание: Деревянный барабан (звуки Д/Б) — корпус + кожи + палочки
- Звуковая ассоциация: Д («Барабан — Д-Д-Д»), Б («БаБаБа — ритм»)
- Использование: ARZone RhythmExercises, ArticulationImitation (Д, Б)

---

## Примечания

1. Блок F v16: удалены 13 нерелевантных Apple Quick Look моделей (~150 MB).
2. Добавлены 10 логопедических процедурных моделей (собственные ассеты).
3. Apple Sample Code License модели (lyalya3d*, scene_solar_panels):
   https://developer.apple.com/terms/intellectual-property/
4. Логопедические модели: MIT-совместимая лицензия HappySpeech project.
