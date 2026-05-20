import OSLog
import SwiftUI

// MARK: - SpecialistAssessmentViewModelHolder

@MainActor
@Observable
final class SpecialistAssessmentViewModelHolder: SpecialistAssessmentDisplayLogic {

    var loadVM: SpecialistAssessmentModels.Load.ViewModel?
    var currentIndex: Int = 0
    var answersByQuestion: [String: SpecialistAssessmentAnswer] = [:]
    var submitVM: SpecialistAssessmentModels.Submit.ViewModel?
    var isFinished: Bool = false

    func displayLoad(viewModel: SpecialistAssessmentModels.Load.ViewModel) async {
        loadVM = viewModel
        currentIndex = 0
        answersByQuestion = [:]
        submitVM = nil
        isFinished = false
    }

    func displaySubmit(viewModel: SpecialistAssessmentModels.Submit.ViewModel) async {
        submitVM = viewModel
        isFinished = true
    }
}

// MARK: - SpecialistAssessmentView
//
// v31 Волна D Ф.3 — пошаговая анкета специалиста (1 вопрос на экране).
//
// Accessibility:
//   • specialist circuit: ColorTokens.Spec.
//   • VoiceOver: каждый вариант — accessibilityLabel.
//   • Dynamic Type: minimumScaleFactor.
//   • Reduced Motion: переходы между вопросами гейтятся.

struct SpecialistAssessmentView: View {

    let childId: String
    let specialistId: String

