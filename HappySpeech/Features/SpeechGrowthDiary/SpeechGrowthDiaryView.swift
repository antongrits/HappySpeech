import AVFoundation
import OSLog
import SwiftUI
import UIKit

// MARK: - Holder

@MainActor
@Observable
final class SpeechGrowthDiaryViewModelHolder: SpeechGrowthDiaryDisplayLogic {

    var listVM: SpeechGrowthDiaryModels.List.ViewModel?
    var shareVM: SpeechGrowthDiaryModels.Share.ViewModel?
    var pickerSheetActive: Bool = false
    var shareSheetActive: Bool = false
    var shareClipId: String?
    var optInAccepted: Bool = false

    func displayList(viewModel: SpeechGrowthDiaryModels.List.ViewModel) async {
        self.listVM = viewModel
    }
    func displayShare(viewModel: SpeechGrowthDiaryModels.Share.ViewModel) async {
        self.shareVM = viewModel
        self.shareSheetActive = true
    }
}

// MARK: - View

/// Дневник роста — daily reflection journal (kid-diary-journal class).
///
/// Первичный контент: вечерняя рефлексия дня (настроение + заметка + сохранение).
/// Вторичная функция: видеодневник речи (доступен через toolbar).
struct SpeechGrowthDiaryView: View {

    let childId: String

    // Video diary (secondary)
    @State private var holder = SpeechGrowthDiaryViewModelHolder()
    @State private var interactor: SpeechGrowthDiaryInteractor?
    @State private var presenter: SpeechGrowthDiaryPresenter?
    @State private var router: SpeechGrowthDiaryRouter?
    @State private var didBootstrap = false
    @State private var pendingNote: String = ""
    @State private var pendingTag: String = "звук"
    @State private var pendingSound: String = ""

    // Daily reflection (primary — uses EveningReflection logic)
    @State private var reflectionInteractor: EveningReflectionInteractor?
    @State private var showVideoSheet = false

    @Environment(\.exitToParentHome) private var exitToParentHome
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator

