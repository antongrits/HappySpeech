import SwiftUI

// MARK: - SoundJournalKidView

struct SoundJournalKidView: View {

    let childId: String

    @State private var interactor: SoundJournalKidInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()

                // Step 10 Batch A — Pattern 1: mesh .kidCool палитра (sky/lilac/mint)
                // подчёркивает «аналитический дневник звуков» — холодный, спокойный фон.
                HSMeshGradientBackground(palette: .kidCool, animated: true)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.28 : 0.50)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)

                content
            }
            .navigationTitle(Text(String(localized: "soundJournal.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
            .task {
                if interactor == nil {
                    let new = SoundJournalKidInteractor(
                        childId: childId,
                        sessionRepository: container.sessionRepository
                    )
                    interactor = new
                    new.refresh()
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            ScrollView {
                VStack(spacing: SpacingTokens.sp4) {
                    hero
                    if interactor.state.isEmpty {
                        emptyState
                    } else {
                        list(interactor: interactor)
                    }
                    cta
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp6)
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private var hero: some View {
        // Step 10 Batch A — Pattern 2: hero обёрнут в HSLiquidGlassCard.elevated.
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.regular) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "soundJournal.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "soundJournal.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var emptyState: some View {
        HSCard(style: .elevated) {
            VStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                    .accessibilityHidden(true)
                Text(String(localized: "soundJournal.empty.title"))
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                Text(String(localized: "soundJournal.empty.subtitle"))
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp3)
        }
        .accessibilityElement(children: .combine)
    }

    private func list(interactor: SoundJournalKidInteractor) -> some View {
        // Step 10 Batch A — Pattern 3: stagger fade+scale entrance.
        VStack(spacing: SpacingTokens.sp2) {
            ForEach(interactor.state.entries) { entry in
                row(entry: entry, isSelected: entry.id == interactor.state.selectedEntryId) {
                    hapticService.impact(.light)
                    interactor.select(entry.id)
                }
                .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                    content
                        .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                        .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.94))
                }
            }
        }
        .animation(reduceMotion ? nil : MotionTokens.settleSpring, value: interactor.state.entries.count)
    }

    private func row(
        entry: SoundJournalKidModels.Entry,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HSCard(style: isSelected ? .tinted(ColorTokens.Semantic.successBg) : .elevated) {
                HStack(spacing: SpacingTokens.sp3) {
                    Text(entry.emoji)
                        .font(.system(size: 32))
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Звук «\(entry.sound)»")
                            .font(TypographyTokens.headline(16))
                            .foregroundStyle(ColorTokens.Kid.ink)
                        Text("Практик × \(entry.timesPracticed)")
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(entry.lastScore)")
                            .font(TypographyTokens.title(18))
                            .foregroundStyle(ColorTokens.Brand.primary)
                        Text("балл")
                            .font(TypographyTokens.caption(10))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Звук \(entry.sound), \(entry.timesPracticed) раз, \(entry.lastScore) баллов"))
        .accessibilityAddTraits(.isButton)
    }

    private var cta: some View {
        HSButton(
            String(localized: "soundJournal.cta.action"),
            style: .primary,
            size: .large,
            icon: "checkmark"
        ) {
            hapticService.notification(.success)
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview("SoundJournalKid — Light") {
    SoundJournalKidView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("SoundJournalKid — Dark") {
    SoundJournalKidView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
