import OSLog
import SwiftUI

// MARK: - AssignedHomeworkViewModelHolder

@MainActor
@Observable
final class AssignedHomeworkViewModelHolder: AssignedHomeworkDisplayLogic {

    var loadVM: AssignedHomeworkModels.Load.ViewModel?
    var lastCreateMessage: String?
    var lastCreateSucceeded: Bool?
    var isLoading: Bool = true

    func displayLoad(viewModel: AssignedHomeworkModels.Load.ViewModel) async {
        self.loadVM = viewModel
        self.isLoading = false
    }

    func displayCreate(viewModel: AssignedHomeworkModels.Create.ViewModel) async {
        self.lastCreateMessage = viewModel.message
        self.lastCreateSucceeded = viewModel.didSucceed
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

    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "AssignedHomework.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Spec.bg.ignoresSafeArea()

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
                        dismiss()
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
        }
        .environment(\.circuitContext, .specialist)
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

            Button {
                Task { await createAssignment() }
            } label: {
                Text("assignedHomework.create.button")
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .fill(canCreate
                                ? ColorTokens.Spec.accent
                                : ColorTokens.Spec.line)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canCreate)
            .accessibilityHint(Text("assignedHomework.create.hint"))
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
                    .lineLimit(2)
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
                ForEach(load.assignments) { row in
                    assignmentRow(row)
                }
            }
        }
    }

    private func assignmentRow(
        _ row: AssignedHomeworkModels.Load.AssignmentRowViewModel
    ) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            Image(systemName: row.isComplete
                ? "checkmark.seal.fill"
                : "tray.full.fill")
                .font(.title3)
                .foregroundStyle(row.isComplete
                    ? ColorTokens.Semantic.success
                    : ColorTokens.Spec.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.childName)
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Spec.ink)
                Text(row.exerciseCountLabel + " · " + row.dueLabel)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                Text(row.statusLabel)
                    .font(TypographyTokens.caption(12).weight(.medium))
                    .foregroundStyle(row.isComplete
                        ? ColorTokens.Semantic.success
                        : ColorTokens.Spec.accent)
            }
            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Spec.panel)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(row.accessibilityLabel + ". " + row.statusLabel))
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
                childRepository: container.childRepository
            )
            let interactor = AssignedHomeworkInteractor(
                specialistId: specialistId,
                worker: worker,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = AssignedHomeworkRouter(dismissAction: { dismiss() })
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
}

// MARK: - Preview

#if DEBUG
#Preview("AssignedHomework / specialist") {
    AssignedHomeworkView(specialistId: "specialist-default")
        .environment(AppContainer.preview())
}
#endif
