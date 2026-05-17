import AVKit
import OSLog
import SwiftUI

// MARK: - HelpCenterViewModelHolder

@MainActor
@Observable
final class HelpCenterViewModelHolder: HelpCenterDisplayLogic {

    var loadVM: HelpCenterModels.Load.ViewModel?
    var expandedIds: Set<String> = []
    var videoDetail: HelpCenterModels.SelectVideo.ViewModel?
    var toastMessage: String?
    var showToast: Bool = false

    func displayLoad(viewModel: HelpCenterModels.Load.ViewModel) async {
        self.loadVM = viewModel
    }

    func displayToggleFAQ(viewModel: HelpCenterModels.ToggleFAQ.ViewModel) async {
        if viewModel.expanded {
            expandedIds.insert(viewModel.entryId)
        } else {
            expandedIds.remove(viewModel.entryId)
        }
    }

    func displaySelectVideo(viewModel: HelpCenterModels.SelectVideo.ViewModel) async {
        self.videoDetail = viewModel
    }

    func displayContactSupport(viewModel: HelpCenterModels.ContactSupport.ViewModel) async {
        self.toastMessage = viewModel.toastMessage
        self.showToast = true
    }
}

// MARK: - HelpCenterView (Clean Swift: View)
//
// Block AE v21 — экран справки.
//
// Layout:
//   1. Hero header (title + subtitle)
//   2. FAQ accordion — 5 категорий, по 2-3 вопроса в каждой
//   3. Video tutorials grid — 5 туториалов (резюме + длительность)
//   4. Contact CTA — переход в LogopedistChat
//
// Accessibility:
//   • VoiceOver: FAQ-секции имеют комбинированные labels;
//     каждая видео-карта — описательный label;
//   • Dynamic Type: ScrollView root, .lineLimit(nil)
//   • Reduced Motion: убираем pulse-анимацию CTA
//   • Touch targets: FAQ row ≥ 44pt, video cell ≥ 64pt
//   • Light + Dark: ColorTokens.Parent.bg / surface адаптируются.

struct HelpCenterView: View {