    @State private var holder = SpecialistAssessmentViewModelHolder()
    @State private var interactor: SpecialistAssessmentInteractor?
    @State private var presenter: SpecialistAssessmentPresenter?
    @State private var router: SpecialistAssessmentRouter?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpecialistAssessment.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Spec.bg.ignoresSafeArea()
                content
            }
            .navigationTitle(Text("specAssessment.title"))
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
                    .accessibilityLabel(Text("specAssessment.close.a11y"))
                }
            }
            .task {
                await setup()
            }
        }
        .environment(\.circuitContext, .specialist)
    }

    @ViewBuilder
    private var content: some View {
        if holder.isFinished, let submit = holder.submitVM {
            summarySection(submit)
        } else if let load = holder.loadVM,
                  load.questions.indices.contains(holder.currentIndex) {
            questionSection(load.questions[holder.currentIndex],
                            total: load.questions.count)
        } else if (holder.loadVM?.questions.isEmpty) == true {
            emptySection
        } else {
            loadingSection
        }
    }

    // MARK: - Question

    private func questionSection(
        _ question: SpecialistAssessmentModels.Load.QuestionViewModel,
        total: Int
    ) -> some View {
        VStack(spacing: SpacingTokens.sp4) {
            progressBar(currentIndex: holder.currentIndex, total: total)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                Text(question.progressLabel)
                    .font(TypographyTokens.caption(13).monospacedDigit())
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                Text(question.text)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .accessibilityIdentifier("specAssessment.question.text")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SpacingTokens.screenEdge)

            Spacer(minLength: 0)

            VStack(spacing: SpacingTokens.sp3) {
                switch question.type {
                case .yesno:
                    yesNoButtons(for: question)
                case .scale:
                    scaleButtons(for: question)
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp5)
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35),
                   value: holder.currentIndex)
    }

    private func yesNoButtons(
        for question: SpecialistAssessmentModels.Load.QuestionViewModel
    ) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            answerButton(
                title: String(localized: "specAssessment.answer.yes"),
                isSelected: holder.answersByQuestion[question.id]?.boolValue == true,
                accent: ColorTokens.Brand.mint
            ) {
                Task { await answer(question: question, boolValue: true) }
            }
            .accessibilityIdentifier("specAssessment.yes")

            answerButton(
                title: String(localized: "specAssessment.answer.no"),
                isSelected: holder.answersByQuestion[question.id]?.boolValue == false,
                accent: ColorTokens.Brand.rose
            ) {
                Task { await answer(question: question, boolValue: false) }
            }
            .accessibilityIdentifier("specAssessment.no")
        }
    }

    private func scaleButtons(
        for question: SpecialistAssessmentModels.Load.QuestionViewModel
    ) -> some View {
        let scale = question.scale ?? SpecialistAssessmentScale(
            min: 1, max: 5, lowLabel: "", highLabel: ""
        )
        return VStack(spacing: SpacingTokens.sp2) {
            HStack {
                Text(scale.lowLabel)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                Spacer()
                Text(scale.highLabel)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
            }

            HStack(spacing: SpacingTokens.sp2) {
                ForEach(scale.min...scale.max, id: \.self) { value in
                    Button {
                        Task { await answer(question: question, numericValue: value) }
                    } label: {
                        Text("\(value)")
                            .font(TypographyTokens.headline(17).monospacedDigit())
                            .foregroundStyle(
                                holder.answersByQuestion[question.id]?.numericValue == value
                                ? ColorTokens.Overlay.onAccent
                                : ColorTokens.Spec.ink
                            )
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(
                                RoundedRectangle(cornerRadius: RadiusTokens.card)
                                    .fill(
                                        holder.answersByQuestion[question.id]?.numericValue == value
                                        ? ColorTokens.Spec.accent
                                        : ColorTokens.Spec.panel
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("specAssessment.scale.\(value)")
                    .accessibilityLabel(Text("\(value)"))
                }
            }
        }
    }

    private func answerButton(
        title: String,
        isSelected: Bool,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(TypographyTokens.headline(17))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(isSelected ? accent : accent.opacity(0.6))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Progress

    private func progressBar(currentIndex: Int, total: Int) -> some View {
        let fraction = total > 0 ? Double(currentIndex + 1) / Double(total) : 0
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(ColorTokens.Spec.panel)
                Capsule()
                    .fill(ColorTokens.Spec.accent)
                    .frame(width: max(0, geo.size.width * fraction))
            }
        }
        .frame(height: 8)
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.sp3)
        .accessibilityHidden(true)
    }

    // MARK: - Summary

    private func summarySection(
        _ submit: SpecialistAssessmentModels.Submit.ViewModel
    ) -> some View {
        ScrollView {
            VStack(spacing: SpacingTokens.sp4) {
                Image(systemName: submit.recommendedAxes.isEmpty
                      ? "checkmark.seal.fill"
                      : "target")
                    .font(.system(size: 64))
                    .foregroundStyle(ColorTokens.Spec.accent)
                    .padding(.top, SpacingTokens.sp4)

                Text(submit.title)
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                if submit.recommendedAxes.isEmpty {
                    Text("specAssessment.summary.empty")
                        .font(TypographyTokens.body(16))
                        .foregroundStyle(ColorTokens.Spec.inkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SpacingTokens.sp5)
                } else {
                    VStack(spacing: SpacingTokens.sp3) {
                        ForEach(submit.recommendedAxes) { axis in
                            axisCard(axis)
                        }
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)

                    Text(submit.validUntilLabel)
                        .font(TypographyTokens.caption(13))
                        .foregroundStyle(ColorTokens.Spec.inkMuted)
                        .padding(.horizontal, SpacingTokens.sp5)
                }

                Button {
                    dismiss()
                } label: {
                    Text(submit.applyCtaTitle)
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(ColorTokens.Spec.accent)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp5)
            }
        }
    }

    private func axisCard(
        _ axis: SpecialistAssessmentModels.Submit.RecommendedAxisViewModel
    ) -> some View {
        HSCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "bolt.heart.fill")
                    .font(TypographyTokens.subtitle(20))
                    .foregroundStyle(ColorTokens.Spec.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(axis.displayName)
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Spec.ink)
                    Text(axis.rationale)
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Spec.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.9)
                }
                Spacer(minLength: 0)
            }
            .padding(SpacingTokens.sp3)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(axis.displayName + ". " + axis.rationale))
    }

    // MARK: - Loading / empty

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ProgressView().controlSize(.large)
            Text("specAssessment.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptySection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            Image(systemName: "exclamationmark.bubble")
                .font(.system(size: 48))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
            Text("specAssessment.empty")
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Wiring / actions

    private func setup() async {
        if interactor == nil {
            let presenter = SpecialistAssessmentPresenter(displayLogic: holder)
            let worker = SpecialistAssessmentWorker(realmActor: container.realmActor)
            let interactor = SpecialistAssessmentInteractor(
                childId: childId,
                specialistId: specialistId,
                worker: worker
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = SpecialistAssessmentRouter(dismissAction: { dismiss() })
        }
        await interactor?.load(
            request: .init(childId: childId, specialistId: specialistId)
        )
    }

    private func answer(
        question: SpecialistAssessmentModels.Load.QuestionViewModel,
        boolValue: Bool? = nil,
        numericValue: Int? = nil
    ) async {
        let request = SpecialistAssessmentModels.Answer.Request(
            questionId: question.id,
            axis: question.axis,
            boolValue: boolValue,
            numericValue: numericValue
        )
        await interactor?.answer(request: request)
        // Локально храним для подсветки выбранного варианта.
        holder.answersByQuestion[question.id] = SpecialistAssessmentAnswer(
            questionId: question.id,
            axis: question.axis,
            boolValue: boolValue,
            numericValue: numericValue
        )
        await advance()
    }

    private func advance() async {
        guard let load = holder.loadVM else { return }
        let next = holder.currentIndex + 1
        if next >= load.questions.count {
            await interactor?.submit(
                request: .init(childId: childId, specialistId: specialistId)
            )
        } else {
            holder.currentIndex = next
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SpecialistAssessment") {
    SpecialistAssessmentView(childId: "preview-child-1", specialistId: "local-parent")
        .environment(AppContainer.preview())
}
#endif
