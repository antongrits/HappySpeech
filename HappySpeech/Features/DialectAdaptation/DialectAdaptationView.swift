import OSLog
import SwiftUI

// MARK: - DialectAdaptationViewModelHolder

@MainActor
@Observable
final class DialectAdaptationViewModelHolder: DialectAdaptationDisplayLogic {

    var loadVM: DialectAdaptationModels.Load.ViewModel?
    var selectVM: DialectAdaptationModels.Select.ViewModel?
    var resetVM: DialectAdaptationModels.Reset.ViewModel?
    var showToast: Bool = false

    func displayLoad(viewModel: DialectAdaptationModels.Load.ViewModel) async {
        self.loadVM = viewModel
    }

    func displaySelect(viewModel: DialectAdaptationModels.Select.ViewModel) async {
        self.selectVM = viewModel
        self.showToast = true
    }

    func displayReset(viewModel: DialectAdaptationModels.Reset.ViewModel) async {
        self.resetVM = viewModel
        self.showToast = true
    }
}

// MARK: - DialectAdaptationView (Clean Swift: View)
//
// Block R.1 v18 — экран выбора регионального диалекта.
//
// Layout (sheet, presentationDetent .large):
//   1. Hero header — текущий диалект + дата применения
//   2. Описание-introduction (логопедическая методология)
//   3. List 5 dialect cards (radio-style selection)
//   4. CTA «Сбросить к стандарту» (только если выбран не default)
//
// Accessibility:
//   • VoiceOver: каждая карточка диалекта = «Диалект <name>, выбран/доступен»
//   • Dynamic Type: scaledFont, lineLimit(nil)
//   • Reduced Motion: убираем shimmer/glow
//   • Touch targets ≥56pt (parent contour, accessible)

struct DialectAdaptationView: View {

    let childId: String

