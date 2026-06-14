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
// Тон месседжа — мягкий, без рассеивающего «нельзя!»; Ляля рекомендует
// вернуться завтра. Тёплый кремовый холст детского контура, без наказывающего
// красного/холодного синего. Соответствует project guide §11 «честные границы».

struct CapReachedView: View {

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showParentalGate: Bool = false
    @State private var mascotAppeared = false

    private static let logger = Logger(
        subsystem: "ru.happyspeech", category: "DailyTimeCap.CapReached"
    )

    var body: some View {
        ZStack {
            background
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: SpacingTokens.sp4) {
                        Spacer(minLength: SpacingTokens.sp6)
                        mascotSection
                        titleSection
                        messageSection
                        Spacer(minLength: SpacingTokens.sp6)
                        okButton
                        parentEscapeButton
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geo.size.height)
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.top, SpacingTokens.sp4)
                    .padding(.bottom, SpacingTokens.sp6)
                }
                .scrollBounceBehavior(.basedOnSize)
                .safeAreaPadding(.bottom, SpacingTokens.sp2)
            }
        }
        // Полноэкранный sheet НЕ dismissible swipe-down.
        .interactiveDismissDisabled(true)
        .sheet(isPresented: $showParentalGate) {
            ParentalGate(isPresented: $showParentalGate) {
                Self.logger.info("CapReached: parental gate passed → DailyTimeCap")
                coordinator.dismissSheet()
                coordinator.navigate(to: .dailyTimeCap)
            }
        }
        .environment(\.circuitContext, .kid)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Background

    /// Тёплый статичный кремовый холст детского контура + мягкий коралловый
    /// glow за маскотом. Без холодного синего/лилового на крупной заливке.
    private var background: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()
            HSMeshGradientBackground(palette: .kidWarm, animated: false)
                .ignoresSafeArea()
                .blendMode(.softLight)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
            RadialGradient(
                colors: [
                    ColorTokens.Brand.primaryLo.opacity(0.55),
                    Color.clear
                ],
                center: .init(x: 0.5, y: 0.34),
                startRadius: 8,
                endRadius: 260
            )
            .ignoresSafeArea()
            .accessibilityHidden(true)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Sections

    private var mascotSection: some View {
        ZStack(alignment: .topTrailing) {
            HSMascotView(mood: .idle, size: 188)
                .accessibilityHidden(true)
            // Мягкое «Zzz» — спокойный конец дня, ребёнок молодец.
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(ColorTokens.Brand.butter)
                .offset(x: 6, y: 8)
                .accessibilityHidden(true)
        }
        .padding(.top, SpacingTokens.sp4)
        .scaleEffect(mascotAppeared ? 1.0 : 0.7)
        .opacity(mascotAppeared ? 1.0 : 0.0)
        .animation(reduceMotion ? .none : MotionTokens.rewardPop, value: mascotAppeared)
        .onAppear {
            withAnimation(reduceMotion ? .none : MotionTokens.rewardPop) {
                mascotAppeared = true
            }
        }
    }

    private var titleSection: some View {
        Text(String(localized: "dailyTimeCap.reached.title"))
            .font(TypographyTokens.title(27))
            .foregroundStyle(ColorTokens.Kid.ink)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, SpacingTokens.sp2)
            .accessibilityAddTraits(.isHeader)
    }

    private var messageSection: some View {
        Text(String(localized: "dailyTimeCap.reached.message"))
            .font(TypographyTokens.body(17))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
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
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: ColorTokens.Brand.primary.opacity(0.34), radius: 16, y: 8)
                )
                .foregroundStyle(ColorTokens.Overlay.onAccent)
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
                    .font(TypographyTokens.body(14).weight(.semibold))
                    .underline()
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(ColorTokens.Brand.primary.opacity(0.9))
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, SpacingTokens.sp1)
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

#Preview("CapReached — Dark") {
    CapReachedView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
