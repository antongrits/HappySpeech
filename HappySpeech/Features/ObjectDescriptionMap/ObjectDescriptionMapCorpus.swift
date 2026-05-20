import Foundation
import OSLog

// MARK: - ObjectDescriptionMapCorpus

/// Стат-фасад над `pack_objectdescriptionmap.json`. Аналогично
/// `OralStoryCreatorCorpus` / `FingerPlayCorpus` — при отказе бандла
/// отдаёт безопасный fallback-корпус, чтобы фича оставалась рабочей.
enum ObjectDescriptionMapCorpus {

    static let objects: [DescriptionObject] = ObjectDescriptionMapPackLoader.shared.objects
    static let categoriesInOrder: [String] = ObjectDescriptionMapPackLoader.shared.categoriesInOrder

    /// Группирует объекты по категориям, сохраняя порядок из `categoriesInOrder`.
    static func grouped() -> [(category: String, items: [DescriptionObject])] {
        categoriesInOrder.map { category in
            (category, objects.filter { $0.category == category })
        }
    }

    /// Поиск объекта по id.
    static func object(id: String) -> DescriptionObject? {
        objects.first { $0.id == id }
    }
}

// MARK: - Loader

struct ObjectDescriptionMapPackLoader {

    static let shared = ObjectDescriptionMapPackLoader()

    let objects: [DescriptionObject]
    let categoriesInOrder: [String]

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ObjectDescriptionMap.PackLoader"
    )

    // MARK: - DTOs

    private struct Pack: Decodable {
        let categoriesInOrder: [String]
        let slotIcons: [String: String]
        let slotTitles: [String: String]
        let objects: [ObjectDTO]
    }

    private struct ObjectDTO: Decodable {
        let id: String
        let title: String
        let category: String
        let symbol: String
        let plan: [PlanItemDTO]
    }

    private struct PlanItemDTO: Decodable {
        let slot: String
        let prompt: String
        let keywords: [String]
    }

    // MARK: - Init

    private init() {
        guard let url = Bundle.main.url(
            forResource: "pack_objectdescriptionmap",
            withExtension: "json"
        ) else {
            Self.logger.error("pack_objectdescriptionmap.json not found — using fallback corpus")
            self.objects = Self.fallback()
            self.categoriesInOrder = ["животные", "еда", "транспорт", "игрушки"]
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(Pack.self, from: data)
            self.categoriesInOrder = pack.categoriesInOrder
            self.objects = pack.objects.map { dto in
                DescriptionObject(
                    id: dto.id,
                    title: dto.title,
                    category: dto.category,
                    symbol: dto.symbol,
                    plan: dto.plan.map { itemDTO in
                        DescriptionPlanItem(
                            slot: itemDTO.slot,
                            slotTitle: pack.slotTitles[itemDTO.slot] ?? itemDTO.slot.capitalized,
                            icon: pack.slotIcons[itemDTO.slot] ?? "circle.fill",
                            prompt: itemDTO.prompt,
                            keywords: itemDTO.keywords
                        )
                    }
                )
            }
            let count = self.objects.count
            Self.logger.info("Loaded \(count) description-map objects.")
        } catch {
            Self.logger.error("Decode failed: \(error.localizedDescription) — fallback corpus")
            self.objects = Self.fallback()
            self.categoriesInOrder = ["животные", "еда", "транспорт", "игрушки"]
        }
    }

    // MARK: - Fallback

    private static func fallback() -> [DescriptionObject] {
        [
            DescriptionObject(
                id: "fb_cat",
                title: "Кот",
                category: "животные",
                symbol: "cat.fill",
                plan: [
                    DescriptionPlanItem(
                        slot: "color",
                        slotTitle: "Цвет",
                        icon: "paintpalette.fill",
                        prompt: "Какого цвета?",
                        keywords: ["рыжий", "серый", "белый", "чёрный", "полосатый"]
                    ),
                    DescriptionPlanItem(
                        slot: "size",
                        slotTitle: "Размер",
                        icon: "ruler.fill",
                        prompt: "Какого размера?",
                        keywords: ["маленький", "большой", "средний"]
                    ),
                    DescriptionPlanItem(
                        slot: "parts",
                        slotTitle: "Части",
                        icon: "puzzlepiece.fill",
                        prompt: "Какие части тела?",
                        keywords: ["лапы", "хвост", "усы", "уши"]
                    ),
                    DescriptionPlanItem(
                        slot: "habitat",
                        slotTitle: "Где живёт",
                        icon: "house.fill",
                        prompt: "Где живёт?",
                        keywords: ["дом", "квартира", "живёт"]
                    ),
                    DescriptionPlanItem(
                        slot: "sound",
                        slotTitle: "Как звучит",
                        icon: "speaker.wave.2.fill",
                        prompt: "Как говорит?",
                        keywords: ["мяу", "мяукает", "мурчит"]
                    ),
                    DescriptionPlanItem(
                        slot: "action",
                        slotTitle: "Что делает",
                        icon: "figure.run",
                        prompt: "Что любит делать?",
                        keywords: ["спит", "играет", "ловит"]
                    )
                ]
            ),
            DescriptionObject(
                id: "fb_pear",
                title: "Груша",
                category: "еда",
                symbol: "leaf.fill",
                plan: [
                    DescriptionPlanItem(
                        slot: "color",
                        slotTitle: "Цвет",
                        icon: "paintpalette.fill",
                        prompt: "Какого цвета?",
                        keywords: ["жёлтая", "зелёная", "румяная"]
                    ),
                    DescriptionPlanItem(
                        slot: "shape",
                        slotTitle: "Форма",
                        icon: "circle.hexagongrid.fill",
                        prompt: "Какой формы?",
                        keywords: ["вытянутая", "круглая", "овальная"]
                    ),
                    DescriptionPlanItem(
                        slot: "taste",
                        slotTitle: "Вкус",
                        icon: "fork.knife",
                        prompt: "Какая на вкус?",
                        keywords: ["сладкая", "сочная", "вкусная"]
                    ),
                    DescriptionPlanItem(
                        slot: "habitat",
                        slotTitle: "Где растёт",
                        icon: "house.fill",
                        prompt: "Где растёт?",
                        keywords: ["дерево", "сад", "на дереве"]
                    ),
                    DescriptionPlanItem(
                        slot: "purpose",
                        slotTitle: "Зачем",
                        icon: "hands.sparkles.fill",
                        prompt: "Что из неё делают?",
                        keywords: ["сок", "компот", "варенье"]
                    ),
                    DescriptionPlanItem(
                        slot: "size",
                        slotTitle: "Размер",
                        icon: "ruler.fill",
                        prompt: "Какого размера?",
                        keywords: ["небольшая", "средняя"]
                    )
                ]
            )
        ]
    }
}