    private static let logger = Logger(
        subsystem: "ru.happyspeech", category: "Diary.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()

                // kid-diary-journal: тёплый статичный kidWarm mesh — скрапбук-дневник.
                HSMeshGradientBackground(palette: .kidWarm, animated: false)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.18 : 0.28)
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)

                if let ri = reflectionInteractor, ri.isLoaded {
                    reflectionContent(ri)
                } else {
                    ProgressView().controlSize(.large)
                }
            }
            .navigationTitle(Text(String(localized: "diary.nav.title", defaultValue: "Дневник роста")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await bootstrap() }
            .sheet(isPresented: $showVideoSheet) {
                videoDiarySheet
            }
            .sheet(isPresented: $holder.pickerSheetActive) {
                VideoPickerSheet(onPick: { url in
                    holder.pickerSheetActive = false
                    Task { await saveRecorded(url: url) }
                })
            }
            .sheet(isPresented: $holder.shareSheetActive) {
                shareDetailSheet
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Primary: Daily reflection

    private func reflectionContent(_ ri: EveningReflectionInteractor) -> some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: SpacingTokens.sp3) {
                    // Date header row
                    dateHeader
                        .padding(.top, SpacingTokens.sp3)

                    // Mascot greeting bubble
                    mascotBubble

                    sectionLabel("diary.section.today", defaultValue: "Как прошёл сегодня день?")

                    // Mood + note card
                    moodAndNoteCard(ri)

                    // CTA
                    saveButton(ri)
                        .padding(.bottom, SpacingTokens.sp2)

                    // History — "БОЛЬШАЯ ВЕХА"
                    if !ri.history.isEmpty {
                        milestoneSection(ri)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: geo.size.height)
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp6)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaPadding(.bottom, SpacingTokens.sp2)
        }
    }

    // MARK: - Date header

    private var dateHeader: some View {
        HStack(spacing: SpacingTokens.sp2) {
            Text(formattedDate())
                .font(TypographyTokens.caption(13).weight(.semibold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            if let count = reflectionInteractor?.history.count, count > 0 {
                HStack(spacing: SpacingTokens.sp1) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .accessibilityHidden(true)
                    Text(String(
                        format: String(localized: "diary.entries.count", defaultValue: "%lld записей"),
                        Int64(count)
                    ))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                }
            }
        }
    }

    private func formattedDate() -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ru_RU")
        fmt.dateFormat = "EEEE, d MMMM"
        return fmt.string(from: Date()).capitalized
    }

    // MARK: - Mascot bubble

    private var mascotBubble: some View {
        HStack(alignment: .bottom, spacing: SpacingTokens.sp2) {
            LyalyaMascotView(state: .encouraging, size: 56)
                .accessibilityHidden(true)
            HSCard(style: .elevated, padding: SpacingTokens.sp3) {
                Text(String(localized: "diary.mascot.bubble", defaultValue: "Давай отметим, чем ты гордишься 💛"))
                    .font(TypographyTokens.kidBody(14))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Mood + note card

    private func moodAndNoteCard(_ ri: EveningReflectionInteractor) -> some View {
        HSCard(style: .flat) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                // Mood question
                Text(String(localized: "diary.mood.question", defaultValue: "Чем ты гордишься?"))
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)

                Text(String(localized: "diary.mood.subtitle", defaultValue: "Выбери настроение и расскажи Ляле пару слов"))
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)

                // Mood picker row
                moodRow(ri)

                // Note field
                TextField(
                    String(localized: "diary.note.placeholder", defaultValue: "Сегодня я почти не запинался, когда читал вслух"),
                    text: Binding(
                        get: { ri.entry.fun },
                        set: { ri.entry.fun = $0 }
                    ),
                    axis: .vertical
                )
                .lineLimit(3...5)
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Kid.ink)
                .padding(SpacingTokens.sp2)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                        .fill(ColorTokens.Kid.bgSoft)
                )
                .accessibilityLabel(String(localized: "diary.note.a11y", defaultValue: "Заметка о дне"))
            }
        }
    }

    private func moodRow(_ ri: EveningReflectionInteractor) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            ForEach(EveningReflectionModels.Mood.allCases) { mood in
                moodButton(mood, ri: ri)
            }
        }
    }

    private func moodButton(
        _ mood: EveningReflectionModels.Mood,
        ri: EveningReflectionInteractor
    ) -> some View {
        let isSelected = ri.entry.mood == mood
        return Button {
            ri.entry.mood = mood
        } label: {
            VStack(spacing: SpacingTokens.sp1) {
                Text(mood.emoji).font(.system(size: 32))
                Text(mood.label)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(isSelected
                        ? ColorTokens.Brand.primary
                        : ColorTokens.Kid.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp2)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                    .fill(isSelected
                        ? ColorTokens.Brand.primary.opacity(0.12)
                        : ColorTokens.Kid.bgSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                    .strokeBorder(
                        isSelected ? ColorTokens.Brand.primary : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mood.label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Save button

    private func saveButton(_ ri: EveningReflectionInteractor) -> some View {
        Button {
            guard ri.entry.mood != nil else { return }
            ri.submit()
        } label: {
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .semibold))
                    .accessibilityHidden(true)
                Text(String(localized: "diary.cta.save", defaultValue: "Сохранить запись"))
                    .font(TypographyTokens.headline(17))
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.button, style: .continuous)
                    .fill(ColorTokens.Brand.primary)
            )
        }
        .buttonStyle(.plain)
        .disabled(ri.entry.mood == nil)
        .opacity(ri.entry.mood == nil ? 0.55 : 1.0)
        .accessibilityLabel(String(localized: "diary.cta.save", defaultValue: "Сохранить запись"))
        .accessibilityHint(String(localized: "diary.cta.save.hint", defaultValue: "Сохраняет запись в дневник"))
    }

    // MARK: - Milestone history section

    private func milestoneSection(_ ri: EveningReflectionInteractor) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            sectionLabel("diary.section.milestones", defaultValue: "БОЛЬШАЯ ВЕХА")

            ForEach(Array(ri.history.prefix(5).enumerated()), id: \.element.id) { index, entry in
                historyEntry(entry)
                    .scrollTransition(
                        .animated(reduceMotion
                            ? .linear(duration: 0)
                            : .spring(response: 0.5, dampingFraction: 0.85))
                    ) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0)
                            .scaleEffect(phase.isIdentity ? 1 : 0.96)
                    }
                    .zIndex(Double(ri.history.count - index))
            }
        }
    }

    private func historyEntry(_ entry: EveningReflectionModels.Entry) -> some View {
        HSCard(style: .flat) {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                ZStack {
                    Circle()
                        .fill(ColorTokens.Brand.primaryLo.opacity(0.22))
                        .frame(width: 44, height: 44)
                    Text(entry.mood?.emoji ?? "🌙")
                        .font(.system(size: 24))
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    if let date = entry.savedAt {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(TypographyTokens.caption(12).weight(.semibold))
                            .foregroundStyle(ColorTokens.Brand.primary)
                    }
                    if !entry.fun.isEmpty {
                        Text(entry.fun)
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(3)
                            .minimumScaleFactor(0.85)
                    }
                    if !entry.hard.isEmpty {
                        Text(entry.hard)
                            .font(TypographyTokens.body(13))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func sectionLabel(_ key: LocalizedStringKey, defaultValue: String) -> some View {
        HStack(spacing: SpacingTokens.tiny) {
            Capsule()
                .fill(ColorTokens.Brand.primaryLo)
                .frame(width: 18, height: 3)
            Text(key)
                .font(TypographyTokens.caption(13).weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 2)
    }

    // MARK: - Video diary sheet (secondary feature)

    private var videoDiarySheet: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()
                HSMeshGradientBackground(palette: .kidWarm, animated: false)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.14 : 0.22)
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)

                if !holder.optInAccepted {
                    videoOptInSection
                } else if let listVM = holder.listVM {
                    if listVM.isEmpty {
                        videoEmptyState
                    } else {
                        clipsListSection(listVM)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(Text(String(localized: "diary.video.title", defaultValue: "Видеодневник речи")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showVideoSheet = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
            .sheet(isPresented: $holder.pickerSheetActive) {
                VideoPickerSheet(onPick: { url in
                    holder.pickerSheetActive = false
                    Task { await saveRecorded(url: url) }
                })
            }
            .sheet(isPresented: $holder.shareSheetActive) {
                shareDetailSheet
            }
        }
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Video opt-in

    private var videoOptInSection: some View {
        VStack(spacing: SpacingTokens.sp4) {
            LyalyaMascotView(state: .explaining, size: 100)
                .accessibilityHidden(true)
            HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.regular) {
                VStack(spacing: SpacingTokens.sp3) {
                    HStack(spacing: SpacingTokens.sp2) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(ColorTokens.Brand.lilac)
                            .symbolRenderingMode(.hierarchical)
                            .hsSymbolEffect(.pulse, value: holder.optInAccepted)
                            .accessibilityHidden(true)
                        Text(String(localized: "diary.optIn.title"))
                            .font(TypographyTokens.title(20))
                            .foregroundStyle(ColorTokens.Parent.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.85)
                            .allowsTightening(true)
                    }
                    Text(String(localized: "diary.optIn.body"))
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                holder.optInAccepted = true
            } label: {
                Text(String(localized: "diary.optIn.accept"))
                    .font(TypographyTokens.headline(17))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.button)
                            .fill(ColorTokens.Brand.primary)
                    )
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(SpacingTokens.screenEdge)
    }

    // MARK: - Video empty state

    private var videoEmptyState: some View {
        VStack(spacing: SpacingTokens.sp4) {
            HSEmptyStateView(
                icon: "film.stack",
                title: String(localized: "diary.empty.title"),
                message: String(localized: "diary.empty.body"),
                action: { holder.pickerSheetActive = true },
                actionTitle: String(localized: "diary.button.record")
            )
            .padding(.top, SpacingTokens.sp4)
        }
        .padding(SpacingTokens.screenEdge)
    }

    // MARK: - Clips list

    private func clipsListSection(_ listVM: SpeechGrowthDiaryModels.List.ViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: SpacingTokens.sp3) {
                ForEach(Array(listVM.clips.enumerated()), id: \.element.id) { index, row in
                    clipRow(row)
                        .scrollTransition(
                            .animated(reduceMotion ? .linear(duration: 0) : .spring(response: 0.55, dampingFraction: 0.85))
                        ) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0)
                                .scaleEffect(phase.isIdentity ? 1 : 0.94)
                        }
                        .zIndex(Double(listVM.clips.count - index))
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.vertical, SpacingTokens.sp3)

            recordButton
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp5)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding(.bottom, SpacingTokens.sp2)
    }

    private func clipRow(_ row: SpeechGrowthDiaryModels.List.ClipRow) -> some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.regular) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                HStack(spacing: SpacingTokens.sp2) {
                    Image(systemName: "video.fill")
                        .foregroundStyle(ColorTokens.Brand.lilac)
                        .symbolRenderingMode(.hierarchical)
                        .hsSymbolEffect(.pulse, value: row.isShared)
                    Text(row.recordedAtLabel)
                        .font(TypographyTokens.headline(15))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                        .allowsTightening(true)
                    Spacer()
                    Text(row.durationLabel)
                        .font(TypographyTokens.caption(12).monospacedDigit())
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                HStack(spacing: SpacingTokens.sp2) {
                    if !row.topicTag.isEmpty { tagPill(row.topicTag) }
                    if !row.targetSound.isEmpty { tagPill("/\(row.targetSound)/") }
                    if row.isShared {
                        tagPill(
                            row.isShareExpired
                                ? String(localized: "diary.tag.expired", defaultValue: "Истёк")
                                : String(localized: "diary.tag.shared", defaultValue: "Расшарено"),
                            tint: row.isShareExpired
                                  ? ColorTokens.Brand.gold
                                  : ColorTokens.Brand.lilac
                        )
                    }
                    Spacer()
                }
                if !row.note.isEmpty {
                    Text(row.note)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                HStack(spacing: SpacingTokens.sp2) {
                    Button {
                        Task { await issueShare(for: row.id) }
                    } label: {
                        Label(String(localized: "diary.button.share"), systemImage: "square.and.arrow.up")
                            .font(TypographyTokens.caption(13))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    Button {
                        Task { await interactor?.deleteClip(id: row.id) }
                    } label: {
                        Label(String(localized: "diary.button.delete"), systemImage: "trash")
                            .font(TypographyTokens.caption(13))
                            .foregroundStyle(ColorTokens.Semantic.error)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func tagPill(_ text: String, tint: Color = ColorTokens.Brand.lilac) -> some View {
        Text(text)
            .font(TypographyTokens.caption(11))
            .padding(.horizontal, SpacingTokens.sp1)
            .padding(.vertical, 2)
            .background(Capsule().fill(tint.opacity(0.18)))
            .foregroundStyle(tint)
    }

    private var recordButton: some View {
        Button {
            holder.pickerSheetActive = true
        } label: {
            Label(String(localized: "diary.button.record"), systemImage: "video.badge.plus")
                .font(TypographyTokens.headline(17))
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(ColorTokens.Brand.primary)
                )
                .foregroundStyle(ColorTokens.Overlay.onAccent)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Share sheet

    private var shareDetailSheet: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
            Text(String(localized: "diary.share.title"))
                .font(TypographyTokens.title(20))
                .foregroundStyle(ColorTokens.Parent.ink)
            if let shareVM = holder.shareVM {
                Text(String(localized: "diary.share.expires"))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                Text(shareVM.expiresAtLabel)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Parent.ink)
                Text(shareVM.token)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(SpacingTokens.sp2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.sm)
                            .fill(ColorTokens.Parent.bg)
                    )
                    .textSelection(.enabled)
                Button {
                    UIPasteboard.general.string = shareVM.token
                } label: {
                    Label(String(localized: "diary.share.copy"), systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .padding(SpacingTokens.screenEdge)
        .presentationDetents([.medium])
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showVideoSheet = true
            } label: {
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
            }
            .accessibilityLabel(Text(String(localized: "diary.video.open.a11y", defaultValue: "Видеодневник")))
        }
        ToolbarItem(placement: .topBarLeading) {
            Button {
                exitToParentHome()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
            }
            .accessibilityLabel(Text(String(localized: "diary.close.a11y")))
        }
    }

    // MARK: - Actions

    private func issueShare(for clipId: String) async {
        _ = await interactor?.issueShareToken(clipId: clipId, durationHours: 24)
    }

    private func saveRecorded(url: URL) async {
        _ = await interactor?.saveClip(
            sourceFileURL: url,
            thumbnailFileURL: nil,
            durationSeconds: await clipDuration(url: url),
            topicTag: pendingTag,
            targetSound: pendingSound,
            note: pendingNote
        )
        pendingNote = ""
        pendingSound = ""
    }

    private func clipDuration(url: URL) async -> Double {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return 0 }
        return CMTimeGetSeconds(duration)
    }

    // MARK: - Bootstrap

    private func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true

        // Primary: daily reflection
        let ri = EveningReflectionInteractor(childId: childId)
        ri.load()
        self.reflectionInteractor = ri

        // Secondary: video diary
        let presenter = SpeechGrowthDiaryPresenter(displayLogic: holder)
        let videoInteractor = SpeechGrowthDiaryInteractor(
            presenter: presenter,
            realmActor: container.realmActor,
            childId: childId
        )
        let router = SpeechGrowthDiaryRouter()
        router.coordinator = coordinator
        self.presenter = presenter
        self.interactor = videoInteractor
        self.router = router
        await videoInteractor.loadClips()
    }
}

// MARK: - VideoPickerSheet (UIImagePickerController wrapper)

private struct VideoPickerSheet: UIViewControllerRepresentable {

    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraDevice = .front
            picker.cameraCaptureMode = .video
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.mediaTypes = ["public.movie"]
        picker.videoMaximumDuration = 30
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject,
                              UIImagePickerControllerDelegate,
                              UINavigationControllerDelegate {

        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            if let url = info[.mediaURL] as? URL {
                onPick(url)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Preview

#Preview("Diary — Light") {
    SpeechGrowthDiaryView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("Diary — Dark") {
    SpeechGrowthDiaryView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
