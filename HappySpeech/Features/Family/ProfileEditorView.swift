import SwiftUI

// MARK: - ProfileEditorView
//
// Sheet-модальный редактор профиля ребёнка.
// Позволяет изменить: имя, возраст, аватар (5 предустановок), тему (5 цветов).
// Вызывается через long-press на карточке ребёнка в FamilyHomeView.
//
// VIP: View → Interactor → Presenter → ViewModel (@Observable).

struct ProfileEditorView: View {

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss

    // MARK: - VIP

    @State private var viewModel = ProfileEditorViewModel()
    @State private var interactor: ProfileEditorInteractor?
    @State private var presenter: ProfileEditorPresenter?
    @State private var router: ProfileEditorRouter?

    // MARK: - Properties

    private let childId: String
    private let onSaved: (() -> Void)?

    init(childId: String, onSaved: (() -> Void)? = nil) {
        self.childId = childId
        self.onSaved = onSaved
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    content
                }
            }
            .navigationTitle(String(localized: "profile.editor.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .task { await bootstrap() }
        .onChange(of: viewModel.isSaved) { _, saved in
            if saved {
                onSaved?()
                dismiss()
            }
        }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.sectionGap) {
                // Avatar preview
                avatarPreviewSection

                // Avatar gallery
                avatarPickerSection

                // Theme picker
                themePickerSection

                // Name field
                nameSection

                // Age picker
                ageSection

                // Save button
                saveButton
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp8)
        }
    }

    // MARK: - Avatar Preview

    private var avatarPreviewSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ZStack {
                Circle()
                    .fill(viewModel.selectedThemeColor.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .shadow(color: viewModel.selectedThemeColor.opacity(0.3), radius: 12, y: 4)

                Text(viewModel.selectedAvatarEmoji)
                    .font(TypographyTokens.kidDisplay(52))
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: viewModel.selectedAvatarId)

            Text(viewModel.name.isEmpty ? String(localized: "profile.editor.name.placeholder") : viewModel.name)
                .font(TypographyTokens.headline(20))
                .foregroundStyle(ColorTokens.Parent.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.top, SpacingTokens.sp5)
    }

    // MARK: - Avatar Picker

    private var avatarPickerSection: some View {
        HSLiquidGlassCard(style: .primary) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
                sectionHeader(String(localized: "profile.editor.avatar"), icon: "face.smiling")

                HStack(spacing: SpacingTokens.sp4) {
                    ForEach(ProfileEditor.avatarPresets) { preset in
                        Button {
                            viewModel.selectedAvatarId = preset.id
                        } label: {
                            avatarCell(preset)
                        }
                        .accessibilityLabel(preset.localizedName)
                        .accessibilityAddTraits(viewModel.selectedAvatarId == preset.id ? .isSelected : [])
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func avatarCell(_ preset: ProfileEditor.AvatarPreset) -> some View {
        let isSelected = viewModel.selectedAvatarId == preset.id
        return ZStack {
            Circle()
                .fill(isSelected
                    ? viewModel.selectedThemeColor.opacity(0.25)
                    : ColorTokens.Parent.surface)
                .frame(width: 52, height: 52)
                .overlay(
                    Circle()
                        .strokeBorder(
                            isSelected ? viewModel.selectedThemeColor : Color.clear,
                            lineWidth: 2
                        )
                )

            Text(preset.emoji)
                .font(TypographyTokens.title(26))
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
    }

    // MARK: - Theme Picker

    private var themePickerSection: some View {
        HSLiquidGlassCard(style: .primary) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
                sectionHeader(String(localized: "profile.editor.theme"), icon: "paintpalette")

                HStack(spacing: SpacingTokens.sp3) {
                    ForEach(ProfileEditor.themePresets) { preset in
                        Button {
                            viewModel.selectedThemeId = preset.id
                        } label: {
                            themeCell(preset)
                        }
                        .accessibilityLabel(preset.localizedName)
                        .accessibilityAddTraits(viewModel.selectedThemeId == preset.id ? .isSelected : [])
                    }
                }
            }
        }
    }

    private func themeCell(_ preset: ProfileEditor.ThemePreset) -> some View {
        let isSelected = viewModel.selectedThemeId == preset.id
        return ZStack {
            Circle()
                .fill(preset.color)
                .frame(width: 40, height: 40)
                .shadow(color: preset.color.opacity(0.4), radius: 4, y: 2)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
    }

    // MARK: - Name Section

    private var nameSection: some View {
        HSLiquidGlassCard(style: .primary) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                sectionHeader(String(localized: "profile.editor.name"), icon: "textformat")

                TextField(String(localized: "profile.editor.name.placeholder"), text: $viewModel.name)
                    .font(TypographyTokens.body(17))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .textFieldStyle(.plain)
                    .padding(SpacingTokens.sp3)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.sm)
                            .fill(ColorTokens.Parent.surface)
                    )
                    .submitLabel(.done)
                    .accessibilityLabel(String(localized: "profile.editor.name"))
            }
        }
    }

    // MARK: - Age Section

    private var ageSection: some View {
        HSLiquidGlassCard(style: .primary) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                sectionHeader(String(localized: "profile.editor.age"), icon: "birthday.cake")

                HStack(spacing: SpacingTokens.sp4) {
                    ForEach(5...8, id: \.self) { ageValue in
                        Button {
                            viewModel.age = ageValue
                        } label: {
                            ageCell(ageValue)
                        }
                        .accessibilityLabel(String(format: String(localized: "child.age.label"), ageValue))
                        .accessibilityAddTraits(viewModel.age == ageValue ? .isSelected : [])
                    }
                    Spacer()
                }
            }
        }
    }

    private func ageCell(_ ageValue: Int) -> some View {
        let isSelected = viewModel.age == ageValue
        return Text("\(ageValue)")
            .font(TypographyTokens.headline(18))
            .foregroundStyle(isSelected ? .white : ColorTokens.Parent.ink)
            .frame(width: 44, height: 44)
            .background(
                Circle().fill(isSelected
                    ? viewModel.selectedThemeColor
                    : ColorTokens.Parent.surface)
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        HSButton(
            String(localized: "profile.editor.save"),
            style: .primary,
            isLoading: viewModel.isSaving
        ) {
            Task { await saveProfile() }
        }
        .disabled(viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty)
        .padding(.top, SpacingTokens.sp2)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(TypographyTokens.caption(12))
            .foregroundStyle(ColorTokens.Parent.inkMuted)
            .textCase(.uppercase)
            .tracking(0.8)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(String(localized: "action.cancel")) {
                dismiss()
            }
            .foregroundStyle(ColorTokens.Parent.accent)
        }
    }

    // MARK: - VIP Bootstrap

    private func bootstrap() async {
        if interactor == nil {
            let presenter = ProfileEditorPresenter()
            let interactor = ProfileEditorInteractor(childRepository: container.childRepository)
            let router = ProfileEditorRouter(coordinator: coordinator)
            presenter.viewModel = viewModel
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = router
        }
        await interactor?.load(ProfileEditor.LoadRequest(childId: childId))
    }

    private func saveProfile() async {
        await interactor?.save(ProfileEditor.SaveRequest(
            childId: viewModel.childId,
            name: viewModel.name,
            age: viewModel.age,
            avatarStyle: viewModel.selectedAvatarId,
            colorTheme: viewModel.selectedThemeId
        ))
    }
}

// MARK: - Preview

#Preview("Profile Editor") {
    ProfileEditorView(childId: "preview-child-1")
        .environment(AppContainer.preview())
        .environment(AppCoordinator())
}
