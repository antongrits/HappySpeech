import OSLog
import SwiftUI

// MARK: - CulturalContentViewModelHolder

@MainActor
@Observable
final class CulturalContentViewModelHolder: CulturalContentDisplayLogic {

    var loadVM: CulturalContentModels.Load.ViewModel?
    var openVM: CulturalContentModels.Open.ViewModel?
    var toggleVM: CulturalContentModels.ToggleBookmark.ViewModel?
    var showToast: Bool = false
    var showReader: Bool = false

    func displayLoad(viewModel: CulturalContentModels.Load.ViewModel) async {
        self.loadVM = viewModel
    }

    func displayOpen(viewModel: CulturalContentModels.Open.ViewModel) async {
        self.openVM = viewModel
        self.showReader = true
    }

    func displayToggleBookmark(viewModel: CulturalContentModels.ToggleBookmark.ViewModel) async {
        self.toggleVM = viewModel
        self.showToast = true
    }
}

// MARK: - CulturalContentView (Clean Swift: View)
//
// Block R.5 v18 — экран культурного контента (сказки/песни/стихи/скороговорки).
//
// Layout (sheet, presentationDetent .large):
//   1. Hero header — иконка + название + total count
//   2. Category picker — горизонтальный scroll из 4 категорий
//   3. Items list — карточки items с durationLabel + bookmark icon
//   4. Reader sheet (full-screen) — открывается при tap на item:
//      • Title + author
//      • Karaoke-style transcript (highlighted line при playback)
//      • Bookmark toggle
//
// Accessibility:
//   • VoiceOver: каждая карточка = «<item>, <author>, <category>»
//   • Dynamic Type: scaledFont, lineLimit(nil)
//   • Reduced Motion: нет karaoke-glow, только current line
//   • Touch targets ≥56pt

struct CulturalContentView: View {

    let childId: String

