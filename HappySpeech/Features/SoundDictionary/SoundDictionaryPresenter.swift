import Foundation
import OSLog

// MARK: - SoundDictionaryPresentationLogic

@MainActor
protocol SoundDictionaryPresentationLogic: AnyObject {
    func presentLoad(response: SoundDictionaryModels.Load.Response) async
    func presentSelectPhoneme(response: SoundDictionaryModels.SelectPhoneme.Response) async
    func presentPlayAudio(response: SoundDictionaryModels.PlayAudio.Response) async
    func presentPracticePhoneme(response: SoundDictionaryModels.PracticePhoneme.Response) async
}

// MARK: - SoundDictionaryPresenter (Clean Swift: Presenter)
//
// Block AE v21 — мапит Response → ViewModel.
// Все строки через `String(localized:)` — ключи появятся в xcstrings
// после первой компиляции.

@MainActor
final class SoundDictionaryPresenter: SoundDictionaryPresentationLogic {

    weak var displayLogic: (any SoundDictionaryDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundDictionary.Presenter"
    )

    init(displayLogic: (any SoundDictionaryDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Load

    func presentLoad(response: SoundDictionaryModels.Load.Response) async {
        let grouped = Dictionary(grouping: response.entries) { $0.group }
        let orderedGroups: [PhonemeGroup] = PhonemeGroup.allCases

        let sections: [SoundDictionaryModels.Load.SectionViewModel] = orderedGroups.compactMap { group in
            guard let entries = grouped[group], !entries.isEmpty else { return nil }

            let cells: [SoundDictionaryModels.Load.CellViewModel] = entries.map { entry in
                .init(
                    id: entry.id,
                    cyrillic: entry.cyrillic,
                    ipa: "[\(entry.ipa)]",
                    exampleSyllable: entry.exampleSyllable,
                    accessibilityLabel: String(
                        format: String(localized: "soundDictionary.cell.a11y"),
                        entry.cyrillic,
                        entry.exampleWord
                    )
                )
            }

            let groupTitle = String(localized: String.LocalizationValue(group.titleKey))
            return .init(
                id: group.rawValue,
                groupTitle: groupTitle,
                groupSymbol: group.symbolName,
                groupAccessibilityLabel: String(
                    format: String(localized: "soundDictionary.section.a11y"),
                    groupTitle,
                    entries.count
                ),
                cells: cells
            )
        }

        let total = response.entries.count
        let totalLabel = String(
            format: String(localized: "soundDictionary.totalCount"),
            total
        )

        let viewModel = SoundDictionaryModels.Load.ViewModel(
            sections: sections,
            totalCount: total,
            totalCountLabel: totalLabel
        )

        await displayLogic?.displayLoad(viewModel: viewModel)
    }

    // MARK: - SelectPhoneme

    func presentSelectPhoneme(response: SoundDictionaryModels.SelectPhoneme.Response) async {
        let entry = response.entry
        let groupTitle = String(localized: String.LocalizationValue(entry.group.titleKey))
        let articulation = String(localized: String.LocalizationValue(entry.articulationNoteKey))

        let viewModel = SoundDictionaryModels.SelectPhoneme.ViewModel(
            title: entry.cyrillic,
            ipaLabel: "[\(entry.ipa)]",
            groupTitle: groupTitle,
            exampleWord: entry.exampleWord,
            articulationNote: articulation,
            hasAudio: response.hasAudio,
            practiceCtaLabel: String(localized: "soundDictionary.detail.cta.practice"),
            playAudioLabel: String(localized: "soundDictionary.detail.cta.playAudio")
        )

        await displayLogic?.displaySelectPhoneme(viewModel: viewModel)
    }

    // MARK: - PlayAudio

    func presentPlayAudio(response: SoundDictionaryModels.PlayAudio.Response) async {
        let toast: String?
        if response.usedFallbackTTS {
            toast = String(localized: "soundDictionary.audio.toast.tts")
        } else if !response.success {
            toast = String(localized: "soundDictionary.audio.toast.failed")
        } else {
            toast = nil
        }
        let viewModel = SoundDictionaryModels.PlayAudio.ViewModel(toastMessage: toast)
        await displayLogic?.displayPlayAudio(viewModel: viewModel)
    }

    // MARK: - PracticePhoneme

    func presentPracticePhoneme(response: SoundDictionaryModels.PracticePhoneme.Response) async {
        let viewModel = SoundDictionaryModels.PracticePhoneme.ViewModel(
            phonemeId: response.phonemeId
        )
        await displayLogic?.displayPracticePhoneme(viewModel: viewModel)
    }
}
