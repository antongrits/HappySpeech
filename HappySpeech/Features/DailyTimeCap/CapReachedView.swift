import OSLog
import SwiftUI

// MARK: - CapReachedView
//
// Полноэкранный sheet, который показывается ребёнку при превышении
// дневного лимита HappySpeech. Не dismissible тапом или жестом — единственный
// «выход» — кнопка «Я родитель», открывающая ParentalGate → DailyTimeCapView.
//
// CTO-decision: НИКАКИХ `exit(0)` / `UIApplication.suspend()` трюков —
// App Review их режет. Ребёнок может закрыть приложение жестом Home/swipe-up,
// что является естественным поведением iOS.
//
// Тон месседжа — мягкий, без рассеивающего «нельзя!»; Лялина рекомендует
// вернуться завтра. Соответствует CLAUDE.md §11 «честные границы».

struct CapReachedView: View {

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showParentalGate: Bool = false

    private static let logger = Logger(
        subsystem: "ru.happyspeech", category: "DailyTimeCap.CapReached"
    )

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: SpacingTokens.sp4) {
                Spacer(minLength: SpacingTokens.sp8)
                mascotSection
                titleSection
                messageSection
                Spacer(minLength: SpacingTokens.sp6)
                okButton
                parentEscapeButton
                    .padding(.bottom, SpacingTokens.sp4)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        // Полноэкранный sheet НЕ dismissible swipe-down.
        .interactiveDismissDisabled(true)
        .sheet(isPresented: $showParentalGate) {
            ParentalGate(isPresented: $showParentalGate) {
                Self.logger.info("CapReached: parental gate passed → DailyTimeCap")
                // Закрываем sheet, переходим на parent-настройки.
                coordinator.dismissSheet()
                coordinator.navigate(to: .dailyTimeCap)
            }
        }
        .environment(\.circuitContext, .kid)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Sections

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                ColorTokens.Brand.sky.opacity(0.85),
                ColorTokens.Brand.lilac.opacity(0.55),
                ColorTokens.Kid.bgSoft
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var mascotSection: some View {
        HSMascotView(mood: .waving, size: 180)
            .accessibilityHidden(true)
            .padding(.top, SpacingTokens.sp4)
    }

    private var titleSection: some View {
        Text(String(localized: "dailyTimeCap.reached.title"))
            .font(TypographyTokens.title(26))
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, SpacingTokens.sp2)
            .accessibilityAddTraits(.isHeader)
    }

    private var messageSection: some View {
        Text(String(localized: "dailyTimeCap.reached.message"))
            .font(TypographyTokens.body(17))
            .foregroundStyle(ColorTokens.Overlay.onAccent.opacity(0.92))
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, SpacingTokens.sp4)
    }

    private var okButton: some View {
        Button {
            // Безопасная no-op: ребёнок остаётся на CapReachedView. Может закрыть
            // приложение естественным жестом iOS (swipe-up / Home). Это сознательное
            // решение — НЕ суспендим программно (App Review reject).
            Self.logger.info("CapReached: child tapped OK — staying on screen")
        } label: {
            Text(String(localized: "dailyTimeCap.reached.ok"))
                .font(TypographyTokens.headline(19))
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(ColorTokens.Overlay.onAccent)
                )
                .foregroundStyle(ColorTokens.Brand.primary)
        }
        .buttonStyle(.plain)
        .accessibilityHint(String(localized: "dailyTimeCap.reached.ok.a11y_hint"))
    }

    private var parentEscapeButton: some View {
        Button {
            Self.logger.info("CapReached: parental gate requested")
            showParentalGate = true
        } label: {
            HStack(spacing: SpacingTokens.sp1) {
                Image(systemName: "person.2.fill")
                    .accessibilityHidden(true)
                Text(String(localized: "dailyTimeCap.reached.parent"))
                    .font(TypographyTokens.body(14))
                    .underline()
            }
            .foregroundStyle(ColorTokens.Overlay.onAccent.opacity(0.82))
            .padding(.vertical, SpacingTokens.sp2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "dailyTimeCap.reached.parent.a11y"))
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Preview

#Preview("CapReached — Light") {
    CapReachedView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}