    @State private var holder = HelpCenterViewModelHolder()
    @State private var interactor: HelpCenterInteractor?
    @State private var presenter: HelpCenterPresenter?
    @State private var router: HelpCenterRouter?
    @State private var showVideoSheet: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "HelpCenter.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: SpacingTokens.sp5) {
                        if let viewModel = holder.loadVM {
                            heroSection
                            faqSection(viewModel: viewModel)
                            videoSection(viewModel: viewModel.videoSection)
                            contactSection(viewModel: viewModel)
                        } else {
                            loadingSection
                        }
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.vertical, SpacingTokens.sp4)
                }
            }
            .navigationTitle(Text("helpCenter.screen.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                    .accessibilityLabel(Text("helpCenter.close.a11y"))
                }
            }
            .sheet(isPresented: $showVideoSheet) {
                if let detail = holder.videoDetail {
                    videoSheet(detail)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
            }
            .overlay(alignment: .top) {
                if holder.showToast, let toast = holder.toastMessage {
                    toastBanner(text: toast)
                        .padding(.top, SpacingTokens.sp2)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.35), value: holder.showToast)
            .task {
                await setupAndLoad()
            }
        }
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text("helpCenter.hero.title")
                        .font(TypographyTokens.title(22))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Text("helpCenter.hero.subtitle")
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(nil)
                }
                Spacer()
                Image(systemName: "questionmark.bubble.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .accessibilityHidden(true)
            }
        }
        .padding(SpacingTokens.sp4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Parent.surface)
        )
    }

    // MARK: - FAQ

    @ViewBuilder
    private func faqSection(viewModel: HelpCenterModels.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            Text("helpCenter.faq.section.title")
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Parent.ink)

            ForEach(viewModel.categories) { category in
                categorySection(category)
            }
        }
    }

    @ViewBuilder
    private func categorySection(_ category: HelpCenterModels.Load.CategoryViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: category.symbolName)
                    .font(.body)
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(ColorTokens.Brand.primary.opacity(0.12)))
                    .accessibilityHidden(true)

                Text(category.title)
                    .font(TypographyTokens.body(15).weight(.medium))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.leading, SpacingTokens.sp1)
            .accessibilityElement(children: .combine)

            VStack(spacing: SpacingTokens.sp2) {
                ForEach(category.entries) { entry in
                    faqRow(entry)
                }
            }
        }
    }

    @ViewBuilder
    private func faqRow(_ entry: HelpCenterModels.Load.FAQEntryViewModel) -> some View {
        let isExpanded = holder.expandedIds.contains(entry.id)
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            Button {
                Task { await toggleFAQ(entry.id) }
            } label: {
                HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                    Text(entry.question)
                        .font(TypographyTokens.body(14).weight(.medium))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.body)
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(
                isExpanded
                    ? Text("helpCenter.faq.collapse.hint")
                    : Text("helpCenter.faq.expand.hint")
            )
            .accessibilityAddTraits(isExpanded ? [.isButton, .isSelected] : .isButton)

            if isExpanded {
                Text(entry.answer)
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.sm)
                .fill(ColorTokens.Parent.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.sm)
                .strokeBorder(ColorTokens.Parent.line, lineWidth: 1)
        )
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isExpanded)
    }

    // MARK: - Video

    @ViewBuilder
    private func videoSection(viewModel: HelpCenterModels.Load.VideoSectionViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.title)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Parent.ink)

                Text(viewModel.subtitle)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(nil)
            }

            if viewModel.videos.isEmpty {
                Text("helpCenter.video.empty")
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .padding(SpacingTokens.sp4)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.sm)
                            .fill(ColorTokens.Parent.surface)
                    )
            } else {
                VStack(spacing: SpacingTokens.sp2) {
                    ForEach(viewModel.videos) { video in
                        videoCell(video)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func videoCell(_ cell: HelpCenterModels.Load.VideoCellViewModel) -> some View {
        Button {
            Task { await selectVideo(id: cell.id) }
        } label: {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: cell.symbolName)
                    .font(.title3)
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .frame(width: 56, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.sm)
                            .fill(ColorTokens.Brand.primary)
                    )
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.caption2)
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .padding(SpacingTokens.micro)
                            .background(Circle().fill(ColorTokens.Overlay.onAccent))
                            .offset(x: 18, y: 18)
                            .accessibilityHidden(true)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(cell.title)
                        .font(TypographyTokens.body(14).weight(.medium))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.leading)

                    Text(cell.description)
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Text(cell.durationLabel)
                    .font(TypographyTokens.caption(11).monospacedDigit())
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .padding(.horizontal, SpacingTokens.sp2)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(ColorTokens.Parent.bg)
                    )
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.sp3)
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.sm)
                    .fill(ColorTokens.Parent.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.sm)
                    .strokeBorder(ColorTokens.Parent.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(cell.accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Video sheet

    @ViewBuilder
    private func videoSheet(_ detail: HelpCenterModels.SelectVideo.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp3) {
            HStack {
                Text(detail.videoTitle)
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Spacer()
                Text(detail.durationLabel)
                    .font(TypographyTokens.caption(12).monospacedDigit())
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp4)

            if let url = videoURL(for: detail.resourceName) {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.md))
                    .padding(.horizontal, SpacingTokens.sp3)
            } else {
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .fill(ColorTokens.Parent.bg)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .overlay(
                        Text("helpCenter.video.unavailable")
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    )
                    .padding(.horizontal, SpacingTokens.sp3)
            }

            Text(detail.videoDescription)
                .font(TypographyTokens.body(13))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, SpacingTokens.screenEdge)

            Spacer()
        }
        .background(ColorTokens.Parent.surface.ignoresSafeArea())
    }

    // MARK: - Contact

    @ViewBuilder
    private func contactSection(viewModel: HelpCenterModels.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                Image(systemName: "person.line.dotted.person.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle().fill(ColorTokens.Brand.primary.opacity(0.12))
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text("helpCenter.contact.title")
                        .font(TypographyTokens.body(15).weight(.medium))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Text(viewModel.contactDescription)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                Task { await contactSupport() }
            } label: {
                Label {
                    Text(viewModel.contactCta)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                } icon: {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                }
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint(Text("helpCenter.contact.hint"))
        }
        .padding(SpacingTokens.sp4)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Parent.surface)
        )
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ProgressView()
                .controlSize(.large)
            Text("helpCenter.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SpacingTokens.sp10)
    }

    // MARK: - Toast

    @ViewBuilder
    private func toastBanner(text: String) -> some View {
        Text(text)
            .font(TypographyTokens.caption(13))
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .padding(.horizontal, SpacingTokens.sp4)
            .padding(.vertical, SpacingTokens.sp2)
            .background(Capsule().fill(ColorTokens.Brand.primary))
            .shadow(color: ColorTokens.Overlay.shadowMedium, radius: 8, y: 4)
            .task {
                try? await Task.sleep(for: .seconds(2.0))
                holder.showToast = false
            }
    }

    // MARK: - Helpers

    private func videoURL(for resourceName: String) -> URL? {
        if let url = Bundle.main.url(
            forResource: resourceName,
            withExtension: "mp4",
            subdirectory: "tutorials"
        ) {
            return url
        }
        return Bundle.main.url(forResource: resourceName, withExtension: "mp4")
    }

    // MARK: - Wiring

    private func setupAndLoad() async {
        if interactor == nil {
            let presenter = HelpCenterPresenter(displayLogic: holder)
            let interactor = HelpCenterInteractor(
                faqWorker: FAQRepositoryWorker(),
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = HelpCenterRouter(dismissAction: { dismiss() })
        }
        await interactor?.load(request: .init())
    }

    private func toggleFAQ(_ id: String) async {
        await interactor?.toggleFAQ(request: .init(entryId: id))
    }

    private func selectVideo(id: String) async {
        await interactor?.selectVideo(request: .init(videoId: id))
        showVideoSheet = true
    }

    private func contactSupport() async {
        await interactor?.contactSupport(request: .init())
        router?.routeToLogopedistChat()
    }
}

// MARK: - Preview

#if DEBUG
#Preview("HelpCenter / loaded") {
    HelpCenterView()
        .environment(AppContainer.preview())
}
#endif
