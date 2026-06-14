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
                    // P1.1: connected badge → Brand.gold
                    HStack(spacing: SpacingTokens.tiny) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ColorTokens.Brand.gold)
                        Text(String(localized: "settings.specialist.connected"))
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Brand.gold)
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