    @State private var holder = DialectAdaptationViewModelHolder()
    @State private var interactor: DialectAdaptationInteractor?
    @State private var presenter: DialectAdaptationPresenter?
    @State private var router: DialectAdaptationRouter?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "DialectAdaptation.View")

    init(childId: String) {
        self.childId = childId
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SpacingTokens.sp5) {
                    if let viewModel = holder.loadVM {
                        heroSection(viewModel: viewModel)
                        introSection
                        dialectsList(viewModel: viewModel)
                        if viewModel.currentDialectId != RegionalDialect.default.id {
                            resetSection
                        }
                        footerSection
                    } else {
                        loadingSection
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.vertical, SpacingTokens.sp4)
            }
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle(Text("dialect.screen.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                    .accessibilityLabel(Text("dialect.close.a11y"))
                }
            }
            .overlay(alignment: .top) {
                if holder.showToast,
                   let toast = holder.selectVM?.toastMessage ?? holder.resetVM?.toastMessage {
                    toastBanner(text: toast)
                        .padding(.top, SpacingTokens.sp2)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.4), value: holder.showToast)
        }
        .environment(\.circuitContext, .parent)
        .task {
            await setupAndLoad()
        }
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            // E v21: 3D Ляля в loading state DialectAdaptation.
            LyalyaHeroView(state: .happy, mood: 0.6, size: 110)
                .accessibilityHidden(true)
            ProgressView()
                .controlSize(.large)
        }
        .padding(.top, SpacingTokens.sp10)
    }

    // MARK: - Hero

    @ViewBuilder
    private func heroSection(viewModel: DialectAdaptationModels.Load.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp3) {
            // E v21: 3D Ляля hero на DialectAdaptation (требование пользователя).
            LyalyaHeroView(state: .thinking, mood: 0.6, size: 160)
                .frame(height: 160)
                .accessibilityHidden(true)

            Text("dialect.hero.title")
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Parent.ink)
                .multilineTextAlignment(.center)

            Text(viewModel.currentDialectTitle)
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Parent.accent)
                .multilineTextAlignment(.center)

            if let appliedText = viewModel.appliedAtText {
                Text(appliedText)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.sp5)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Parent.surface)
                .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String(
            format: String(localized: "dialect.hero.a11y"),
            viewModel.currentDialectTitle
        )))
    }

    // MARK: - Intro (методология)

    private var introSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "info.circle")
                    .font(.body)
                    .foregroundStyle(ColorTokens.Parent.accent)
                    .accessibilityHidden(true)
                Text("dialect.intro.title")
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Parent.ink)
            }

            Text("dialect.intro.body")
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SpacingTokens.sp4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .fill(ColorTokens.Parent.accent.opacity(0.08))
        )
    }

    // MARK: - Dialects list

    @ViewBuilder
    private func dialectsList(viewModel: DialectAdaptationModels.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            Text("dialect.list.title")
                .font(TypographyTokens.headline(17))
                .foregroundStyle(ColorTokens.Parent.ink)
                .padding(.leading, SpacingTokens.sp1)

            VStack(spacing: SpacingTokens.sp2) {
                ForEach(viewModel.dialects) { row in
                    dialectCard(row: row)
                }
            }
        }
    }

    @ViewBuilder
    private func dialectCard(row: DialectAdaptationModels.Load.DialectRow) -> some View {
        Button {
            Task { await select(dialectId: row.id) }
        } label: {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                // Icon
                Image(systemName: row.symbolName)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(
                        row.isSelected ? ColorTokens.Parent.accent : ColorTokens.Parent.inkSoft
                    )
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(
                                row.isSelected
                                    ? ColorTokens.Parent.accent.opacity(0.15)
                                    : ColorTokens.Parent.bgDeep
                            )
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                    HStack {
                        Text(row.title)
                            .font(TypographyTokens.headline(17))
                            .foregroundStyle(ColorTokens.Parent.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Spacer(minLength: 0)

                        if row.isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(ColorTokens.Parent.accent)
                                .accessibilityHidden(true)
                        }
                    }

                    Text(row.description)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if !row.markers.isEmpty {
                        HStack(spacing: SpacingTokens.sp1) {
                            ForEach(row.markers.prefix(3), id: \.self) { marker in
                                Text(marker)
                                    .font(.caption2)
                                    .foregroundStyle(ColorTokens.Parent.accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(ColorTokens.Parent.accent.opacity(0.1))
                                    )
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .padding(SpacingTokens.sp4)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Parent.surface)
                    .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .strokeBorder(
                        row.isSelected
                            ? ColorTokens.Parent.accent
                            : ColorTokens.Parent.line,
                        lineWidth: row.isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(row.accessibilityLabel))
        .accessibilityAddTraits(row.isSelected ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: - Reset CTA

    private var resetSection: some View {
        Button {
            Task { await reset() }
        } label: {
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "arrow.counterclockwise.circle")
                    .accessibilityHidden(true)
                Text("dialect.reset.cta")
                    .font(TypographyTokens.callout())
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(ColorTokens.Parent.accent)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, SpacingTokens.sp4)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.button)
                    .fill(ColorTokens.Parent.accent.opacity(0.1))
            )
        }
        .accessibilityHint(Text("dialect.reset.hint"))
    }

    // MARK: - Footer

    private var footerSection: some View {
        Text("dialect.footer.note")
            .font(TypographyTokens.caption(12))
            .foregroundStyle(ColorTokens.Parent.inkMuted)
            .lineLimit(nil)
            .multilineTextAlignment(.center)
            .padding(.horizontal, SpacingTokens.sp4)
            .padding(.top, SpacingTokens.sp2)
    }

    // MARK: - Toast

    @ViewBuilder
    private func toastBanner(text: String) -> some View {
        Text(text)
            .font(TypographyTokens.caption(13))
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .padding(.horizontal, SpacingTokens.sp4)
            .padding(.vertical, SpacingTokens.sp2)
            .background(
                Capsule().fill(ColorTokens.Parent.accent)
            )
            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
            .task {
                try? await Task.sleep(for: .seconds(2.5))
                holder.showToast = false
            }
    }

    // MARK: - Wiring

    private func setupAndLoad() async {
        if interactor == nil {
            let presenter = DialectAdaptationPresenter(displayLogic: holder)
            let interactor = DialectAdaptationInteractor(
                childId: childId,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = DialectAdaptationRouter(dismissAction: { dismiss() })
        }

        await interactor?.load(request: .init(childId: childId))
    }

    private func select(dialectId: String) async {
        await interactor?.select(request: .init(
            childId: childId,
            dialectId: dialectId,
            now: Date()
        ))
        await interactor?.load(request: .init(childId: childId))
    }

    private func reset() async {
        await interactor?.reset(request: .init(childId: childId))
        await interactor?.load(request: .init(childId: childId))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("DialectAdaptation / loaded") {
    DialectAdaptationView(childId: "preview-child")
        .environment(AppContainer.preview())
}
#endif
