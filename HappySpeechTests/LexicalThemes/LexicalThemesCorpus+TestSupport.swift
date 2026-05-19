@testable import HappySpeech
import Foundation

// MARK: - LexicalThemesCorpus + TestSupport
//
// Plan v30 Phase 6 — после миграции `LexicalThemesCorpus` на загрузку из
// пака (`pack_lexical_themes.json`, v30) статический член `.vegetables`
// удалён из product-кода: темы теперь динамические.
//
// Тесты `LexicalThemesPresenterTests` / `LexicalThemesInteractorTests`
// исторически использовали `LexicalThemesCorpus.vegetables` как стабильную
// фикстуру. Чтобы не возвращать хардкод в product-код, тема «Овощи»
// резолвится из загруженного пака по id `vegetables` (он гарантированно
// присутствует в `pack_lexical_themes.json` и в fallback-наборе пак-лоадера).
//
// Если по какой-то причине темы нет — используется минимальная локальная
// фикстура, чтобы тест дал осмысленный assert, а не упал на nil.

extension LexicalThemesCorpus {

    /// Тема «Овощи» — стабильная тест-фикстура.
    /// Резолвится из загруженного пака; при отсутствии — локальный fallback.
    static var vegetables: LexicalTheme {
        if let packTheme = theme(id: "vegetables") {
            return packTheme
        }
        return LexicalTheme(
            id: "vegetables",
            title: "Овощи",
            generalization: "овощи",
            symbolName: "carrot.fill",
            words: [
                LexicalWord(id: "veg-1", text: "морковь", action: "растёт", attribute: "оранжевая"),
                LexicalWord(id: "veg-2", text: "капуста", action: "хрустит", attribute: "хрустящая"),
                LexicalWord(id: "veg-3", text: "помидор", action: "краснеет", attribute: "красный"),
                LexicalWord(id: "veg-4", text: "огурец", action: "зеленеет", attribute: "зелёный"),
                LexicalWord(id: "veg-5", text: "картофель", action: "варится", attribute: "рассыпчатый"),
                LexicalWord(id: "veg-6", text: "лук", action: "горчит", attribute: "горький"),
                LexicalWord(id: "veg-7", text: "свёкла", action: "зреет", attribute: "бордовая"),
                LexicalWord(id: "veg-8", text: "тыква", action: "наливается", attribute: "большая")
            ]
        )
    }
}
