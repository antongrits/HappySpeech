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

struct SpeechGrowthDiaryView: View {

    let childId: String

    @State private var holder = SpeechGrowthDiaryViewModelHolder()
    @State private var interactor: SpeechGrowthDiaryInteractor?
    @State private var presenter: SpeechGrowthDiaryPresenter?
    @State private var router: SpeechGrowthDiaryRouter?
    @State private var didBootstrap = false
    @State private var pendingNote: String = ""
    @State private var pendingTag: String = "звук"
    @State private var pendingSound: String = ""

    @Environment(\.exitToParentHome) private var exitToParentHome
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator

    @State private var contentAppeared = false

    private static let logger = Logger(
        subsystem: "ru.happyspeech", category: "Diary.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()

                // kid-diary-journal: тёплый статичный mesh — дневник-скрапбук
                // (вместо холодного calm), но контур остаётся parent-gated.
                HSMeshGradientBackground(palette: .kidWarm, animated: false)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.14 : 0.22)
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)

                if !holder.optInAccepted {
                    optInSection
                } else if let listVM = holder.listVM {
                    if listVM.isEmpty {
                        emptyStateSection
                    } else {
                        clipsListSection(listVM)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(Text("diary.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await bootstrap() }
            .onAppear {
                withAnimation(reduceMotion ? .none : MotionTokens.settleSpring) {
                    contentAppeared = true
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

    // MARK: - Opt-in

    private var optInSection: some View {
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
                        Text("diary.optIn.title")
                            .font(TypographyTokens.title(20))
                            .foregroundStyle(ColorTokens.Parent.ink)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .allowsTightening(true)
                    }
                    Text("diary.optIn.body")
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
                Text("diary.optIn.accept")
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
        .opacity(contentAppeared ? 1 : 0)
        .animation(reduceMotion ? .none : MotionTokens.settleSpring, value: contentAppeared)
    }

    // MARK: - Empty state

    private var emptyStateSection: some View {
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

    // MARK: - List

    private func clipsListSection(_ listVM: SpeechGrowthDiaryModels.List.ViewModel) -> some View {
        ScrollView {
            VStack(spacing: SpacingTokens.sp3) {
                mascotBubble
                sectionLabel("diary.section.timeline")
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp3)

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
                        .hsParallaxTile(factor: 0.18)
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

    // kid-diary-journal: Ляля с тёплым пузырём-подсказкой над лентой записей.
    private var mascotBubble: some View {
        HStack(alignment: .bottom, spacing: SpacingTokens.sp2) {
            LyalyaMascotView(state: .encouraging, size: 52)
                .accessibilityHidden(true)
            HSCard(style: .elevated, padding: SpacingTokens.sp3) {
                Text("diary.mascot.bubble")
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func sectionLabel(_ key: LocalizedStringKey) -> some View {
        HStack(spacing: SpacingTokens.tiny) {
            Capsule()
                .fill(ColorTokens.Brand.primaryLo)
                .frame(width: 18, height: 3)
            Text(key)
                .font(TypographyTokens.caption(13).weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 2)
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
                        .lineLimit(2)
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
                    if !row.topicTag.isEmpty {
                        tagPill(row.topicTag)
                    }
                    if !row.targetSound.isEmpty {
                        tagPill("/\(row.targetSound)/")
                    }
                    if row.isShared {
                        tagPill(row.isShareExpired ? "Истёк" : "Расшарено",
                                tint: row.isShareExpired
                                      ? ColorTokens.Semantic.warning
                                      : ColorTokens.Semantic.success)
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
                        Label("diary.button.share", systemImage: "square.and.arrow.up")
                            .font(TypographyTokens.caption(13))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    Button {
                        Task { await interactor?.deleteClip(id: row.id) }
                    } label: {
                        Label("diary.button.delete", systemImage: "trash")
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
            .background(
                Capsule().fill(tint.opacity(0.18))
            )
            .foregroundStyle(tint)
    }

    private var recordButton: some View {
        Button {
            holder.pickerSheetActive = true
        } label: {
            Label("diary.button.record", systemImage: "video.badge.plus")
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
            Text("diary.share.title")
                .font(TypographyTokens.title(20))
                .foregroundStyle(ColorTokens.Parent.ink)
            if let shareVM = holder.shareVM {
                Text("diary.share.expires")
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                Text(shareVM.expiresAtLabel)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Parent.ink)
                Text(shareVM.token)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(ColorTokens.Parent.ink)
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
                    Label("diary.share.copy", systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .padding(SpacingTokens.screenEdge)
        .presentationDetents([.medium])
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

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                exitToParentHome()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
            }
            .accessibilityLabel(Text("diary.close.a11y"))
        }
    }

    // MARK: - Bootstrap

    private func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        let presenter = SpeechGrowthDiaryPresenter(displayLogic: holder)
        let interactor = SpeechGrowthDiaryInteractor(
            presenter: presenter,
            realmActor: container.realmActor,
            childId: childId
        )
        let router = SpeechGrowthDiaryRouter()
        router.coordinator = coordinator
        self.presenter = presenter
        self.interactor = interactor
        self.router = router
        await interactor.loadClips()
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
