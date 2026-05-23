import OSLog
import SwiftUI

// MARK: - Holder

@MainActor
@Observable
final class VoiceJournalViewModelHolder: VoiceJournalDisplayLogic {

    var loadVM: VoiceJournalModels.LoadEntries.ViewModel?
    var isRecording: Bool = false
    var errorMessage: String?

    func displayLoadEntries(viewModel: VoiceJournalModels.LoadEntries.ViewModel) async {
        self.loadVM = viewModel
    }

    func displayRecordingStarted() async {
        self.isRecording = true
        self.errorMessage = nil
    }

    func displayRecordingFailed(message: String) async {
        self.isRecording = false
        self.errorMessage = message
    }

    func displayRecordingSaved(
        viewModel: VoiceJournalModels.LoadEntries.ViewModel
    ) async {
        self.isRecording = false
        self.loadVM = viewModel
    }
}

// MARK: - View

struct VoiceJournalView: View {

    let childId: String

    @State private var holder = VoiceJournalViewModelHolder()
    @State private var interactor: VoiceJournalInteractor?
    @State private var presenter: VoiceJournalPresenter?
    @State private var router: VoiceJournalRouter?
    @State private var didBootstrap = false
    @State private var isRecordingSheetPresented: Bool = false
    @State private var newEntryTitle: String = ""

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "VoiceJournal.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()
                if let vm = holder.loadVM {
                    if vm.isEmpty {
                        emptyState(vm)
                    } else {
                        list(vm)
                    }
                } else {
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .navigationTitle(Text("voice.journal.nav.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $isRecordingSheetPresented) {
                recordingSheet
            }
            .task { await bootstrap() }
            .onDisappear { interactor?.stopPlayback() }
        }
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Empty state

    private func emptyState(_ vm: VoiceJournalModels.LoadEntries.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp3) {
            LyalyaMascotView(state: .idle, size: 80)
                .accessibilityHidden(true)
            Text(vm.emptyTitle)
                .font(TypographyTokens.title(20))
                .foregroundStyle(ColorTokens.Parent.ink)
                .multilineTextAlignment(.center)
            Text(vm.emptyBody)
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
            HSButton(
                vm.emptyCtaTitle,
                style: .primary,
                size: .large,
                icon: "mic.fill"
            ) {
                openRecordingSheet()
            }
        }
        .padding(SpacingTokens.screenEdge)
        .frame(maxWidth: .infinity)
    }

    // MARK: - List

    private func list(_ vm: VoiceJournalModels.LoadEntries.ViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: SpacingTokens.sp2) {
                ForEach(vm.rows) { row in
                    rowView(row)
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.vertical, SpacingTokens.sp3)
        }
    }

    private func rowView(_ row: VoiceJournalModels.LoadEntries.Row) -> some View {
        HSCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                ZStack {
                    Circle()
                        .fill(ColorTokens.Brand.lilac.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ColorTokens.Brand.lilac)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    HStack(spacing: SpacingTokens.sp2) {
                        Text(row.dateText)
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                        Text("·")
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                            .accessibilityHidden(true)
                        Text(row.durationText)
                            .font(TypographyTokens.caption(12).monospacedDigit())
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }
                }
                Spacer(minLength: 0)
                Button {
                    Task { await play(row.entry) }
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(ColorTokens.Brand.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("voice.journal.row.play"))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(row.accessibilityLabel))
        .contextMenu {
            Button(role: .destructive) {
                Task { await delete(row.entry) }
            } label: {
                Label("common.delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Recording sheet

    private var recordingSheet: some View {
        NavigationStack {
            VStack(spacing: SpacingTokens.sp4) {
                Spacer(minLength: 0)
                ZStack {
                    Circle()
                        .fill(
                            holder.isRecording
                                ? ColorTokens.Semantic.error.opacity(0.18)
                                : ColorTokens.Brand.primary.opacity(0.18)
                        )
                        .frame(width: 160, height: 160)
                        .scaleEffect(holder.isRecording && !reduceMotion ? 1.05 : 1.0)
                        .animation(
                            holder.isRecording && !reduceMotion
                                ? .easeInOut(duration: 0.9).repeatForever()
                                : .default,
                            value: holder.isRecording
                        )
                    Image(systemName: holder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(
                            holder.isRecording
                                ? ColorTokens.Semantic.error
                                : ColorTokens.Brand.primary
                        )
                        .accessibilityHidden(true)
                }
                Text(holder.isRecording
                     ? String(localized: "voice.journal.sheet.recording")
                     : String(localized: "voice.journal.sheet.idle"))
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .multilineTextAlignment(.center)
                TextField(
                    String(localized: "voice.journal.sheet.title.placeholder"),
                    text: $newEntryTitle
                )
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, SpacingTokens.sp4)
                    .submitLabel(.done)
                if let errorMessage = holder.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Semantic.error)
                        .multilineTextAlignment(.center)
                }
                Spacer(minLength: 0)
                VStack(spacing: SpacingTokens.sp2) {
                    HSButton(
                        holder.isRecording
                            ? String(localized: "voice.journal.sheet.save")
                            : String(localized: "voice.journal.sheet.start"),
                        style: holder.isRecording ? .primary : .primary,
                        size: .large,
                        icon: holder.isRecording ? "checkmark.circle.fill" : "mic.fill"
                    ) {
                        Task { await toggleRecording() }
                    }
                    HSButton(
                        String(localized: "common.cancel"),
                        style: .ghost,
                        size: .medium
                    ) {
                        Task { await cancelRecording() }
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp4)
            }
            .padding(.top, SpacingTokens.sp4)
            .frame(maxWidth: .infinity)
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle(Text("voice.journal.sheet.nav"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
            }
            .accessibilityLabel(Text("common.close"))
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                openRecordingSheet()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(ColorTokens.Brand.primary)
            }
            .accessibilityLabel(Text("voice.journal.toolbar.add"))
        }
    }

    // MARK: - Actions

    private func openRecordingSheet() {
        newEntryTitle = ""
        holder.errorMessage = nil
        isRecordingSheetPresented = true
    }

    private func toggleRecording() async {
        guard let interactor else { return }
        if holder.isRecording {
            await interactor.stopRecording(.init(
                childId: childId,
                title: newEntryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            ))
            isRecordingSheetPresented = false
            newEntryTitle = ""
        } else {
            await interactor.startRecording(.init())
        }
    }

    private func cancelRecording() async {
        interactor?.cancelRecording()
        holder.isRecording = false
        isRecordingSheetPresented = false
        newEntryTitle = ""
    }

    private func play(_ entry: VoiceJournalEntry) async {
        _ = await interactor?.play(.init(entry: entry))
    }

    private func delete(_ entry: VoiceJournalEntry) async {
        await interactor?.delete(.init(entry: entry))
    }

    // MARK: - Lifecycle

    private func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        let presenter = VoiceJournalPresenter(displayLogic: holder)
        let router = VoiceJournalRouter()
        router.coordinator = coordinator
        let interactor = VoiceJournalInteractor(
            presenter: presenter,
            router: router,
            realmActor: container.realmActor,
            childId: childId
        )
        self.presenter = presenter
        self.router = router
        self.interactor = interactor
        await interactor.loadEntries(.init(childId: childId))
    }
}

// MARK: - Preview

#Preview("VoiceJournal — Light") {
    VoiceJournalView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("VoiceJournal — Dark") {
    VoiceJournalView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
