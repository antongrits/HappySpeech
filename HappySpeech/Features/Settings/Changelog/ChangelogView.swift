import OSLog
import SwiftUI

// MARK: - ChangelogView
//
// Экран "Что нового" — рендерит changelog.md через HSMarkdownView (Down).
// Открывается из Settings → "О приложении" → "Что нового".
//
// Нет зависимостей на Services/Data: чисто ресурсный файл из Bundle.

struct ChangelogView: View {

    // MARK: - State

    @State private var markdownContent: String?
    @State private var loadFailed = false

    private let logger = Logger(subsystem: "ru.happyspeech", category: "ChangelogView")

    // MARK: - Body

    var body: some View {
        ScrollView {
            Group {
                if let content = markdownContent {
                    HSMarkdownView(markdown: content)
                        .padding(.horizontal, SpacingTokens.screenEdge)
                        .padding(.vertical, SpacingTokens.large)
                } else if loadFailed {
                    VStack(spacing: SpacingTokens.regular) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(TypographyTokens.display(32))
                            .foregroundStyle(ColorTokens.Semantic.warning)
                        Text(String(localized: "changelog.loadError"))
                            .font(TypographyTokens.body(15))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, SpacingTokens.xLarge)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, SpacingTokens.xLarge)
                        .tint(ColorTokens.Brand.primary)
                }
            }
        }
        .background(ColorTokens.Parent.bg.ignoresSafeArea())
        .navigationTitle(String(localized: "settings.about.whatsNew"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadChangelog() }
        .accessibilityLabel(String(localized: "settings.about.whatsNew"))
    }

    // MARK: - Private

    private func loadChangelog() async {
        guard let url = Bundle.main.url(forResource: "changelog", withExtension: "md") else {
            logger.error("ChangelogView: changelog.md not found in Bundle")
            loadFailed = true
            return
        }
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            markdownContent = content
        } catch {
            logger.error("ChangelogView: failed to read changelog.md — \(error.localizedDescription, privacy: .public)")
            loadFailed = true
        }
    }
}

// MARK: - Preview

#Preview("Changelog") {
    NavigationStack {
        ChangelogView()
    }
    .environment(AppContainer.preview())
}
