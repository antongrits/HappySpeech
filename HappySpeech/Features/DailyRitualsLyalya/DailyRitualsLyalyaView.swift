import OSLog
import SwiftUI

// MARK: - DailyRitualsLyalyaViewModelHolder

@MainActor
@Observable
final class DailyRitualsLyalyaViewModelHolder: DailyRitualsLyalyaDisplayLogic {
    var loadVM: DailyRitualsLyalyaModels.Load.ViewModel?
    var lastPermissionGranted: Bool?
    var authorizationRequestNeeded: Bool = false

    func displayLoad(viewModel: DailyRitualsLyalyaModels.Load.ViewModel) async {
        self.loadVM = viewModel
    }

    func displayToggleReminder(response: DailyRitualsLyalyaModels.ToggleReminder.Response) async {
        authorizationRequestNeeded = response.authorizationNeeded
    }

    func displayUpdateTime(response: DailyRitualsLyalyaModels.UpdateTime.Response) async {
        // Refresh handled by reload in interactor.
    }

    func displayPermissionResult(response: DailyRitualsLyalyaModels.RequestPermission.Response) async {
        lastPermissionGranted = response.granted
        authorizationRequestNeeded = false
    }
}

// MARK: - DailyRitualsLyalyaView (Clean Swift: View)
//
// v31 Волна A, Функция Ф8 «Утро и вечер с Лялей».
//
// Layout:
//   1. Hero: иконка солнца/луны, заголовок и подзаголовок
//   2. Карточка с шагами ритуала (4 утром / 3 вечером)
//   3. Настройка локального напоминания: toggle + time picker
//   4. Авторизация уведомлений: CTA, если разрешения не выданы
//
// Accessibility:
//   • VoiceOver: combined labels по шагам, time picker через DatePicker (бесплатно)
//   • Dynamic Type: ScrollView root, .lineLimit(nil) + .fixedSize по вертикали
//   • Reduced Motion: переходы без spring
//   • Touch targets: toggles/buttons ≥ 56pt
//   • Light + Dark: ColorTokens

struct DailyRitualsLyalyaView: View {

    let kind: RitualKind

