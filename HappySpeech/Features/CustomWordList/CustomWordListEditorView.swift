import SwiftUI

// MARK: - CustomWordListEditorView
//
// v31 Волна C Ф.4 — sheet редактора списка слов.
// v32+ — добавлена секция «Автоподбор слов» (G-04, паритет с Articulation Station).
//
// Принимает initialDraft и callback'и: onPreview / onAutoPick / onSave / onCancel.
// Локальное state управление держит черновик; запрос на preview/save/autoPick
// идёт наверх через замыкания.

struct CustomWordListEditorView: View {

    let initialDraft: WordListDraft
    let previewText: String?
    let previewCount: Int
    let errorMessage: String?
    let autoPickResult: CustomWordListModels.AutoPick.ViewModel?
    let isAutoPickLoading: Bool
    let onPreview: (WordListDraft) -> Void
    let onAutoPick: (AutoPickParams) -> Void
    let onSave: (WordListDraft) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var targetSound: String = "Р"
    @State private var words: [String] = [""]
    @FocusState private var focusedWordIndex: Int?

    // AutoPick state
    @State private var autoPickPosition: WordPosition = .any
    @State private var autoPickSyllables: SyllableRange = .all
    @State private var autoPickCount: Int = 10
    @State private var showAutoPickSection: Bool = false

    private var currentDraft: WordListDraft {
        WordListDraft(
            id: initialDraft.id,
            name: name,
            targetSound: targetSound,
            words: words
        )
    }

