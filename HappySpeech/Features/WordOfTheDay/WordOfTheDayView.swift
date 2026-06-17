import SwiftUI

// MARK: - WordOfTheDayView
//
// kid-sound-detail эталон: «Звук / слово дня» — единый шаблон для всего класса.
//
// Layout (по ref kid-sound-detail_ref.png):
//   1. Chip-заголовок «ЗВУК ДНЯ» (капслок, coral capsule)
//   2. Hero-карточка: название группы + кириллическая буква звука в lilac-кружке
//      + Ляля справа с репликой «р-р-р!»
//   3. «Послушай, как говорит Ляля» — крупная coral CTA (аудио-демо)
//   4. «Как сказать» — flat card, иконка языка + текст подсказки
//   5. «Слова со звуком «Р»» — горизонтальный 2-колоночный грид (реальные данные
//      из word_manifest через LessonContentMap.words(soundFamily:))
//   6. «Произнести» — mic CTA внизу
//
// Инварианты: тёплая палитра; lineLimit(nil)+minimumScaleFactor; SE-safe;
// симметричные screenEdge-отступы; light+dark; Dynamic Type; VoiceOver; Reduced Motion.

struct WordOfTheDayView: View {

    let childId: String

    @State private var interactor: WordOfTheDayInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.exitGame) private var exitGame
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                // kid-sound-detail: статичный тёплый kidWarm mesh (без волн).
                HSMeshGradientBackground(palette: .kidWarm, animated: false)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.18 : 0.30)
                    .blendMode(.softLight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                content
            }
            .navigationTitle(Text(String(localized: "wotd.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exitGame()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
            .task {
                if interactor == nil {
                    interactor = WordOfTheDayInteractor(
                        childId: childId,
                        audioService: container.audioService,
                        scorer: container.pronunciationService,
                        adaptivePlanner: container.adaptivePlannerService
                    )
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let interactor {
            ScrollView {
                VStack(spacing: SpacingTokens.sp4) {
                    soundChip(interactor: interactor)
                    soundHeroCard(interactor: interactor)
                    listenCTA(interactor: interactor)
                    howToCard(interactor: interactor)
                    relatedWordsSection(interactor: interactor)
                    feedback(interactor: interactor)
                    pronounceCTA(interactor: interactor)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp6)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaPadding(.bottom, SpacingTokens.sp2)
        } else {
            ProgressView().controlSize(.large)
        }
    }

    // MARK: - 1. Chip-заголовок «ЗВУК ДНЯ»
    //
    // Маленький pill в левом углу — показывает что это за экран.

    private func soundChip(interactor: WordOfTheDayInteractor) -> some View {
        HStack {
            Text(String(localized: "wotd.chip.label", defaultValue: "ЗВУК ДНЯ"))
                .font(TypographyTokens.caption(11).weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .padding(.horizontal, SpacingTokens.sp3)
                .padding(.vertical, SpacingTokens.sp1)
                .background(
                    Capsule()
                        .fill(ColorTokens.Brand.primary)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .accessibilityHidden(true)
            Spacer()
        }
    }

    // MARK: - 2. Hero — буква звука + название группы + Ляля

    private func soundHeroCard(interactor: WordOfTheDayInteractor) -> some View {
        HSCard(style: .gradientTinted(GradientTokens.cardLilacRose), padding: SpacingTokens.sp4) {
            HStack(alignment: .center, spacing: SpacingTokens.sp3) {
                // Левая колонка: название группы + кружок с буквой + слово
                VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                    Text(soundGroupName(interactor.card.targetSound))
                        .font(TypographyTokens.caption(12).weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(ColorTokens.Brand.lilac)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)

                    // Кружок с буквой — главный элемент (эталон: 104pt lilac circle)
                    ZStack {
                        Circle()
                            .fill(ColorTokens.Brand.lilac.opacity(0.15))
                            .frame(width: 104, height: 104)
                        Text(interactor.card.targetSound)
                            .font(TypographyTokens.kidDisplay(68))
                            .foregroundStyle(ColorTokens.Brand.lilac)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }
                    .accessibilityHidden(true)

                    // Слово дня под кружком
                    Text(interactor.card.word.capitalized)
                        .font(TypographyTokens.title(22))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: SpacingTokens.sp2)

                // Правая колонка: Ляля + чант-пузырь
                VStack(alignment: .center, spacing: SpacingTokens.sp2) {
                    Text(soundChantText(interactor.card.targetSound))
                        .font(TypographyTokens.kidCardTitle(14))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, SpacingTokens.sp2)
                        .padding(.vertical, SpacingTokens.micro)
                        .background(
                            Capsule()
                                .fill(ColorTokens.Kid.surface)
                                .overlay(Capsule().strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
                        )
                        .accessibilityHidden(true)
                    LyalyaMascotView(state: .singing, size: 80)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String(
            format: String(localized: "wotd.hero.a11y", defaultValue: "Звук дня: %@, слово %@"),
            interactor.card.targetSound,
            interactor.card.word
        )))
    }

    // MARK: - 3. «Послушай, как говорит Ляля» — аудио-демо CTA

    private func listenCTA(interactor: WordOfTheDayInteractor) -> some View {
        Button {
            hapticService.impact(.medium)
            interactor.playModelAudio()
        } label: {
            HStack(spacing: SpacingTokens.sp3) {
                ZStack {
                    Circle()
                        .fill(ColorTokens.Overlay.onAccent.opacity(0.20))
                        .frame(width: 44, height: 44)
                    Image(systemName: interactor.isPlayingModel ? "waveform" : "play.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .hsSymbolEffect(.pulse, value: interactor.isPlayingModel)
                }
                .accessibilityHidden(true)
                Text(String(localized: "wotd.listen.cta", defaultValue: "Послушай, как говорит Ляля"))
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, SpacingTokens.sp5)
            .padding(.vertical, SpacingTokens.sp4)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(ColorTokens.Brand.primary)
            )
            .depthShadow(ShadowTokens.kidDepth)
        }
        .buttonStyle(.plain)
        .disabled(interactor.isPlayingModel)
        .accessibilityLabel(Text(String(localized: "wotd.listen.a11y", defaultValue: "Послушать произношение Ляли")))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - 4. «Как сказать» — артикуляционная подсказка

    private func howToCard(interactor: WordOfTheDayInteractor) -> some View {
        HSCard(style: .flat, padding: SpacingTokens.sp4) {
            HStack(spacing: SpacingTokens.sp3) {
                // Иконка языка / артикуляции
                ZStack {
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .fill(ColorTokens.Brand.rose.opacity(0.16))
                        .frame(width: 64, height: 64)
                    Image(systemName: "mouth.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .symbolRenderingMode(.hierarchical)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(String(localized: "wotd.howto.label", defaultValue: "КАК СКАЗАТЬ"))
                        .font(TypographyTokens.caption(11).weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(ColorTokens.Kid.inkSoft)
                    Text(interactor.card.hint)
                        .font(TypographyTokens.kidCardTitle(15))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 5. Слова со звуком (реальные данные из word_manifest)

    @ViewBuilder
    private func relatedWordsSection(interactor: WordOfTheDayInteractor) -> some View {
        let words = relatedWords(for: interactor.card.targetSound)
        if !words.isEmpty {
            let title = String(
                format: String(localized: "wotd.related.title", defaultValue: "Слова со звуком «%@»"),
                interactor.card.targetSound
            )
            let meta = String(
                format: String(localized: "wotd.related.meta", defaultValue: "%lld слов"),
                words.count
            )

            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                HStack {
                    Text(title)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                    Spacer()
                    Text(meta)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                let cols = [
                    GridItem(.flexible(), spacing: SpacingTokens.sp3),
                    GridItem(.flexible(), spacing: SpacingTokens.sp3)
                ]
                LazyVGrid(columns: cols, spacing: SpacingTokens.sp2) {
                    ForEach(words.prefix(8), id: \.word) { entry in
                        wordTile(entry: entry, targetSound: interactor.card.targetSound)
                            .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] c, phase in
                                c
                                    .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                                    .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.94))
                            }
                    }
                }
            }
        }
    }

    private func wordTile(entry: LessonContentMap.Entry, targetSound: String) -> some View {
        HSCard(style: .elevated, padding: SpacingTokens.sp3) {
            HStack(spacing: SpacingTokens.sp2) {
                HSContentSymbol(
                    LessonContentMap.asset(for: entry.word) ?? "textformat.abc",
                    size: 40,
                    tint: ColorTokens.Brand.primary
                )
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)

                Text(entry.word)
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(entry.word))
    }

    // MARK: - 6. Обратная связь по произношению

    @ViewBuilder
    private func feedback(interactor: WordOfTheDayInteractor) -> some View {
        switch interactor.phase {
        case .idle:
            EmptyView()
        case .recording:
            HStack(spacing: SpacingTokens.sp2) {
                ProgressView().controlSize(.regular)
                Text(String(localized: "wotd.listening", defaultValue: "Слушаю…"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
        case .scored(let stars):
            HStack(spacing: SpacingTokens.sp1) {
                ForEach(0..<3, id: \.self) { idx in
                    Image(systemName: idx < stars ? "star.fill" : "star")
                        .foregroundStyle(ColorTokens.Brand.gold)
                        .font(.system(size: 28))
                        .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] c, phase in
                            c
                                .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                                .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.9))
                        }
                        .hsSymbolEffect(.bounce, value: stars)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(
                String(format: String(localized: "wotd.stars.a11y", defaultValue: "Оценка: %lld из 3"), stars)
            ))
        case .tryAgain:
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                    .font(.system(size: 24))
                Text(String(localized: "wotd.tryAgain", defaultValue: "Давай попробуем ещё раз!"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - 7. «Произнести» — mic CTA

    private func pronounceCTA(interactor: WordOfTheDayInteractor) -> some View {
        HSButton(
            String(localized: "wotd.cta.speak"),
            style: .primary,
            size: .large,
            icon: "mic.fill"
        ) {
            hapticService.impact(.medium)
            interactor.startRecording()
        }
        .disabled(interactor.phase == .recording)
    }

    // MARK: - Helpers

    /// Возвращает до 8 слов из word_manifest для заданного targetSound.
    private func relatedWords(for sound: String) -> [LessonContentMap.Entry] {
        let all = LessonContentMap.words(soundFamily: sound)
        if all.isEmpty { return [] }
        let shuffled = all.shuffled()
        return Array(shuffled.prefix(8))
    }

    /// Тёплая реплика Ляли: «р-р-р!», «с-с-с!» и т.д.
    private func soundChantText(_ letter: String) -> String {
        let trimmed = letter.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return "ура!" }
        let s = String(first).lowercased()
        return "\(s)-\(s)-\(s)!"
    }

    /// Методическое название группы звука (соноры, шипящие и т.д.)
    private func soundGroupName(_ sound: String) -> String {
        switch sound.uppercased() {
        case "Р", "РЬ", "Л", "ЛЬ", "М", "Н":
            return String(localized: "wotd.group.sonor", defaultValue: "Сонорный «моторчик»")
        case "С", "З", "Ц":
            return String(localized: "wotd.group.whistle", defaultValue: "Свистящий")
        case "Ш", "Ж", "Ч", "Щ":
            return String(localized: "wotd.group.hiss", defaultValue: "Шипящий")
        case "К", "Г", "Х":
            return String(localized: "wotd.group.back", defaultValue: "Заднеязычный")
        default:
            return String(localized: "wotd.group.other", defaultValue: "Звук")
        }
    }
}

// MARK: - Preview

#Preview("WordOfTheDay — Light") {
    WordOfTheDayView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("WordOfTheDay — Dark") {
    WordOfTheDayView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
