import OSLog
import SwiftUI

// MARK: - ParentGuideViewModelHolder

@MainActor
@Observable
final class ParentGuideViewModelHolder: ParentGuideDisplayLogic {

    var loadVM: ParentGuideModels.Load.ViewModel?
    var readIds: Set<String> = []
    var favoriteIds: Set<String> = []

    func displayLoad(viewModel: ParentGuideModels.Load.ViewModel) async {
        self.loadVM = viewModel
        // Инициализация локальных множеств из ViewModel.
        var read: Set<String> = []
        var fav: Set<String> = []
        if let tip = viewModel.tipOfDay {
            if tip.isRead { read.insert(tip.id) }
            if tip.isFavorite { fav.insert(tip.id) }
        }
        for topic in viewModel.topics {
            for lesson in topic.lessons {
                if lesson.isRead { read.insert(lesson.id) }
                if lesson.isFavorite { fav.insert(lesson.id) }
            }
        }
        self.readIds = read
        self.favoriteIds = fav
    }

    func displayMarkRead(viewModel: ParentGuideModels.MarkRead.ViewModel) async {
        if viewModel.isRead {
            readIds.insert(viewModel.lessonId)
        } else {
            readIds.remove(viewModel.lessonId)
        }
    }

    func displayToggleFavorite(viewModel: ParentGuideModels.ToggleFavorite.ViewModel) async {
        if viewModel.isFavorite {
            favoriteIds.insert(viewModel.lessonId)
        } else {
            favoriteIds.remove(viewModel.lessonId)
        }
    }
}

// MARK: - ParentGuideView (Clean Swift: View)
//
// v29 Фаза 8, Функция 3 «Логопед для родителей».
//
// Layout:
//   1. Hero header
//   2. «Совет дня» — рекомендованная карточка-урок (HSLiquidGlassCard)
//   3. Темы — аккордеон уроков; рекомендованные помечены
//   4. Sheet с полным текстом урока + кнопка «Прочитано» + «В избранное»
//
// Accessibility:
//   • VoiceOver: карточки уроков — комбинированные labels
//   • Dynamic Type: ScrollView root, .lineLimit(nil)
//   • Reduced Motion: анимация аккордеона гейтится reduceMotion
//   • Touch targets: строки уроков ≥ 56pt, кнопки sheet ≥ 48pt
//   • Light + Dark: ColorTokens.Parent адаптируются

struct ParentGuideView: View {

    let childId: String

