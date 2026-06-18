import OSLog
import SwiftUI

// MARK: - ChildHomeView + v25EntryCards
//
// v29 Фаза 8 — секция full-width карточек-входов вынесена в отдельный файл,
// чтобы не раздувать тело и длину `ChildHomeView.swift` (SwiftLint
// type_body_length / file_length). Чистый view-рендер, без бизнес-логики.

extension ChildHomeView {

    /// Группа карточек-входов в дополнительные детские режимы.
    @ViewBuilder
    var v25EntryCards: some View {
        // Stories — «Сказки Ляли» (каталог 20 анимированных историй).
        ChildHomeV25EntryCard(
            titleKey: "storyLibrary.entry.title",
            hintKey: "storyLibrary.entry.hint",
            iconName: "books.vertical.fill",
            accent: ColorTokens.Brand.rose
        ) {
            router?.routeToStoryLibrary(childId: childId)
        }

        // F-302 v25 — Articulation Gym «Зарядка для язычка».
        ChildHomeV25EntryCard(
            titleKey: "articulationGym.entry.title",
            hintKey: "articulationGym.entry.hint",
            iconName: "mouth.fill",
            accent: ColorTokens.Brand.mint
        ) {
            router?.routeToArticulationGym()
        }

        // F-303 v25 — Word Bank «Копилка слов».
        ChildHomeV25EntryCard(
            titleKey: "wordBank.entry.title",
            hintKey: "wordBank.entry.hint",
            iconName: "star.square.on.square.fill",
            accent: ColorTokens.Brand.gold
        ) {
            router?.routeToWordBank(childId: childId)
        }

        // v29 Фаза 8 Ф.5 — Sound Traffic Light «Звуковой светофор».
        ChildHomeV25EntryCard(
            titleKey: "soundTrafficLight.entry.title",
            hintKey: "soundTrafficLight.entry.hint",
            iconName: "car.2.fill",
            accent: ColorTokens.Brand.sky
        ) {
            router?.routeToSoundTrafficLight(childId: childId)
        }

        // v29 Фаза 8 Ф.12 — Phonemic Listening «Слушай внимательно».
        ChildHomeV25EntryCard(
            titleKey: "phonemicListening.entry.title",
            hintKey: "phonemicListening.entry.hint",
            iconName: "ear.fill",
            accent: ColorTokens.Brand.lilac
        ) {
            router?.routeToPhonemicListening(childId: childId)
        }

        // F2-009 (Wave 2) — Sound Detective «Звуковой детектив»
        // (позиционный фонематический анализ: начало / середина / конец / нет).
        ChildHomeV25EntryCard(
            titleKey: "soundDetective.entry.title",
            hintKey: "soundDetective.entry.hint",
            iconName: "magnifyingglass",
            accent: ColorTokens.Brand.sky
        ) {
            router?.routeToSoundDetective(childId: childId)
        }

        // F2-003 (Wave 2) — Syllable Snail «Слоговая улитка»
        // (слоговая структура слова по Марковой: прохлопай / выложи / почини).
        ChildHomeV25EntryCard(
            titleKey: "syllableSnail.entry.title",
            hintKey: "syllableSnail.entry.hint",
            iconName: "tortoise.fill",
            accent: ColorTokens.Brand.mint
        ) {
            router?.routeToSyllableSnail(childId: childId)
        }

        // F2-005 (Wave 2) — Fourth Extra «Четвёртый лишний»
        // (классификация / обобщение: семантический + фонетический варианты).
        ChildHomeV25EntryCard(
            titleKey: "fourthExtra.entry.title",
            hintKey: "fourthExtra.entry.hint",
            iconName: "square.grid.2x2.fill",
            accent: ColorTokens.Brand.gold
        ) {
            router?.routeToFourthExtra(childId: childId)
        }

        // F2-007 (Wave 2) — Word Formation «Назови ласково / Один-много-нет»
        // (словообразование + словоизменение: уменьш.-ласк., число, род. множ.).
        ChildHomeV25EntryCard(
            titleKey: "wordFormation.entry.title",
            hintKey: "wordFormation.entry.hint",
            iconName: "textformat.abc",
            accent: ColorTokens.Brand.lilac
        ) {
            router?.routeToWordFormation(childId: childId)
        }

        // F2-006 (Wave 2) — Whose Tail «Чей хвост / чей домик»
        // (словообразование прилагательных: притяжательные / притяжательно-
        // локативные / относительные «из чего сделан»).
        ChildHomeV25EntryCard(
            titleKey: "whoseTail.entry.title",
            hintKey: "whoseTail.entry.hint",
            iconName: "pawprint.fill",
            accent: ColorTokens.Brand.sky
        ) {
            router?.routeToWhoseTail(childId: childId)
        }

        // F2-004 (Wave 2) — Sentence Builder «Конструктор предложения»
        // (синтаксис: порядок слов / согласование / предлоги; последовательная
        // сборка ленты слов-карточек с частичной оценкой).
        ChildHomeV25EntryCard(
            titleKey: "sentenceBuilder.entry.title",
            hintKey: "sentenceBuilder.entry.hint",
            iconName: "text.append",
            accent: ColorTokens.Brand.mint
        ) {
            router?.routeToSentenceConstructor(childId: childId)
        }

        // v29 Фаза 8 Ф.6 — Speech Tempo «Темп-дорожка».
        ChildHomeV25EntryCard(
            titleKey: "speechTempo.entry.title",
            hintKey: "speechTempo.entry.hint",
            iconName: "metronome.fill",
            accent: ColorTokens.Brand.rose
        ) {
            router?.routeToSpeechTempo(childId: childId)
        }

        // v29 Фаза 8 Ф.10 — Breathe And Speak «Дыши и говори».
        ChildHomeV25EntryCard(
            titleKey: "breatheAndSpeak.entry.title",
            hintKey: "breatheAndSpeak.entry.hint",
            iconName: "wind",
            accent: ColorTokens.Brand.mint
        ) {
            router?.routeToBreatheAndSpeak(childId: childId)
        }

        // v29 Фаза 8 Ф.1 — Prosody «Голосовые краски».
        ChildHomeV25EntryCard(
            titleKey: "prosody.entry.title",
            hintKey: "prosody.entry.hint",
            iconName: "music.note",
            accent: ColorTokens.Brand.lilac
        ) {
            router?.routeToProsody(childId: childId)
        }

        // v29 Фаза 8 Ф.2 — Retelling «Расскажи по-настоящему».
        ChildHomeV25EntryCard(
            titleKey: "retelling.entry.title",
            hintKey: "retelling.entry.hint",
            iconName: "book.fill",
            accent: ColorTokens.Brand.sky
        ) {
            router?.routeToRetelling(childId: childId)
        }

        // v29 Фаза 8 Ф.7 — Lexical Themes «Мир слов».
        ChildHomeV25EntryCard(
            titleKey: "lexicalThemes.entry.title",
            hintKey: "lexicalThemes.entry.hint",
            iconName: "square.grid.3x3.fill",
            accent: ColorTokens.Brand.gold
        ) {
            router?.routeToLexicalThemes(childId: childId)
        }

        // v29 Фаза 8 Ф.11 — Storytelling «Я расскажу историю».
        ChildHomeV25EntryCard(
            titleKey: "storytelling.entry.title",
            hintKey: "storytelling.entry.hint",
            iconName: "books.vertical.fill",
            accent: ColorTokens.Brand.rose
        ) {
            router?.routeToStorytelling(childId: childId)
        }

        // v29 Фаза 8 Ф.8 — CoPlay «Занятие вместе».
        ChildHomeV25EntryCard(
            titleKey: "coPlay.entry.title",
            hintKey: "coPlay.entry.hint",
            iconName: "hands.and.sparkles.fill",
            accent: ColorTokens.Brand.mint
        ) {
            router?.routeToCoPlay(childId: childId)
        }

        // v31 Волна B Ф.1 — SyllableConstructor «Слог-конструктор».
        ChildHomeV25EntryCard(
            titleKey: "syllable.entry.title",
            hintKey: "syllable.entry.hint",
            iconName: "square.split.2x1.fill",
            accent: ColorTokens.Brand.primary
        ) {
            router?.routeToSyllableConstructor(childId: childId)
        }

        // v31 Волна B Ф.2 — ComprehensionDetective «Понимание-детектив».
        ChildHomeV25EntryCard(
            titleKey: "detective.entry.title",
            hintKey: "detective.entry.hint",
            iconName: "magnifyingglass.circle.fill",
            accent: ColorTokens.Brand.sky
        ) {
            router?.routeToComprehensionDetective(childId: childId)
        }

        // v31 Волна B Ф.3 — BedtimeMode «Перед сном».
        ChildHomeV25EntryCard(
            titleKey: "bedtime.entry.title",
            hintKey: "bedtime.entry.hint",
            iconName: "moon.stars.fill",
            accent: ColorTokens.Brand.lilac
        ) {
            router?.routeToBedtimeMode(childId: childId)
        }

        // v31 Волна C Ф.1 — RewardShop «Магазин наград».
        ChildHomeV25EntryCard(
            titleKey: "rewardShop.entry.title",
            hintKey: "rewardShop.entry.hint",
            iconName: "bag.fill",
            accent: ColorTokens.Brand.gold
        ) {
            router?.routeToRewardShop(childId: childId)
        }

        // v31 Волна C Ф.2 — LetterTrace «Пиши пальчиком/пером».
        ChildHomeV25EntryCard(
            titleKey: "letterTrace.entry.title",
            hintKey: "letterTrace.entry.hint",
            iconName: "pencil.tip",
            accent: ColorTokens.Brand.sky
        ) {
            router?.routeToLetterTrace(childId: childId)
        }

        // v31 Волна D Ф.1 — ReadAloudStory «Слушай и понимай».
        ChildHomeV25EntryCard(
            titleKey: "readAloud.entry.title",
            hintKey: "readAloud.entry.hint",
            iconName: "headphones",
            accent: ColorTokens.Brand.lilac
        ) {
            router?.routeToReadAloudStory(childId: childId)
        }

        // v31 Wave E Ф.1 — Karaoke с pitch-контуром.
        ChildHomeV25EntryCard(
            titleKey: "karaoke.entry.title",
            hintKey: "karaoke.entry.hint",
            iconName: "waveform.path.ecg.rectangle",
            accent: ColorTokens.Brand.primary
        ) {
            router?.routeToKaraokePitch(childId: childId)
        }

        // v31 Wave E Ф.2 — Пальчики-говоруны.
        ChildHomeV25EntryCard(
            titleKey: "fingerPlay.entry.title",
            hintKey: "fingerPlay.entry.hint",
            iconName: "hand.raised.fingers.spread.fill",
            accent: ColorTokens.Brand.mint
        ) {
            router?.routeToFingerPlay(childId: childId)
        }

        // v31 Wave E Ф.3 — Oral story creator.
        ChildHomeV25EntryCard(
            titleKey: "storyCreator.entry.title",
            hintKey: "storyCreator.entry.hint",
            iconName: "text.book.closed.fill",
            accent: ColorTokens.Brand.rose
        ) {
            router?.routeToOralStoryCreator(childId: childId)
        }

        // v31 Wave F Ф.2 — Описательная карта объекта (план-схема Ткаченко).
        ChildHomeV25EntryCard(
            titleKey: "descriptionMap.entry.title",
            hintKey: "descriptionMap.entry.hint",
            iconName: "rectangle.grid.2x2.fill",
            accent: ColorTokens.Brand.lilac
        ) {
            router?.routeToObjectDescriptionMap(childId: childId)
        }

        // v31 Wave F Ф.7 — Логоритмика (Картушина / Волкова, метроном + тапы).
        ChildHomeV25EntryCard(
            titleKey: "logorhythmics.entry.title",
            hintKey: "logorhythmics.entry.hint",
            iconName: "music.note.list",
            accent: ColorTokens.Brand.butter
        ) {
            router?.routeToLogorhythmics(childId: childId)
        }

        // v31 Wave F Ф.11 — Билингвальный режим (русский + белорусский / английский).
        ChildHomeV25EntryCard(
            titleKey: "bilingualMode.entry.title",
            hintKey: "bilingualMode.entry.hint",
            iconName: "character.bubble.fill",
            accent: ColorTokens.Brand.lilac
        ) {
            router?.routeToBilingualMode(childId: childId)
        }

        // v32 Sprint 12 — Sound Composition «Звуковая мастерская»
        // (эльконинский звуковой анализ-синтез: схема-домик, цветные фишки, синтез).
        ChildHomeV25EntryCard(
            titleKey: "soundComposition.entry.title",
            hintKey: "soundComposition.entry.hint",
            iconName: "circle.hexagongrid.fill",
            accent: ColorTokens.Brand.primary
        ) {
            router?.routeToSoundComposition(childId: childId)
        }

        // v32 Sprint 12 — Voicing & Softness «Карта звонкости и мягкости»
        // (дифференциация фонем: звонкий↔глухой, твёрдый↔мягкий + слова-ловушки).
        ChildHomeV25EntryCard(
            titleKey: "voicingSoftness.entry.title",
            hintKey: "voicingSoftness.entry.hint",
            iconName: "waveform.path.ecg",
            accent: ColorTokens.Brand.rose
        ) {
            router?.routeToVoicingSoftness(childId: childId)
        }

        // v32 Sprint 12 — Listen Yourself «Послушай себя»
        // (слуховой самоконтроль: два дубля + A/B-сравнение с эталоном Ляли).
        ChildHomeV25EntryCard(
            titleKey: "listenYourself.entry.title",
            hintKey: "listenYourself.entry.hint",
            iconName: "ear.fill",
            accent: ColorTokens.Brand.primary
        ) {
            router?.routeToListenYourself(childId: childId)
        }

        // v32 expansion 2.4 — Voice Colors «Голосовые краски»
        // (просодика: интонация, логическое ударение, эмоциональная окраска голоса).
        ChildHomeV25EntryCard(
            titleKey: "voiceColors.entry.title",
            hintKey: "voiceColors.entry.hint",
            iconName: "waveform.path",
            accent: ColorTokens.Brand.lilac
        ) {
            router?.routeToVoiceColors(childId: childId)
        }

        // v32 expansion 2.10 — Voice Strongman «Силач-голос»
        // (фонопедия: сила голоса — зона комфортной громкости по RMS, антикрик;
        // высота голоса — глиссандо-лесенка вверх/вниз, reuse YINPitchTracker).
        ChildHomeV25EntryCard(
            title: String(localized: "voiceStrongman.entry.title", defaultValue: "Силач-голос"),
            hint: String(localized: "voiceStrongman.entry.hint",
                         defaultValue: "Громко-тихо, высоко-низко"),
            iconName: "dumbbell",
            accent: ColorTokens.Brand.primary
        ) {
            router?.routeToVoiceStrongman(childId: childId)
        }

        // v32 expansion 2.6 — Story Pictures «Рассказ по картинкам»
        // (связная речь по серии сюжетов: упорядочивание → рассказ → радар полноты).
        ChildHomeV25EntryCard(
            title: String(localized: "storyPictures.entry.title", defaultValue: "Рассказ по картинкам"),
            hint: String(localized: "storyPictures.entry.hint", defaultValue: "Составь историю по серии"),
            iconName: "rectangle.3.group",
            accent: ColorTokens.Brand.primary
        ) {
            router?.routeToStoryPictures(childId: childId)
        }

        // v32 expansion 2.11 — Tongue Twisters «Чистоговорки-конструктор»
        // (автоматизация звука во фразе с ритмом: разминка → рифма → запись/ASR →
        // наращивание строки «вагончиками»; метроном опционален и замедляем).
        ChildHomeV25EntryCard(
            title: String(localized: "tongueTwisters.entry.title", defaultValue: "Чистоговорки"),
            hint: String(localized: "tongueTwisters.entry.hint", defaultValue: "Скороговорки с ритмом"),
            iconName: "metronome",
            accent: ColorTokens.Brand.primary
        ) {
            router?.routeToTongueTwisters(childId: childId)
        }

        // v32 expansion 2.5 — Sound Hunter Day «Звуковой охотник дня»
        // (перенос звука в спонтанную бытовую речь: дневная миссия → «поймал
        // слово» → копилка дня → родительское подтверждение переноса).
        ChildHomeV25EntryCard(
            title: String(localized: "soundHunterDay.entry.title", defaultValue: "Звуковой охотник"),
            hint: String(localized: "soundHunterDay.entry.hint", defaultValue: "Лови звук в жизни"),
            iconName: "target",
            accent: ColorTokens.Brand.primary
        ) {
            router?.routeToSoundHunterDay(childId: childId)
        }

        // v32 expansion 2.12 — Live Sounds «Живые звуки»
        // (устный фонематический синтез: Ляля произносит слово по звукам,
        // ребёнок собирает слово — выбор картинки / звуки-человечки в ряд).
        ChildHomeV25EntryCard(
            title: String(localized: "liveSounds.entry.title", defaultValue: "Живые звуки"),
            hint: String(localized: "liveSounds.entry.hint", defaultValue: "Собери слово из звуков"),
            iconName: "circle.grid.3x3",
            accent: ColorTokens.Brand.rose
        ) {
            router?.routeToLiveSounds(childId: childId)
        }

        // v32 expansion 2.15 — Advanced Grammar «Грамматический конструктор-2».
        ChildHomeV25EntryCard(
            title: String(localized: "advancedGrammar.entry.title", defaultValue: "Грамматика+"),
            hint: String(localized: "advancedGrammar.entry.hint", defaultValue: "Сложные предлоги, согласование"),
            iconName: "text.book.closed",
            accent: ColorTokens.Brand.primary
        ) {
            router?.routeToAdvancedGrammar(childId: childId)
        }
    }
}
