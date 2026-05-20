import Foundation
import OSLog

// MARK: - SpeechNormsEncyclopediaPresentationLogic

@MainActor
protocol SpeechNormsEncyclopediaPresentationLogic: AnyObject {
    func presentLoad(response: SpeechNormsEncyclopediaModels.Load.Response) async
}

// MARK: - SpeechNormsEncyclopediaPresenter (Clean Swift: Presenter)
//
// v31 Волна A, Функция Ф10 «Что должно быть в возрасте».
//
// Формирует ViewModel: группирует карточки по осям (overview → sounds →
// vocabulary → grammar → connected → motor → redflags), готовит a11y-метки.

@MainActor
final class SpeechNormsEncyclopediaPresenter: SpeechNormsEncyclopediaPresentationLogic {

    weak var displayLogic: (any SpeechNormsEncyclopediaDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpeechNorms.Presenter"
    )

    init(displayLogic: (any SpeechNormsEncyclopediaDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    func presentLoad(response: SpeechNormsEncyclopediaModels.Load.Response) async {

        let ageTabs: [SpeechNormsEncyclopediaModels.Load.AgeTabViewModel] = NormAge.allCases.map { age in
            let title = localized(age.titleKey)
            let isSelected = age == response.selectedAge
            let stateLabel = isSelected
                ? String(localized: "speechNorms.age.selected.a11y")
                : String(localized: "speechNorms.age.unselected.a11y")
            return .init(
                id: age.rawValue,
                age: age,
                title: title,
                isSelected: isSelected,
                accessibilityLabel: "\(title). \(stateLabel)"
            )
        }

        let grouped = Dictionary(grouping: response.cards) { $0.axis }
        let sections: [SpeechNormsEncyclopediaModels.Load.SectionViewModel] = NormAxis.allCases.compactMap { axis in
            guard let group = grouped[axis], !group.isEmpty else { return nil }
            let title = localized(axis.titleKey)
            let cards = group.map { card in
                let stateLabel: String
                if axis == .redflags {
                    stateLabel = String(localized: "speechNorms.card.redflag.a11y")
                } else {
                    stateLabel = String(localized: "speechNorms.card.note.a11y")
                }
                return SpeechNormsEncyclopediaModels.Load.CardViewModel(
                    id: card.id,
                    title: card.title,
                    summary: card.summary,
                    body: card.body,
                    sources: card.sources,
                    isRedFlag: axis == .redflags,
                    accessibilityLabel: "\(card.title). \(card.summary). \(stateLabel)"
                )
            }
            return .init(
                id: axis.rawValue,
                axis: axis,
                title: title,
                symbolName: axis.symbolName,
                isRedFlag: axis == .redflags,
                cards: cards
            )
        }

        let isEmpty = response.cards.isEmpty
        let emptyMessage = response.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? String(localized: "speechNorms.empty.noContent")
            : String(localized: "speechNorms.empty.noMatch")

        let viewModel = SpeechNormsEncyclopediaModels.Load.ViewModel(
            headerTitle: String(localized: "speechNorms.header.title"),
            headerSubtitle: String(localized: "speechNorms.header.subtitle"),
            ethicsNote: SpeechNormsEncyclopediaCorpus.ethicsNote,
            ageTabs: ageTabs,
            selectedAge: response.selectedAge,
            query: response.query,
            sections: sections,
            isEmpty: isEmpty,
            emptyMessage: emptyMessage
        )
        await displayLogic?.displayLoad(viewModel: viewModel)
    }

    private func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }
}