    @State private var holder = DailyRitualsLyalyaViewModelHolder()
    @State private var interactor: DailyRitualsLyalyaInteractor?
    @State private var presenter: DailyRitualsLyalyaPresenter?
    @State private var router: DailyRitualsLyalyaRouter?
    @State private var pickerDate: Date = Date()

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "DailyRituals.View"
    )

    init(kind: RitualKind = .morning) {
        self.kind = kind
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: SpacingTokens.sp5) {
                        if let viewModel = holder.loadVM {
                            heroSection(viewModel)
                            stepsSection(viewModel.steps, totalLabel: viewModel.totalMinutesLabel)
                            reminderSection(viewModel)
                        } else {
                            loadingSection
                        }
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.vertical, SpacingTokens.sp4)
                }
            }
            .navigationTitle(Text("dailyRituals.screen.title"))
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
                    .accessibilityLabel(Text("dailyRituals.close.a11y"))
                }
            }
            .task {
                await setupAndLoad()
            }
        }
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Hero

    private func heroSection(
        _ viewModel: DailyRitualsLyalyaModels.Load.ViewModel
    ) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.sp3) {
            Image(systemName: viewModel.symbolName)
                .font(.system(size: 38))
                .foregroundStyle(
                    viewModel.kind == .morning
                        ? ColorTokens.Brand.butter
                        : ColorTokens.Brand.lilac
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text(viewModel.title)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(viewModel.subtitle)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
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

    // MARK: - Steps

    private func stepsSection(
        _ steps: [DailyRitualsLyalyaModels.Load.StepViewModel],
        totalLabel: String
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            HStack {
                Text("dailyRituals.steps.sectionTitle")
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Parent.ink)
                Spacer()
                Text(totalLabel)
                    .font(TypographyTokens.caption(12).monospacedDigit())
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
            }
            VStack(spacing: SpacingTokens.sp2) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    stepRow(step, index: index + 1)
                }
            }
        }
    }

    private func stepRow(
        _ step: DailyRitualsLyalyaModels.Load.StepViewModel,
        index: Int
    ) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.sp3) {
            Text("\(index)")
                .font(TypographyTokens.body(14).weight(.bold).monospacedDigit())
                .foregroundStyle(ColorTokens.Brand.primary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(ColorTokens.Brand.primary.opacity(0.12)))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.sp2) {
                    Image(systemName: step.symbolName)
                        .font(.caption)
                        .foregroundStyle(ColorTokens.Parent.inkSoft)
                        .accessibilityHidden(true)
                    Text(step.title)
                        .font(TypographyTokens.body(15).weight(.semibold))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(step.description)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Text(step.durationLabel)
                    .font(TypographyTokens.caption(11).monospacedDigit())
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.sm)
                .fill(ColorTokens.Parent.surface)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(step.accessibilityLabel))
    }

    // MARK: - Reminder

    private func reminderSection(
        _ viewModel: DailyRitualsLyalyaModels.Load.ViewModel
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            Text("dailyRituals.reminder.sectionTitle")
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Parent.ink)

            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                Toggle(isOn: Binding(
                    get: { viewModel.reminderEnabled },
                    set: { newValue in
                        Task {
                            await interactor?.toggleReminder(
                                request: .init(kind: viewModel.kind, isEnabled: newValue)
                            )
                            if holder.authorizationRequestNeeded {
                                await interactor?.requestPermission(
                                    request: .init(kind: viewModel.kind)
                                )
                            }
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.reminderToggleLabel)
                            .font(TypographyTokens.body(15).weight(.medium))
                            .foregroundStyle(ColorTokens.Parent.ink)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(viewModel.reminderToggleSubtitle)
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(minHeight: 56)
                .tint(ColorTokens.Brand.primary)

                if viewModel.reminderEnabled {
                    timePickerRow(viewModel: viewModel)
                }

                if viewModel.needsAuthorization {
                    authorizationCTA(viewModel: viewModel)
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
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: viewModel.reminderEnabled)
    }

    private func timePickerRow(
        viewModel: DailyRitualsLyalyaModels.Load.ViewModel
    ) -> some View {
        HStack {
            Text("dailyRituals.reminder.timeLabel")
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Parent.ink)
            Spacer()
            DatePicker(
                "",
                selection: Binding(
                    get: {
                        let calendar = Calendar.current
                        var comps = calendar.dateComponents([.year, .month, .day], from: Date())
                        comps.hour = viewModel.reminderTime.hour
                        comps.minute = viewModel.reminderTime.minute
                        return calendar.date(from: comps) ?? Date()
                    },
                    set: { newDate in
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                        let time = ReminderTime(
                            hour: comps.hour ?? viewModel.reminderTime.hour,
                            minute: comps.minute ?? viewModel.reminderTime.minute
                        )
                        Task {
                            await interactor?.updateTime(
                                request: .init(kind: viewModel.kind, time: time)
                            )
                        }
                    }
                ),
                displayedComponents: [.hourAndMinute]
            )
            .labelsHidden()
            .accessibilityLabel(Text("dailyRituals.reminder.timePicker.a11y"))
        }
        .frame(minHeight: 56)
    }

    private func authorizationCTA(
        viewModel: DailyRitualsLyalyaModels.Load.ViewModel
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            Text("dailyRituals.reminder.authorize.note")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Task {
                    await interactor?.requestPermission(
                        request: .init(kind: viewModel.kind)
                    )
                }
            } label: {
                Text(viewModel.authorizationCtaLabel)
                    .font(TypographyTokens.body(14).weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(ColorTokens.Brand.primary)
        }
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ProgressView()
                .controlSize(.large)
            Text("dailyRituals.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SpacingTokens.sp10)
    }

    // MARK: - Wiring

    private func setupAndLoad() async {
        if interactor == nil {
            let worker = DailyRitualsLyalyaWorker()
            let presenter = DailyRitualsLyalyaPresenter(displayLogic: holder)
            let interactor = DailyRitualsLyalyaInteractor(worker: worker)
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = DailyRitualsLyalyaRouter(dismissAction: { dismiss() })
        }
        await interactor?.load(request: .init(kind: kind))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("DailyRituals / morning") {
    DailyRitualsLyalyaView(kind: .morning)
        .environment(AppContainer.preview())
}

#Preview("DailyRituals / evening") {
    DailyRitualsLyalyaView(kind: .evening)
        .environment(AppContainer.preview())
}
#endif
