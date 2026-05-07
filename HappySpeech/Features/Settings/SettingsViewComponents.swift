import SwiftUI

// MARK: - SettingsViewComponents
//
// Подкомпоненты для `SettingsView`. Все структуры — `internal` внутри
// модуля, чтобы быть доступными из `SettingsView.swift`.
// Секции и биндинги SettingsView вынесены в `SettingsViewSections.swift`.

// MARK: - SettingsProfileEditor

struct SettingsProfileEditor: View {

    @Environment(\.dismiss) private var dismiss

    let availableAvatars: [String]
    let availableAges: [Int]

    @State private var name: String
    @State private var age: Int
    @State private var avatar: String

    private let onSave: (String, Int, String) -> Void

    init(
        name: String,
        age: Int,
        avatar: String,
        availableAvatars: [String],
        availableAges: [Int],
        onSave: @escaping (String, Int, String) -> Void
    ) {
        self._name = State(initialValue: name)
        self._age = State(initialValue: age)
        self._avatar = State(initialValue: avatar)
        self.availableAvatars = availableAvatars
        self.availableAges = availableAges
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.large) {
                    avatarPicker
                    nameField
                    agePicker
                    Spacer(minLength: SpacingTokens.large)
                    HSButton(
                        String(localized: "settings.profile.save"),
                        style: .primary,
                        size: .large,
                        icon: "checkmark"
                    ) {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(
                            trimmed.isEmpty ? String(localized: "settings.profile.defaultName") : trimmed,
                            age,
                            avatar
                        )
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.vertical, SpacingTokens.large)
            }
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle(String(localized: "settings.profile.editorTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "settings.profile.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var avatarPicker: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
            Text(String(localized: "settings.profile.avatarHeader"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.tiny), count: 6),
                spacing: SpacingTokens.tiny
            ) {
                ForEach(availableAvatars, id: \.self) { item in
                    Button {
                        avatar = item
                    } label: {
                        Image(item)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(SpacingTokens.micro)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle().fill(
                                    avatar == item
                                        ? ColorTokens.Brand.primary.opacity(0.18)
                                        : ColorTokens.Parent.surface
                                )
                            )
                            .overlay(
                                Circle().strokeBorder(
                                    avatar == item ? ColorTokens.Brand.primary : ColorTokens.Parent.line,
                                    lineWidth: avatar == item ? 2 : 1
                                )
                            )
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(
                        format: String(localized: "settings.a11y.avatar"),
                        item
                    ))
                    .accessibilityAddTraits(avatar == item ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
            Text(String(localized: "settings.profile.nameHeader"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
            TextField(
                String(localized: "settings.profile.namePlaceholder"),
                text: $name
            )
            .textFieldStyle(.plain)
            .font(TypographyTokens.body(16))
            .padding(SpacingTokens.regular)
            .frame(minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .fill(ColorTokens.Parent.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .strokeBorder(ColorTokens.Parent.line, lineWidth: 1)
            )
        }
    }

    private var agePicker: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
            Text(String(localized: "settings.profile.ageHeader"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
            Picker(
                String(localized: "settings.profile.ageHeader"),
                selection: $age
            ) {
                ForEach(availableAges, id: \.self) { value in
                    Text(String(
                        format: String(localized: "settings.profile.ageOptionPattern"),
                        value
                    )).tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxHeight: 140)
        }
    }
}

// MARK: - SettingsSpecialistConnectSheet

struct SettingsSpecialistConnectSheet: View {

    @Environment(\.dismiss) private var dismiss
    @State private var code: String
    private let initialCode: String
    private let isConnected: Bool
    private let onConnect: (String) -> Void

    init(
        initialCode: String,
        isConnected: Bool,
        onConnect: @escaping (String) -> Void
    ) {
        self.initialCode = initialCode
        self.isConnected = isConnected
        self._code = State(initialValue: initialCode)
        self.onConnect = onConnect
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: SpacingTokens.large) {
                VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                    Text(String(localized: "settings.specialist.sheetTitle"))
                        .font(TypographyTokens.headline(20))
                        .foregroundStyle(ColorTokens.Parent.ink)
                    Text(String(localized: "settings.specialist.sheetSubtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(nil)
                }

                TextField(
                    String(localized: "settings.specialist.codePlaceholder"),
                    text: $code
                )
                .keyboardType(.numberPad)
                .font(TypographyTokens.mono(20))
                .padding(SpacingTokens.regular)
                .frame(minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.md)
                        .fill(ColorTokens.Parent.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.md)
                        .strokeBorder(ColorTokens.Parent.line, lineWidth: 1)
                )
                .accessibilityLabel(String(localized: "settings.a11y.specialistCode"))

                if isConnected {
                    HStack(spacing: SpacingTokens.tiny) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ColorTokens.Semantic.success)
                        Text(String(localized: "settings.specialist.connected"))
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Semantic.success)
                    }
                }

                Spacer()

                HSButton(
                    String(localized: "settings.specialist.connectButton"),
                    style: .primary,
                    size: .large,
                    icon: "link"
                ) {
                    onConnect(code)
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.vertical, SpacingTokens.large)
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle(String(localized: "settings.specialist.navTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "settings.profile.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - SettingsLegalSheet

struct SettingsLegalSheet: View {

    @Environment(\.dismiss) private var dismiss
    let title: String
    let bodyText: String

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(bodyText)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineSpacing(TypographyTokens.LineSpacing.normal)
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.vertical, SpacingTokens.large)
            }
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "settings.profile.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - ModelPackRow

struct ModelPackRow: View {

    let item: ModelPackRowVM
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SpacingTokens.regular) {
                ZStack {
                    Circle()
                        .fill(iconBackground)
                        .frame(width: 38, height: 38)
                    Image(systemName: iconName)
                        .font(TypographyTokens.body(16))
                        .foregroundStyle(iconForeground)
                }

                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    HStack(spacing: SpacingTokens.tiny) {
                        Text(item.title)
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Parent.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        if item.isActive {
                            Text(String(localized: "settings.models.badge.active"))
                                .font(TypographyTokens.caption(10).weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(ColorTokens.Semantic.success)
                                )
                        }
                    }
                    Text(item.subtitle)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    if item.isDownloading {
                        ProgressView(value: max(0.02, item.progress))
                            .tint(ColorTokens.Brand.primary)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(item.sizeText)
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                }
                Spacer()
                Text(item.actionTitle)
                    .font(TypographyTokens.caption(12).weight(.semibold))
                    .foregroundStyle(actionColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.title)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(item.canDelete
                           ? String(localized: "settings.a11y.modelPack.delete.hint")
                           : (item.isInstalled
                              ? String(localized: "settings.a11y.modelPack.active.hint")
                              : String(localized: "settings.a11y.modelPack.download.hint")))
    }

    private var iconName: String {
        item.id.hasPrefix("llm.") ? "brain.head.profile" : "waveform"
    }

    private var iconBackground: Color {
        if item.isActive { return ColorTokens.Semantic.success.opacity(0.15) }
        if item.isInstalled { return ColorTokens.Brand.primary.opacity(0.15) }
        return ColorTokens.Parent.line.opacity(0.6)
    }

    private var iconForeground: Color {
        if item.isActive { return ColorTokens.Semantic.success }
        if item.isInstalled { return ColorTokens.Brand.primary }
        return ColorTokens.Parent.inkMuted
    }

    private var actionColor: Color {
        if item.isActive { return ColorTokens.Semantic.success }
        if item.isInstalled { return ColorTokens.Semantic.error }
        if item.isDownloading { return ColorTokens.Parent.inkMuted }
        return ColorTokens.Brand.primary
    }

    private var accessibilityValue: String {
        if item.isActive { return String(localized: "settings.a11y.modelPack.active") }
        if item.isDownloading {
            let percent = Int(item.progress * 100)
            return String(format: String(localized: "settings.a11y.modelPack.progress"), percent)
        }
        if item.isInstalled { return String(localized: "settings.a11y.modelPack.installed") }
        return item.sizeText
    }
}

// MARK: - SettingsLicensesListSheet

struct SettingsLicensesListSheet: View {

    @Environment(\.dismiss) private var dismiss
    let licenses: [OpenSourceLicenseVM]
    let onSelect: (OpenSourceLicenseVM) -> Void

    var body: some View {
        NavigationStack {
            List(licenses) { license in
                Button {
                    onSelect(license)
                } label: {
                    VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                        Text(license.title)
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Parent.ink)
                        Text(license.subtitle)
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityHint(String(localized: "settings.a11y.licenseRow.hint"))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(ColorTokens.Parent.bg)
            .navigationTitle(String(localized: "settings.about.licenses"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "settings.profile.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - SettingsLicenseDetailSheet

struct SettingsLicenseDetailSheet: View {

    @Environment(\.dismiss) private var dismiss
    let license: OpenSourceLicenseVM
    let onOpenURL: (URL) -> Void

    init(license: OpenSourceLicenseVM, onOpenURL: @escaping (URL) -> Void) {
        self.license = license
        self.onOpenURL = onOpenURL
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.regular) {
                    VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                        Text(license.title)
                            .font(TypographyTokens.headline(20))
                            .foregroundStyle(ColorTokens.Parent.ink)
                        Text(license.subtitle)
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }

                    if let url = license.url {
                        Button {
                            onOpenURL(url)
                        } label: {
                            Label {
                                Text(String(localized: "settings.licenses.openRepo"))
                                    .font(TypographyTokens.body(14))
                            } icon: {
                                Image(systemName: "arrow.up.right.square")
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .accessibilityLabel(String(localized: "settings.licenses.openRepo"))
                        .accessibilityHint(String(localized: "parental_gate.external_link_hint"))
                    }

                    Text(license.bodyText)
                        .font(TypographyTokens.mono(12))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineSpacing(TypographyTokens.LineSpacing.normal)
                        .padding(SpacingTokens.regular)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.md)
                                .fill(ColorTokens.Parent.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: RadiusTokens.md)
                                .strokeBorder(ColorTokens.Parent.line, lineWidth: 1)
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.vertical, SpacingTokens.large)
            }
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle(license.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "settings.profile.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - SettingsShareSheet

struct SettingsShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
