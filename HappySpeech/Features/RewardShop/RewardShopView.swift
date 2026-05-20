import OSLog
import SwiftUI

// MARK: - RewardShopViewModelHolder

@MainActor
@Observable
final class RewardShopViewModelHolder: RewardShopDisplayLogic {

    var loadVM: RewardShopModels.Load.ViewModel?
    var toastTitle: String?
    var toastMessage: String?
    var toastIsError: Bool = false
    var pendingPurchase: RewardShopModels.Load.StickerViewModel?

    func displayLoad(viewModel: RewardShopModels.Load.ViewModel) async {
        self.loadVM = viewModel
    }

    func displayPurchaseSuccess(viewModel: RewardShopModels.Purchase.ViewModel) async {
        toastTitle = viewModel.toastTitle
        toastMessage = viewModel.toastMessage
        toastIsError = false
    }

    func displayPurchaseFailure(viewModel: RewardShopModels.Purchase.FailureViewModel) async {
        toastTitle = viewModel.toastTitle
        toastMessage = viewModel.toastMessage
        toastIsError = true
    }
}

// MARK: - RewardShopView (Clean Swift: View)
//
// v31 Волна C, Функция Ф.1 «Магазин наград».
//
// Детский контур: яркий, тёплый, large touch targets ≥ 56pt. Сетка
// стикеров по категориям. Купленные стикеры показаны цветным значком
// «галочка», недоступные — затемнены с подсказкой цены. Покупка идёт
// через `confirmationDialog`, чтобы избежать случайных кликов.
//
// Accessibility:
//   • VoiceOver: каждая карточка — combine с label из Presenter
//   • Dynamic Type: ScrollView, lineLimit(nil), minimumScaleFactor
//   • Reduced Motion: учитывается на анимации появления toast'а
//   • WCAG AA: контрастные цвета токенов на Kid surface
//   • Touch targets: каждая sticker tile ≥ 100×100pt, кнопки ≥ 56pt

struct RewardShopView: View {

    let childId: String

