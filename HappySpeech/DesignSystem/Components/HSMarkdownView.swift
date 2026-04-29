import Down
import OSLog
import SwiftUI
import UIKit

// MARK: - HSMarkdownView

/// SwiftUI компонент для рендеринга Markdown через Down 0.11+.
///
/// Применение:
/// - In-app Privacy Policy / Terms (не WebView)
/// - FAQ / Help контент
/// - Changelog внутри приложения
///
/// Пример:
/// ```swift
/// HSMarkdownView(markdown: "## Привет\nЭто **жирный** текст.")
/// ```
public struct HSMarkdownView: View {

    private let markdown: String

    public init(markdown: String) {
        self.markdown = markdown
    }

    public var body: some View {
        HSMarkdownRepresentable(markdown: markdown)
    }
}

// MARK: - UIViewRepresentable

private struct HSMarkdownRepresentable: UIViewRepresentable {

    let markdown: String

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "HSMarkdownView")

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentHuggingPriority(.defaultLow, for: .vertical)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        do {
            let down = Down(markdownString: markdown)
            let config = DownStylerConfiguration(fonts: makeFontCollection(), colors: makeColorCollection())
            let styler = DownStyler(configuration: config)
            let result = try down.toAttributedString(.default, styler: styler)
            textView.attributedText = result
        } catch {
            Self.logger.error("HSMarkdownView: failed to render markdown — \(error.localizedDescription, privacy: .public)")
            textView.text = markdown
        }
    }

    // MARK: - Style configuration

    private func makeFontCollection() -> StaticFontCollection {
        StaticFontCollection(
            heading1: .systemFont(ofSize: 24, weight: .bold),
            heading2: .systemFont(ofSize: 20, weight: .semibold),
            heading3: .systemFont(ofSize: 17, weight: .semibold),
            heading4: .systemFont(ofSize: 15, weight: .semibold),
            heading5: .systemFont(ofSize: 13, weight: .semibold),
            heading6: .systemFont(ofSize: 12, weight: .semibold),
            body: .systemFont(ofSize: 15, weight: .regular),
            code: .monospacedSystemFont(ofSize: 13, weight: .regular),
            listItemPrefix: .monospacedSystemFont(ofSize: 15, weight: .regular)
        )
    }

    private func makeColorCollection() -> StaticColorCollection {
        let isDark = UITraitCollection.current.userInterfaceStyle == .dark
        let ink: UIColor = isDark ? .white : .label
        let subtle: UIColor = isDark ? UIColor.white.withAlphaComponent(0.55) : UIColor.black.withAlphaComponent(0.45)
        let accent: UIColor = UIColor(ColorTokens.Brand.primary)
        let codeBg: UIColor = isDark
            ? UIColor.white.withAlphaComponent(0.07)
            : UIColor.black.withAlphaComponent(0.05)
        return StaticColorCollection(
            heading1: ink,
            heading2: ink,
            heading3: ink,
            heading4: ink,
            heading5: ink,
            heading6: ink,
            body: ink,
            code: ink,
            link: accent,
            quote: subtle,
            quoteStripe: accent,
            thematicBreak: subtle,
            listItemPrefix: subtle,
            codeBlockBackground: codeBg
        )
    }
}

// MARK: - Preview

#Preview("HSMarkdownView") {
    ScrollView {
        HSMarkdownView(markdown: """
        # Политика конфиденциальности

        Последнее обновление: **29 апреля 2026**

        ## Какие данные собираются

        HappySpeech не собирает персональные данные детей в интернет.
        Все данные хранятся **локально** на устройстве.

        ## Аудиозаписи

        Аудио обрабатывается исключительно на устройстве через модель WhisperKit.
        Записи `не передаются` на серверы.

        ## Контакт

        По вопросам конфиденциальности пишите: support@happyspeech.ru
        """)
        .padding()
    }
}
