import SwiftUI

// MARK: - SpecialistCaseNotesView

struct SpecialistCaseNotesView: View {

    let childId: String
    let specialistId: String

    @State private var interactor: SpecialistCaseNotesInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM, HH:mm"
        return f
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                HSMeshGradientBackground(palette: .calm, animated: !reduceMotion)
                    .ignoresSafeArea()
                content
            }
            .navigationTitle(Text(String(localized: "specialistNotes.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Spec.inkMuted)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
            .task {
                if interactor == nil {
                    interactor = SpecialistCaseNotesInteractor(
                        childId: childId,
                        specialistId: specialistId
                    )
                }
            }
            .sheet(isPresented: Binding(
                get: { interactor?.state.isAddingNote ?? false },
                set: { newValue in
                    if !newValue { interactor?.cancelAdding() }
                }
            )) {
                if let interactor {
                    addNoteSheet(interactor: interactor)
                }
            }
        }
        .environment(\.circuitContext, .specialist)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            ScrollView {
                VStack(spacing: SpacingTokens.sp4) {
                    hero(state: interactor.state)
                    notesList(interactor: interactor)
                    cta(interactor: interactor)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp6)
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private func hero(state: SpecialistCaseNotesModels.ViewState) -> some View {
        HSLiquidGlassCard(style: .elevated) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "specialistNotes.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "specialistNotes.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                HStack(spacing: SpacingTokens.tiny) {
                    Image(systemName: "note.text")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.Spec.accent)
                        .hsSymbolEffect(.bounce, value: state.notes.count)
                    Text("Всего заметок: \(state.notes.count)")
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Spec.accent)
                }
                .padding(.top, 2)
            }
        }
    }

    private func notesList(interactor: SpecialistCaseNotesInteractor) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            if interactor.state.notes.isEmpty {
                HSCard(style: .flat) {
                    Text("Заметок пока нет")
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Spec.inkMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, SpacingTokens.sp3)
                }
            } else {
                ForEach(interactor.state.notes) { note in
                    noteCard(note)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.92).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
        }
        .animation(
            reduceMotion ? nil : MotionTokens.settleSpring,
            value: interactor.state.notes.count
        )
    }

    private func noteCard(_ note: SpecialistCaseNotesModels.Note) -> some View {
        HSCard(style: .flat) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.Spec.accent)
                    Text(Self.dateFormatter.string(from: note.date))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Spec.inkMuted)
                    Spacer()
                }
                Text(note.body)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func cta(interactor: SpecialistCaseNotesInteractor) -> some View {
        HSButton(
            String(localized: "specialistNotes.cta.action"),
            style: .primary,
            size: .large,
            icon: "plus"
        ) {
            hapticService.impact(.light)
            interactor.startAdding()
        }
    }

    private func addNoteSheet(interactor: SpecialistCaseNotesInteractor) -> some View {
        NavigationStack {
            VStack(spacing: SpacingTokens.sp3) {
                TextEditor(text: Binding(
                    get: { interactor.state.draftBody },
                    set: { interactor.state.draftBody = $0 }
                ))
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Spec.ink)
                .scrollContentBackground(.hidden)
                .padding(SpacingTokens.sp2)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ColorTokens.Spec.surface)
                )
                .frame(minHeight: 220)
                Spacer()
                HSButton(
                    "Сохранить заметку",
                    style: .primary,
                    size: .large,
                    icon: "checkmark"
                ) {
                    hapticService.notification(.success)
                    interactor.saveNote()
                }
                .disabled(interactor.state.draftBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(interactor.state.draftBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            }
            .padding(SpacingTokens.sp4)
            .background(
                HSMeshGradientBackground(palette: .calm, animated: !reduceMotion)
                    .ignoresSafeArea()
            )
            .navigationTitle(Text("Новая заметка"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") {
                        interactor.cancelAdding()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .environment(\.circuitContext, .specialist)
    }
}

// MARK: - Preview

#Preview("SpecialistCaseNotes — Light") {
    SpecialistCaseNotesView(childId: "preview-child-1", specialistId: "local-parent")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("SpecialistCaseNotes — Dark") {
    SpecialistCaseNotesView(childId: "preview-child-1", specialistId: "local-parent")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
