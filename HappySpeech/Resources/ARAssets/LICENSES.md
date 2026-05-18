# AR Assets — Лицензионная атрибуция

---

## Статус каталога (ADR-V28-MASCOT-2D-CANON, 2026-05-18)

Каталог `ARAssets/` **больше не содержит USDZ-моделей**.

Ранее здесь лежали:

- `lyalya3d.usdz` / `lyalya3d_v2.usdz` — 3D-модель маскота «Ляля»;
- `scene_solar_panels.usdz` — Apple Quick Look сцена «солнечные панели»;
- 10 «логопедических» USDZ-объектов (`apple_red`, `mouse_grey`, `fox_orange`,
  `snake_green`, `cup_steaming`, `bell_brass`, `truck_red`, `whale_blue`,
  `rocket_silver`, `drum_wooden`).

Все они удалены, потому что:

1. **3D-маскот выведен из рендера** (решение D-3 v27 и ADR-V28-MASCOT-2D-CANON).
   Приложение использует единый 2D-канон «подружка-пчёлка» — иллюстрации
   `mascot_lyalya_*` в `Assets.xcassets`, согласованные с `AppIcon`.
   3D-компоненты (`LyalyaRealityKitView`, `LyalyaRealityView`, `LyalyaSceneView`)
   в рендере нигде не инстанцируются.
2. **10 «логопедических» USDZ были заглушками 4–12 KB** — процедурные примитивы
   без реальной геометрии. На симуляторе давали пустой/битый 3D-вид. Они нигде
   не загружались кодом. Честная замена — 2D-иллюстрации предметов из
   `Assets.xcassets` (`word_*`).
3. `scene_solar_panels.usdz` нигде не использовался кодом.

Если в будущем понадобится настоящий 3D/AR-контент (полноценные модели
10–15 MB, реальные blendshapes) — это отдельная задача; на момент v28
3D-ассеты в проекте отсутствуют намеренно.

---

## Текущее содержимое `ARAssets/`

- `LICENSES.md` — этот файл.

Каталог сохранён как точка подключения ресурсов (folder-reference в
`project.yml` / `pbxproj`) на случай будущего AR-контента.
