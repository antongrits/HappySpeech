import SwiftUI

// MARK: - StoryScenePainter
//
// Рендерит кадр сюжетной серии как лёгкую векторную сцену (Canvas) —
// COPPA-safe животные/предметы БЕЗ людей. Иллюстрации серий не зависят от
// фото-ассетов: каждая сцена — детерминированный рисунок в тёплой палитре,
// согласованной с open-design (cream-фон, зелёная трава, коралловые яблоки).
//
// Если у кадра есть `word_*`-ассет (один предмет) — View рендерит его поверх
// сцены; здесь же — самодостаточный сюжетный фон.

struct StoryScenePainter: View {

    let scene: StoryPictureScene
    /// Компактный режим (для ленты/подноса) — упрощённый рисунок.
    var compact: Bool = false

    var body: some View {
        Canvas { ctx, size in
            Self.draw(scene: scene, in: ctx, size: size, compact: compact)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Palette (тёплая, из open-design)

    private static let sky = Color(red: 1.0, green: 0.957, blue: 0.925)        // #FFF4EC
    private static let grass = Color(red: 0.851, green: 0.922, blue: 0.788)    // #D9EBC9
    private static let apple = Color(red: 0.886, green: 0.341, blue: 0.298)    // #E2574C
    private static let leaf = Color(red: 0.561, green: 0.725, blue: 0.420)     // #8FB96B
    private static let trunk = Color(red: 0.604, green: 0.416, blue: 0.251)    // #9A6A40
    private static let furDark = Color(red: 0.722, green: 0.541, blue: 0.353)  // #B88A5A
    private static let furLight = Color(red: 0.788, green: 0.604, blue: 0.416) // #C99A6A
    private static let sun = Color(red: 1.0, green: 0.890, blue: 0.604)        // #FFE39A
    private static let eye = Color(red: 0.227, green: 0.165, blue: 0.114)      // #3a2a1d
    private static let house = Color(red: 0.910, green: 0.769, blue: 0.604)    // #E8C49A
    private static let roof = Color(red: 0.780, green: 0.498, blue: 0.290)     // #C77F4A
    private static let milk = Color(red: 0.96, green: 0.96, blue: 0.99)
    private static let carrot = Color(red: 0.95, green: 0.55, blue: 0.20)
    private static let snow = Color(red: 0.92, green: 0.95, blue: 0.98)

    // MARK: - Draw dispatch

    static func draw(scene: StoryPictureScene, in ctx: GraphicsContext, size: CGSize, compact: Bool) {
        let w = size.width
        let h = size.height
        // Фон + земля (общие для всех сюжетов).
        ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)), with: .color(sky))
        let groundH = h * 0.22
        ctx.fill(Path(CGRect(x: 0, y: h - groundH, width: w, height: groundH)), with: .color(grass))

