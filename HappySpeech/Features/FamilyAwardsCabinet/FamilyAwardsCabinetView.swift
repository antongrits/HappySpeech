import OSLog
import RealityKit
import SwiftUI

// MARK: - FamilyAwardsCabinetViewModelHolder

@MainActor
@Observable
final class FamilyAwardsCabinetViewModelHolder: FamilyAwardsCabinetDisplayLogic {

    var loadVM: FamilyAwardsCabinetModels.Load.ViewModel?
    var selectedAwardVM: FamilyAwardsCabinetModels.SelectAward.ViewModel?

    func displayLoad(viewModel: FamilyAwardsCabinetModels.Load.ViewModel) async {
        self.loadVM = viewModel
    }

    func displaySelectAward(viewModel: FamilyAwardsCabinetModels.SelectAward.ViewModel) async {
        self.selectedAwardVM = viewModel
    }
}

// MARK: - FamilyAwardsCabinetView (Clean Swift: View)
//
// Block AE batch 2 v21 — 3D витрина семейных наград.
//
// Layout:
//   1. Hero — заголовок «Кабинет наград» + резюме (X наград, Y детей)
//   2. CabinetView — 3D-витрина (iOS 18+: RealityView с примитивами)
//      → 2D fallback (iOS 17 либо при unavailable RealityKit)
//   3. Tier shelves — карточки полок (платина → бронза)
//   4. Trophy grid — 3 трофея в ряд внутри каждой полки
//
// Accessibility:
//   • RealityView помечен `.accessibilityHidden(true)` — это декоративный 3D-фон;
//     полная семантика — в trophy-карточках под ним.
//   • Reduced Motion: убираем idle-вращение 3D куба.
//   • Touch targets ≥44pt на каждом trophy-tile.

struct FamilyAwardsCabinetView: View {

    let parentId: String