    @State private var holder = RewardShopViewModelHolder()
    @State private var interactor: RewardShopInteractor?
    @State private var presenter: RewardShopPresenter?
    @State private var router: RewardShopRouter?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "RewardShop.View"
    )

    private let gridColumns = [
        GridItem(.adaptive(minimum: 110, maximum: 160), spacing: SpacingTokens.sp3)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
                        if let viewModel = holder.loadVM {
                            coinsBalanceCard(viewModel)
                            ForEach(viewModel.categories) { category in
                                categorySection(category)
                            }
                        } else {
                            loadingState
                        }
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.vertical, SpacingTokens.sp4)
                }

                toastOverlay
            }
            .navigationTitle(Text("rewardShop.screen.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router?.dismiss()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text("rewardShop.close.a11y"))
                }
            }
            .task {
                await setupAndLoad()
            }
            .confirmationDialog(
                Text("rewardShop.confirm.title"),
                isPresented: Binding(
                    get: { holder.pendingPurchase != nil },
                    set: { newValue in
                        if !newValue { holder.pendingPurchase = nil }
                    }
                ),
                titleVisibility: .visible,
                presenting: holder.pendingPurchase
            ) { sticker in
                Button(
                    role: nil,
                    action: { confirmPurchase(sticker) }
                ) {
                    Text(String(
                        format: String(localized: "rewardShop.confirm.buy"),
                        sticker.price
                    ))
                }
                Button(role: .cancel) {
                    holder.pendingPurchase = nil
                } label: {
                    Text("rewardShop.confirm.cancel")
                }
            } message: { sticker in
                Text(sticker.name)
            }
        }
        .environment(\.circuitContext, .kid)
        .accessibilityIdentifier("RewardShopRoot")
    }

    // MARK: - Balance card

    private func coinsBalanceCard(
        _ viewModel: RewardShopModels.Load.ViewModel
    ) -> some View {
        HSCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                ZStack {
                    Circle()
                        .fill(ColorTokens.Brand.gold.opacity(0.18))
                        .frame(width: 56, height: 56)
                    Image(systemName: "bitcoinsign.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(ColorTokens.Brand.gold)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.coinsBalanceText)
                        .font(TypographyTokens.title(24).weight(.bold).monospacedDigit())
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(viewModel.totalEarnedText)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(nil)
                    Text(viewModel.totalSpentText)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(nil)
                }

                Spacer(minLength: 0)
            }
            .padding(SpacingTokens.sp4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            viewModel.coinsBalanceText + ". " + viewModel.totalEarnedText
            + ". " + viewModel.totalSpentText
        )
    }

    // MARK: - Category section

    private func categorySection(
        _ category: RewardShopModels.Load.CategoryViewModel
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            Text(LocalizedStringKey(category.titleKey))
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Kid.ink)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: gridColumns, spacing: SpacingTokens.sp3) {
                ForEach(category.stickers) { sticker in
                    stickerTile(sticker)
                }
            }
        }
    }

    // MARK: - Sticker tile

    private func stickerTile(
        _ sticker: RewardShopModels.Load.StickerViewModel
    ) -> some View {
        let isDisabled = sticker.isOwned || !sticker.isAffordable
        return Button {
            guard !sticker.isOwned, sticker.isAffordable else { return }
            holder.pendingPurchase = sticker
        } label: {
            VStack(spacing: SpacingTokens.sp2) {
                stickerArt(sticker)
                Text(sticker.name)
                    .font(TypographyTokens.caption(12).weight(.medium))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
                priceChip(sticker)
            }
            .padding(SpacingTokens.sp2)
            .frame(maxWidth: .infinity, minHeight: 156)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(rarityBackground(sticker.rarity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .strokeBorder(rarityBorder(sticker.rarity), lineWidth: 1)
            )
            .opacity(sticker.isOwned ? 1.0 : (sticker.isAffordable ? 1.0 : 0.55))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(Text(sticker.accessibilityLabel))
        .accessibilityIdentifier("stickerTile_\(sticker.id)")
    }

    @ViewBuilder
    private func stickerArt(
        _ sticker: RewardShopModels.Load.StickerViewModel
    ) -> some View {
        ZStack {
            Image(sticker.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)

            if sticker.isOwned {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Brand.mint)
                            .padding(4)
                            .background(Circle().fill(Color.white.opacity(0.9)))
                            .accessibilityHidden(true)
                    }
                    Spacer()
                }
                .frame(width: 72, height: 72)
            }
        }
    }

    @ViewBuilder
    private func priceChip(
        _ sticker: RewardShopModels.Load.StickerViewModel
    ) -> some View {
        if sticker.isOwned {
            Text("rewardShop.sticker.owned")
                .font(TypographyTokens.caption(11).weight(.semibold))
                .foregroundStyle(ColorTokens.Brand.mint)
                .padding(.horizontal, SpacingTokens.sp2)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(ColorTokens.Brand.mint.opacity(0.18))
                )
        } else {
            HStack(spacing: 4) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.caption2)
                    .accessibilityHidden(true)
                Text(sticker.priceText)
                    .font(TypographyTokens.caption(11).weight(.semibold).monospacedDigit())
            }
            .foregroundStyle(
                sticker.isAffordable ? ColorTokens.Brand.gold : ColorTokens.Kid.inkSoft
            )
            .padding(.horizontal, SpacingTokens.sp2)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(
                    sticker.isAffordable
                    ? ColorTokens.Brand.gold.opacity(0.16)
                    : ColorTokens.Kid.surface
                )
            )
        }
    }

    // MARK: - Toast overlay

    @ViewBuilder
    private var toastOverlay: some View {
        if let title = holder.toastTitle, let message = holder.toastMessage {
            VStack {
                Spacer()
                HSCard(style: .elevated) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(2)
                        Text(message)
                            .font(TypographyTokens.body(13))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(SpacingTokens.sp3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp4)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                .task {
                    try? await Task.sleep(for: .seconds(2.4))
                    holder.toastTitle = nil
                    holder.toastMessage = nil
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title). \(message)")
        }
    }

    private var loadingState: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ProgressView()
                .controlSize(.large)
                .tint(ColorTokens.Brand.primary)
            Text("rewardShop.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SpacingTokens.sp10)
    }

    // MARK: - Rarity styling

    private func rarityBackground(_ rarity: ShopStickerRarity) -> Color {
        switch rarity {
        case .common:    return ColorTokens.Kid.surface
        case .uncommon:  return ColorTokens.Brand.sky.opacity(0.10)
        case .rare:      return ColorTokens.Brand.lilac.opacity(0.12)
        case .epic:      return ColorTokens.Brand.rose.opacity(0.12)
        case .legendary: return ColorTokens.Brand.gold.opacity(0.18)
        }
    }

    private func rarityBorder(_ rarity: ShopStickerRarity) -> Color {
        switch rarity {
        case .common:    return ColorTokens.Kid.line
        case .uncommon:  return ColorTokens.Brand.sky.opacity(0.5)
        case .rare:      return ColorTokens.Brand.lilac.opacity(0.6)
        case .epic:      return ColorTokens.Brand.rose.opacity(0.6)
        case .legendary: return ColorTokens.Brand.gold.opacity(0.8)
        }
    }

    // MARK: - Wiring

    private func setupAndLoad() async {
        if interactor == nil {
            let presenter = RewardShopPresenter(displayLogic: holder)
            let worker = LiveRewardShopWorker(realmActor: container.realmActor)
            let interactor = RewardShopInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = RewardShopRouter(dismissAction: { dismiss() })
        }
        await interactor?.load(request: .init(childId: childId))
    }

    private func confirmPurchase(_ sticker: RewardShopModels.Load.StickerViewModel) {
        holder.pendingPurchase = nil
        Task {
            await interactor?.purchase(
                request: .init(childId: childId, stickerId: sticker.id)
            )
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("RewardShop / kid") {
    RewardShopView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