    @State private var holder = CulturalContentViewModelHolder()
    @State private var interactor: CulturalContentInteractor?
    @State private var presenter: CulturalContentPresenter?
    @State private var router: CulturalContentRouter?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "CulturalContent.View")

    init(childId: String) {
        self.childId = childId
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SpacingTokens.sp4) {
                        if let viewModel = holder.loadVM {
                            heroSection
                            categoriesSection(viewModel: viewModel)
                            itemsSection(viewModel: viewModel)
                            footerSection
                        } else {
                            loadingSection
                        }
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.vertical, SpacingTokens.sp4)
                }
            }
            .navigationTitle(Text("cultural.screen.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text("cultural.close.a11y"))
                }
            }
            .overlay(alignment: .top) {
                if holder.showToast, let toast = holder.toggleVM?.toastMessage {
                    toastBanner(text: toast)
                        .padding(.top, SpacingTokens.sp2)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.4), value: holder.showToast)
            .sheet(isPresented: $holder.showReader) {
                if let openVM = holder.openVM {
                    CulturalContentReaderView(
                        viewModel: openVM,
                        onToggleBookmark: { itemId in
                            Task { await toggleBookmark(itemId: itemId) }
                        }
                    )
                    .environment(container)
                    .presentationDetents([.large])
                }
            }
        }
        .environment(\.circuitContext, .kid)
        .task {
            await setupAndLoad()
        }
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            LyalyaMascotView(state: .happy, size: 80)
                .accessibilityHidden(true)
            ProgressView()
                .controlSize(.large)
        }
        .padding(.top, SpacingTokens.sp10)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            LyalyaMascotView(state: .explaining, size: 140)
                .frame(height: 140)
                .accessibilityHidden(true)

            Text("cultural.hero.title")
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Text("cultural.hero.subtitle")
                .font(TypographyTokens.body(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.sp4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.sp4)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Kid.surface)
        )
        .depthShadow(ShadowTokens.kidDepth)
    }

    // MARK: - Categories

    @ViewBuilder
    private func categoriesSection(viewModel: CulturalContentModels.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            Text("cultural.categories.title")
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Kid.ink)
                .padding(.leading, SpacingTokens.sp1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SpacingTokens.sp2) {
                    // «Все» chip
                    allCategoriesChip(isActive: viewModel.activeCategoryId == nil)

                    ForEach(viewModel.categories) { row in
                        categoryChip(row: row)
                    }
                }
                .padding(.vertical, SpacingTokens.sp1)
            }
            // D-19 v27 — contentMargins даёт ровный отступ по краям, последний
            // чип не обрезается жёстко — виден намёк на скролл.
            .contentMargins(.horizontal, SpacingTokens.sp1, for: .scrollContent)
        }
    }

    @ViewBuilder
    private func allCategoriesChip(isActive: Bool) -> some View {
        Button {
            Task { await load(category: nil) }
        } label: {
            HStack(spacing: SpacingTokens.sp1) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.caption)
                    .accessibilityHidden(true)
                Text("cultural.category.all")
                    .font(TypographyTokens.body(13))
                    .lineLimit(1)
            }
            .padding(.horizontal, SpacingTokens.sp3)
            .frame(minHeight: 44)
            .foregroundStyle(
                isActive ? ColorTokens.Overlay.onAccent : ColorTokens.Kid.ink
            )
            .background(
                Capsule()
                    .fill(
                        isActive ? ColorTokens.Brand.primary : ColorTokens.Kid.surface
                    )
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isActive ? Color.clear : ColorTokens.Kid.line,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("cultural.category.all"))
        .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : .isButton)
    }

    @ViewBuilder
    private func categoryChip(row: CulturalContentModels.Load.CategoryRow) -> some View {
        Button {
            if let cat = CulturalCategory(rawValue: row.id) {
                Task { await load(category: cat) }
            }
        } label: {
            HStack(spacing: SpacingTokens.sp1) {
                Image(systemName: row.symbolName)
                    .font(.caption)
                    .accessibilityHidden(true)
                Text(row.title)
                    .font(TypographyTokens.body(13))
                    .lineLimit(1)
                Text(verbatim: "\(row.count)")
                    .font(.caption2)
                    .opacity(0.7)
            }
            .padding(.horizontal, SpacingTokens.sp3)
            .frame(minHeight: 44)
            .foregroundStyle(
                row.isActive ? ColorTokens.Overlay.onAccent : ColorTokens.Kid.ink
            )
            .background(
                Capsule()
                    .fill(
                        row.isActive ? ColorTokens.Brand.primary : ColorTokens.Kid.surface
                    )
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        row.isActive ? Color.clear : ColorTokens.Kid.line,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(row.accessibilityLabel))
        .accessibilityAddTraits(row.isActive ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: - Items

    @ViewBuilder
    private func itemsSection(viewModel: CulturalContentModels.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            HStack {
                Text("cultural.items.title")
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Spacer()
                Text(viewModel.totalLabel)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
            .padding(.horizontal, SpacingTokens.sp1)

            if let emptyHint = viewModel.emptyHint {
                Text(emptyHint)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(SpacingTokens.sp4)
            } else {
                VStack(spacing: SpacingTokens.sp2) {
                    ForEach(viewModel.items) { item in
                        itemCard(item: item)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func itemCard(item: CulturalContentModels.Load.ItemRow) -> some View {
        Button {
            Task { await open(itemId: item.id) }
        } label: {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                Image(systemName: item.symbolName)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(ColorTokens.Brand.primary.opacity(0.12))
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.title)
                            .font(TypographyTokens.headline(16))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        if item.isBookmarked {
                            Image(systemName: "bookmark.fill")
                                .font(.caption)
                                .foregroundStyle(ColorTokens.Brand.gold)
                                .accessibilityHidden(true)
                        }
                    }

                    if let author = item.author {
                        Text(author)
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .lineLimit(1)
                    }

                    HStack(spacing: SpacingTokens.sp2) {
                        Label(item.categoryTitle, systemImage: "tag")
                            .font(.caption2)
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .labelStyle(.titleAndIcon)

                        if !item.durationLabel.isEmpty {
                            Label(item.durationLabel, systemImage: "clock")
                                .font(.caption2)
                                .foregroundStyle(ColorTokens.Kid.inkMuted)
                                .labelStyle(.titleAndIcon)
                        }

                        Label(item.targetSoundsText, systemImage: "waveform")
                            .font(.caption2)
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .labelStyle(.titleAndIcon)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(SpacingTokens.sp3)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .fill(ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
            )
            .depthShadow(ShadowTokens.kidDepth)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(item.accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Footer

    private var footerSection: some View {
        Text("cultural.footer.note")
            .font(TypographyTokens.caption(11))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, SpacingTokens.sp4)
            .padding(.top, SpacingTokens.sp2)
    }

    // MARK: - Toast

    @ViewBuilder
    private func toastBanner(text: String) -> some View {
        Text(text)
            .font(TypographyTokens.caption(13))
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .padding(.horizontal, SpacingTokens.sp4)
            .padding(.vertical, SpacingTokens.sp2)
            .background(
                Capsule().fill(ColorTokens.Brand.primary)
            )
            .depthShadow(ShadowTokens.kidDepth)
            .task {
                try? await Task.sleep(for: .seconds(2.0))
                holder.showToast = false
            }
    }

    // MARK: - Wiring

    private func setupAndLoad() async {
        if interactor == nil {
            let presenter = CulturalContentPresenter(displayLogic: holder)
            let interactor = CulturalContentInteractor(
                childId: childId,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = CulturalContentRouter(dismissAction: { dismiss() })
        }

        await interactor?.load(request: .init(childId: childId, category: nil))
    }

    private func load(category: CulturalCategory?) async {
        await interactor?.load(request: .init(childId: childId, category: category))
    }

    private func open(itemId: String) async {
        await interactor?.open(request: .init(itemId: itemId))
    }

    private func toggleBookmark(itemId: String) async {
        await interactor?.toggleBookmark(request: .init(
            childId: childId,
            itemId: itemId
        ))
        // Перезагружаем list чтобы обновить isBookmarked флаги.
        await interactor?.load(request: .init(
            childId: childId,
            category: holder.loadVM?.activeCategoryId.flatMap { CulturalCategory(rawValue: $0) }
        ))
    }
}

// MARK: - Reader View (sub-screen)
//
// Karaoke-style transcript: текущая строка подсвечивается.
// MVP: timer-based progression (без real audio file — bundled placeholder).
// Reduce Motion: пропуск progress анимации, статичный list.

private struct CulturalContentReaderView: View {

    let viewModel: CulturalContentModels.Open.ViewModel
    let onToggleBookmark: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentLineIdx: Int = 0
    @State private var isPlaying: Bool = false
    @State private var progressTimer: Timer?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
                    headerSection
                    transcriptSection
                    controlsSection
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.vertical, SpacingTokens.sp4)
            }
            .background(ColorTokens.Kid.bg.ignoresSafeArea())
            .navigationTitle(Text("cultural.reader.navTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text("cultural.reader.close.a11y"))
                }
            }
        }
        .onDisappear {
            stopPlayback()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.title)
                        .font(TypographyTokens.title(24))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    if let author = viewModel.author {
                        Text(author)
                            .font(TypographyTokens.body(13))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .lineLimit(1)
                    }

                    HStack(spacing: SpacingTokens.sp3) {
                        Label(viewModel.durationLabel, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .labelStyle(.titleAndIcon)
                        Label(viewModel.targetSoundsText, systemImage: "waveform")
                            .font(.caption)
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .labelStyle(.titleAndIcon)
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
                Button {
                    onToggleBookmark(itemId)
                } label: {
                    Image(systemName: viewModel.isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.title2)
                        .foregroundStyle(
                            viewModel.isBookmarked
                                ? ColorTokens.Brand.gold
                                : ColorTokens.Kid.inkSoft
                        )
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    viewModel.isBookmarked
                        ? Text("cultural.reader.unbookmark.a11y")
                        : Text("cultural.reader.bookmark.a11y")
                )
            }
        }
        .padding(SpacingTokens.sp4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Kid.surface)
        )
    }

    /// Извлекаем itemId из openVM — т.к. в OpenViewModel нет поля id,
    /// используем title как fallback (catalog уникален по id, на parent layer
    /// будет передан правильный id через onToggleBookmark).
    private var itemId: String {
        // Используем title для match — в этом MVP
        CulturalItem.catalog.first(where: {
            String(localized: String.LocalizationValue($0.titleKey)) == viewModel.title
        })?.id ?? ""
    }

    // MARK: - Transcript (karaoke)

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            HStack(spacing: SpacingTokens.sp1) {
                Image(systemName: "music.mic")
                    .font(.body)
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .accessibilityHidden(true)
                Text("cultural.reader.transcript.title")
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Kid.ink)
            }

            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                ForEach(Array(viewModel.lines.enumerated()), id: \.element.id) { idx, line in
                    transcriptLine(line: line, idx: idx)
                }
            }
            .padding(SpacingTokens.sp4)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .fill(ColorTokens.Kid.surfaceAlt)
            )
        }
    }

    @ViewBuilder
    private func transcriptLine(
        line: CulturalContentModels.Open.LineViewModel,
        idx: Int
    ) -> some View {
        let isCurrent = idx == currentLineIdx && isPlaying
        let isPast = idx < currentLineIdx && isPlaying
        Text(line.text)
            .font(TypographyTokens.body(16))
            .foregroundStyle(
                isCurrent
                    ? ColorTokens.Brand.primary
                    : (isPast ? ColorTokens.Kid.inkMuted : ColorTokens.Kid.ink)
            )
            .fontWeight(isCurrent ? .semibold : .regular)
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, SpacingTokens.sp1)
            .padding(.horizontal, SpacingTokens.sp2)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.sm)
                    .fill(
                        isCurrent
                            ? ColorTokens.Brand.primary.opacity(0.1)
                            : Color.clear
                    )
            )
            .accessibilityLabel(Text(line.text))
            .accessibilityAddTraits(isCurrent ? .isHeader : [])
    }

    // MARK: - Controls

    private var controlsSection: some View {
        HStack(spacing: SpacingTokens.sp3) {
            Button {
                if isPlaying {
                    stopPlayback()
                } else {
                    startPlayback()
                }
            } label: {
                HStack(spacing: SpacingTokens.sp2) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .accessibilityHidden(true)
                    Text(isPlaying
                         ? String(localized: "cultural.reader.pause")
                         : String(localized: "cultural.reader.play"))
                        .font(TypographyTokens.callout())
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.button)
                        .fill(ColorTokens.Brand.primary)
                )
            }
            .accessibilityHint(Text("cultural.reader.play.hint"))

            Button {
                stopPlayback()
                currentLineIdx = 0
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title3)
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(ColorTokens.Brand.primary.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("cultural.reader.restart.a11y"))
        }
    }

    // MARK: - Playback (timer-based MVP)

    private func startPlayback() {
        isPlaying = true
        currentLineIdx = 0
        scheduleNextLine()
    }

    private func stopPlayback() {
        progressTimer?.invalidate()
        progressTimer = nil
        isPlaying = false
    }

    private func scheduleNextLine() {
        guard isPlaying, currentLineIdx < viewModel.lines.count else {
            stopPlayback()
            return
        }

        let line = viewModel.lines[currentLineIdx]
        let duration = max(line.endSeconds - line.startSeconds, 1.0)

        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(
            withTimeInterval: duration,
            repeats: false
        ) { _ in
            Task { @MainActor in
                guard isPlaying else { return }
                if currentLineIdx + 1 >= viewModel.lines.count {
                    stopPlayback()
                } else {
                    if reduceMotion {
                        currentLineIdx += 1
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentLineIdx += 1
                        }
                    }
                    scheduleNextLine()
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("CulturalContent / loaded") {
    CulturalContentView(childId: "preview-child")
        .environment(AppContainer.preview())
}
#endif
