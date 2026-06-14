import SwiftUI

// MARK: - ChildAchievementShareView

struct ChildAchievementShareView: View {

    @State private var interactor: ChildAchievementShareInteractor?
    @State private var shareItem: ChildAchievementShareItem?
    @Environment(AppContainer.self) private var container
    @Environment(\.exitToParentHome) private var exitToParentHome
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                HSMeshGradientBackground(palette: .rewards, animated: !reduceMotion)
                    .ignoresSafeArea()
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                if let interactor {
                    content(interactor)
                } else {
                    ProgressView().controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(Text(String(localized: "achievementShare.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exitToParentHome()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
            .sheet(item: $shareItem) { item in
                ChildAchievementShareSheet(items: [item.text])
            }
            .task {
                if interactor == nil {
                    let new = ChildAchievementShareInteractor(
                        childRepository: container.childRepository
                    )
                    interactor = new
                    await new.loadChildName()
                }
            }
        }
        .environment(\.circuitContext, .parent)
    }

    private func content(_ interactor: ChildAchievementShareInteractor) -> some View {
        ScrollView {
            VStack(spacing: SpacingTokens.sp3) {
                hero
                sectionLabel("achievementShare.section.list")
                list(interactor)
                if let selected = interactor.selected {
                    previewCard(selected, childName: interactor.childName)
                }
                cta(interactor)
                gateNote
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp3)
            .padding(.bottom, SpacingTokens.sp6)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding(.bottom, SpacingTokens.sp2)
    }

    // kid-diary-journal: Ляля с тёплым пузырём над списком достижений.
    private var hero: some View {
        HStack(alignment: .bottom, spacing: SpacingTokens.sp2) {
            LyalyaMascotView(state: .celebrating, size: 52)
                .accessibilityHidden(true)
            HSCard(style: .elevated, padding: SpacingTokens.sp3) {
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(String(localized: "achievementShare.hero.title"))
                        .font(TypographyTokens.kidCardTitle(16))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                    Text("achievementShare.mascot.bubble")
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func sectionLabel(_ key: LocalizedStringKey) -> some View {
        HStack(spacing: SpacingTokens.tiny) {
            Capsule()
                .fill(ColorTokens.Brand.primaryLo)
                .frame(width: 18, height: 3)
            Text(key)
                .font(TypographyTokens.caption(13).weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 2)
    }

    // kid-diary-journal share-inset: тёплая открытка-превью выбранного достижения.
    private func previewCard(_ item: ChildAchievementShareModels.Item, childName: String) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
            HStack {
                Text("achievementShare.card.brand")
                    .font(TypographyTokens.caption(11).weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(ColorTokens.Overlay.onAccent.opacity(0.92))
                Spacer(minLength: 0)
                Text(item.emoji).font(.system(size: 30))
                    .accessibilityHidden(true)
            }
            Text(item.title)
                .font(TypographyTokens.title(22).weight(.bold))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.8)
            Text(item.subtitle)
                .font(TypographyTokens.body(14).weight(.semibold))
                .foregroundStyle(ColorTokens.Overlay.onAccent.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
            Text(childName)
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Overlay.onAccent.opacity(0.88))
                .padding(.top, SpacingTokens.micro)
        }
        .padding(SpacingTokens.sp4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(GradientTokens.warmSunset)
        )
        .overlay(alignment: .bottomTrailing) {
            LyalyaMascotView(state: .celebrating, size: 56)
                .padding(SpacingTokens.sp2)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(item.title). \(item.subtitle)"))
    }

    private var gateNote: some View {
        HStack(spacing: SpacingTokens.tiny) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
            Text("achievementShare.gate.note")
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func list(_ interactor: ChildAchievementShareInteractor) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            ForEach(Array(interactor.items.enumerated()), id: \.element.id) { index, item in
                row(item, interactor: interactor)
                    .scrollTransition(.animated(reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.85))) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0)
                            .scaleEffect(phase.isIdentity ? 1 : 0.96)
                    }
                    .hsParallaxTile(factor: 0.22)
                    .zIndex(Double(interactor.items.count - index))
            }
        }
    }

    private func row(_ item: ChildAchievementShareModels.Item, interactor: ChildAchievementShareInteractor) -> some View {
        let selected = interactor.selectedId == item.id
        return Button {
            hapticService.impact(.light)
            interactor.select(item.id)
        } label: {
            HSCard(style: selected ? .tinted(ColorTokens.Brand.primaryLo.opacity(0.18)) : .flat) {
                HStack(spacing: SpacingTokens.sp3) {
                    ZStack {
                        Circle()
                            .fill(ColorTokens.Brand.primaryLo.opacity(0.22))
                            .frame(width: 46, height: 46)
                        Text(item.emoji).font(.system(size: 28))
                    }
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Parent.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.85)
                        Text(item.subtitle)
                            .font(TypographyTokens.body(13))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.85)
                    }
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .font(.system(size: 22))
                            .hsSymbolEffect(.bounce, value: selected)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(item.title). \(item.subtitle)"))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func cta(_ interactor: ChildAchievementShareInteractor) -> some View {
        HSButton(
            String(localized: "achievementShare.cta.share"),
            style: .primary,
            size: .large,
            icon: "square.and.arrow.up"
        ) {
            guard let text = interactor.makeShareText() else { return }
            hapticService.impact(.medium)
            shareItem = ChildAchievementShareItem(text: text)
        }
        .disabled(interactor.selectedId == nil)
        .opacity(interactor.selectedId == nil ? 0.5 : 1.0)
    }
}

// MARK: - Share helpers

private struct ChildAchievementShareItem: Identifiable {
    let id = UUID()
    let text: String
}

private struct ChildAchievementShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview("ChildAchievementShare — Light") {
    ChildAchievementShareView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("ChildAchievementShare — Dark") {
    ChildAchievementShareView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