    @State private var holder = ParentGuideViewModelHolder()
    @State private var interactor: ParentGuideInteractor?
    @State private var presenter: ParentGuidePresenter?
    @State private var router: ParentGuideRouter?
    @State private var expandedTopics: Set<String> = []
    @State private var selectedLesson: ParentGuideModels.Load.LessonViewModel?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ParentGuide.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: SpacingTokens.sp5) {
                        if let viewModel = holder.loadVM {
                            heroSection(viewModel)
                            if let tip = viewModel.tipOfDay {
                                tipOfDaySection(tip)
                                    .hsScrollEffect(.scaleFade)
                            }
                            topicsSection(viewModel.topics)
                        } else {
                            loadingSection
                        }
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.vertical, SpacingTokens.sp4)
                }
            }
            .navigationTitle(Text("parentGuide.screen.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                    .accessibilityLabel(Text("parentGuide.close.a11y"))
                }
            }
            .sheet(item: $selectedLesson) { lesson in
                lessonSheet(lesson)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .task {
                await setupAndLoad()
            }
        }
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Hero

    private func heroSection(_ viewModel: ParentGuideModels.Load.ViewModel) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text(viewModel.headerTitle)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(viewModel.headerSubtitle)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 34))
                .foregroundStyle(ColorTokens.Brand.lilac)
                .accessibilityHidden(true)
        }
        .padding(SpacingTokens.sp4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Parent.surface)
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Tip of day

    private func tipOfDaySection(
        _ tip: ParentGuideModels.Load.LessonViewModel
    ) -> some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp4) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                HStack(spacing: SpacingTokens.sp2) {
                    Image(systemName: "sparkles")
                        .font(.body)
                        .foregroundStyle(ColorTokens.Brand.butter)
                        .accessibilityHidden(true)
                    Text("parentGuide.tipOfDay.label")
                        .font(TypographyTokens.caption(12).weight(.semibold))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .textCase(.uppercase)
                }

                Text(tip.title)
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(tip.summary)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text(tip.readLabel)
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Parent.inkSoft)
                    Spacer()
                    Text("parentGuide.tipOfDay.open")
                        .font(TypographyTokens.body(13).weight(.medium))
                        .foregroundStyle(ColorTokens.Brand.primary)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { openLesson(tip) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "parentGuide.tipOfDay.label") + ". " + tip.accessibilityLabel
        )
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Topics

    private func topicsSection(
        _ topics: [ParentGuideModels.Load.TopicViewModel]
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            Text("parentGuide.topics.sectionTitle")
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Parent.ink)

            ForEach(topics) { topic in
                topicCard(topic)
            }
        }
    }

    private func topicCard(
        _ topic: ParentGuideModels.Load.TopicViewModel
    ) -> some View {
        let isExpanded = expandedTopics.contains(topic.id)
        return VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            Button {
                toggleTopic(topic.id)
            } label: {
                HStack(spacing: SpacingTokens.sp3) {
                    Image(systemName: topic.symbolName)
                        .font(.body)
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(ColorTokens.Brand.primary.opacity(0.12)))
                        .accessibilityHidden(true)

                    Text(topic.title)
                        .font(TypographyTokens.body(15).weight(.medium))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Spacer()

                    Text("\(topic.lessons.count)")
                        .font(TypographyTokens.caption(11).monospacedDigit())
                        .foregroundStyle(ColorTokens.Parent.inkMuted)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.body)
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(
                isExpanded
                    ? Text("parentGuide.topic.collapse.hint")
                    : Text("parentGuide.topic.expand.hint")
            )
            .accessibilityAddTraits(isExpanded ? [.isButton, .isSelected] : .isButton)

            if isExpanded {
                VStack(spacing: SpacingTokens.sp2) {
                    ForEach(topic.lessons) { lesson in
                        lessonRow(lesson)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Parent.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .strokeBorder(ColorTokens.Parent.line, lineWidth: 1)
        )
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isExpanded)
    }

    private func lessonRow(
        _ lesson: ParentGuideModels.Load.LessonViewModel
    ) -> some View {
        let isRead = holder.readIds.contains(lesson.id)
        return Button {
            openLesson(lesson)
        } label: {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: isRead ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(
                        isRead ? ColorTokens.Brand.mint : ColorTokens.Parent.inkSoft
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: SpacingTokens.sp1) {
                        Text(lesson.title)
                            .font(TypographyTokens.body(14).weight(.medium))
                            .foregroundStyle(ColorTokens.Parent.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        if lesson.isRecommended {
                            Text("parentGuide.lesson.recommendedBadge")
                                .font(TypographyTokens.caption(9).weight(.bold))
                                .foregroundStyle(ColorTokens.Overlay.onAccent)
                                .padding(.horizontal, SpacingTokens.sp1)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(ColorTokens.Brand.lilac))
                        }
                    }
                    Text(lesson.summary)
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                if holder.favoriteIds.contains(lesson.id) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(ColorTokens.Brand.butter)
                        .accessibilityHidden(true)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.sp3)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.sm)
                    .fill(ColorTokens.Parent.bg)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(lesson.accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Lesson sheet

    private func lessonSheet(
        _ lesson: ParentGuideModels.Load.LessonViewModel
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
                VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                    HStack(spacing: SpacingTokens.sp2) {
                        Image(systemName: lesson.symbolName)
                            .font(.body)
                            .foregroundStyle(ColorTokens.Brand.primary)
                        Text(lesson.topicTitle)
                            .font(TypographyTokens.caption(12).weight(.medium))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .textCase(.uppercase)
                        Spacer()
                        Text(lesson.readLabel)
                            .font(TypographyTokens.caption(11))
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }

                    Text(lesson.title)
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(lesson.body)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: SpacingTokens.sp3) {
                    Button {
                        Task { await toggleFavorite(lesson.id) }
                    } label: {
                        Label {
                            Text(
                                holder.favoriteIds.contains(lesson.id)
                                    ? "parentGuide.lesson.removeFavorite"
                                    : "parentGuide.lesson.addFavorite"
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        } icon: {
                            Image(systemName: holder.favoriteIds.contains(lesson.id)
                                ? "star.fill" : "star")
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task { await markRead(lesson.id) }
                    } label: {
                        Label {
                            Text(
                                holder.readIds.contains(lesson.id)
                                    ? "parentGuide.lesson.alreadyRead"
                                    : "parentGuide.lesson.markRead"
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        } icon: {
                            Image(systemName: "checkmark")
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(holder.readIds.contains(lesson.id))
                }
            }
            .padding(SpacingTokens.screenEdge)
        }
        .background(ColorTokens.Parent.surface.ignoresSafeArea())
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ProgressView()
                .controlSize(.large)
            Text("parentGuide.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SpacingTokens.sp10)
    }

    // MARK: - Actions

    private func toggleTopic(_ id: String) {
        if expandedTopics.contains(id) {
            expandedTopics.remove(id)
        } else {
            expandedTopics.insert(id)
        }
    }

    private func openLesson(_ lesson: ParentGuideModels.Load.LessonViewModel) {
        selectedLesson = lesson
    }

    // MARK: - Wiring

    private func setupAndLoad() async {
        if interactor == nil {
            let presenter = ParentGuidePresenter(displayLogic: holder)
            let worker = ParentGuideWorker(childRepository: container.childRepository)
            let interactor = ParentGuideInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = ParentGuideRouter(dismissAction: { dismiss() })
        }
        await interactor?.load(request: .init(childId: childId))
    }

    private func markRead(_ id: String) async {
        await interactor?.markRead(request: .init(lessonId: id))
    }

    private func toggleFavorite(_ id: String) async {
        await interactor?.toggleFavorite(request: .init(lessonId: id))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("ParentGuide / loaded") {
    ParentGuideView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