    @State private var holder = FamilyAwardsCabinetViewModelHolder()
    @State private var interactor: FamilyAwardsCabinetInteractor?
    @State private var presenter: FamilyAwardsCabinetPresenter?
    @State private var router: FamilyAwardsCabinetRouter?
    @State private var showDetailSheet: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "FamilyAwardsCabinet.View"
    )

    private let trophyColumns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: SpacingTokens.sp2),
        count: 3
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: SpacingTokens.sp5) {
                        if let viewModel = holder.loadVM {
                            heroSection(viewModel: viewModel)
                            cabinet3DSection(viewModel: viewModel)
                            if viewModel.cabinetIsEmpty {
                                emptyState(viewModel: viewModel)
                            } else {
                                shelvesSection(viewModel: viewModel)
                            }
                            footerNote
                        } else {
                            loadingSection
                        }
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.vertical, SpacingTokens.sp4)
                }
            }
            .navigationTitle(Text("familyAwardsCabinet.screen.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                    .accessibilityLabel(Text("familyAwardsCabinet.close.a11y"))
                }
            }
            .sheet(isPresented: $showDetailSheet) {
                if let detail = holder.selectedAwardVM {
                    detailSheet(viewModel: detail)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
            .task {
                await setupAndLoad()
            }
        }
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Hero

    @ViewBuilder
    private func heroSection(viewModel: FamilyAwardsCabinetModels.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
            Text(viewModel.heroTitle)
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Parent.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .accessibilityAddTraits(.isHeader)

            Text(viewModel.heroSubtitle)
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Cabinet 3D

    @ViewBuilder
    private func cabinet3DSection(viewModel: FamilyAwardsCabinetModels.Load.ViewModel) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(
                    LinearGradient(
                        colors: [
                            ColorTokens.Parent.bgDeep,
                            ColorTokens.Parent.surface
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 200)
                .shadow(color: .black.opacity(0.10), radius: 12, y: 6)

            // 3D scene — iOS 18+ RealityView; иначе 2D-fallback с layered cards.
            if #available(iOS 18.0, *), !viewModel.cabinetIsEmpty {
                CabinetRealityView(
                    shelves: viewModel.shelves,
                    reduceMotion: reduceMotion
                )
                .frame(height: 200)
                .accessibilityHidden(true)
            } else {
                cabinet2DFallback(viewModel: viewModel)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private func cabinet2DFallback(
        viewModel: FamilyAwardsCabinetModels.Load.ViewModel
    ) -> some View {
        // Параллакс-стиль: 3 «полки» располагаются ярусами с легкой перспективой.
        VStack(spacing: SpacingTokens.sp1) {
            ForEach(Array(viewModel.shelves.prefix(3).enumerated()), id: \.element.id) { idx, shelf in
                HStack(spacing: SpacingTokens.sp2) {
                    ForEach(shelf.trophies.prefix(4)) { trophy in
                        ZStack {
                            RoundedRectangle(cornerRadius: RadiusTokens.sm)
                                .fill(tierColor(for: shelf.tierColorName))
                                .frame(width: 28, height: 28)
                                .shadow(color: .black.opacity(0.10), radius: 2, y: 1)

                            Image(systemName: trophy.symbolName)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    if shelf.trophies.count > 4 {
                        Text("+\(shelf.trophies.count - 4)")
                            .font(TypographyTokens.caption(10).weight(.semibold))
                            .foregroundStyle(tierColor(for: shelf.tierColorName))
                    }
                    Spacer()
                }
                .padding(.horizontal, CGFloat(idx) * SpacingTokens.sp2)
            }
        }
        .padding(SpacingTokens.sp3)
    }

    // MARK: - Shelves

    @ViewBuilder
    private func shelvesSection(viewModel: FamilyAwardsCabinetModels.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
            ForEach(viewModel.shelves) { shelf in
                if !shelf.trophies.isEmpty {
                    shelfCard(shelf)
                }
            }
        }
    }

    @ViewBuilder
    private func shelfCard(_ shelf: FamilyAwardsCabinetModels.Load.ShelfViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "trophy.fill")
                    .font(.title3)
                    .foregroundStyle(tierColor(for: shelf.tierColorName))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(tierColor(for: shelf.tierColorName).opacity(0.15))
                    )
                    .accessibilityHidden(true)

                Text(shelf.tierTitle)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer()

                Text(shelf.trophyCountLabel)
                    .font(TypographyTokens.caption(11).monospacedDigit())
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .padding(.horizontal, SpacingTokens.sp2)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(ColorTokens.Parent.bg)
                    )
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(shelf.tierTitle), \(shelf.trophyCountLabel)"))

            LazyVGrid(columns: trophyColumns, spacing: SpacingTokens.sp2) {
                ForEach(shelf.trophies) { trophy in
                    trophyTile(trophy, tierColor: tierColor(for: shelf.tierColorName))
                }
            }
        }
        .padding(SpacingTokens.sp4)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Parent.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .strokeBorder(ColorTokens.Parent.line, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func trophyTile(
        _ trophy: FamilyAwardsCabinetModels.Load.TrophyViewModel,
        tierColor: Color
    ) -> some View {
        Button {
            Task { await selectAward(id: trophy.id) }
        } label: {
            VStack(spacing: SpacingTokens.sp1) {
                ZStack {
                    RoundedRectangle(cornerRadius: RadiusTokens.sm)
                        .fill(tierColor.opacity(0.18))
                        .frame(height: 56)
                    Image(systemName: trophy.symbolName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(tierColor)
                }

                Text(trophy.title)
                    .font(TypographyTokens.caption(11).weight(.semibold))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)

                Text(trophy.childName)
                    .font(TypographyTokens.caption(10))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .padding(SpacingTokens.sp2)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.sm)
                    .fill(ColorTokens.Parent.bg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.sm)
                    .strokeBorder(tierColor.opacity(0.30), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(trophy.accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Empty state

    @ViewBuilder
    private func emptyState(viewModel: FamilyAwardsCabinetModels.Load.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            Image(systemName: "trophy")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .accessibilityHidden(true)

            Text(viewModel.emptyTitle)
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Parent.ink)
                .multilineTextAlignment(.center)

            Text(viewModel.emptySubtitle)
                .font(TypographyTokens.body(13))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.sp5)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Footer

    private var footerNote: some View {
        Text("familyAwardsCabinet.footer.note")
            .font(TypographyTokens.caption(11))
            .foregroundStyle(ColorTokens.Parent.inkMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, SpacingTokens.sp4)
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ProgressView()
                .controlSize(.large)
            Text("familyAwardsCabinet.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SpacingTokens.sp10)
    }

    // MARK: - Detail sheet

    @ViewBuilder
    private func detailSheet(
        viewModel: FamilyAwardsCabinetModels.SelectAward.ViewModel
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
                HStack(spacing: SpacingTokens.sp3) {
                    Image(systemName: viewModel.symbolName)
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(ColorTokens.Brand.gold)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                        Text(viewModel.tierTitle)
                            .font(TypographyTokens.caption(11).weight(.semibold))
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .foregroundStyle(ColorTokens.Brand.primary)

                        Text(viewModel.title)
                            .font(TypographyTokens.title(22))
                            .foregroundStyle(ColorTokens.Parent.ink)
                            .lineLimit(3)
                            .minimumScaleFactor(0.85)
                            .accessibilityAddTraits(.isHeader)

                        Text(viewModel.subtitle)
                            .font(TypographyTokens.body(13))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                            .lineLimit(2)
                    }
                    Spacer()
                }
                .padding(.top, SpacingTokens.sp4)

                Text(viewModel.detail)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(SpacingTokens.sp4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.md)
                            .fill(ColorTokens.Parent.bg)
                    )

                Spacer(minLength: SpacingTokens.sp4)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .background(ColorTokens.Parent.surface.ignoresSafeArea())
    }

    // MARK: - Tier color

    private func tierColor(for raw: String) -> Color {
        AwardTier(rawValue: raw)?.displayColor ?? ColorTokens.Brand.primary
    }

    // MARK: - Wiring

    private func setupAndLoad() async {
        if interactor == nil {
            let presenter = FamilyAwardsCabinetPresenter(displayLogic: holder)
            let catalogWorker = AwardsCatalogWorker(
                childRepository: container.childRepository
            )
            let interactor = FamilyAwardsCabinetInteractor(
                catalogWorker: catalogWorker,
                childRepository: container.childRepository,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = FamilyAwardsCabinetRouter(
                dismissAction: { [self] in dismiss() },
                openAchievementsAction: { [self] childId in
                    coordinator.navigate(to: .achievements(childId: childId))
                }
            )
        }
        await interactor?.load(request: .init(parentId: parentId))
    }

    private func selectAward(id: String) async {
        await interactor?.selectAward(request: .init(awardId: id))
        showDetailSheet = true
    }
}

// MARK: - CabinetRealityView (iOS 18+)
//
// Минималистичный 3D-кабинет: 3 «полки» (тонкие прямоугольные параллелепипеды)
// и небольшие кубики-трофеи на них. Освещение — directional + ambient.
// При reduceMotion idle-rotation не запускается.

@available(iOS 18.0, *)
private struct CabinetRealityView: View {
    let shelves: [FamilyAwardsCabinetModels.Load.ShelfViewModel]
    let reduceMotion: Bool

    var body: some View {
        RealityView { content in
            let root = Entity()
            content.add(root)

            // 3 полки + трофеи (примитивы RealityKit).
            let shelfWidth: Float = 0.40
            let shelfHeight: Float = 0.014
            let shelfDepth: Float = 0.06
            let shelfSpacing: Float = 0.07

            for (idx, shelf) in shelves.prefix(3).enumerated() {
                let shelfY: Float = 0.10 - Float(idx) * shelfSpacing

                // Полка — деревянный куб
                let shelfMesh = MeshResource.generateBox(
                    width: shelfWidth,
                    height: shelfHeight,
                    depth: shelfDepth
                )
                let woodMaterial = SimpleMaterial(
                    color: UIColor(red: 0.42, green: 0.30, blue: 0.20, alpha: 1.0),
                    isMetallic: false
                )
                let shelfEntity = ModelEntity(mesh: shelfMesh, materials: [woodMaterial])
                shelfEntity.position = SIMD3(0, shelfY, 0)
                root.addChild(shelfEntity)

                // До 4 «трофеев»-кубиков, расставленных вдоль полки
                let maxOnShelf = min(4, shelf.trophies.count)
                guard maxOnShelf > 0 else { continue }
                let trophyMesh = MeshResource.generateBox(
                    width: 0.04, height: 0.05, depth: 0.04, cornerRadius: 0.006
                )

                let uiColor = UIColor(
                    AwardTier(rawValue: shelf.tierColorName)?.displayColor
                        ?? ColorTokens.Brand.primary
                )
                let trophyMat = SimpleMaterial(color: uiColor, isMetallic: true)
                let span: Float = shelfWidth * 0.85
                let step: Float = span / Float(max(maxOnShelf, 1))
                let startX: Float = -span / 2 + step / 2

                for i in 0..<maxOnShelf {
                    let trophyEntity = ModelEntity(
                        mesh: trophyMesh,
                        materials: [trophyMat]
                    )
                    trophyEntity.position = SIMD3(
                        startX + step * Float(i),
                        shelfY + 0.032,
                        0
                    )
                    root.addChild(trophyEntity)
                }
            }

            // Idle-поворот всего root для лёгкого живого эффекта.
            if !reduceMotion {
                let startTransform = root.transform
                var endTransform = startTransform
                endTransform.rotation = simd_quatf(angle: 0.12, axis: SIMD3(0, 1, 0))

                let definition = FromToByAnimation<Transform>(
                    name: "cabinet-idle",
                    from: startTransform,
                    to: endTransform,
                    duration: 5.5,
                    timing: .easeInOut,
                    bindTarget: .transform,
                    repeatMode: .autoReverse
                )
                if let resource = try? AnimationResource.generate(with: definition) {
                    root.playAnimation(resource.repeat())
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("FamilyAwardsCabinet / Parent") {
    FamilyAwardsCabinetView(parentId: "local-parent")
        .environment(AppContainer.preview())
        .environment(AppCoordinator())
}
#endif
