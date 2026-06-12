import SwiftUI

// MARK: - RedeemInviteView
//
// Parent-circuit sheet «Присоединиться к семье». Приглашённый вводит
// 6-символьный код и применяет приглашение через FamilyInviteService.
// redeemerUid берётся из AuthService; без входа показывается CTA «Войти».
//
// Результат: роль + успех. Ошибки (consumed / expired / notFound) —
// дружелюбными русскими сообщениями.
//
// VIP: View → Interactor → Presenter → ViewModel (@Observable).

struct RedeemInviteView: View {

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - VIP

    @State private var viewModel = RedeemInviteViewModel()
    @State private var interactor: RedeemInviteInteractor?
    @State private var presenter: RedeemInvitePresenter?
    @State private var router: FamilyInviteRouter?

    @FocusState private var codeFieldFocused: Bool

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SpacingTokens.sectionGap) {
                    if viewModel.didSucceed {
                        successSection
                    } else {
                        headerSection
                        codeEntrySection
                        if let message = viewModel.errorMessage {
                            errorBanner(message)
                        }
                        if viewModel.requiresSignIn {
                            signInButton
                        } else {
                            joinButton
                        }
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp4)
                .padding(.bottom, SpacingTokens.sp10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(backgroundLayer.ignoresSafeArea())
            .navigationTitle(String(localized: "familyInvite.redeem.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.done")) { dismiss() }
                        .font(TypographyTokens.body(16).weight(.semibold))
                        .foregroundStyle(ColorTokens.Brand.primary)
                }
            }
        }
        .task { bootstrap() }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            ColorTokens.Parent.bg
            HSMeshGradientBackground(palette: .calm, animated: !reduceMotion)
                .blendMode(.softLight)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center, spacing: SpacingTokens.sp3) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                Text(String(localized: "familyInvite.redeem.heading"))
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(String(localized: "familyInvite.redeem.subheading"))
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: SpacingTokens.sp1)
            LyalyaMascotView(state: .waving, size: 64)
                .opacity(colorScheme == .dark ? 0.92 : 1.0)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Code entry

    private var codeEntrySection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            Text(String(localized: "familyInvite.redeem.codeLabel"))
                .font(TypographyTokens.caption(13).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
            TextField(
                String(localized: "familyInvite.redeem.codePlaceholder"),
                text: $viewModel.enteredCode
            )
            .font(TypographyTokens.mono(28).weight(.bold))
            .tracking(8)
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled(true)
            .keyboardType(.asciiCapable)
            .submitLabel(.go)
            .focused($codeFieldFocused)
            .foregroundStyle(ColorTokens.Parent.ink)
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.horizontal, SpacingTokens.sp4)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Parent.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .strokeBorder(
                        codeFieldFocused ? ColorTokens.Brand.primary : ColorTokens.Parent.line,
                        lineWidth: codeFieldFocused ? 2 : 1
                    )
            )
            .onSubmit {
                if viewModel.isCodeComplete { Task { await redeem() } }
            }
            .accessibilityLabel(String(localized: "familyInvite.redeem.codeLabel"))
            .accessibilityHint(String(localized: "familyInvite.redeem.codeField.hint"))
            Text(String(localized: "familyInvite.redeem.codeHelp"))
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Parent.inkSoft)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear { codeFieldFocused = true }
    }

    private var joinButton: some View {
        HSButton(
            String(localized: "familyInvite.redeem.cta"),
            style: .primary,
            size: .large,
            icon: "person.crop.circle.badge.plus",
            isLoading: viewModel.isRedeeming
        ) {
            codeFieldFocused = false
            Task { await redeem() }
        }
        .disabled(!viewModel.isCodeComplete || viewModel.isRedeeming)
        .accessibilityHint(String(localized: "familyInvite.redeem.cta.hint"))
    }

    private var signInButton: some View {
        HSButton(
            String(localized: "familyInvite.redeem.signInCta"),
            style: .primary,
            size: .large,
            icon: "person.fill"
        ) {
            router?.routeToSignIn()
            dismiss()
        }
        .accessibilityHint(String(localized: "familyInvite.redeem.signInCta.hint"))
    }

    // MARK: - Success

    private var successSection: some View {
        VStack(spacing: SpacingTokens.sp5) {
            LyalyaMascotView(state: .celebrating, size: 120)
                .accessibilityHidden(true)
            Text(String(localized: "familyInvite.redeem.success.title"))
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Parent.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(viewModel.successText)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Parent.inkSoft)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Text(String(localized: "familyInvite.redeem.success.note"))
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, SpacingTokens.sp4)
            HSButton(
                String(localized: "common.done"),
                style: .primary,
                size: .large,
                icon: "checkmark"
            ) {
                dismiss()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SpacingTokens.sp8)
    }

    // MARK: - Error banner

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.sp2) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ColorTokens.Semantic.error)
                .accessibilityHidden(true)
            Text(message)
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Parent.ink)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .fill(ColorTokens.Semantic.errorBg)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - VIP wiring

    private func bootstrap() {
        guard interactor == nil else { return }
        let presenter = RedeemInvitePresenter()
        presenter.viewModel = viewModel
        let interactor = RedeemInviteInteractor(
            inviteService: container.familyInviteService,
            authService: container.authService,
            membershipStore: container.familyMembershipStore
        )
        interactor.presenter = presenter
        self.presenter = presenter
        self.interactor = interactor
        self.router = FamilyInviteRouter(coordinator: coordinator)
    }

    private func redeem() async {
        await interactor?.redeem(
            FamilyInvite.Redeem.Request(shortCode: viewModel.enteredCode)
        )
    }
}

// MARK: - Preview

#Preview("Redeem Invite") {
    RedeemInviteView()
        .environment(AppContainer.preview())
        .environment(AppCoordinator())
}