        switch scene {
        case .hedgehogSeesTree:   drawHedgehogTree(ctx, w, h, hedgehogX: 0.78, apples: true, shake: false)
        case .hedgehogShakesTree: drawHedgehogTree(ctx, w, h, hedgehogX: 0.45, apples: true, shake: true)
        case .hedgehogRollsApple: drawHedgehogWithApple(ctx, w, h)
        case .hedgehogCarriesHome: drawHedgehogHome(ctx, w, h)
        case .kittenSeesMilk:     drawKitten(ctx, w, h, withMilk: true, sleeping: false, drinking: false)
        case .kittenDrinks:       drawKitten(ctx, w, h, withMilk: true, sleeping: false, drinking: true)
        case .kittenSleeps:       drawKitten(ctx, w, h, withMilk: false, sleeping: true, drinking: false)
        case .squirrelFindsNut:   drawSquirrel(ctx, w, h, stage: 0)
        case .squirrelClimbs:     drawSquirrel(ctx, w, h, stage: 1)
        case .squirrelHidesNut:   drawSquirrel(ctx, w, h, stage: 2)
        case .squirrelWinter:     drawSquirrel(ctx, w, h, stage: 3)
        case .bunnyDigs:          drawBunny(ctx, w, h, stage: 0)
        case .bunnyWaters:        drawBunny(ctx, w, h, stage: 1)
        case .bunnyHarvest:       drawBunny(ctx, w, h, stage: 2)
        case .generic:            drawGeneric(ctx, w, h)
        }
    }

    // MARK: - Primitives

    private static func ellipse(_ ctx: GraphicsContext, _ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ color: Color) {
        let rect = CGRect(x: x - rx, y: y - ry, width: rx * 2, height: ry * 2)
        ctx.fill(Path(ellipseIn: rect), with: .color(color))
    }

    private static func circle(_ ctx: GraphicsContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ color: Color) {
        ellipse(ctx, x, y, r, r, color)
    }

    /// Иглы ёжика (короткие штрихи).
    private static func spikes(_ ctx: GraphicsContext, cx: CGFloat, cy: CGFloat, scale: CGFloat) {
        var p = Path()
        for i in -3...3 {
            let dx = CGFloat(i) * 6 * scale
            p.move(to: CGPoint(x: cx + dx, y: cy))
            p.addLine(to: CGPoint(x: cx + dx + 2 * scale, y: cy - 12 * scale))
        }
        ctx.stroke(p, with: .color(Color(red: 0.541, green: 0.376, blue: 0.220)), lineWidth: 2.4 * scale)
    }

    // MARK: - Hedgehog scenes

    private static func appleTree(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, cx: CGFloat, apples: Bool) {
        let crownR = w * 0.20
        ellipse(ctx, cx, h * 0.36, crownR, crownR * 1.05, leaf)
        ctx.fill(Path(CGRect(x: cx - w * 0.018, y: h * 0.50, width: w * 0.036, height: h * 0.22)), with: .color(trunk))
        if apples {
            circle(ctx, cx - crownR * 0.5, h * 0.32, w * 0.022, apple)
            circle(ctx, cx + crownR * 0.45, h * 0.40, w * 0.022, apple)
            circle(ctx, cx, h * 0.26, w * 0.022, apple)
        }
    }

    private static func hedgehog(_ ctx: GraphicsContext, cx: CGFloat, cy: CGFloat, bodyR: CGFloat, scale: CGFloat) {
        ellipse(ctx, cx, cy, bodyR, bodyR * 0.72, furDark)
        spikes(ctx, cx: cx, cy: cy - bodyR * 0.4, scale: scale)
        circle(ctx, cx - bodyR * 0.7, cy, bodyR * 0.42, furLight)        // мордочка
        circle(ctx, cx - bodyR * 0.78, cy - bodyR * 0.12, bodyR * 0.07, eye)
        circle(ctx, cx - bodyR * 0.98, cy + bodyR * 0.05, bodyR * 0.08, Color(red: 0.2, green: 0.15, blue: 0.1))
    }

    private static func drawHedgehogTree(_ ctx: GraphicsContext, _ w: CGFloat, _ h: CGFloat, hedgehogX: CGFloat, apples: Bool, shake: Bool) {
        circle(ctx, w * 0.86, h * 0.16, w * 0.06, sun)
        appleTree(ctx, w: w, h: h, cx: w * 0.42, apples: apples)
        if shake {
            // Падающие яблоки.
            circle(ctx, w * 0.30, h * 0.62, w * 0.018, apple)
            circle(ctx, w * 0.54, h * 0.64, w * 0.018, apple)
        }
        hedgehog(ctx, cx: w * hedgehogX, cy: h * 0.74, bodyR: w * 0.11, scale: w / 320)
    }

    private static func drawHedgehogWithApple(_ ctx: GraphicsContext, _ w: CGFloat, _ h: CGFloat) {
        hedgehog(ctx, cx: w * 0.46, cy: h * 0.70, bodyR: w * 0.13, scale: w / 320)
        // Яблоко на спинке.
        circle(ctx, w * 0.52, h * 0.50, w * 0.04, apple)
        ctx.fill(Path(CGRect(x: w * 0.515, y: h * 0.43, width: w * 0.01, height: h * 0.05)), with: .color(trunk))
    }

    private static func drawHedgehogHome(_ ctx: GraphicsContext, _ w: CGFloat, _ h: CGFloat) {
        // Домик-норка.
        let hx = w * 0.70
        ctx.fill(Path(CGRect(x: hx, y: h * 0.40, width: w * 0.22, height: h * 0.34)), with: .color(house))
        var roofPath = Path()
        roofPath.move(to: CGPoint(x: hx - w * 0.02, y: h * 0.40))
        roofPath.addLine(to: CGPoint(x: hx + w * 0.11, y: h * 0.22))
        roofPath.addLine(to: CGPoint(x: hx + w * 0.24, y: h * 0.40))
        roofPath.closeSubpath()
        ctx.fill(roofPath, with: .color(roof))
        hedgehog(ctx, cx: w * 0.30, cy: h * 0.72, bodyR: w * 0.11, scale: w / 320)
        circle(ctx, w * 0.36, h * 0.56, w * 0.035, apple)
    }

    // MARK: - Kitten scenes

    private static func kitten(_ ctx: GraphicsContext, cx: CGFloat, cy: CGFloat, r: CGFloat, sleeping: Bool) {
        let cat = Color(red: 0.80, green: 0.70, blue: 0.58)
        ellipse(ctx, cx, cy, r, r * 0.8, cat)
        circle(ctx, cx, cy - r * 0.7, r * 0.55, cat)
        // Ушки.
        var ears = Path()
        ears.move(to: CGPoint(x: cx - r * 0.5, y: cy - r * 0.95))
        ears.addLine(to: CGPoint(x: cx - r * 0.3, y: cy - r * 1.3))
        ears.addLine(to: CGPoint(x: cx - r * 0.1, y: cy - r * 1.0))
        ears.move(to: CGPoint(x: cx + r * 0.5, y: cy - r * 0.95))
        ears.addLine(to: CGPoint(x: cx + r * 0.3, y: cy - r * 1.3))
        ears.addLine(to: CGPoint(x: cx + r * 0.1, y: cy - r * 1.0))
        ctx.fill(ears, with: .color(cat))
        if sleeping {
            var eyes = Path()
            eyes.move(to: CGPoint(x: cx - r * 0.3, y: cy - r * 0.7))
            eyes.addQuadCurve(to: CGPoint(x: cx - r * 0.1, y: cy - r * 0.7), control: CGPoint(x: cx - r * 0.2, y: cy - r * 0.58))
            eyes.move(to: CGPoint(x: cx + r * 0.1, y: cy - r * 0.7))
            eyes.addQuadCurve(to: CGPoint(x: cx + r * 0.3, y: cy - r * 0.7), control: CGPoint(x: cx + r * 0.2, y: cy - r * 0.58))
            ctx.stroke(eyes, with: .color(eye), lineWidth: 2)
        } else {
            circle(ctx, cx - r * 0.2, cy - r * 0.72, r * 0.08, eye)
            circle(ctx, cx + r * 0.2, cy - r * 0.72, r * 0.08, eye)
        }
    }

    private static func drawKitten(_ ctx: GraphicsContext, _ w: CGFloat, _ h: CGFloat, withMilk: Bool, sleeping: Bool, drinking: Bool) {
        if withMilk {
            // Блюдце с молоком.
            ellipse(ctx, w * 0.72, h * 0.74, w * 0.10, h * 0.04, Color(red: 0.85, green: 0.85, blue: 0.88))
            ellipse(ctx, w * 0.72, h * 0.73, w * 0.075, h * 0.025, milk)
        }
        let cy = sleeping ? h * 0.72 : h * 0.66
        kitten(ctx, cx: w * 0.36, cy: cy, r: w * 0.11, sleeping: sleeping)
        if drinking {
            // Наклон к блюдцу — язычок.
            var tongue = Path()
            tongue.move(to: CGPoint(x: w * 0.47, y: h * 0.70))
            tongue.addLine(to: CGPoint(x: w * 0.55, y: h * 0.73))
            ctx.stroke(tongue, with: .color(Color(red: 0.95, green: 0.55, blue: 0.6)), lineWidth: 3)
        }
        if sleeping {
            // Зззз.
            let z = Text("z z z").font(.system(size: w * 0.05, weight: .bold)).foregroundColor(eye.opacity(0.5))
            ctx.draw(z, at: CGPoint(x: w * 0.5, y: h * 0.4))
        }
    }

    // MARK: - Squirrel scenes

    private static func squirrel(_ ctx: GraphicsContext, cx: CGFloat, cy: CGFloat, r: CGFloat) {
        let fur = Color(red: 0.78, green: 0.45, blue: 0.25)
        // Хвост.
        ellipse(ctx, cx + r * 0.9, cy - r * 0.3, r * 0.5, r * 0.9, fur)
        ellipse(ctx, cx, cy, r, r * 0.85, fur)
        circle(ctx, cx - r * 0.5, cy - r * 0.6, r * 0.45, fur)
        circle(ctx, cx - r * 0.6, cy - r * 0.7, r * 0.08, eye)
        // Ушко.
        circle(ctx, cx - r * 0.4, cy - r * 1.0, r * 0.16, fur)
    }

    private static func drawSquirrel(_ ctx: GraphicsContext, _ w: CGFloat, _ h: CGFloat, stage: Int) {
        switch stage {
        case 0:
            squirrel(ctx, cx: w * 0.40, cy: h * 0.66, r: w * 0.10)
            circle(ctx, w * 0.25, h * 0.74, w * 0.025, Color(red: 0.62, green: 0.45, blue: 0.30)) // орех
        case 1:
            appleTree(ctx, w: w, h: h, cx: w * 0.70, apples: false)
            squirrel(ctx, cx: w * 0.40, cy: h * 0.60, r: w * 0.09)
            circle(ctx, w * 0.34, h * 0.55, w * 0.022, Color(red: 0.62, green: 0.45, blue: 0.30))
        case 2:
            appleTree(ctx, w: w, h: h, cx: w * 0.55, apples: false)
            // Дупло.
            ellipse(ctx, w * 0.55, h * 0.42, w * 0.035, h * 0.05, Color(red: 0.35, green: 0.25, blue: 0.16))
            squirrel(ctx, cx: w * 0.42, cy: h * 0.50, r: w * 0.08)
        default:
            // Зима: снег.
            ctx.fill(Path(CGRect(x: 0, y: h - h * 0.22, width: w, height: h * 0.22)), with: .color(snow))
            for i in 0..<10 {
                circle(ctx, w * CGFloat(i) / 10 + w * 0.05, h * (0.2 + CGFloat(i % 3) * 0.1), w * 0.008, .white)
            }
            squirrel(ctx, cx: w * 0.45, cy: h * 0.66, r: w * 0.10)
            circle(ctx, w * 0.30, h * 0.72, w * 0.022, Color(red: 0.62, green: 0.45, blue: 0.30))
        }
    }

    // MARK: - Bunny scenes

    private static func bunny(_ ctx: GraphicsContext, cx: CGFloat, cy: CGFloat, r: CGFloat) {
        let fur = Color(red: 0.88, green: 0.85, blue: 0.80)
        ellipse(ctx, cx, cy, r, r * 0.85, fur)
        circle(ctx, cx, cy - r * 0.8, r * 0.5, fur)
        // Уши.
        ellipse(ctx, cx - r * 0.2, cy - r * 1.5, r * 0.12, r * 0.5, fur)
        ellipse(ctx, cx + r * 0.2, cy - r * 1.5, r * 0.12, r * 0.5, fur)
        circle(ctx, cx - r * 0.18, cy - r * 0.85, r * 0.07, eye)
        circle(ctx, cx + r * 0.18, cy - r * 0.85, r * 0.07, eye)
    }

    private static func drawBunny(_ ctx: GraphicsContext, _ w: CGFloat, _ h: CGFloat, stage: Int) {
        // Грядка.
        ctx.fill(Path(CGRect(x: w * 0.55, y: h * 0.70, width: w * 0.35, height: h * 0.08)), with: .color(Color(red: 0.45, green: 0.32, blue: 0.20)))
        bunny(ctx, cx: w * 0.30, cy: h * 0.66, r: w * 0.10)
        switch stage {
        case 0:
            // Ботва на грядке.
            for i in 0..<3 {
                let x = w * (0.62 + CGFloat(i) * 0.08)
                ctx.stroke(Path { p in p.move(to: CGPoint(x: x, y: h * 0.70)); p.addLine(to: CGPoint(x: x, y: h * 0.62)) }, with: .color(leaf), lineWidth: 3)
            }
        case 1:
            // Лейка-капли.
            for i in 0..<4 {
                circle(ctx, w * (0.60 + CGFloat(i) * 0.06), h * 0.58, w * 0.008, Color(red: 0.4, green: 0.6, blue: 0.9))
            }
        default:
            // Большая морковка в лапках.
            var car = Path()
            car.move(to: CGPoint(x: w * 0.42, y: h * 0.55))
            car.addLine(to: CGPoint(x: w * 0.50, y: h * 0.58))
            car.addLine(to: CGPoint(x: w * 0.42, y: h * 0.66))
            car.closeSubpath()
            ctx.fill(car, with: .color(carrot))
            ctx.stroke(Path { p in p.move(to: CGPoint(x: w * 0.42, y: h * 0.55)); p.addLine(to: CGPoint(x: w * 0.40, y: h * 0.48)) }, with: .color(leaf), lineWidth: 3)
        }
    }

    // MARK: - Generic fallback

    private static func drawGeneric(_ ctx: GraphicsContext, _ w: CGFloat, _ h: CGFloat) {
        appleTree(ctx, w: w, h: h, cx: w * 0.5, apples: true)
    }
}
