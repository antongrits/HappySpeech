import OSLog
import SwiftUI

// MARK: - AssignedHomeworkViewModelHolder

@MainActor
@Observable
final class AssignedHomeworkViewModelHolder: AssignedHomeworkDisplayLogic {

    var loadVM: AssignedHomeworkModels.Load.ViewModel?
    var familyLoadVM: AssignedHomeworkModels.FamilyLoad.ViewModel?
    var lastCreateMessage: String?
    var lastCreateSucceeded: Bool?
    var lastUpdateStatus: AssignedHomeworkModels.UpdateStatus.ViewModel?
    var lastDeleteMessage: String?
    var isLoading: Bool = true

    func displayLoad(viewModel: AssignedHomeworkModels.Load.ViewModel) async {
        self.loadVM = viewModel
        self.isLoading = false
    }

    func displayCreate(viewModel: AssignedHomeworkModels.Create.ViewModel) async {
        self.lastCreateMessage = viewModel.message
        self.lastCreateSucceeded = viewModel.didSucceed
    }

    func displayUpdateStatus(viewModel: AssignedHomeworkModels.UpdateStatus.ViewModel) async {
        self.lastUpdateStatus = viewModel
    }

    func displayDelete(viewModel: AssignedHomeworkModels.Delete.ViewModel) async {
        self.lastDeleteMessage = viewModel.message
    }

    func displayFamilyLoad(viewModel: AssignedHomeworkModels.FamilyLoad.ViewModel) async {
        self.familyLoadVM = viewModel
        self.isLoading = false
    }
}

// MARK: - AssignedHomeworkView (Clean Swift: View)
//
// v29 Фаза 8, Функция 4 «Домашнее задание от логопеда».
//
// Специалистский конструктор домашних заданий: выбор ребёнка, упражнений,
// числа повторов, срока, комментария родителю; список созданных заданий.
//
// Accessibility:
//   • Specialist circuit: компактнее, но интерактивные элементы ≥ 44pt
//   • VoiceOver: описательные labels строк и кнопок
//   • Dynamic Type: minimumScaleFactor
//   • Light + Dark: ColorTokens.Spec адаптируются

struct AssignedHomeworkView: View {

    let specialistId: String

    @State private var holder = AssignedHomeworkViewModelHolder()
    @State private var interactor: AssignedHomeworkInteractor?
    @State private var presenter: AssignedHomeworkPresenter?
    @State private var router: AssignedHomeworkRouter?

    // Конструктор задания.
    @State private var selectedChildId: String = ""
    @State private var selectedTemplateIds: Set<String> = []
    @State private var repeatsPerExercise: Int = 3
    @State private var dueInDays: Int = 3
    @State private var comment: String = ""

    // Подтверждение удаления задания.
    @State private var pendingDeleteAssignmentId: String?

