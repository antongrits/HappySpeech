import SwiftUI

// MARK: - CustomWordListEditorView
//
// v31 Волна C Ф.4 — sheet редактора списка слов. Принимает initialDraft и
// callback'и: onPreview / onSave / onCancel. Локальное state управление
// держит черновик; запрос на preview/save идёт наверх через замыкания.

struct CustomWordListEditorView: View {

    let initialDraft: WordListDraft
    let previewText: String?
    let previewCount: Int
    let errorMessage: String?
    let onPreview: (WordListDraft) -> Void
    let onSave: (WordListDraft) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var targetSound: String = "Р"
    @State private var words: [String] = [""]
    @FocusState private var focusedWordIndex: Int?

    private var currentDraft: WordListDraft {
        WordListDraft(
            id: initialDraft.id,
            name: name,
            targetSound: targetSound,
            words: words
        )
    }

    var body: some View {
        NavigationStack {
            Form {
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

                if let message = errorMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(ColorTokens.Brand.rose)
                            .font(TypographyTokens.caption(13))
                    }
                }
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
}

// MARK: - Array safe index

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
