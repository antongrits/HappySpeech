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

    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator

    private static let logger = Logger(
        subsystem: "ru.happyspeech", category: "Diary.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()
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
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .task { await bootstrap() }
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
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(ColorTokens.Brand.lilac)
            Text("diary.optIn.title")
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Parent.ink)
                .multilineTextAlignment(.center)
            Text("diary.optIn.body")
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
            Button {
                holder.optInAccepted = true
            } label: {
                Text("diary.optIn.accept")
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
        .padding(SpacingTokens.screenEdge)
    }

    // MARK: - Empty state

    private var emptyStateSection: some View {
        VStack(spacing: SpacingTokens.sp4) {
            Image(systemName: "film.stack")
                .font(.system(size: 64))
                .foregroundStyle(ColorTokens.Parent.inkSoft)
            Text("diary.empty.title")
                .font(TypographyTokens.title(20))
                .foregroundStyle(ColorTokens.Parent.ink)
            Text("diary.empty.body")
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
            recordButton
        }
        .padding(SpacingTokens.screenEdge)
    }

    // MARK: - List

    private func clipsListSection(_ listVM: SpeechGrowthDiaryModels.List.ViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: SpacingTokens.sp3) {
                ForEach(listVM.clips) { row in
                    clipRow(row)
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.vertical, SpacingTokens.sp3)

            recordButton
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp5)
        }
    }

    private func clipRow(_ row: SpeechGrowthDiaryModels.List.ClipRow) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "video.fill")
                    .foregroundStyle(ColorTokens.Brand.lilac)
                Text(row.recordedAtLabel)
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Parent.ink)
                Spacer()
                Text(row.durationLabel)
                    .font(TypographyTokens.caption(12).monospacedDigit())
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
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
            }
            HStack(spacing: SpacingTokens.sp2) {
                Button {
                    Task { await issueShare(for: row.id) }
                } label: {
                    Label("diary.button.share", systemImage: "square.and.arrow.up")
                        .font(TypographyTokens.caption(13))
                        .foregroundStyle(ColorTokens.Brand.primary)
                }
                .buttonStyle(.plain)
                Button {
                    Task { await interactor?.deleteClip(id: row.id) }
                } label: {
                    Label("diary.button.delete", systemImage: "trash")
                        .font(TypographyTokens.caption(13))
                        .foregroundStyle(ColorTokens.Semantic.error)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(SpacingTokens.sp3)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Parent.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .strokeBorder(ColorTokens.Parent.line, lineWidth: 1)
        )
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
            durationSeconds: clipDuration(url: url),
            topicTag: pendingTag,
            targetSound: pendingSound,
            note: pendingNote
        )
        pendingNote = ""
        pendingSound = ""
    }

    private func clipDuration(url: URL) -> Double {
        let asset = AVURLAsset(url: url)
        return CMTimeGetSeconds(asset.duration)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                dismiss()
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
