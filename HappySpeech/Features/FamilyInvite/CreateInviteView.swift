import SwiftUI

// MARK: - CreateInviteView
//
// Parent-circuit sheet «Пригласить близкого». Родитель-primary выбирает роль
// (со-родитель / наблюдатель), генерирует 6-символьный код через
// FamilyInviteService и делится приглашением (ShareLink).
//
// VIP: View → Interactor → Presenter → ViewModel (@Observable). Реальный
// сервис из DI; никаких заглушек.

struct CreateInviteView: View {

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - VIP

    @State private var viewModel = CreateInviteViewModel()
    @State private var interactor: CreateInviteInteractor?
    @State private var presenter: CreateInvitePresenter?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SpacingTokens.sectionGap) {
                    headerSection
                    if viewModel.hasCode {
                        codeSection
                    } else {
                        roleSection
                        createButton
                    }
                    if let message = viewModel.errorMessage {
                        errorBanner(message)
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp4)
                .padding(.bottom, SpacingTokens.sp10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(backgroundLayer.ignoresSafeArea())
            .navigationTitle(String(localized: "familyInvite.create.title"))
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
                Text(String(localized: "familyInvite.create.heading"))
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(String(localized: "familyInvite.create.subheading"))
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

    // MARK: - Role picker

    private var roleSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            Text(String(localized: "familyInvite.create.roleSection"))
                .font(TypographyTokens.caption(13).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
            ForEach(FamilyInvite.InvitableRole.allCases) { role in
                roleCard(role)
            }
        }
    }

    private func roleCard(_ role: FamilyInvite.InvitableRole) -> some View {
        let isSelected = viewModel.selectedRole == role
        return Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) {
                viewModel.selectedRole = role
            }
        } label: {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                Image(systemName: role.iconName)
                    .font(TypographyTokens.headline(20))
                    .foregroundStyle(isSelected ? ColorTokens.Brand.primary : ColorTokens.Parent.inkMuted)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.sm)
                            .fill(isSelected ? ColorTokens.Brand.primaryLo.opacity(0.5)
                                  : ColorTokens.Parent.surface)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                    Text(role.title)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(role.subtitle)
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Parent.inkSoft)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: SpacingTokens.sp1)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(TypographyTokens.headline(20))
                    .foregroundStyle(isSelected ? ColorTokens.Brand.primary : ColorTokens.Parent.line)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.sp4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Parent.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .strokeBorder(
                        isSelected ? ColorTokens.Brand.primary : ColorTokens.Parent.line,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(role.title). \(role.subtitle)")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private var createButton: some View {
        HSButton(
            String(localized: "familyInvite.create.cta"),
            style: .primary,
            size: .large,
            icon: "qrcode",
            isLoading: viewModel.isCreating
        ) {
            Task { await createInvite() }
        }
        .disabled(viewModel.isCreating)
        .accessibilityHint(String(localized: "familyInvite.create.cta.hint"))
    }

    // MARK: - Generated code

    private var codeSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
            VStack(spacing: SpacingTokens.sp3) {
                Text(String(localized: "familyInvite.create.codeCaption"))
                    .font(TypographyTokens.caption(13).weight(.semibold))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
                codeBoxes(viewModel.shortCode ?? "")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(codeAccessibilityLabel)
                Text(viewModel.expiryText)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .lineLimit(nil)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp6)
            .padding(.horizontal, SpacingTokens.sp4)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(
                        LinearGradient(
                            colors: [
                                ColorTokens.Brand.primaryLo.opacity(colorScheme == .dark ? 0.22 : 0.40),
                                ColorTokens.Brand.butter.opacity(colorScheme == .dark ? 0.16 : 0.32)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .strokeBorder(ColorTokens.Brand.gold.opacity(0.4), lineWidth: 1)
            )

            if let code = viewModel.shortCode, let url = viewModel.shareURL {
                ShareLink(
                    item: url,
                    subject: Text(String(localized: "familyInvite.create.shareSubject")),
                    message: Text(viewModel.shareMessage(code: code))
                ) {
                    Label {
                        Text(String(localized: "familyInvite.create.shareButton"))
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .font(TypographyTokens.cta())
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.button)
                            .fill(ColorTokens.Brand.primary)
                    )
                }
                .accessibilityHint(String(localized: "familyInvite.create.shareButton.hint"))
            }

            HSButton(
                String(localized: "familyInvite.create.newCode"),
                style: .ghost,
                size: .medium,
                icon: "arrow.clockwise"
            ) {
                resetCode()
            }
            .frame(maxWidth: .infinity)
        }
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

    // MARK: - Code boxes

    /// Код-приглашение в виде отдельных символов-плиток (как в дизайн-эталоне).
    private func codeBoxes(_ code: String) -> some View {
        let chars = Array(code)
        return HStack(spacing: SpacingTokens.sp1) {
            ForEach(Array(chars.enumerated()), id: \.offset) { _, ch in
                Text(String(ch))
                    .font(TypographyTokens.mono(26).weight(.bold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(width: 40, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(ColorTokens.Parent.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(ColorTokens.Brand.primaryLo, lineWidth: 1)
                    )
            }
        }
        .minimumScaleFactor(0.6)
    }

    // MARK: - Accessibility

    private var codeAccessibilityLabel: String {
        let spelled = (viewModel.shortCode ?? "").map(String.init).joined(separator: " ")
        return String(format: String(localized: "familyInvite.create.code.a11y"), spelled)
    }

    // MARK: - VIP wiring

    private func bootstrap() {
        guard interactor == nil else { return }
        let presenter = CreateInvitePresenter()
        presenter.viewModel = viewModel
        let interactor = CreateInviteInteractor(inviteService: container.familyInviteService)
        interactor.presenter = presenter
        self.presenter = presenter
        self.interactor = interactor
    }

    private func createInvite() async {
        await interactor?.createInvite(
            FamilyInvite.Create.Request(
                role: viewModel.selectedRole,
                durationHours: FamilyInvite.defaultDurationHours
            )
        )
    }

    private func resetCode() {
        viewModel.shortCode = nil
        viewModel.expiresAt = nil
        viewModel.shareURL = nil
        viewModel.issuedRole = nil
        viewModel.errorMessage = nil
    }
}

// MARK: - Preview

#Preview("Create Invite") {
    CreateInviteView()
        .environment(AppContainer.preview())
}