    @Environment(\.exitToSpecialistHome) private var exitToSpecialistHome
    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "AssignedHomework.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                // РЕДИЗАЙН specialist-editor (2026-06-13): нейтрально-холодный
                // статичный холст `Spec.bg` (эталон #ECEEF2) + едва заметный
                // coral-radial в hero-зоне вместо тёплого kid-mesh.
                ZStack(alignment: .top) {
                    ColorTokens.Spec.bg
                    RadialGradient(
                        colors: [ColorTokens.Spec.accent.opacity(0.07), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 320
                    )
                }
                .ignoresSafeArea()
                .accessibilityHidden(true)
                .allowsHitTesting(false)

                if holder.isLoading {
                    loadingSection
                } else if let load = holder.loadVM {
                    contentSection(load)
                } else {
                    loadingSection
                }
            }
            .navigationTitle(Text("assignedHomework.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exitToSpecialistHome()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Spec.inkMuted)
                    }
                    .accessibilityLabel(Text("assignedHomework.close.a11y"))
                }
            }
            .task {
                await setup()
            }
            .confirmationDialog(
                Text("assignedHomework.delete.confirm.title"),
                isPresented: deleteDialogBinding,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    // Capture the id synchronously at tap time; SwiftUI clears the
                    // binding on dismissal, so the async delete must not re-read it.
                    let assignmentId = pendingDeleteAssignmentId
                    pendingDeleteAssignmentId = nil
                    if let assignmentId {
                        Task { await confirmDelete(assignmentId: assignmentId) }
                    }
                } label: {
                    Text("assignedHomework.delete.confirm.action")
                }
                Button(role: .cancel) {
                    pendingDeleteAssignmentId = nil
                } label: {
                    Text("assignedHomework.delete.confirm.cancel")
                }
            } message: {
                Text("assignedHomework.delete.confirm.message")
            }
        }
        .environment(\.circuitContext, .specialist)
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteAssignmentId != nil },
            set: { isPresented in
                if !isPresented { pendingDeleteAssignmentId = nil }
            }
        )
    }

    // MARK: - Content

    private func contentSection(
        _ load: AssignedHomeworkModels.Load.ViewModel
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sp5) {
                builderSection(load)
                Divider().background(ColorTokens.Spec.line)
                assignmentsSection(load)
            }
            .padding(SpacingTokens.screenEdge)
        }
    }

    // MARK: - Builder

    private func builderSection(
        _ load: AssignedHomeworkModels.Load.ViewModel
    ) -> some View {
        HSLiquidGlassCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
                Text("assignedHomework.builder.title")
                    .font(TypographyTokens.headline(18))
                    .foregroundStyle(ColorTokens.Spec.ink)

            // Ребёнок
            fieldLabel("assignedHomework.field.child")
            if load.children.isEmpty {
                Text("assignedHomework.noChildren")
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
            } else {
                Picker("assignedHomework.field.child", selection: $selectedChildId) {
                    Text("assignedHomework.pickChild").tag("")
                    ForEach(load.children) { child in
                        Text(child.name).tag(child.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(ColorTokens.Spec.accent)
                .accessibilityLabel(Text("assignedHomework.field.child"))
            }

            // Шаблоны
            fieldLabel("assignedHomework.field.exercises")
            VStack(spacing: SpacingTokens.sp2) {
                ForEach(load.templates) { template in
                    templateRow(template)
                }
            }

            // Повторы
            Stepper(
                value: $repeatsPerExercise,
                in: 1...10
            ) {
                Text(String(
                    format: String(localized: "assignedHomework.field.repeats"),
                    repeatsPerExercise
                ))
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Spec.ink)
            }
            .accessibilityLabel(Text(String(
                format: String(localized: "assignedHomework.field.repeats"),
                repeatsPerExercise
            )))

            // Срок
            Stepper(
                value: $dueInDays,
                in: 1...14
            ) {
                Text(String(
                    format: String(localized: "assignedHomework.field.dueDays"),
                    dueInDays
                ))
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Spec.ink)
            }
            .accessibilityLabel(Text(String(
                format: String(localized: "assignedHomework.field.dueDays"),
                dueInDays
            )))

            // Комментарий
            fieldLabel("assignedHomework.field.comment")
            TextField(
                String(localized: "assignedHomework.field.comment.placeholder"),
                text: $comment,
                axis: .vertical
            )
            .lineLimit(2...4)
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel(Text("assignedHomework.field.comment"))

            if let message = holder.lastCreateMessage,
               let succeeded = holder.lastCreateSucceeded {
                Label {
                    Text(message)
                        .font(TypographyTokens.body(14))
                } icon: {
                    Image(systemName: succeeded
                        ? "checkmark.circle.fill"
                        : "exclamationmark.triangle.fill")
                }
                .foregroundStyle(succeeded
                    ? ColorTokens.Semantic.success
                    : ColorTokens.Semantic.error)
                .accessibilityElement(children: .combine)
            }

            HSButton(
                String(localized: "assignedHomework.create.button"),
                style: .primary,
                size: .large,
                icon: "plus.circle.fill"
            ) {
                Task { await createAssignment() }
            }
            .disabled(!canCreate)
            .opacity(canCreate ? 1 : 0.5)
            .accessibilityHint(Text("assignedHomework.create.hint"))
            }
        }
    }

    private func templateRow(
        _ template: AssignedHomeworkModels.Load.TemplateOptionViewModel
    ) -> some View {
        Button {
            if selectedTemplateIds.contains(template.id) {
                selectedTemplateIds.remove(template.id)
            } else if selectedTemplateIds.count < 4 {
                selectedTemplateIds.insert(template.id)
            }
        } label: {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: selectedTemplateIds.contains(template.id)
                    ? "checkmark.square.fill"
                    : "square")
                    .foregroundStyle(selectedTemplateIds.contains(template.id)
                        ? ColorTokens.Spec.accent
                        : ColorTokens.Spec.inkMuted)
                Text(template.name)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(template.name))
        .accessibilityAddTraits(
            selectedTemplateIds.contains(template.id) ? [.isButton, .isSelected] : .isButton
        )
    }

    private func fieldLabel(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(TypographyTokens.caption(12))
            .foregroundStyle(ColorTokens.Spec.inkMuted)
            .textCase(.uppercase)
    }

    // MARK: - Assignments list

    private func assignmentsSection(
        _ load: AssignedHomeworkModels.Load.ViewModel
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            Text("assignedHomework.list.title")
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Spec.ink)

            if load.assignments.isEmpty {
                Text(load.emptyStateText)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
            } else {
                ForEach(Array(load.assignments.enumerated()), id: \.element.id) { index, row in
                    assignmentRow(row)
                        .scrollTransition(.animated(reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.85))) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0)
                                .scaleEffect(phase.isIdentity ? 1 : 0.96)
                        }
                        .hsParallaxTile(factor: 0.15)
                        .zIndex(Double(load.assignments.count - index))
                }
            }
        }
    }

    private func assignmentRow(
        _ row: AssignedHomeworkModels.Load.AssignmentRowViewModel
    ) -> some View {
        HSCard(style: .flat, padding: SpacingTokens.sp3) {
            HStack(spacing: SpacingTokens.sp3) {
                // Status icon tile — coral when pending, success-green when complete
                ZStack {
                    RoundedRectangle(cornerRadius: RadiusTokens.sm)
                        .fill((row.isComplete
                            ? ColorTokens.Semantic.success
                            : ColorTokens.Spec.accent).opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: row.isComplete
                        ? "checkmark.seal.fill"
                        : "tray.full.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(row.isComplete
                            ? ColorTokens.Semantic.success
                            : ColorTokens.Spec.accent)
                        .hsSymbolEffect(.bounce, value: row.isComplete)
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.childName)
                        .font(TypographyTokens.headline(15))
                        .foregroundStyle(ColorTokens.Spec.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(row.exerciseCountLabel + " · " + row.dueLabel)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Spec.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(row.statusLabel)
                        .font(TypographyTokens.caption(12).weight(.semibold))
                        .foregroundStyle(row.isComplete
                            ? ColorTokens.Semantic.success
                            : ColorTokens.Spec.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(row.accessibilityLabel + ". " + row.statusLabel))
        .contextMenu {
            Button(role: .destructive) {
                pendingDeleteAssignmentId = row.id
            } label: {
                Label {
                    Text("assignedHomework.delete.action")
                } icon: {
                    Image(systemName: "trash")
                }
            }
        }
        .accessibilityAction(named: Text("assignedHomework.delete.action")) {
            pendingDeleteAssignmentId = row.id
        }
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ProgressView()
                .controlSize(.large)
            Text("assignedHomework.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private var canCreate: Bool {
        !selectedChildId.isEmpty && !selectedTemplateIds.isEmpty
    }

    // MARK: - Wiring

    private func setup() async {
        if interactor == nil {
            let presenter = AssignedHomeworkPresenter(displayLogic: holder)
            let worker = AssignedHomeworkWorker(
                childRepository: container.childRepository,
                homeworkRepository: container.homeworkRepository,
                notificationService: container.notificationService
            )
            let interactor = AssignedHomeworkInteractor(
                specialistId: specialistId,
                worker: worker,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = AssignedHomeworkRouter(dismissAction: { exitToSpecialistHome() })
        }
        await interactor?.load(request: .init(specialistId: specialistId))
    }

    private func createAssignment() async {
        await interactor?.create(request: .init(
            childId: selectedChildId,
            templateRaws: Array(selectedTemplateIds),
            repeatsPerExercise: repeatsPerExercise,
            dueInDays: dueInDays,
            comment: comment
        ))
        if holder.lastCreateSucceeded == true {
            selectedTemplateIds = []
            comment = ""
        }
    }

    private func confirmDelete(assignmentId: String) async {
        await interactor?.delete(request: .init(assignmentId: assignmentId))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("AssignedHomework / specialist") {
    AssignedHomeworkView(specialistId: "specialist-default")
        .environment(AppContainer.preview())
}
#endif