    private var currentAutoPickParams: AutoPickParams {
        AutoPickParams(
            targetSound: targetSound,
            position: autoPickPosition,
            syllableRange: autoPickSyllables,
            requestedCount: autoPickCount
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                soundSection
                autoPickSection
                wordsSection
                previewSection
                errorSection
            }
            .navigationTitle(Text("customWordList.editor.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onCancel()
                    } label: {
                        Text("customWordList.cancel")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSave(currentDraft)
                    } label: {
                        Text("customWordList.save")
                            .fontWeight(.semibold)
                    }
                    .accessibilityIdentifier("customWordList.editor.saveButton")
                }
            }
            .onAppear {
                name = initialDraft.name
                targetSound = initialDraft.targetSound
                words = initialDraft.words.isEmpty ? [""] : initialDraft.words
                onPreview(currentDraft)
            }
        }
        .environment(\.circuitContext, .specialist)
    }

    // MARK: - Name Section

    private var nameSection: some View {
        Section {
            TextField(
                String(localized: "customWordList.editor.name.placeholder"),
                text: $name
            )
            .accessibilityIdentifier("customWordList.editor.nameField")
            .onChange(of: name) { _, _ in
                onPreview(currentDraft)
            }
        } header: {
            Text("customWordList.editor.name")
        }
    }

    // MARK: - Sound Section

    private var soundSection: some View {
        Section {
            Picker(
                String(localized: "customWordList.editor.sound"),
                selection: $targetSound
            ) {
                ForEach(CustomWordListModels.availableSounds, id: \.self) { sound in
                    Text(sound).tag(sound)
                }
            }
            .accessibilityIdentifier("customWordList.editor.soundPicker")
            .onChange(of: targetSound) { _, _ in
                onPreview(currentDraft)
            }
        } header: {
            Text("customWordList.editor.sound")
        }
    }

    // MARK: - AutoPick Section

    private var autoPickSection: some View {
        Section {
            // Заголовок-кнопка раскрытия
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showAutoPickSection.toggle()
                }
            } label: {
                HStack(spacing: SpacingTokens.sp3) {
                    HSIconCircle(
                        systemName: "sparkles",
                        size: 36,
                        color: ColorTokens.Brand.lilac,
                        iconScale: 0.48
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("customWordList.autoPick.title")
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Spec.ink)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)
                        Text("customWordList.autoPick.subtitle")
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Spec.inkMuted)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: showAutoPickSection ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ColorTokens.Spec.inkMuted)
                        .animation(.spring(response: 0.3), value: showAutoPickSection)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("customWordList.autoPick.toggle.a11y"))
            .accessibilityIdentifier("customWordList.autoPick.toggleButton")

            if showAutoPickSection {
                autoPickControls
            }
        } header: {
            Text("customWordList.autoPick.sectionHeader")
        }
    }

    @ViewBuilder
    private var autoPickControls: some View {
        // Позиция звука в слове
        Picker(
            String(localized: "customWordList.autoPick.position.label"),
            selection: $autoPickPosition
        ) {
            ForEach(WordPosition.allCases) { position in
                Text(String(localized: String.LocalizationValue(position.localizedKey)))
                    .tag(position)
            }
        }
        .accessibilityIdentifier("customWordList.autoPick.positionPicker")

        // Диапазон слогов
        Picker(
            String(localized: "customWordList.autoPick.syllables.label"),
            selection: $autoPickSyllables
        ) {
            ForEach(SyllableRange.allCases) { range in
                Text(String(localized: String.LocalizationValue(range.localizedKey)))
                    .tag(range)
            }
        }
        .accessibilityIdentifier("customWordList.autoPick.syllablesPicker")

        // Количество слов
        Stepper(
            value: $autoPickCount,
            in: 3...30,
            step: 1
        ) {
            HStack {
                Text("customWordList.autoPick.count.label")
                    .foregroundStyle(ColorTokens.Spec.ink)
                Spacer()
                Text("\(autoPickCount)")
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Spec.accent)
                    .monospacedDigit()
            }
        }
        .accessibilityLabel(
            String(format: String(localized: "customWordList.autoPick.count.a11y"), autoPickCount)
        )
        .accessibilityIdentifier("customWordList.autoPick.countStepper")

        // Кнопка «Подобрать слова»
        Button {
            onAutoPick(currentAutoPickParams)
        } label: {
            HStack {
                Spacer()
                if isAutoPickLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(ColorTokens.Brand.lilac)
                    Text("customWordList.autoPick.loading")
                        .font(TypographyTokens.headline(15))
                        .foregroundStyle(ColorTokens.Brand.lilac)
                } else {
                    Image(systemName: "sparkles")
                    Text("customWordList.autoPick.action")
                        .font(TypographyTokens.headline(15))
                }
                Spacer()
            }
            .foregroundStyle(ColorTokens.Brand.lilac)
            .padding(.vertical, SpacingTokens.sp1)
        }
        .disabled(isAutoPickLoading)
        .accessibilityIdentifier("customWordList.autoPick.actionButton")

        // Результат автоподбора
        if let result = autoPickResult {
            autoPickResultView(result)
        }
    }

    @ViewBuilder
    private func autoPickResultView(_ result: CustomWordListModels.AutoPick.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            // Текст-сводка
            HStack(alignment: .top, spacing: SpacingTokens.sp2) {
                Image(systemName: result.showShortWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(result.showShortWarning ? ColorTokens.Brand.gold : ColorTokens.Brand.primary)
                    .font(.system(size: 14))
                Text(result.summaryText)
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(result.summaryText)

            if !result.words.isEmpty {
                // Превью найденных слов в виде Chips
                autoPickWordChips(result.words)

                // Кнопка «Добавить в список»
                Button {
                    addAutoPickedWords(result.words)
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("customWordList.autoPick.addToList")
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)
                    }
                    .font(TypographyTokens.headline(14))
                    .foregroundStyle(ColorTokens.Spec.accent)
                }
                .accessibilityIdentifier("customWordList.autoPick.addToListButton")
            }
        }
        .padding(.vertical, SpacingTokens.sp1)
    }

    private func autoPickWordChips(_ pickedWords: [String]) -> some View {
        // Горизонтально не влезет на SE — используем FlowLayout через lazy LazyVGrid
        let columns = [
            GridItem(.adaptive(minimum: 80, maximum: 160), spacing: SpacingTokens.sp2)
        ]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: SpacingTokens.sp2) {
            ForEach(pickedWords, id: \.self) { word in
                Text(word)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .padding(.horizontal, SpacingTokens.sp2)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(ColorTokens.Brand.lilac.opacity(0.15))
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityLabel(word)
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Words Section

    private var wordsSection: some View {
        Section {
            ForEach(words.indices, id: \.self) { index in
                HStack(spacing: SpacingTokens.sp2) {
                    TextField(
                        String(localized: "customWordList.editor.word.placeholder"),
                        text: Binding(
                            get: { words[safe: index] ?? "" },
                            set: { newValue in
                                if index < words.count {
                                    words[index] = newValue
                                }
                                onPreview(currentDraft)
                            }
                        )
                    )
                    .focused($focusedWordIndex, equals: index)
                    .accessibilityIdentifier("customWordList.editor.wordField_\(index)")
                    if words.count > 1 {
                        Button {
                            if index < words.count {
                                words.remove(at: index)
                                onPreview(currentDraft)
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(ColorTokens.Brand.rose.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("customWordList.delete"))
                    }
                }
            }
            Button {
                words.append("")
                DispatchQueue.main.async {
                    focusedWordIndex = words.count - 1
                }
                onPreview(currentDraft)
            } label: {
                Label(
                    String(localized: "customWordList.editor.addWord"),
                    systemImage: "plus.circle.fill"
                )
                .foregroundStyle(ColorTokens.Spec.accent)
            }
            .accessibilityIdentifier("customWordList.editor.addWordButton")
        } header: {
            Text("customWordList.editor.words")
        }
    }

    // MARK: - Preview Section

    @ViewBuilder
    private var previewSection: some View {
        if let preview = previewText, previewCount > 0 {
            Section {
                VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                    Text(preview)
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Spec.ink)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            } header: {
                Text("customWordList.editor.preview")
            }
        }
    }

    // MARK: - Error Section

    @ViewBuilder
    private var errorSection: some View {
        if let message = errorMessage {
            Section {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(ColorTokens.Brand.rose)
                    .font(TypographyTokens.caption(13))
            }
        }
    }

    // MARK: - Actions

    /// Добавляет слова из автоподбора в список (без дублей).
    private func addAutoPickedWords(_ newWords: [String]) {
        let existing = Set(words.map { $0.lowercased().trimmingCharacters(in: .whitespaces) })
        let toAdd = newWords.filter {
            let key = $0.lowercased().trimmingCharacters(in: .whitespaces)
            return !key.isEmpty && !existing.contains(key)
        }
        // Убираем пустые «заглушки» если список был пуст
        let cleanedCurrent = words.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        words = cleanedCurrent + toAdd
        if words.isEmpty { words = [""] }
        onPreview(currentDraft)
    }
}

// MARK: - Array safe index

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
