import Foundation
import OSLog

// MARK: - FamilyAwardsCabinetPresentationLogic

@MainActor
protocol FamilyAwardsCabinetPresentationLogic: AnyObject {
    func presentLoad(response: FamilyAwardsCabinetModels.Load.Response) async
    func presentSelectAward(response: FamilyAwardsCabinetModels.SelectAward.Response) async
}

// MARK: - FamilyAwardsCabinetPresenter (Clean Swift: Presenter)
//
// Block AE batch 2 v21 — мапит Response → ViewModel.

@MainActor
final class FamilyAwardsCabinetPresenter: FamilyAwardsCabinetPresentationLogic {

    weak var displayLogic: (any FamilyAwardsCabinetDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "FamilyAwardsCabinet.Presenter"
    )

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    init(displayLogic: (any FamilyAwardsCabinetDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Load

    func presentLoad(response: FamilyAwardsCabinetModels.Load.Response) async {
        let heroTitle = String(localized: "familyAwardsCabinet.hero.title")
        let heroSubtitle: String = {
            if response.totalAwards == 0 {
                return String(localized: "familyAwardsCabinet.hero.subtitle.empty")
            }
            return String(
                format: String(localized: "familyAwardsCabinet.hero.subtitle.summary"),
                response.totalAwards,
                response.totalChildren
            )
        }()

        let shelves: [FamilyAwardsCabinetModels.Load.ShelfViewModel] = response.shelves.map { bucket in
            let tierTitle = String(localized: String.LocalizationValue(bucket.tier.titleKey))
            let trophyCountLabel = String(
                format: String(localized: "familyAwardsCabinet.shelf.count"),
                bucket.awards.count
            )
            let trophies: [FamilyAwardsCabinetModels.Load.TrophyViewModel] = bucket.awards.map { award in
                let title = String(localized: String.LocalizationValue(award.titleKey))
                let dateLabel = dateFormatter.string(from: award.unlockedDate)
                let a11y = String(
                    format: String(localized: "familyAwardsCabinet.trophy.a11y"),
                    title, award.childName, tierTitle
                )
                return .init(
                    id: award.id,
                    title: title,
                    childName: award.childName,
                    dateLabel: dateLabel,
                    symbolName: award.symbolName,
                    accessibilityLabel: a11y
                )
            }
            return .init(
                tierRaw: bucket.tier.rawValue,
                tierTitle: tierTitle,
                tierColorName: bucket.tier.rawValue,
                trophyCount: bucket.awards.count,
                trophyCountLabel: trophyCountLabel,
                trophies: trophies
            )
        }

        let totalAwards = response.totalAwards
        let cabinetIsEmpty = totalAwards == 0
        let emptyTitle = String(localized: "familyAwardsCabinet.empty.title")
        let emptySubtitle = String(localized: "familyAwardsCabinet.empty.subtitle")

        let viewModel = FamilyAwardsCabinetModels.Load.ViewModel(
            heroTitle: heroTitle,
            heroSubtitle: heroSubtitle,
            shelves: shelves,
            cabinetIsEmpty: cabinetIsEmpty,
            emptyTitle: emptyTitle,
            emptySubtitle: emptySubtitle
        )

        await displayLogic?.displayLoad(viewModel: viewModel)
    }

    // MARK: - SelectAward

    func presentSelectAward(response: FamilyAwardsCabinetModels.SelectAward.Response) async {
        let award = response.award
        let title = String(localized: String.LocalizationValue(award.titleKey))
        let tierTitle = String(localized: String.LocalizationValue(award.tier.titleKey))
        let subtitle = String(
            format: String(localized: "familyAwardsCabinet.detail.subtitle"),
            award.childName,
            dateFormatter.string(from: award.unlockedDate)
        )
        let detail = String(
            format: String(localized: "familyAwardsCabinet.detail.body"),
            award.childName,
            tierTitle
        )

        let viewModel = FamilyAwardsCabinetModels.SelectAward.ViewModel(
            title: title,
            subtitle: subtitle,
            tierTitle: tierTitle,
            symbolName: award.symbolName,
            detail: detail
        )

        await displayLogic?.displaySelectAward(viewModel: viewModel)
    }
}
